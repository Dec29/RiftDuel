package main

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	randv2 "math/rand/v2"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func put(t *testing.T, p string, b []byte) {
	t.Helper()
	if e := os.MkdirAll(filepath.Dir(p), 0700); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(p, b, 0600); e != nil {
		t.Fatal(e)
	}
}
func hashBytes(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }
func fixture(t *testing.T) (string, string, Manifest) {
	t.Helper()
	dir := t.TempDir()
	job := t.TempDir()
	m := Manifest{Schema: 1, Version: 157, Tag: "demo-test-157", MinHelper: 1}
	for i, p := range []string{"RiftDuel.exe", "RiftDuel.pck", "RiftDuelUpdater.exe", "client_version.json", "licenses/test.txt"} {
		data := []byte(strings.Repeat(p, 400+i))
		if p == "client_version.json" {
			data = []byte(`{"version":157,"label":"M157"}`)
		}
		put(t, filepath.Join(job, "files", filepath.FromSlash(p)), data)
		m.Files = append(m.Files, FileSpec{Path: p, SHA: hashBytes(data), Size: int64(len(data)), Full: Artifact{Name: "file.gz", SHA: strings.Repeat("a", 64), Size: 100}})
		if p != "licenses/test.txt" {
			put(t, filepath.Join(dir, filepath.FromSlash(p)), []byte("old:"+p))
		}
	}
	return dir, job, m
}
func sign(t *testing.T, m Manifest) []byte {
	t.Helper()
	pub, key, e := ed25519.GenerateKey(rand.Reader)
	if e != nil {
		t.Fatal(e)
	}
	old := manifestKey
	manifestKey = pub
	t.Cleanup(func() { manifestKey = old })
	payload, e := json.Marshal(m)
	if e != nil {
		t.Fatal(e)
	}
	sig := ed25519.Sign(key, append([]byte("RiftDuel update v1\n"), payload...))
	b, _ := json.Marshal(Envelope{base64.StdEncoding.EncodeToString(payload), base64.StdEncoding.EncodeToString(sig)})
	return b
}
func TestManifestSignatureAndPaths(t *testing.T) {
	_, _, m := fixture(t)
	b := sign(t, m)
	if _, e := decodeEnvelope(b, manifestKey); e != nil {
		t.Fatal(e)
	}
	var env Envelope
	_ = json.Unmarshal(b, &env)
	env.Payload = base64.StdEncoding.EncodeToString([]byte(`{}`))
	bad, _ := json.Marshal(env)
	if _, e := decodeEnvelope(bad, manifestKey); e == nil {
		t.Fatal("tampered signature accepted")
	}
	for _, p := range []string{"../RiftDuel.exe", "/RiftDuel.exe", "C:/evil.exe", `addons\evil.dll`, "licenses/../evil.exe", "squad.cfg", "preferences.cfg", "addons/spine_bridge/hook.ps1", "licenses/x:ads", "licenses/./x"} {
		if allowedPath(p) {
			t.Fatal("unsafe path", p)
		}
	}
	m.Files[1].Path = m.Files[0].Path
	if validateManifest(m) == nil {
		t.Fatal("duplicate path accepted")
	}
}
func TestDeltaExactReconstructionAndCorruption(t *testing.T) {
	dir := t.TempDir()
	base := make([]byte, 8<<20)
	rng := randv2.New(randv2.NewPCG(5, 7))
	for i := range base {
		base[i] = byte(rng.Uint32())
	}
	target := append([]byte{}, base[:123456]...)
	target = append(target, []byte("inserted update and shifted offsets")...)
	target = append(target, base[124000:]...)
	old := filepath.Join(dir, "old")
	new := filepath.Join(dir, "new")
	patch := filepath.Join(dir, "patch")
	out := filepath.Join(dir, "out")
	put(t, old, base)
	put(t, new, target)
	if e := makeDelta(old, new, patch); e != nil {
		t.Fatal(e)
	}
	s, _ := os.Stat(patch)
	if s.Size() > int64(len(target))/8 {
		t.Fatal("delta failed to reuse shifted content", s.Size())
	}
	if e := applyDelta(old, patch, out, int64(len(target))); e != nil {
		t.Fatal(e)
	}
	got, _ := os.ReadFile(out)
	if !bytes.Equal(got, target) {
		t.Fatal("target differs")
	}
	data, _ := os.ReadFile(patch)
	put(t, patch, data[:len(data)/2])
	if applyDelta(old, patch, out, int64(len(target))) == nil {
		t.Fatal("truncated delta accepted")
	}
}
func TestInstallRollbackAndStartupFailure(t *testing.T) {
	for _, failure := range []string{"replace", "startup", "none"} {
		t.Run(failure, func(t *testing.T) {
			dir, job, m := fixture(t)
			before := map[string][]byte{}
			for _, f := range m.Files {
				before[f.Path], _ = os.ReadFile(filepath.Join(dir, filepath.FromSlash(f.Path)))
			}
			put(t, filepath.Join(dir, "squad.cfg"), []byte("untouched"))
			count := 0
			hook := func(p string) error {
				count++
				if failure == "replace" && count == 2 {
					return errors.New("injected replacement failure")
				}
				return nil
			}
			launch := func() error {
				if failure == "startup" {
					return errors.New("startup failed")
				}
				return nil
			}
			e := installUpdate(dir, job, m, hook, launch)
			if failure == "none" {
				if e != nil {
					t.Fatal(e)
				}
				for _, f := range m.Files {
					if !matches(filepath.Join(dir, filepath.FromSlash(f.Path)), f) {
						t.Fatal("new file mismatch")
					}
				}
			} else {
				if e == nil {
					t.Fatal("failure ignored")
				}
				for _, f := range m.Files {
					got, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(f.Path)))
					if before[f.Path] == nil {
						if !os.IsNotExist(err) {
							t.Fatal("new file survived rollback")
						}
					} else if !bytes.Equal(got, before[f.Path]) {
						t.Fatal("old file not restored", f.Path)
					}
				}
			}
			b, _ := os.ReadFile(filepath.Join(dir, "squad.cfg"))
			if string(b) != "untouched" {
				t.Fatal("save changed")
			}
		})
	}
}
func TestCorruptStageNeverChangesInstall(t *testing.T) {
	dir, job, m := fixture(t)
	put(t, filepath.Join(job, "files", "RiftDuel.pck"), []byte("corrupt"))
	if installUpdate(dir, job, m, nil, nil) == nil {
		t.Fatal("bad stage accepted")
	}
	b, _ := os.ReadFile(filepath.Join(dir, "RiftDuel.exe"))
	if string(b) != "old:RiftDuel.exe" {
		t.Fatal("installation changed before validation")
	}
}
func TestInterruptedInstallRecovery(t *testing.T) {
	dir := t.TempDir()
	tx := filepath.Join(dir, transactionName)
	put(t, filepath.Join(dir, "RiftDuel.pck"), []byte("partial new"))
	put(t, filepath.Join(tx, "old", "RiftDuel.pck"), []byte("original"))
	if e := atomicJSON(filepath.Join(tx, "journal.json"), Journal{[]JournalEntry{{"RiftDuel.pck", true, hashBytes([]byte("original"))}}}); e != nil {
		t.Fatal(e)
	}
	if e := recoverInstall(dir); e != nil {
		t.Fatal(e)
	}
	b, _ := os.ReadFile(filepath.Join(dir, "RiftDuel.pck"))
	if string(b) != "original" {
		t.Fatal("journal recovery failed")
	}
}

