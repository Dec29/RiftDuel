package main

import (
	"encoding/json"
	"fmt"
	"testing"
)

func TestItemCommandBoundaries(t *testing.T) {
	for item := 0; item < 4; item++ {
		for _, cell := range [][2]int{{0, 0}, {20, 10}} {
			faces := []int{-1}
			if item == 0 {
				faces = []int{0, 1, 2, 3}
			}
			for _, facing := range faces {
				t.Run(fmt.Sprintf("item%d_%v_facing%d", item, cell, facing), func(t *testing.T) {
					data := fmt.Sprintf(`[[6,3,"",-1,%d,%d,-1,%d,%d]]`, cell[0], cell[1], facing, item)
					var rows [][]any
					if err := json.Unmarshal([]byte(data), &rows); err != nil {
						t.Fatal(err)
					}
					if !validCommands(rows, 6) {
						t.Fatal("valid item boundary rejected", data)
					}
				})
			}
		}
	}
}

func TestInvalidNineFieldCommands(t *testing.T) {
	for _, row := range []string{
		`[6,0,"bagpipe",-1,12,5,-1,2]`, `[6,1,"",1,0,0,0,-1]`, `[6,2,"",1,0,0,-1,-1]`, `[6,3,"",-1,0,0,-1,0]`,
		`[6,3,"",-1,0,0,-1,0,0,0]`, `[6,4,"",-1,0,0,-1,0,0]`, `[6,-1,"",-1,0,0,-1,0,0]`,
		`[6,3,"bagpipe",-1,0,0,-1,0,0]`, `[6,3,"",0,0,0,-1,0,0]`, `[6,3,"",-2,0,0,-1,0,0]`,
		`[6,3,"",-1,-1,0,-1,0,0]`, `[6,3,"",-1,21,0,-1,0,0]`, `[6,3,"",-1,0,-1,-1,0,0]`, `[6,3,"",-1,0,11,-1,0,0]`,
		`[6,3,"",-1,0,0,0,0,0]`, `[6,3,"",-1,0,0,-1,-1,0]`, `[6,3,"",-1,0,0,-1,4,0]`,
		`[6,3,"",-1,0,0,-1,0,1]`, `[6,3,"",-1,0,0,-1,3,2]`, `[6,3,"",-1,0,0,-1,-2,1]`,
		`[6,3,"",-1,0,0,-1,0,-1]`, `[6,3,"",-1,0,0,-1,-1,4]`,
		`[6,0,"bagpipe",-1,12,5,-1,2,0]`, `[6,1,"",1,0,0,0,-1,1]`, `[6,2,"",1,0,0,-1,-1,2]`,
		`[7,3,"",-1,0,0,-1,0,0]`, `[6,3,null,-1,0,0,-1,0,0]`, `[6,3,0,-1,0,0,-1,0,0]`,
	} {
		t.Run(row, func(t *testing.T) {
			var rows [][]any
			if err := json.Unmarshal([]byte("["+row+"]"), &rows); err != nil {
				t.Fatal(err)
			}
			if validCommands(rows, 6) {
				t.Fatal("invalid command accepted")
			}
			_, url := setup(t)
			a, b, r, m := playing(t, url)
			input(a, r, m, 6, []any{rows[0]})
			b.read("aborted")
			a.rejected()
		})
	}
	// Every numeric field rejects fractions and nonnumeric JSON scalars/containers.
	for _, field := range []int{0, 1, 3, 4, 5, 6, 7, 8} {
		for _, value := range []any{0.5, "0", nil, true, []any{0.0}, map[string]any{"value": 0.0}} {
			row := []any{6.0, 3.0, "", -1.0, 0.0, 0.0, -1.0, 0.0, 0.0}
			row[field] = value
			if validCommands([][]any{row}, 6) {
				t.Fatalf("invalid field %d accepted: %v", field, value)
			}
		}
	}
}

func TestNineFieldLocalRelay(t *testing.T) {
	_, url := setup(t)
	a, b, r, m := playing(t, url)
	commands := []any{
		[]any{6, 0, "bagpipe", -1, 12, 5, -1, 2, -1},
		[]any{6, 1, "", 1, 0, 0, 0, -1, -1},
		[]any{6, 2, "", 1, 0, 0, -1, -1, -1},
		[]any{6, 3, "", -1, 0, 0, -1, 0, 0},
		[]any{6, 3, "", -1, 20, 10, -1, -1, 1},
		[]any{6, 3, "", -1, 10, 5, -1, -1, 2},
		[]any{6, 3, "", -1, 20, 10, -1, -1, 3},
		[]any{6, 5, "", -1, 0, 0, -1, -1, -1},
		[]any{6, 6, "bagpipe", -1, 2, 5, -1, 0, -1},
	}
	wantJSON, err := json.Marshal(commands)
	if err != nil {
		t.Fatal(err)
	}
	for side, from := range []*testClient{a, b} {
		to := b
		if side == 1 {
			to = a
		}
		input(from, r, m, 6, commands)
		got := to.read("input")
		gotJSON, err := json.Marshal(got["commands"])
		if err != nil {
			t.Fatal(err)
		}
		if len(got) != 8 || got["room_id"] != r || got["match_id"] != m || got["tick"] != float64(6) || got["side"] != float64(side) || string(gotJSON) != string(wantJSON) {
			t.Fatal("input changed during relay", got)
		}
	}
	for _, c := range []*testClient{a, b} {
		c.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": 7, "result": 3})
	}
	a.read("ended")
	b.read("ended")
}

func TestRecoveryIntentBoundaries(t *testing.T) {
	valid := [][]any{{6.0, 5.0, "", -1.0, 0.0, 0.0, -1.0, -1.0, -1.0}, {6.0, 6.0, "bagpipe", -1.0, 20.0, 10.0, -1.0, 3.0, -1.0}}
	if !validCommands(valid, 6) {
		t.Fatal("recovery intents rejected")
	}
	for _, index := range []int{2, 3, 4, 5, 6, 7, 8} {
		row := append([]any(nil), valid[0]...)
		if index == 2 {
			row[index] = "bagpipe"
		} else {
			row[index] = 2.0
		}
		if validCommands([][]any{row}, 6) {
			t.Fatalf("skip placeholder accepted: %d", index)
		}
	}
	if (matchRules{Mode: "score", Minutes: 30, Rounds: 1}).maxTicks() != 40500*339 {
		t.Fatal("recovery input cap")
	}
	if (matchRules{Mode: "single", Minutes: 30, Rounds: 1}).maxTicks() != 41850 {
		t.Fatal("single cap changed")
	}
}
