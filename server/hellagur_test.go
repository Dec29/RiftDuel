package main

import "testing"

func TestHellagurStrictID(t *testing.T) {
	row := [][]any{{float64(6), float64(0), "hellagur", float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
	if !validCommands(row, 6) {
		t.Fatal("hellagur deploy rejected")
	}
	row[0][2] = "hellagur_unknown"
	if validCommands(row, 6) {
		t.Fatal("unknown operator accepted")
	}
}
