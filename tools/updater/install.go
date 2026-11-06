package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

const transactionName = ".riftduel-update"

type JournalEntry struct {
	Path    string `json:"path"`
	Existed bool   `json:"existed"`
	SHA     string `json:"sha256"`
}
type Journal struct {
	Entries []JournalEntry `json:"entries"`
}

func copyFile(src, dest string) error {
	if e := os.MkdirAll(filepath.Dir(dest), 0700); e != nil {
		return e
	}
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.Create(dest)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	if e == nil {
		e = out.Sync()
	}
	ce := out.Close()
	if e == nil {
		e = ce
	}
	return e
}
func replaceFile(src, dst string) error {
	if e := os.MkdirAll(filepath.Dir(dst), 0755); e != nil {
		return e
	}
	return os.Rename(src, dst)
}
func recoverInstall(dir string) error {
	tx := filepath.Join(dir, transactionName)
	if _, e := os.Stat(tx); os.IsNotExist(e) {
		return nil
	}
	if _, e := os.Stat(filepath.Join(tx, "complete")); e == nil {
		return os.RemoveAll(tx)
	}
	b, e := os.ReadFile(filepath.Join(tx, "journal.json"))
	if os.IsNotExist(e) {
		return os.RemoveAll(tx)
	}
	if e != nil {
		return e
	}
	var j Journal
	if e = json.Unmarshal(b, &j); e != nil {
		return e
	}
	if len(j.Entries) > 300 {
		return errors.New("安装恢复记录过大")
	}
	for _, entry := range j.Entries {
		dst, e := safePath(dir, entry.Path)
		if e != nil {
			return e
		}
		if entry.Existed {
			backup := filepath.Join(tx, "old", filepath.FromSlash(entry.Path))
			hash, err := fileDigest(backup)
			if err != nil || hash != entry.SHA {
				return errors.New("恢复备份校验失败：" + entry.Path)
			}
			current, err := fileDigest(dst)
			if err == nil && current == entry.SHA {
				continue
			}
			temp := filepath.Join(tx, "restore.tmp")
			if e = copyFile(backup, temp); e != nil {
				return e
			}
			if e = replaceFile(temp, dst); e != nil {
				return e
			}
		} else {
			if e = os.Remove(dst); e != nil && !os.IsNotExist(e) {
				return e
			}
		}
	}
	return os.RemoveAll(tx)
}
func installUpdate(dir, job string, m Manifest, afterReplace func(string) error, launch func() error) error {
	if e := validateManifest(m); e != nil {
		return e
	}
	if e := recoverInstall(dir); e != nil {
		return e
	}
	tx := filepath.Join(dir, transactionName)
	if e := os.Mkdir(tx, 0700); e != nil {
		return e
	}
	journal := Journal{}
	// Prepare and verify all files before changing a single installed file.
	for _, f := range m.Files {
		dst, e := safePath(dir, f.Path)
		if e != nil {
			_ = os.RemoveAll(tx)
			return e
		}
		if matches(dst, f) {
			continue
		}
		staged := filepath.Join(job, "files", filepath.FromSlash(f.Path))
		if !matches(staged, f) {
			_ = os.RemoveAll(tx)
			return errors.New("待安装文件校验失败：" + f.Path)
		}
		entry := JournalEntry{Path: f.Path}
		if _, e = os.Stat(dst); e == nil {
			entry.Existed = true
			entry.SHA, e = fileDigest(dst)
			if e != nil {
				_ = os.RemoveAll(tx)
				return e
			}
			if e = copyFile(dst, filepath.Join(tx, "old", filepath.FromSlash(f.Path))); e != nil {
				_ = os.RemoveAll(tx)
				return e
			}
			backupHash, err := fileDigest(filepath.Join(tx, "old", filepath.FromSlash(f.Path)))
			if err != nil || backupHash != entry.SHA {
				_ = os.RemoveAll(tx)
				return errors.New("安装备份校验失败")
			}
		} else if !os.IsNotExist(e) {
			_ = os.RemoveAll(tx)
			return e
		}
		newPath := filepath.Join(tx, "new", filepath.FromSlash(f.Path))
		if e = copyFile(staged, newPath); e != nil {
			_ = os.RemoveAll(tx)
			return e
		}
		if !matches(newPath, f) {
			_ = os.RemoveAll(tx)
			return errors.New("安装准备校验失败")
		}
		journal.Entries = append(journal.Entries, entry)
	}
	if e := atomicJSON(filepath.Join(tx, "journal.json"), journal); e != nil {
		return e
	}
	fail := func(e error) error {
		if recovery := recoverInstall(dir); recovery != nil {
			return fmt.Errorf("%v；恢复失败：%w", e, recovery)
		}
		return fmt.Errorf("%v；已恢复原版本", e)
	}
	for _, entry := range journal.Entries {
		dst, e := safePath(dir, entry.Path)
		if e != nil {
			return fail(e)
		}
		if e = replaceFile(filepath.Join(tx, "new", filepath.FromSlash(entry.Path)), dst); e != nil {
			return fail(e)
		}
		if afterReplace != nil {
			if e = afterReplace(entry.Path); e != nil {
				return fail(e)
			}
		}
	}
	for _, f := range m.Files {
		dst, e := safePath(dir, f.Path)
		if e != nil {
			return fail(e)
		}
		if !matches(dst, f) {
			return fail(errors.New("安装后校验失败：" + f.Path))
		}
	}
	if launch != nil {
		if e := launch(); e != nil {
			return fail(e)
		}
	}
	if e := atomicBytes(filepath.Join(tx, "complete"), []byte("ok")); e != nil {
		return fail(e)
	}
	return os.RemoveAll(tx)
}
func launchGame(dir string, health bool, logPath ...string) error {
	var args []string
	if health {
		args = []string{"--", "--riftduel-update-health"}
	}
	cmd := exec.Command(filepath.Join(dir, "RiftDuel.exe"), args...)
	cmd.Dir = dir
	if len(logPath) > 0 {
		log, e := os.Create(logPath[0])
		if e != nil {
			return e
		}
		defer log.Close()
		cmd.Stdout = log
		cmd.Stderr = log
	}
	if e := cmd.Start(); e != nil {
		return e
	}
	if !health {
		return cmd.Process.Release()
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	timeout := time.NewTimer(45 * time.Second)
	defer timeout.Stop()
	poll := time.NewTicker(100 * time.Millisecond)
	defer poll.Stop()
	for {
		select {
		case <-done:
			return errors.New("新版启动提前退出")
		case <-timeout.C:
			_ = cmd.Process.Kill()
			<-done
			return errors.New("新版启动确认超时")
		case <-poll.C:
			b, e := os.ReadFile(filepath.Join(dir, transactionName, "health.json"))
			if e == nil {
				var v Version
				if json.Unmarshal(b, &v) == nil && v.Version == readVersion(dir).Version {
					return nil
				}
			}
		}
	}
}
