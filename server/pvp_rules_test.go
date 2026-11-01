package main

import (
	"encoding/json"
	"testing"
	"time"
)

func TestPVPRulesAndSeries(t *testing.T) {
	s, url := setup(t)
	a, b := dial(t, url), dial(t, url)
	hello(a)
	hello(b)
	a.send("create", map[string]any{})
	created := a.read("created")
	rID := created["room_id"].(string)
	b.send("join", map[string]any{"code": created["code"]})
	b.read("joined")
	a.read("joined")
	for _, c := range []*testClient{a, b} {
		c.send("ready", map[string]any{"room_id": rID, "ready": true})
		a.read("ready")
		b.read("ready")
	}
	a.send("rules", map[string]any{"room_id": rID, "rules": matchRules{Mode: "score", Minutes: 30, Rounds: 3}, "revision": 2})
	a.read("rules")
	b.read("rules")
	s.mu.Lock()
	r := aRoom(s, rID)
	if r.players[0].ready || r.players[1].ready {
		t.Error("rule edit must invalidate both ready")
	}
	s.mu.Unlock()
	// In-flight readiness from the previous revision is harmless.
	b.send("ready", map[string]any{"room_id": rID, "ready": true, "revision": 1})
	for _, c := range []*testClient{a, b} {
		c.send("ready", map[string]any{"room_id": rID, "ready": true, "revision": 2})
		a.read("ready")
		b.read("ready")
	}
	last := ""
	for round := 1; round <= 3; round++ {
		time.Sleep(1100 * time.Millisecond)
		a.send("start", map[string]any{"room_id": rID, "revision": 2})
		load := a.read("load")
		b.read("load")
		mid := load["match_id"].(string)
		if mid == last || int(load["round"].(float64)) != round {
			t.Fatal("new match ID/round")
		}
		last = mid
		for _, c := range []*testClient{a, b} {
			c.send("loaded", map[string]any{"room_id": rID, "match_id": mid})
		}
		a.read("begin")
		b.read("begin")
		// Controlled boundary fixture: exercise the extended cap, preserving sequential input validation.
		s.mu.Lock()
		r = aRoom(s, rID)
		for _, p := range r.players {
			p.nextTick = 40500
		}
		s.mu.Unlock()
		input(a, rID, mid, 40500, []any{})
		b.read("input")
		input(b, rID, mid, 40500, []any{})
		a.read("input")
		for _, c := range []*testClient{a, b} {
			c.send("finish", map[string]any{"room_id": rID, "match_id": mid, "tick": 40500, "result": round})
		}
		a.read("ended")
		b.read("ended")
		for _, c := range []*testClient{b, a} {
			c.send("return_room", map[string]any{"room_id": rID, "match_id": mid})
			a.read("returned")
			b.read("returned")
		}
		a.read("room")
		b.read("room")
		s.mu.Lock()
		r = aRoom(s, rID)
		if r.phase != "waiting" || r.matchID != "" || r.rules.Minutes != 30 || r.revision != 2 {
			t.Error("retain rules and room")
		}
		if round < 3 {
			if r.round != round || !r.players[0].ready || !r.players[1].ready {
				t.Error("next-round barrier")
			}
		} else if r.round != 0 || r.players[0].ready || r.players[1].ready {
			t.Error("series end must unlock room")
		}
		s.mu.Unlock()
	}
}
func aRoom(s *relay, id string) *room {
	for _, r := range s.rooms {
		if r.id == id {
			return r
		}
	}
	panic("missing room")
}
func TestPVPRulesMessageGuards(t *testing.T) {
	for _, raw := range []string{`{"mode":"score","minutes":0,"rounds":1}`, `{"mode":"single","minutes":31,"rounds":1}`, `{"mode":"score","minutes":5,"rounds":10}`, `{"mode":"x","minutes":5,"rounds":1}`, `{"mode":"score","minutes":5.5,"rounds":1}`, `{"mode":"score","minutes":5,"rounds":1,"extra":0}`} {
		data := []byte(`{"v":5,"type":"rules","seq":1,"room_id":"x","revision":2,"rules":` + raw + `}`)
		if _, err := decodeMessage(data); err == nil {
			t.Fatal("accepted invalid rules", raw)
		}
	}
	for _, kind := range []string{"guest", "during_play", "revision", "limit"} {
		t.Run(kind, func(t *testing.T) {
			s, url := setup(t)
			a, b, rID, mid := playing(t, url)
			if kind == "during_play" {
				a.send("rules", map[string]any{"room_id": rID, "rules": matchRules{Mode: "score", Minutes: 5, Rounds: 1}, "revision": 2})
				a.rejected()
				return
			}
			if kind == "limit" {
				s.mu.Lock()
				r := aRoom(s, rID)
				for _, p := range r.players {
					p.nextTick = r.rules.maxTicks() + inputDelay
				}
				s.mu.Unlock()
				input(a, rID, mid, (matchRules{Mode: "score", Minutes: 5, Rounds: 1}).maxTicks()+inputDelay, []any{})
				a.rejected()
				return
			}
			for _, c := range []*testClient{a, b} {
				c.send("finish", map[string]any{"room_id": rID, "match_id": mid, "tick": 6, "result": 3})
			}
			a.read("ended")
			b.read("ended")
			for _, c := range []*testClient{a, b} {
				c.send("return_room", map[string]any{"room_id": rID, "match_id": mid})
				a.read("returned")
				b.read("returned")
			}
			a.read("room")
			b.read("room")
			time.Sleep(1100 * time.Millisecond)
			sender := b
			revision := 2
			if kind == "revision" {
				sender = a
				revision = 3
			}
			sender.send("rules", map[string]any{"room_id": rID, "rules": matchRules{Mode: "score", Minutes: 5, Rounds: 1}, "revision": revision})
			sender.rejected()
		})
	}
	valid := map[string]any{"v": 5, "type": "rules", "seq": 1, "room_id": "x", "rules": matchRules{Mode: "single", Minutes: 30, Rounds: 9}, "revision": 2}
	data, _ := json.Marshal(valid)
	if _, err := decodeMessage(data); err != nil {
		t.Fatal(err)
	}
}
