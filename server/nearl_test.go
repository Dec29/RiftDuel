package main

import "testing"

func TestNearlStrictID(t *testing.T) {
	row := [][]any{{float64(6), float64(0), "nearl", float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
	if !validCommands(row, 6) {
		t.Fatal("nearl deploy rejected")
	}
	row[0][2] = "nearl_unknown"
	if validCommands(row, 6) {
		t.Fatal("unknown operator accepted")
	}
}
