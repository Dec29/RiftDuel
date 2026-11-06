//go:build !windows

package main

import "errors"

func waitParent(pid int) error { return errors.New("更新安装仅支持Windows") }