type rewriteTransport struct {
	base http.RoundTripper
	url  *url.URL
}

func (t rewriteTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	q := req.Clone(req.Context())
	u := *req.URL
	u.Scheme = t.url.Scheme
	u.Host = t.url.Host
	q.URL = &u
	return t.base.RoundTrip(q)
}
func TestCheckStageDownloadAndExactInstall(t *testing.T) {
	dir, job, m := fixture(t)
	assets := map[string][]byte{}
	// Give one file a real delta and leave one installed file unchanged.
	base := filepath.Join(dir, "RiftDuel.pck")
	put(t, base, bytes.Repeat([]byte("old PCK structure"), 10000))
	oldHash, _ := fileDigest(base)
	for i := range m.Files {
		f := &m.Files[i]
		gz := filepath.Join(job, "gzip")
		if e := gzipFile(filepath.Join(job, "files", filepath.FromSlash(f.Path)), gz); e != nil {
			t.Fatal(e)
		}
		a, _ := artifact(gz)
		a.Name = string(rune('a'+i)) + ".gz"
		f.Full = a
		assets[a.Name], _ = os.ReadFile(gz)
		if f.Path == "RiftDuel.pck" {
			patch := filepath.Join(job, "delta")
			if e := makeDelta(base, filepath.Join(job, "files", f.Path), patch); e != nil {
				t.Fatal(e)
			}
			a, _ := artifact(patch)
			a.Name = "patch.gz"
			f.Deltas = []Delta{{oldHash, a}}
			assets[a.Name], _ = os.ReadFile(patch)
		}
	}
	envelope := sign(t, m)
	requests := []string{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests = append(requests, r.URL.Path)
		name := filepath.Base(r.URL.Path)
		if strings.HasSuffix(r.URL.Path, "/releases") {
			io.WriteString(w, `[{"tag_name":"demo-test-157","draft":false,"prerelease":true,"assets":[{"name":"update-manifest.json"}]}]`)
			return
		}
		if name == manifestAsset {
			w.Write(envelope)
			return
		}
		if b, ok := assets[name]; ok {
			w.Write(b)
			return
		}
		http.NotFound(w, r)
	}))
	defer server.Close()
	u, _ := url.Parse(server.URL)
	previous := webClient
	webClient = &http.Client{Transport: rewriteTransport{http.DefaultTransport, u}}
	defer func() { webClient = previous }()
	report := &Reporter{Path: filepath.Join(job, "status.json")}
	if e := checkUpdates(context.Background(), dir, job, report); e != nil {
		t.Fatal(e)
	}
	if report.Value.Phase != "available" {
		t.Fatal(report.Value)
	}
	// Remove prebuilt staged files so real verified HTTP downloads are required.
	if e := os.RemoveAll(filepath.Join(job, "files")); e != nil {
		t.Fatal(e)
	}
	if e := stageUpdate(context.Background(), dir, job, report); e != nil {
		t.Fatal(e)
	}
	if report.Value.Phase != "ready" {
		t.Fatal(report.Value)
	}
	if e := installUpdate(dir, job, m, nil, nil); e != nil {
		t.Fatal(e)
	}
	for _, f := range m.Files {
		if !matches(filepath.Join(dir, filepath.FromSlash(f.Path)), f) {
			t.Fatal("installed mismatch", f.Path)
		}
	}
	_ = requests
}
