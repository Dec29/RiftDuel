package main

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const repository = "Dec29/RiftDuel"
const manifestAsset = "update-manifest.json"
const helperVersion = 1

type Artifact struct {
	Name string `json:"name"`
	SHA  string `json:"sha256"`
	Size int64  `json:"size"`
}
type Delta struct {
	Base     string   `json:"base_sha256"`
	Artifact Artifact `json:"artifact"`
}
type FileSpec struct {
	Path   string   `json:"path"`
	SHA    string   `json:"sha256"`
	Size   int64    `json:"size"`
	Full   Artifact `json:"full"`
	Deltas []Delta  `json:"deltas,omitempty"`
}
type Manifest struct {
	Schema    int        `json:"schema"`
	Version   int        `json:"version"`
	Tag       string     `json:"tag"`
	Notes     string     `json:"notes"`
	MinHelper int        `json:"min_helper"`
	Files     []FileSpec `json:"files"`
}
type Envelope struct {
	Payload   string `json:"payload"`
	Signature string `json:"signature"`
}
type Version struct {
	Version int    `json:"version"`
	Label   string `json:"label"`
}

var digestRE = regexp.MustCompile(`^[a-f0-9]{64}$`)
var tagRE = regexp.MustCompile(`^[a-zA-Z0-9._-]{1,100}$`)

func allowedPath(p string) bool {
	if p == "" || strings.ContainsAny(p, "\\:\x00") || strings.HasPrefix(p, "/") || filepath.ToSlash(filepath.Clean(p)) != p {
		return false
	}
	for _, part := range strings.Split(p, "/") {
		if part == "." || part == ".." || strings.HasSuffix(part, ".") || strings.HasSuffix(part, " ") {
			return false
		}
	}
	switch p {
	case "RiftDuel.exe", "RiftDuel.pck", "RiftDuelUpdater.exe", "client_version.json", "libspine_bridge.windows.template_release.x86_64.dll":
		return true
	}
	if strings.HasPrefix(p, "licenses/") {
		return true
	}
	if strings.HasPrefix(p, "addons/spine_bridge/") {
		switch filepath.Ext(p) {
		case ".dll", ".gdextension", ".json":
			return true
		}
	}
	return false
}
func validateManifest(m Manifest) error {
	if m.Schema != 1 || m.Version < 1 || m.MinHelper < 1 || m.MinHelper > helperVersion || !tagRE.MatchString(m.Tag) || len(m.Files) < 3 || len(m.Files) > 300 || len(m.Notes) > 10000 {
		return errors.New("不支持的更新清单")
	}
	seen := map[string]bool{}
	for _, f := range m.Files {
		lower := strings.ToLower(f.Path)
		if !allowedPath(f.Path) || seen[lower] || !digestRE.MatchString(f.SHA) || f.Size < 1 || f.Size > 2<<30 {
			return fmt.Errorf("更新文件无效：%s", f.Path)
		}
		seen[lower] = true
		artifacts := []Artifact{f.Full}
		for _, d := range f.Deltas {
			if !digestRE.MatchString(d.Base) {
				return errors.New("差分基线无效")
			}
			artifacts = append(artifacts, d.Artifact)
		}
		for _, a := range artifacts {
			if !tagRE.MatchString(a.Name) || !digestRE.MatchString(a.SHA) || a.Size < 1 || a.Size > 2<<30 {
				return errors.New("更新附件无效")
			}
		}
	}
	for _, p := range []string{"riftduel.exe", "riftduel.pck", "riftduelupdater.exe", "client_version.json"} {
		if !seen[p] {
			return errors.New("更新缺少必要文件：" + p)
		}
	}
	return nil
}
func decodeEnvelope(data []byte, key ed25519.PublicKey) (Manifest, error) {
	var e Envelope
	var m Manifest
	if len(data) > 2<<20 || json.Unmarshal(data, &e) != nil {
		return m, errors.New("无法读取更新清单")
	}
	payload, err := base64.StdEncoding.DecodeString(e.Payload)
	if err != nil {
		return m, err
	}
	sig, err := base64.StdEncoding.DecodeString(e.Signature)
	if err != nil || !ed25519.Verify(key, append([]byte("RiftDuel update v1\n"), payload...), sig) {
		return m, errors.New("更新清单签名不正确")
	}
	if err = json.Unmarshal(payload, &m); err != nil {
		return m, err
	}
	return m, validateManifest(m)
}
func trustedKey() ed25519.PublicKey {
	b, _ := hex.DecodeString(publicKeyHex)
	return ed25519.PublicKey(b)
}
func fileDigest(p string) (string, error) {
	f, e := os.Open(p)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	_, e = io.Copy(h, f)
	return hex.EncodeToString(h.Sum(nil)), e
}
func matches(p string, f FileSpec) bool {
	s, e := os.Stat(p)
	if e != nil || s.Size() != f.Size {
		return false
	}
	h, e := fileDigest(p)
	return e == nil && h == f.SHA
}
func readVersion(dir string) Version {
	var v Version
	b, e := os.ReadFile(filepath.Join(dir, "client_version.json"))
	if e == nil {
		_ = json.Unmarshal(b, &v)
	}
	return v
}
func safePath(root, p string) (string, error) {
	if !allowedPath(p) {
		return "", errors.New("拒绝安装路径")
	}
	root, e := filepath.Abs(root)
	if e != nil {
		return "", e
	}
	realRoot, e := filepath.EvalSymlinks(root)
	if e != nil {
		return "", e
	}
	dest := filepath.Join(realRoot, filepath.FromSlash(p))
	parent := dest
	for {
		_, err := os.Lstat(parent)
		if err == nil {
			break
		}
		if !os.IsNotExist(err) {
			return "", err
		}
		parent = filepath.Dir(parent)
	}
	real, e := filepath.EvalSymlinks(parent)
	if e != nil {
		return "", e
	}
	rel, e := filepath.Rel(realRoot, real)
	if e != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
		return "", errors.New("安装路径越界")
	}
	return dest, nil
}
func atomicJSON(p string, v any) error {
	b, e := json.MarshalIndent(v, "", "  ")
	if e != nil {
		return e
	}
	return atomicBytes(p, b)
}
func atomicBytes(p string, b []byte) error {
	if e := os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		return e
	}
	f, e := os.CreateTemp(filepath.Dir(p), ".write-")
	if e != nil {
		return e
	}
	name := f.Name()
	defer os.Remove(name)
	if _, e = f.Write(b); e == nil {
		e = f.Sync()
	}
	ce := f.Close()
	if e == nil {
		e = ce
	}
	if e != nil {
		return e
	}
	return os.Rename(name, p)
}
