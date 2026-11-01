package main

import "testing"

func TestTwoGroupsDeployCommands(t *testing.T) {
	for _, id := range []string{"flametail", "elysium", "mountain", "surtr", "mudrock", "gummy", "rosa", "jessica", "passenger", "haze", "warfarin", "sussurro", "shamare", "podenco", "mizuki", "feater", "curse_doll"} {
		row := [][]any{{float64(6), float64(0), id, float64(-1), float64(12), float64(5), float64(-1), float64(0), float64(-1)}}
		if !validCommands(row, 6) {
			t.Fatalf("new deploy rejected: %s", id)
		}
		row[0][2] = id + "_unknown"
		if validCommands(row, 6) {
			t.Fatalf("unknown deploy accepted: %s", id)
		}
	}
}
