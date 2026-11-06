package main

// Content-defined copy/literal streams reconstruct the exact signed target file.
// Both the source hash and reconstructed target hash are checked outside this codec.
import (
	"bufio"
	"compress/gzip"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"io"
	"os"
)

type chunkRef struct {
	Offset int64
	Size   int
}

func gearTable() (a [256]uint64) {
	x := uint64(0x72e35a91)
	for i := range a {
		x += 0x9e3779b97f4a7c15
		z := x
		z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9
		z = (z ^ (z >> 27)) * 0x94d049bb133111eb
		a[i] = z ^ (z >> 31)
	}
	return
}

var gear = gearTable()

func chunks(p string, fn func([]byte, int64) error) error {
	f, e := os.Open(p)
	if e != nil {
		return e
	}
	defer f.Close()
	r := bufio.NewReaderSize(f, 256<<10)
	block := make([]byte, 0, 512<<10)
	var hash uint64
	var offset int64
	for {
		b, e := r.ReadByte()
		if e == io.EOF {
			if len(block) > 0 {
				return fn(block, offset)
			}
			return nil
		}
		if e != nil {
			return e
		}
		block = append(block, b)
		hash = (hash << 1) + gear[b]
		if len(block) >= 512<<10 || (len(block) >= 32<<10 && hash&((1<<17)-1) == 0) {
			if e = fn(block, offset); e != nil {
				return e
			}
			offset += int64(len(block))
			block = block[:0]
			hash = 0
		}
	}
}
func makeDelta(base, target, out string) error {
	refs := map[[32]byte]chunkRef{}
	if e := chunks(base, func(b []byte, off int64) error { refs[sha256.Sum256(b)] = chunkRef{off, len(b)}; return nil }); e != nil {
		return e
	}
	f, e := os.Create(out)
	if e != nil {
		return e
	}
	defer f.Close()
	z := gzip.NewWriter(f)
	if _, e = z.Write([]byte("RDU1")); e != nil {
		return e
	}
	e = chunks(target, func(b []byte, off int64) error {
		_ = off
		if ref, ok := refs[sha256.Sum256(b)]; ok && ref.Size == len(b) {
			if _, e = z.Write([]byte{0}); e != nil {
				return e
			}
			if e = binary.Write(z, binary.LittleEndian, uint64(ref.Offset)); e != nil {
				return e
			}
			return binary.Write(z, binary.LittleEndian, uint32(ref.Size))
		}
		if _, e = z.Write([]byte{1}); e != nil {
			return e
		}
		if e = binary.Write(z, binary.LittleEndian, uint32(len(b))); e != nil {
			return e
		}
		_, e = z.Write(b)
		return e
	})
	if e != nil {
		return e
	}
	return z.Close()
}
func applyDelta(base, patch, out string, expected int64) error {
	old, e := os.Open(base)
	if e != nil {
		return e
	}
	defer old.Close()
	oldStat, e := old.Stat()
	if e != nil {
		return e
	}
	p, e := os.Open(patch)
	if e != nil {
		return e
	}
	defer p.Close()
	z, e := gzip.NewReader(p)
	if e != nil {
		return e
	}
	defer z.Close()
	var header [4]byte
	if _, e = io.ReadFull(z, header[:]); e != nil || string(header[:]) != "RDU1" {
		return errors.New("差分格式错误")
	}
	f, e := os.Create(out)
	if e != nil {
		return e
	}
	defer f.Close()
	var written int64
	for {
		var kind [1]byte
		_, e = io.ReadFull(z, kind[:])
		if e == io.EOF {
			break
		}
		if e != nil {
			return e
		}
		var off uint64
		var n uint32
		if kind[0] == 0 {
			if e = binary.Read(z, binary.LittleEndian, &off); e != nil {
				return e
			}
		} else if kind[0] != 1 {
			return errors.New("差分指令无效")
		}
		if e = binary.Read(z, binary.LittleEndian, &n); e != nil {
			return e
		}
		if n == 0 || n > 512<<10 || written+int64(n) > expected {
			return errors.New("差分长度无效")
		}
		var input io.Reader = z
		if kind[0] == 0 {
			if off > uint64(oldStat.Size()) || uint64(n) > uint64(oldStat.Size())-off {
				return errors.New("差分基线越界")
			}
			input = io.NewSectionReader(old, int64(off), int64(n))
		}
		if _, e = io.CopyN(f, input, int64(n)); e != nil {
			return e
		}
		written += int64(n)
	}
	if written != expected {
		return errors.New("差分目标长度不符")
	}
	return f.Sync()
}
