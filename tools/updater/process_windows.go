package main

import (
	"errors"
	"syscall"
	"time"
)

func waitParent(pid int) error {
	if pid <= 0 {
		return errors.New("无效的游戏进程")
	}
	h, e := syscall.OpenProcess(0x00100000, false, uint32(pid))
	if e != nil {
		if e == syscall.Errno(87) {
			return nil
		}
		return e
	}
	defer syscall.CloseHandle(h)
	result, e := syscall.WaitForSingleObject(h, uint32((120*time.Second)/time.Millisecond))
	if e != nil {
		return e
	}
	if result != 0 {
		return errors.New("游戏尚未关闭，请退出后重试")
	}
	return nil
}
