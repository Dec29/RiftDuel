package main

import (
	"fmt"
	"reflect"
	"strings"
	"testing"
)

func squadRoom(t *testing.T, url string) (*testClient, *testClient, string) {
	t.Helper()
	a, b := dial(t, url), dial(t, url)
	hello(a)
	hello(b)
	a.send("create", map[string]any{})
	created := a.read("created")
	r := created["room_id"].(string)
	b.send("join", map[string]any{"code": created["code"]})
	b.read("joined")
	a.read("joined")
	disableDraft(a, b, r)
	return a, b, r
}

func TestSquadForwardAndUpdate(t *testing.T) {
	_, url := setup(t)
	a, b, r := squadRoom(t, url)
	longID := "a" + strings.Repeat("0", 63)
	full := []string{longID}
	for i := 1; i < 12; i++ {
		full = append(full, fmt.Sprintf("new_operator_%d", i))
	}
	for side, operators := range [][]string{{"a"}, full} {
		from, to := a, b
		if side == 1 {
			from, to = b, a
		}
		from.send("squad", map[string]any{"room_id": r, "operators": operators})
		got := to.read("squad")
		want := make([]any, len(operators))
		for i, id := range operators {
			want[i] = id
		}
		if len(got) != 8 || got["room_id"] != r || got["side"] != float64(side) || !reflect.DeepEqual(got["operators"], want) {
			t.Fatal("squad changed or unexpected fields", got)
		}
	}
	// The next messages also prove neither sender received its own squad event.
	a.send("ready", map[string]any{"room_id": r, "ready": true})
	a.read("ready")
	b.read("ready")
	// The other player's readiness does not block the unready sender's update.
	b.send("squad", map[string]any{"room_id": r, "operators": []string{"unknown_valid_id"}})
	a.read("squad")
	a.send("ready", map[string]any{"room_id": r, "ready": false})
	a.read("ready")
	b.read("ready")
	a.send("squad", map[string]any{"room_id": r, "operators": []string{"replacement"}})
	got := b.read("squad")
	if !reflect.DeepEqual(got["operators"], []any{"replacement"}) {
		t.Fatal("updated squad not relayed")
	}
	a.send("ready", map[string]any{"room_id": r, "ready": true})
	a.read("ready")
	b.read("ready")
	b.send("ready", map[string]any{"room_id": r, "ready": true})
	a.read("ready")
	b.read("ready")
	a.send("start", map[string]any{"room_id": r})
	a.read("load")
	b.read("load")
}

func TestSquadInvalidOperators(t *testing.T) {
	thirteen := make([]string, 13)
	for i := range thirteen {
		thirteen[i] = fmt.Sprintf("operator_%d", i)
	}
	for name, operators := range map[string]any{
		"empty": []string{}, "thirteen": thirteen, "duplicate": []string{"a", "a"},
		"null": nil, "string": "a", "number": 1, "object": map[string]any{"id": "a"},
		"non_string": []any{"a", 1}, "null_entry": []any{nil}, "empty_id": []string{""},
		"uppercase": []string{"Angelina"}, "leading_number": []string{"1a"}, "leading_underscore": []string{"_a"},
		"hyphen": []string{"a-b"}, "space": []string{"a "}, "unicode": []string{"夜莺"},
		"newline": []string{"a\n"}, "nul": []string{"a\x00"}, "too_long": []string{strings.Repeat("a", 65)},
	} {
		t.Run(name, func(t *testing.T) {
			_, url := setup(t)
			a, b, r := squadRoom(t, url)
			a.send("squad", map[string]any{"room_id": r, "operators": operators})
			b.read("aborted")
			a.rejected()
		})
	}
}

