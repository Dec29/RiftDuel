package main

import (
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type Status struct {
	Phase      string `json:"phase"`
	Message    string `json:"message"`
	Current    int    `json:"current"`
	Latest     int    `json:"latest"`
	Notes      string `json:"notes"`
	Downloaded int64  `json:"downloaded"`
	Total      int64  `json:"total"`
}
type Reporter struct {
	Path  string
	Value Status
}

func (r *Reporter) write(phase, message string) {
	r.Value.Phase = phase
	r.Value.Message = message
	_ = atomicJSON(r.Path, r.Value)
}

var webClient = &http.Client{Timeout: 10 * time.Minute}
var manifestKey = trustedKey()

func request(ctx context.Context, url string) (*http.Response, error) {
	req, e := http.NewRequestWithContext(ctx, "GET", url, nil)
	if e != nil {
		return nil, e
	}
	req.Header.Set("User-Agent", "RiftDuelUpdater/1")
	req.Header.Set("Accept", "application/vnd.github+json")
	resp, e := webClient.Do(req)
	if e != nil {
		return nil, e
	}
	if resp.StatusCode != 200 {
		resp.Body.Close()
		return nil, fmt.Errorf("下载服务返回 %d", resp.StatusCode)
	}
	return resp, nil
}
func smallGET(ctx context.Context, url string, limit int64) ([]byte, error) {
	resp, e := request(ctx, url)
	if e != nil {
		return nil, e
	}
	defer resp.Body.Close()
	b, e := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if int64(len(b)) > limit {
		return nil, errors.New("更新响应过大")
	}
	return b, e
}
func artifactURL(tag, name string) string {
	return "https://github.com/" + repository + "/releases/download/" + tag + "/" + name
}
func checkUpdates(ctx context.Context, dir, job string, r *Reporter) error {
	r.Value.Current = readVersion(dir).Version
	r.write("checking", "正在检查新版本…")
	ctx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	data, e := smallGET(ctx, "https://api.github.com/repos/"+repository+"/releases?per_page=30", 2<<20)
	if e != nil {
		return e
	}
	var releases []struct {
		Tag    string `json:"tag_name"`
		Draft  bool   `json:"draft"`
		Assets []struct {
			Name string `json:"name"`
		} `json:"assets"`
	}
	if e = json.Unmarshal(data, &releases); e != nil {
		return e
	}
	var newest Manifest
	var envelope []byte
	for _, release := range releases {
		if release.Draft || !tagRE.MatchString(release.Tag) {
			continue
		}
		has := false
		for _, a := range release.Assets {
			if a.Name == manifestAsset {
				has = true
			}
		}
		if !has {
			continue
		}
		b, err := smallGET(ctx, artifactURL(release.Tag, manifestAsset), 2<<20)
		if err != nil {
			return err
		}
		m, err := decodeEnvelope(b, manifestKey)
		if err != nil {
			return err
		}
		if m.Tag != release.Tag {
			return errors.New("发布标签与签名版本不符")
		}
		if m.Version > newest.Version {
			newest = m
			envelope = b
		}
	}
	if newest.Version == 0 {
		r.write("current", "当前发布渠道暂无新的自动更新包")
		return nil
	}
	r.Value.Latest = newest.Version
	r.Value.Notes = newest.Notes
	if newest.Version <= r.Value.Current {
		r.write("current", "已是最新版本")
		return nil
	}
	if e = atomicBytes(filepath.Join(job, "manifest.json"), envelope); e != nil {
		return e
	}
	r.Value.Total = plannedBytes(dir, newest)
	r.write("available", fmt.Sprintf("发现新版本 M%d", newest.Version))
	return nil
}
func chooseArtifact(dir string, f FileSpec) (Artifact, bool) {
	h, _ := fileDigest(filepath.Join(dir, filepath.FromSlash(f.Path)))
	for _, d := range f.Deltas {
		if d.Base == h && d.Artifact.Size < f.Full.Size {
			return d.Artifact, true
		}
	}
	return f.Full, false
}
func plannedBytes(dir string, m Manifest) int64 {
	var total int64
	for _, f := range m.Files {
		if !matches(filepath.Join(dir, filepath.FromSlash(f.Path)), f) {
			a, _ := chooseArtifact(dir, f)
			total += a.Size
		}
	}
	return total
}
func downloadArtifact(ctx context.Context, url, p string, a Artifact, r *Reporter) error {
	resp, e := request(ctx, url)
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.ContentLength >= 0 && resp.ContentLength != a.Size {
		return errors.New("附件长度与签名不符")
	}
	if e = os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		return e
	}
	f, e := os.Create(p)
	if e != nil {
		return e
	}
	defer f.Close()
	h := sha256.New()
	buf := make([]byte, 128<<10)
	var n int64
	last := time.Now()
	for {
		count, err := resp.Body.Read(buf)
		if count > 0 {
			n += int64(count)
			if n > a.Size {
				return errors.New("附件超过签名长度")
			}
			if _, e = f.Write(buf[:count]); e != nil {
				return e
			}
			h.Write(buf[:count])
			r.Value.Downloaded += int64(count)
			if time.Since(last) > 200*time.Millisecond {
				r.write("downloading", "正在下载更新…")
				last = time.Now()
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	if n != a.Size || hex.EncodeToString(h.Sum(nil)) != a.SHA {
		return errors.New("更新附件校验失败")
	}
	return f.Sync()
}
func expandGzip(in, out string, size int64) error {
	f, e := os.Open(in)
	if e != nil {
		return e
	}
	defer f.Close()
	z, e := gzip.NewReader(f)
	if e != nil {
		return e
	}
	defer z.Close()
	o, e := os.Create(out)
	if e != nil {
		return e
	}
	defer o.Close()
	n, e := io.Copy(o, io.LimitReader(z, size+1))
	if e != nil {
		return e
	}
	if n != size {
		return errors.New("更新解压长度不符")
	}
	return o.Sync()
}
func loadManifest(job string) (Manifest, []byte, error) {
	b, e := os.ReadFile(filepath.Join(job, "manifest.json"))
	if e != nil {
		return Manifest{}, nil, e
	}
	m, e := decodeEnvelope(b, manifestKey)
	return m, b, e
}
func stageUpdate(ctx context.Context, dir, job string, r *Reporter) error {
	m, _, e := loadManifest(job)
	if e != nil {
		return e
	}
	current := readVersion(dir).Version
	if m.Version <= current {
		return errors.New("更新版本不高于当前版本")
	}
	r.Value.Current = current
	r.Value.Latest = m.Version
	r.Value.Notes = m.Notes
	r.Value.Total = plannedBytes(dir, m)
	r.Value.Downloaded = 0
	for i, f := range m.Files {
		dest, e := safePath(dir, f.Path)
		if e != nil {
			return e
		}
		if matches(dest, f) {
			continue
		}
		r.write("downloading", fmt.Sprintf("正在准备更新 %d/%d", i+1, len(m.Files)))
		a, delta := chooseArtifact(dir, f)
		asset := filepath.Join(job, fmt.Sprintf("download-%d", i))
		staged := filepath.Join(job, "files", filepath.FromSlash(f.Path))
		if e = os.MkdirAll(filepath.Dir(staged), 0700); e != nil {
			return e
		}
		if !matches(staged, f) {
			if e = downloadArtifact(ctx, artifactURL(m.Tag, a.Name), asset, a, r); e != nil {
				return e
			}
			r.write("verifying", "正在校验并准备安装…")
			if delta {
				e = applyDelta(dest, asset, staged, f.Size)
			} else {
				e = expandGzip(asset, staged, f.Size)
			}
			if e != nil {
				return e
			}
			if !matches(staged, f) {
				return errors.New("重建文件校验失败：" + f.Path)
			}
		}
		_ = os.Remove(asset)
	}
	if e = atomicJSON(filepath.Join(job, "ready.json"), map[string]int{"version": m.Version}); e != nil {
		return e
	}
	r.write("ready", "更新已下载，重启即可安装")
	return nil
}
