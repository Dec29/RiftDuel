package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

func main() {
	if e := run(os.Args[1:]); e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
func run(args []string) error {
	command := "launch"
	if len(args) > 0 {
		command = args[0]
		args = args[1:]
	}
	fs := flag.NewFlagSet(command, flag.ContinueOnError)
	dir := fs.String("install-dir", "", "")
	job := fs.String("job", "", "")
	status := fs.String("status", "", "")
	parent := fs.Int("parent", 0, "")
	fs.String("key", "", "")
	fs.String("public-out", "", "")
	fs.String("output", "", "")
	fs.String("base", "", "")
	fs.Int("version", 0, "")
	fs.String("tag", "", "")
	fs.String("notes", "", "")
	if e := fs.Parse(args); e != nil {
		return e
	}
	if command == "keygen" || command == "release" {
		return developerCommand(command, fs)
	}
	if *dir == "" {
		exe, e := os.Executable()
		if e != nil {
			return e
		}
		*dir = filepath.Dir(exe)
	}
	root, e := filepath.EvalSymlinks(*dir)
	if e != nil {
		return e
	}
	*dir = root
	r := &Reporter{Path: *status}
	fail := func(e error) error { r.write("error", e.Error()); return e }
	if command == "launch" {
		unlock, e := lockInstall(*dir)
		if e != nil {
			return e
		}
		defer unlock()
		if e = recoverInstall(*dir); e != nil {
			return e
		}
		return launchGame(*dir, false)
	}
	if *job == "" || *status == "" {
		return errors.New("缺少更新工作目录")
	}
	if e = os.MkdirAll(*job, 0700); e != nil {
		return fail(e)
	}
	switch command {
	case "check":
		return reportError(r, checkUpdates(context.Background(), *dir, *job, r))
	case "stage":
		return reportError(r, stageUpdate(context.Background(), *dir, *job, r))
	case "apply":
		if e = waitParent(*parent); e != nil {
			return fail(e)
		}
		unlock, e := lockInstall(*dir)
		if e != nil {
			return fail(e)
		}
		defer unlock()
		m, _, e := loadManifest(*job)
		if e != nil {
			return fail(e)
		}
		if _, e = os.Stat(filepath.Join(*job, "ready.json")); e != nil {
			return fail(e)
		}
		if m.Version <= readVersion(*dir).Version {
			return fail(errors.New("拒绝重复安装或降级"))
		}
		r.write("installing", "正在安装更新…")
		e = installUpdate(*dir, *job, m, nil, func() error { return launchGame(*dir, true, filepath.Join(*job, "restarted-game.log")) })
		if e != nil {
			r.write("error", e.Error())
			_ = launchGame(*dir, false)
			return e
		}
		r.Value.Latest = m.Version
		r.write("installed", "更新安装成功")
		// Keep a small signed receipt and status, not a second game installation.
		_ = os.RemoveAll(filepath.Join(*job, "files"))
		return nil
	default:
		return errors.New("未知更新命令")
	}
}
func reportError(r *Reporter, e error) error {
	if e != nil {
		r.write("error", e.Error())
	}
	return e
}
