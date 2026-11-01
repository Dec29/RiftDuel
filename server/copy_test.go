package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/coder/websocket"
	"strings"
	"testing"
	"time"
)

func TestCopyCommandBoundaries(t *testing.T) {
	for facing := 0; facing < 4; facing++ {
		row := []any{6.0, 4.0, "bagpipe", 999999.0, 0.0, 0.0, -1.0, float64(facing), -1.0}
		if !validCommands([][]any{row}, 6) {
			t.Fatal("valid copy rejected", row)
		}
	}
	for _, id := range []string{"vigil_wolf", "pozyomka_typewriter", "silence_alter_drone", "curse_doll", "medical_drone", "phantom_clone", "nightingale_phantom", "weedy_cannon", "seaborn", "mon3tr", "magallan_drone_f", "magallan_drone_l", "magallan_drone_a", "", "unknown"} {
		if validCommands([][]any{{6.0, 4.0, id, 0.0, 0.0, 0.0, -1.0, 0.0, -1.0}}, 6) {
			t.Fatal("invalid target accepted", id)
		}
	}
	for _, change := range []struct {
		field int
		value any
	}{{0, 7.0}, {1, 5.0}, {3, -1.0}, {4, 1.0}, {5, 1.0}, {6, 0.0}, {7, -1.0}, {7, 4.0}, {8, 0.0}} {
		row := []any{6.0, 4.0, "bagpipe", 0.0, 0.0, 0.0, -1.0, 0.0, -1.0}
		row[change.field] = change.value
		if validCommands([][]any{row}, 6) {
			t.Fatal("invalid copy field", row)
		}
	}
	for _, field := range []int{0, 1, 3, 4, 5, 6, 7, 8} {
		for _, value := range []any{0.5, true, nil, "0", []any{0.0}} {
			row := []any{6.0, 4.0, "bagpipe", 0.0, 0.0, 0.0, -1.0, 0.0, -1.0}
			row[field] = value
			if validCommands([][]any{row}, 6) {
				t.Fatal("invalid numeric field", field, value)
			}
		}
	}
	for _, row := range [][]any{{6.0, 4.0, "bagpipe", 0.0, 0.0, 0.0, -1.0, 0.0}, {6.0, 4.0, "bagpipe", 0.0, 0.0, 0.0, -1.0, 0.0, -1.0, 0.0}} {
		if validCommands([][]any{row}, 6) {
			t.Fatal("must use nine fields")
		}
	}
}

func TestCopyRelayForwardsIntent(t *testing.T) {
	_, url := setup(t)
	a, b, r, m := playing(t, url)
	commands := []any{[]any{6, 4, "bagpipe", 99999, 0, 0, -1, 3, -1}}
	input(a, r, m, 6, commands)
	event := b.read("input")
	want, _ := json.Marshal(commands)
	got, _ := json.Marshal(event["commands"])
	if string(want) != string(got) {
		t.Fatal("copy fields changed", string(got))
	}
	// Relay does not own simulated unit IDs, copy windows, or operator deployment state.
	input(b, r, m, 6, []any{})
	a.read("input")
}

func TestCopyProtocolRejectsLegacy(t *testing.T) {
	for version := 0; version < protocolVersion; version++ {
		t.Run(fmt.Sprint(version), func(t *testing.T) {
			_, url := setup(t)
			client := dial(t, url)
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			raw := fmt.Sprintf(`{"v":%d,"type":"hello","seq":1,"build":"%s"}`, version, strings.Repeat("a", 64))
			if err := client.c.Write(ctx, websocket.MessageText, []byte(raw)); err != nil {
				t.Fatal(err)
			}
			client.rejected()
		})
	}
}
