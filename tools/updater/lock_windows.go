package main

import (
	"os"
	"path/filepath"
	"syscall"
)

func lockInstall(dir string) (func(), error) {
	path := filepath.Join(dir, ".riftduel-update.lock")
	p, e := syscall.UTF16PtrFromString(path)
	if e != nil {
		return nil, e
	}
	h, e := syscall.CreateFile(p, syscall.GENERIC_READ|syscall.GENERIC_WRITE, 0, nil, syscall.OPEN_ALWAYS, syscall.FILE_ATTRIBUTE_NORMAL, 0)
	if e != nil {
		return nil, e
	}
	return func() { syscall.CloseHandle(h); _ = os.Remove(path) }, nil
}
