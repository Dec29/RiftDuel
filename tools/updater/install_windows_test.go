package main

import (
	"bytes"
	"os"
	"path/filepath"
	"syscall"
	"testing"
)

func TestLockedTargetKeepsOriginal(t *testing.T) {
	dir, job, m := fixture(t)
	p, _ := syscall.UTF16PtrFromString(filepath.Join(dir, "RiftDuel.pck"))
	handle, e := syscall.CreateFile(p, syscall.GENERIC_READ, syscall.FILE_SHARE_READ, nil, syscall.OPEN_EXISTING, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if e != nil {
		t.Fatal(e)
	}
	defer syscall.CloseHandle(handle)
	if e = installUpdate(dir, job, m, nil, nil); e == nil {
		t.Fatal("locked target installed")
	}
	b, _ := os.ReadFile(filepath.Join(dir, "RiftDuel.exe"))
	if !bytes.Equal(b, []byte("old:RiftDuel.exe")) {
		t.Fatal("earlier replacement not restored")
	}
	if _, e = os.Stat(filepath.Join(dir, transactionName)); !os.IsNotExist(e) {
		t.Fatal("successful rollback left transaction", e)
	}
}
func TestInstallationLockRejectsConcurrentApply(t *testing.T) {
	dir := t.TempDir()
	unlock, e := lockInstall(dir)
	if e != nil {
		t.Fatal(e)
	}
	defer unlock()
	second, e := lockInstall(dir)
	if e == nil {
		second()
		t.Fatal("concurrent installer accepted")
	}
}
