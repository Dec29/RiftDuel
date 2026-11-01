package main

import "testing"

func TestMeteoriteStrictID(t *testing.T) {
	row := [][]any{{float64(6), float64(0), "meteorite", float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
	if !validCommands(row, 6) {
		t.Fatal("meteorite deploy rejected")
	}
	row[0][2] = "meteorite_unknown"
	if validCommands(row, 6) {
		t.Fatal("unknown operator accepted")
	}
}
