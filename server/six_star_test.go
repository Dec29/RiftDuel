package main

import "testing"

func TestSixStarDeployCommands(t *testing.T) {
	for _, id := range []string{"ines", "vigil", "pozyomka", "reed_alter", "eyjafjalla_alter", "gnosis", "silence_alter", "lee", "vigil_wolf", "pozyomka_typewriter", "silence_alter_drone", "thorns", "archetto", "pallas", "carnelian", "lin", "blemishine", "penance", "texas_alter"} {
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
