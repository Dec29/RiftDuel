package main

import "testing"

func TestSilenceStrictID(t *testing.T) {
	row := [][]any{{float64(6), float64(0), "silence", float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
	if !validCommands(row, 6) {
		t.Fatal("silence deploy rejected")
	}
	row[0][2] = "medical_drone"
	if !validCommands(row, 6) {
		t.Fatal("medical drone deploy rejected")
	}
	row[0][2] = "silence_unknown"
	if validCommands(row, 6) {
		t.Fatal("unknown operator accepted")
	}
}
