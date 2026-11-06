//go:build !windows

package main

import "errors"

func lockInstall(dir string) (func(), error) { return nil, errors.New("Windows only") }
