package main

import "testing"

func TestGitanoStrictID(t *testing.T) {
	row := [][]any{{float64(6), float64(0), "gitano", float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
	if !validCommands(row, 6) {
		t.Fatal("gitano deploy rejected")
	}
	row[0][2] = "gitano_unknown"
	if validCommands(row, 6) {
		t.Fatal("unknown operator accepted")
	}
}
