package main

import (
	"encoding/json"
	"reflect"
	"sort"
	"testing"
	"time"
)

func draftIDs(d *draftState, n int, base []string) []string {
	ids := make([]string, 0, len(draftSkillCounts))
	for id := range draftSkillCounts {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	result := append([]string{}, base...)
	for _, id := range ids {
		if len(result) >= n {
			break
		}
		if !hasID(result, id) && !d.banned(id) {
			result = append(result, id)
		}
	}
	return result
}
func TestDraftRulesPrivacyAndTimeout(t *testing.T) {
	now := time.Now()
	d := newDraft(now)
	r := &room{draft: d, players: [2]*peer{{squad: []string{"nightingale", "bagpipe"}, skills: []int{2, 1}}, {}}}
	if d.deadline.Sub(now) != 20*time.Second {
		t.Fatal("ban20")
	}
	if err := d.ban(0, "bagpipe", now); err != nil {
		t.Fatal(err)
	}
	if err := d.ban(1, "bagpipe", now); err == nil || len(d.bans[1]) != 0 {
		t.Fatal("duplicate ban")
	}
	d.selection(0, []string{}, []int{}, true, now)
	d.selection(1, []string{}, []int{}, true, now)
	first := draftIDs(d, 6, nil)
	d.selection(0, first[:3], nil, false, now)
	if len(d.picks[0]) != 0 {
		t.Fatal("pending leak")
	}
	d.selection(0, first, nil, true, now)
	if len(d.picks[0]) != 0 || !d.locked[0] {
		t.Fatal("confirmed leak")
	}
	d.selection(1, first, nil, true, now)
	if d.stage != 2 || !reflect.DeepEqual(d.picks[0], d.picks[1]) || d.banLimits != [2]int{3, 2} {
		t.Fatal("shared picks or empty-ban limit")
	}
	if err := d.ban(0, first[0], now); err == nil {
		t.Fatal("protected first picks")
	}
	d.expire(r, now)
	second := draftIDs(d, 12, first)
	d.selection(0, second, nil, true, now)
	d.selection(1, second[:9], nil, false, now)
	d.expire(r, now)
	if d.stage != 4 || len(d.picks[1]) != 12 || !reflect.DeepEqual(d.picks[1][:9], second[:9]) {
		t.Fatal("partial timeout preservation")
	}
	indices := make([]int, 12)
	for i, id := range d.picks[0] {
		indices[i] = draftSkillCounts[id] - 1
	}
	d.selection(0, d.picks[0], indices, true, now)
	if len(d.skills[0]) != 0 {
		t.Fatal("skill leak")
	}
	bad := append([]int{}, indices...)
	bad[0] = 3
	if err := d.selection(1, d.picks[1], bad, true, now); err == nil {
		t.Fatal("invalid skill")
	}
	d.expire(r, now)
	if d.stage != 5 || !reflect.DeepEqual(d.skills[0], indices) || len(d.skills[1]) != 12 {
		t.Fatal("final skills")
	}
	auto := newDraft(now)
	r.draft = auto
	for phase, want := range []time.Duration{20 * time.Second, 100 * time.Second, 20 * time.Second, 100 * time.Second, 30 * time.Second} {
		if auto.stage != phase || auto.duration() != want {
			t.Fatal("five stage clocks", phase)
		}
		auto.expire(r, auto.deadline)
	}
	if auto.picks[0][0] != "nightingale" || auto.skills[0][0] != 2 || len(auto.picks[0]) != 12 {
		t.Fatal("favorite fallback")
	}
}
func TestDraftProtocolGuards(t *testing.T) {
	for _, kind := range []string{"draft_update", "draft_submit"} {
		value := map[string]any{"v": protocolVersion, "seq": 1, "type": kind, "room_id": "r", "draft_id": "d", "stage": 1, "operators": []string{}, "skills": []int{}}
		data, _ := json.Marshal(value)
		if _, err := decodeMessage(data); err != nil {
			t.Fatal(err)
		}
		delete(value, "stage")
		data, _ = json.Marshal(value)
		if _, err := decodeMessage(data); err == nil {
			t.Fatal("missing phase")
		}
	}
	for _, extra := range []string{`"draft_enabled":null`, `"draft_enabled":1`, `"draft_enabled":"true"`, `"unknown":false`} {
		raw := []byte(`{"v":8,"seq":1,"type":"rules","room_id":"r","revision":2,"rules":{"mode":"score","minutes":5,"rounds":1,` + extra + `}}`)
		if _, err := decodeMessage(raw); err == nil {
			t.Fatal("bad rules", extra)
		}
	}
}
func draftRoom(t *testing.T, rounds int) (*relay, *testClient, *testClient, string, string) {
	t.Helper()
	s, url := setup(t)
	a, b := dial(t, url), dial(t, url)
	hello(a)
	hello(b)
	a.send("create", map[string]any{})
	created := a.read("created")
	rid := created["room_id"].(string)
	if !created["rules"].(map[string]any)["draft_enabled"].(bool) {
		t.Fatal("default off")
	}
	b.send("join", map[string]any{"code": created["code"]})
	b.read("joined")
	a.read("joined")
	a.send("rules", map[string]any{"room_id": rid, "rules": matchRules{Mode: "score", Minutes: 1, Rounds: rounds, DraftEnabled: true}, "revision": 2})
	a.read("rules")
	b.read("rules")
	for _, c := range []*testClient{a, b} {
		c.send("squad", map[string]any{"room_id": rid, "operators": []string{"bagpipe", "nightingale"}, "skills": []int{1, 2}, "revision": 2})
		if c == a {
			b.read("squad")
		} else {
			a.read("squad")
		}
		c.send("ready", map[string]any{"room_id": rid, "ready": true, "revision": 2})
		a.read("ready")
		b.read("ready")
	}
	a.send("start", map[string]any{"room_id": rid, "revision": 2})
	first := a.read("draft")
	b.read("draft")
	did := first["draft"].(map[string]any)["draft_id"].(string)
	return s, a, b, rid, did
}
func draftRequest(c *testClient, kind, rid, did string, stage int, ids []string, skills []int) {
	if ids == nil {
		ids = []string{}
	}
	if skills == nil {
		skills = []int{}
	}
	c.send(kind, map[string]any{"room_id": rid, "draft_id": did, "stage": stage, "operators": ids, "skills": skills})
}
func readDraftPair(a, b *testClient) map[string]any {
	left, right := a.read("draft")["draft"].(map[string]any), b.read("draft")["draft"].(map[string]any)
	if !reflect.DeepEqual(left, right) {
		a.t.Fatal("different public draft events")
	}
	return left
}
func TestDraftRelayFlowAndSeries(t *testing.T) {
	s, a, b, rid, did := draftRoom(t, 2)
	a.send("draft_ban", map[string]any{"room_id": rid, "draft_id": did, "stage": 0, "operator_id": "aak"})
	event := readDraftPair(a, b)
	if len(event["bans"].([]any)[0].([]any)) != 1 {
		t.Fatal("immediate ban")
	}
	b.send("draft_ban", map[string]any{"room_id": rid, "draft_id": did, "stage": 0, "operator_id": "aak"})
	b.read("draft_rejected")
	draftRequest(a, "draft_submit", rid, did, 0, nil, nil)
	readDraftPair(a, b)
	draftRequest(b, "draft_submit", rid, did, 0, nil, nil)
	readDraftPair(a, b)
	s.mu.Lock()
	r := aRoom(s, rid)
	first := draftIDs(r.draft, 6, nil)
	s.mu.Unlock()
	draftRequest(a, "draft_update", rid, did, 1, first[:2], nil)
	draftRequest(a, "draft_submit", rid, did, 1, first, nil)
	event = readDraftPair(a, b)
	if len(event["picks"].([]any)[0].([]any)) != 0 {
		t.Fatal("wire pick leak")
	}
	draftRequest(b, "draft_submit", rid, did, 1, first, nil)
	event = readDraftPair(a, b)
	if !reflect.DeepEqual(event["picks"].([]any)[0], event["picks"].([]any)[1]) {
		t.Fatal("same picks rejected")
	}
	a.send("draft_ban", map[string]any{"room_id": rid, "draft_id": did, "stage": 2, "operator_id": first[0]})
	a.read("draft_rejected")
	draftRequest(a, "draft_submit", rid, did, 2, nil, nil)
	readDraftPair(a, b)
	draftRequest(b, "draft_submit", rid, did, 2, nil, nil)
	readDraftPair(a, b)
	s.mu.Lock()
	second := draftIDs(r.draft, 12, first)
	s.mu.Unlock()
	draftRequest(a, "draft_submit", rid, did, 3, second, nil)
	readDraftPair(a, b)
	draftRequest(b, "draft_submit", rid, did, 3, second, nil)
	readDraftPair(a, b)
	indices := make([]int, 12)
	for i, id := range second {
		indices[i] = draftSkillCounts[id] - 1
	}
	draftRequest(a, "draft_update", rid, did, 4, second, indices)
	draftRequest(a, "draft_submit", rid, did, 4, second, indices)
	event = readDraftPair(a, b)
	if len(event["skills"].([]any)[0].([]any)) != 0 {
		t.Fatal("wire skill leak")
	}
	draftRequest(b, "draft_submit", rid, did, 4, second, indices)
	event = readDraftPair(a, b)
	if event["stage"] != float64(5) {
		t.Fatal("final stage")
	}
	for round := 1; round <= 2; round++ {
		load := a.read("load")
		b.read("load")
		mid := load["match_id"].(string)
		for _, c := range []*testClient{a, b} {
			c.send("loaded", map[string]any{"room_id": rid, "match_id": mid})
		}
		a.read("begin")
		b.read("begin")
		for _, c := range []*testClient{a, b} {
			c.send("finish", map[string]any{"room_id": rid, "match_id": mid, "tick": 6, "result": 1})
		}
		a.read("ended")
		b.read("ended")
		for _, c := range []*testClient{a, b} {
			c.send("return_room", map[string]any{"room_id": rid, "match_id": mid})
			a.read("returned")
			b.read("returned")
		}
		a.read("room")
		b.read("room")
		if round == 1 {
			a.send("start", map[string]any{"room_id": rid, "revision": 2})
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if r.draft != nil || r.round != 0 || r.phase != "waiting" {
		t.Fatal("final room reset")
	}
}
func TestDraftCancelAndSweep(t *testing.T) {
	s, a, b, rid, did := draftRoom(t, 1)
	s.mu.Lock()
	r := aRoom(s, rid)
	deadline := r.draft.deadline
	s.mu.Unlock()
	s.sweep(deadline)
	event := readDraftPair(a, b)
	if event["stage"] != float64(1) {
		t.Fatal("ban timeout")
	}
	for expected := 2; expected <= 5; expected++ {
		s.mu.Lock()
		deadline = r.draft.deadline
		s.mu.Unlock()
		s.sweep(deadline)
		event = readDraftPair(a, b)
		if event["stage"] != float64(expected) {
			t.Fatal("sweep phase", expected)
		}
	}
	a.read("load")
	b.read("load")
	// A fresh room verifies cancellation does not disconnect or spend room identity.
	_, a, b, rid, did = draftRoom(t, 1)
	a.send("draft_cancel", map[string]any{"room_id": rid, "draft_id": did, "stage": 0})
	a.read("draft_cancelled")
	b.read("draft_cancelled")
	a.send("ready", map[string]any{"room_id": rid, "revision": 2, "ready": true})
	a.read("ready")
	b.read("ready")
}
