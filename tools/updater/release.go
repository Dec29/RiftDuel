package main

import (
	"compress/gzip"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func option(fs *flag.FlagSet, name string) string { return fs.Lookup(name).Value.String() }
func developerCommand(command string, fs *flag.FlagSet) error {
	keyPath := option(fs, "key")
	if keyPath == "" {
		return errors.New("必须指定签名密钥位置")
	}
	if command == "keygen" {
		if _, e := os.Stat(keyPath); !os.IsNotExist(e) {
			return errors.New("拒绝覆盖已有签名密钥")
		}
		pub, priv, e := ed25519.GenerateKey(rand.Reader)
		if e != nil {
			return e
		}
		if e = os.MkdirAll(filepath.Dir(keyPath), 0700); e != nil {
			return e
		}
		f, e := os.OpenFile(keyPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if e != nil {
			return e
		}
		_, e = f.Write(priv)
		ce := f.Close()
		if e == nil {
			e = ce
		}
		if e != nil {
			return e
		}
		return atomicBytes(option(fs, "public-out"), []byte("package main\n\n// Release verification key; private key is stored outside the published tree.\nconst publicKeyHex = \""+hex.EncodeToString(pub)+"\"\n"))
	}
	key, e := os.ReadFile(keyPath)
	if e != nil {
		return e
	}
	if len(key) != ed25519.PrivateKeySize {
		return errors.New("签名密钥格式不符")
	}
	if !strings.EqualFold(hex.EncodeToString(ed25519.PrivateKey(key).Public().(ed25519.PublicKey)), publicKeyHex) {
		return errors.New("签名密钥与客户端公钥不匹配")
	}
	version, e := strconv.Atoi(option(fs, "version"))
	if e != nil {
		return e
	}
	dir := option(fs, "install-dir")
	out := option(fs, "output")
	if dir == "" || out == "" {
		return errors.New("缺少发布路径")
	}
	if e = os.MkdirAll(out, 0755); e != nil {
		return e
	}
	if e = atomicJSON(filepath.Join(dir, "client_version.json"), Version{version, fmt.Sprintf("M%d", version)}); e != nil {
		return e
	}
	m := Manifest{Schema: 1, Version: version, Tag: option(fs, "tag"), Notes: option(fs, "notes"), MinHelper: 1}
	files := []string{}
	e = filepath.WalkDir(dir, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(dir, p)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if allowedPath(rel) {
			if d.Type()&os.ModeSymlink != 0 {
				return errors.New("发布文件不可为链接")
			}
			files = append(files, rel)
		}
		return nil
	})
	if e != nil {
		return e
	}
	sort.Strings(files)
	bases := []string{}
	for _, b := range strings.Split(option(fs, "base"), ",") {
		if b != "" {
			bases = append(bases, b)
		}
	}
	for i, p := range files {
		src := filepath.Join(dir, filepath.FromSlash(p))
		stat, e := os.Stat(src)
		if e != nil {
			return e
		}
		h, e := fileDigest(src)
		if e != nil {
			return e
		}
		spec := FileSpec{Path: p, SHA: h, Size: stat.Size()}
		name := fmt.Sprintf("file-%03d.gz", i)
		dest := filepath.Join(out, name)
		if e = gzipFile(src, dest); e != nil {
			return e
		}
		spec.Full, e = artifact(dest)
		if e != nil {
			return e
		}
		for _, base := range bases {
			old := filepath.Join(base, filepath.FromSlash(p))
			hash, err := fileDigest(old)
			if err != nil || hash == h {
				continue
			}
			patchName := fmt.Sprintf("delta-%03d-%s.gz", i, hash[:16])
			patch := filepath.Join(out, patchName)
			if e = makeDelta(old, src, patch); e != nil {
				return e
			}
			a, e := artifact(patch)
			if e != nil {
				return e
			}
			if a.Size < spec.Full.Size {
				// Verify every generated patch by applying it, not by estimating its size.
				reconstructed := filepath.Join(out, ".reconstructed")
				if e = applyDelta(old, patch, reconstructed, spec.Size); e != nil {
					return e
				}
				if !matches(reconstructed, spec) {
					return errors.New("生成的差分重建不一致")
				}
				_ = os.Remove(reconstructed)
				spec.Deltas = append(spec.Deltas, Delta{hash, a})
			} else {
				_ = os.Remove(patch)
			}
		}
		m.Files = append(m.Files, spec)
	}
	if e = validateManifest(m); e != nil {
		return e
	}
	payload, e := json.Marshal(m)
	if e != nil {
		return e
	}
	sig := ed25519.Sign(ed25519.PrivateKey(key), append([]byte("RiftDuel update v1\n"), payload...))
	if e = atomicJSON(filepath.Join(out, manifestAsset), Envelope{base64.StdEncoding.EncodeToString(payload), base64.StdEncoding.EncodeToString(sig)}); e != nil {
		return e
	}
	return atomicJSON(filepath.Join(out, "release-audit.json"), m)
}
func gzipFile(src, dst string) error {
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.Create(dst)
	if e != nil {
		return e
	}
	defer out.Close()
	z := gzip.NewWriter(out)
	if _, e = io.Copy(z, in); e != nil {
		return e
	}
	return z.Close()
}
func artifact(p string) (Artifact, error) {
	s, e := os.Stat(p)
	if e != nil {
		return Artifact{}, e
	}
	h, e := fileDigest(p)
	return Artifact{filepath.Base(p), h, s.Size()}, e
}