func TestSquadSchema(t *testing.T) {
	for _, problem := range []string{"missing_operators", "missing_room", "skill", "side", "extra", "duplicate_key"} {
		t.Run(problem, func(t *testing.T) {
			fields := fmt.Sprintf(`"v":3,"type":"squad","seq":1,"room_id":"%s","operators":["a"],"skills":[0]`, strings.Repeat("a", 32))
			switch problem {
			case "missing_operators":
				fields = `"v":3,"type":"squad","seq":1,"room_id":"a"`
			case "missing_room":
				fields = `"v":3,"type":"squad","seq":1,"operators":["a"]`
			case "skill":
				fields += `,"skill":0`
			case "side":
				fields += `,"side":0`
			case "extra":
				fields += `,"extra":true`
			case "duplicate_key":
				fields += `,"operators":["b"]`
			}
			if _, err := decodeMessage([]byte("{" + fields + "}")); err == nil {
				t.Fatal("invalid schema accepted")
			}
		})
	}
}

func TestSquadPhaseAndBinding(t *testing.T) {
	for _, problem := range []string{"before_join", "no_room", "wrong_room", "ready", "loading", "playing"} {
		t.Run(problem, func(t *testing.T) {
			_, url := setup(t)
			var a, b *testClient
			var r string
			switch problem {
			case "before_join", "no_room":
				a = dial(t, url)
				hello(a)
				r = strings.Repeat("a", 32)
				if problem == "before_join" {
					a.send("create", map[string]any{})
					r = a.read("created")["room_id"].(string)
				}
			case "playing":
				a, b, r, _ = playing(t, url)
			default:
				a, b, r = squadRoom(t, url)
				if problem == "wrong_room" {
					r = strings.Repeat("f", 32)
				}
				if problem == "ready" || problem == "loading" {
					a.send("ready", map[string]any{"room_id": r, "ready": true})
					a.read("ready")
					b.read("ready")
				}
				if problem == "loading" {
					b.send("ready", map[string]any{"room_id": r, "ready": true})
					a.read("ready")
					b.read("ready")
					a.send("start", map[string]any{"room_id": r})
					a.read("load")
					b.read("load")
				}
			}
			a.send("squad", map[string]any{"room_id": r, "operators": []string{"a"}})
			if b != nil {
				b.read("aborted")
			}
			a.rejected()
		})
	}
}

func TestSquadControlRate(t *testing.T) {
	_, url := setup(t)
	a, b, r := squadRoom(t, url)
	// hello and create have already consumed two of the ten control messages.
	for i := 0; i < 8; i++ {
		a.send("squad", map[string]any{"room_id": r, "operators": []string{"a"}})
		b.read("squad")
	}
	a.send("squad", map[string]any{"room_id": r, "operators": []string{"a"}})
	b.read("aborted")
	a.rejected()
}

func TestSquadSkillSelection(t *testing.T) {
	_, url := setup(t)
	a, b, r := squadRoom(t, url)
	a.send("squad", map[string]any{"room_id": r, "operators": []string{"exusiai", "other"}, "skills": []int{1, 2}})
	got := b.read("squad")
	if !reflect.DeepEqual(got["skills"], []any{float64(1), float64(2)}) {
		t.Fatal("selected skills changed", got)
	}
}

func TestSquadInvalidSkills(t *testing.T) {
	for name, skills := range map[string]any{"short": []int{}, "long": []int{0, 1}, "negative": []int{-1}, "unavailable_index": []int{3}, "null": nil, "fraction": []float64{1.5}, "boolean": []bool{true}, "string": []string{"1"}} {
		t.Run(name, func(t *testing.T) {
			_, url := setup(t)
			a, b, r := squadRoom(t, url)
			a.send("squad", map[string]any{"room_id": r, "operators": []string{"a"}, "skills": skills})
			b.read("aborted")
			a.rejected()
		})
	}
	if _, err := decodeMessage([]byte(`{"v":3,"type":"squad","seq":1,"room_id":"a","operators":["a"]}`)); err == nil {
		t.Fatal("legacy IDs-only squad accepted")
	}
}
