package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

type testClient struct {
	t           *testing.T
	c           *websocket.Conn
	seq, outSeq int
	revision    int
}

func setup(t *testing.T) (*relay, string) {
	s := newRelay()
	h := httptest.NewServer(s)
	t.Cleanup(func() { s.stop(); h.Close() })
	return s, "ws" + strings.TrimPrefix(h.URL, "http") + "/ws"
}

func dial(t *testing.T, url string) *testClient {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	c, _, err := websocket.Dial(ctx, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { c.CloseNow() })
	return &testClient{t: t, c: c, revision: 1}
}

func (c *testClient) send(kind string, fields map[string]any) {
	c.t.Helper()
	c.seq++
	if kind == "ready" || kind == "squad" || kind == "start" {
		if _, ok := fields["revision"]; !ok {
			fields["revision"] = c.revision
		}
	}
	fields["v"], fields["type"], fields["seq"] = protocolVersion, kind, c.seq
	if kind == "squad" {
		if _, exists := fields["skills"]; !exists {
			if ids, ok := fields["operators"].([]string); ok {
				fields["skills"] = make([]int, len(ids))
			} else {
				fields["skills"] = []int{0}
			}
		}
	}
	data, err := json.Marshal(fields)
	if err != nil {
		c.t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := c.c.Write(ctx, websocket.MessageText, data); err != nil {
		c.t.Fatal(err)
	}
}

func (c *testClient) read(kind string) map[string]any {
	c.t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := c.c.Read(ctx)
	if err != nil {
		c.t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		c.t.Fatal(err)
	}
	c.outSeq++
	if m["type"] != kind || m["v"] != float64(protocolVersion) || m["seq"] != float64(c.outSeq) {
		c.t.Fatalf("expected %s seq %d: %s", kind, c.outSeq, data)
	}
	if revision, ok := m["revision"].(float64); ok {
		c.revision = int(revision)
	}
	return m
}

func (c *testClient) rejected() {
	c.t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, _, err := c.c.Read(ctx)
	if err == nil || ctx.Err() != nil {
		c.t.Fatalf("expected immediate close, got %v", err)
	}
}

func hello(c *testClient) {
	c.send("hello", map[string]any{"build": strings.Repeat("a", 64)})
	c.read("hello")
}

func playing(t *testing.T, url string) (*testClient, *testClient, string, string) {
	t.Helper()
	a, b := dial(t, url), dial(t, url)
	hello(a)
	hello(b)
	a.send("create", map[string]any{})
	created := a.read("created")
	roomID := created["room_id"].(string)
	b.send("join", map[string]any{"code": created["code"]})
	b.read("joined")
	a.read("joined")
	disableDraft(a, b, roomID)
	for _, c := range []*testClient{a, b} {
		c.send("ready", map[string]any{"room_id": roomID, "ready": true})
		a.read("ready")
		b.read("ready")
	}
	a.send("start", map[string]any{"room_id": roomID})
	loadA, loadB := a.read("load"), b.read("load")
	if loadA["seed"] != loadB["seed"] || loadA["match_id"] != loadB["match_id"] {
		t.Fatal("load contract differs")
	}
	matchID := loadA["match_id"].(string)
	for _, c := range []*testClient{a, b} {
		c.send("loaded", map[string]any{"room_id": roomID, "match_id": matchID})
	}
	a.read("begin")
	b.read("begin")
	return a, b, roomID, matchID
}

func input(c *testClient, roomID, matchID string, tick int, commands []any) {
	c.send("input", map[string]any{"room_id": roomID, "match_id": matchID, "tick": tick, "commands": commands})
}

func TestFullFlowAndEndReports(t *testing.T) {
	for _, result := range []int{1, 2, 3} {
		t.Run(fmt.Sprint(result), func(t *testing.T) {
			s, url := setup(t)
			a, b, r, m := playing(t, url)
			input(a, r, m, 6, []any{[]any{6, 0, "bagpipe", -1, 12, 5, -1, 2, -1}})
			got := b.read("input")
			if got["side"] != float64(0) || len(got["commands"].([]any)) != 1 {
				t.Fatal("command not relayed")
			}
			input(b, r, m, 6, []any{})
			a.read("input")
			a.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": 7, "result": result})
			// First report must not close the stream before the other peer reports.
			input(b, r, m, 7, []any{})
			a.read("input")
			b.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": 7, "result": result})
			for _, c := range []*testClient{a, b} {
				ended := c.read("ended")
				if ended["result"] != float64(result) {
					t.Fatal("result declaration changed")
				}
			}
			s.mu.Lock()
			rooms := len(s.rooms)
			s.mu.Unlock()
			if rooms != 1 {
				t.Fatal("ended room must be retained")
			}
			a.send("leave", map[string]any{"room_id": r})
			b.read("aborted")
			b.send("create", map[string]any{})
			b.read("created")
		})
	}
}

func TestDeployOperatorIDs(t *testing.T) {
	for _, id := range []string{"zima", "liskarm", "blue_poison", "projekt_red", "amiya", "skyfire", "istina", "pramanix", "platinum", "specter", "perfumer", "cuora", "texas", "lappland", "ptilopsis", "gravel", "w", "saga", "lumen", "skadi_alter", "seaborn", "chen", "aak", "nian", "kaltsit", "mon3tr", "angelina", "bagpipe", "blaze", "ceobe", "exusiai", "hoshiguma", "nightingale", "nightingale_phantom", "phantom", "phantom_clone", "swire_alter", "skadi", "typhon", "ifrit", "siege", "saria", "mostima", "weedy", "magallan", "weedy_cannon", "magallan_drone_f", "magallan_drone_l", "magallan_drone_a"} {
		t.Run(id, func(t *testing.T) {
			_, url := setup(t)
			a, b, r, m := playing(t, url)
			commands := []any{[]any{6, 0, id, -1, 12, 5, -1, 2, -1}}
			input(a, r, m, 6, commands)
			got := b.read("input")
			wantJSON, err := json.Marshal(commands)
			if err != nil {
				t.Fatal(err)
			}
			gotJSON, err := json.Marshal(got["commands"])
			if err != nil {
				t.Fatal(err)
			}
			if got["side"] != float64(0) || string(gotJSON) != string(wantJSON) {
				t.Fatal("deployment command changed during relay", got)
			}
		})
	}
	for _, id := range []any{"", "nightingale_phantom ", "Nightingale_phantom", "nightingale_phantom_extra", "nightingale_phantom\x00", "nightingale-phantom", 0, nil} {
		t.Run(fmt.Sprintf("reject_%v", id), func(t *testing.T) {
			_, url := setup(t)
			a, b, r, m := playing(t, url)
			input(a, r, m, 6, []any{[]any{6, 0, id, -1, 12, 5, -1, 2, -1}})
			b.read("aborted")
			a.rejected()
		})
	}
}

func TestRejectedInput(t *testing.T) {
	for _, problem := range []string{"skip", "past", "cross_room", "cross_match", "bad_command", "duplicate", "sequence", "finish_mismatch"} {
		t.Run(problem, func(t *testing.T) {
			_, url := setup(t)
			a, b, r, m := playing(t, url)
			tick := 6
			commands := []any{}
			switch problem {
			case "skip":
				tick = 7
			case "past":
				tick = 5
			case "cross_room":
				r = strings.Repeat("f", 32)
			case "cross_match":
				m = strings.Repeat("f", 32)
			case "bad_command":
				commands = []any{[]any{6, 0, "bad", -1, 12, 5, -1, 2, -1}}
			case "duplicate":
				input(a, r, m, 6, commands)
				b.read("input")
			case "sequence":
				a.seq--
			case "finish_mismatch":
				a.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": 6, "result": 1})
				// Ordered input delivery proves the first finish was processed before the conflicting report.
				input(a, r, m, 6, []any{})
				b.read("input")
				b.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": 6, "result": 2})
				a.read("aborted")
				b.rejected()
				return
			}
			input(a, r, m, tick, commands)
			b.read("aborted")
			a.rejected()
		})
	}
}

func TestJoinGuards(t *testing.T) {
	for _, problem := range []string{"unknown_room", "build", "third"} {
		t.Run(problem, func(t *testing.T) {
			_, url := setup(t)
			a, b := dial(t, url), dial(t, url)
			hello(a)
			build := strings.Repeat("a", 64)
			if problem == "build" {
				build = strings.Repeat("b", 64)
			}
			b.send("hello", map[string]any{"build": build})
			b.read("hello")
			a.send("create", map[string]any{})
			r := a.read("created")
			code := r["code"].(string)
			if problem == "unknown_room" {
				if code[0] == '0' {
					code = "1" + code[1:]
				} else {
					code = "0" + code[1:]
				}
			}
			if problem == "third" {
				b.send("join", map[string]any{"code": code})
				b.read("joined")
				a.read("joined")
				b = dial(t, url)
				hello(b)
			}
			b.send("join", map[string]any{"code": code})
			b.rejected()
		})
	}
}

func TestInvalidMessage(t *testing.T) {
	for _, data := range []string{
		`{"v":1,"type":"hello","seq":1,"build":"` + strings.Repeat("a", 64) + `"}`,
		`{"v":2,"type":"hello","seq":1,"build":"` + strings.Repeat("a", 64) + `"}`,
		`{"v":3,"type":"hello","seq":1,"build":"` + strings.Repeat("a", 64) + `","other":1}`,
		`{"v":3,"v":3,"type":"create","seq":1}`, `[]`, `{} {}`, `{"v":null}`, strings.Repeat("x", 32769),
	} {
		t.Run(fmt.Sprint(len(data), data[:1]), func(t *testing.T) {
			_, url := setup(t)
			c := dial(t, url)
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			if err := c.c.Write(ctx, websocket.MessageText, []byte(data)); err != nil {
				t.Fatal(err)
			}
			c.rejected()
		})
	}
}

func TestTimeoutsDisconnectAndLimits(t *testing.T) {
	s, url := setup(t)
	a, b, r, _ := playing(t, url)
	a.c.CloseNow()
	b.read("aborted")
	s.mu.Lock()
	rooms := len(s.rooms)
	s.mu.Unlock()
	if rooms != 0 {
		t.Fatal("disconnect leaked room", r)
	}
	c := dial(t, url)
	hello(c)
	c.send("create", map[string]any{})
	c.read("created")
	s.sweep(time.Now().Add(11 * time.Minute))
	c.rejected()
	s.mu.Lock()
	rooms = len(s.rooms)
	s.mu.Unlock()
	if rooms != 0 {
		t.Fatal("expiry leaked room")
	}
	// Queue limit is deterministic; socket buffering is OS dependent.
	s.mu.Lock()
	p := &peer{out: make(chan []byte, 1), done: make(chan struct{})}
	s.peers[p] = true
	s.send(p, "test", map[string]any{})
	s.send(p, "test", map[string]any{})
	closed := p.closed
	s.mu.Unlock()
	if !closed {
		t.Fatal("slow consumer not closed")
	}
}

func TestCapacityAndOrigin(t *testing.T) {
	s, url := setup(t)
	for i := 0; i < 5; i++ {
		c := dial(t, url)
		hello(c)
		c.send("create", map[string]any{})
		c.read("created")
	}
	c := dial(t, url)
	hello(c)
	c.send("create", map[string]any{})
	c.rejected()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_, resp, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: http.Header{"Origin": []string{"https://example.com"}}})
	if err == nil || resp.StatusCode != 403 {
		t.Fatal("unexpected browser origin accepted")
	}
	s.stop()
}

func TestProtocolValidation(t *testing.T) {
	for _, row := range []string{
		`[6,0,"bagpipe",-1,12,5,-1,2,-1]`, `[6,1,"",1,0,0,0,-1,-1]`, `[6,1,"",1,0,0,1,-1,-1]`, `[6,1,"",1,0,0,2,-1,-1]`, `[6,2,"",1,0,0,-1,-1,-1]`,
	} {
		var rows [][]any
		json.Unmarshal([]byte("["+row+"]"), &rows)
		if !validCommands(rows, 6) {
			t.Fatal("valid row rejected", row)
		}
	}
	for _, row := range []string{
		`[6,0,"bagpipe",-1,21,5,-1,2,-1]`, `[6,1,"",1,0,0,3,-1,-1]`, `[6,2,"",1,0,0,-1,0,-1]`, `[6.5,0,"bagpipe",-1,12,5,-1,2,-1]`,
	} {
		var rows [][]any
		json.Unmarshal([]byte("["+row+"]"), &rows)
		if validCommands(rows, 6) {
			t.Fatal("bad row accepted", row)
		}
	}
}

func TestJitterAndLoadingBarrier(t *testing.T) {
	s, url := setup(t)
	a, b, r, m := playing(t, url)
	for i, delay := range []time.Duration{0, 200 * time.Millisecond, 20 * time.Millisecond, 90 * time.Millisecond} {
		input(a, r, m, 6+i, []any{})
		time.Sleep(delay)
		if b.read("input")["tick"] != float64(6+i) {
			t.Fatal("jitter reordered tick")
		}
		input(b, r, m, 6+i, []any{})
		if a.read("input")["tick"] != float64(6+i) {
			t.Fatal("reverse stream reordered tick")
		}
	}
	s.sweep(time.Now().Add(9 * time.Second))
	s.mu.Lock()
	if len(s.rooms) != 0 || len(s.peers) != 1 {
		t.Error("timeout must remove room and close one peer")
	}
	for p := range s.peers {
		if p.room != nil || p.closed {
			t.Error("survivor must detach from room")
		}
	}
	s.mu.Unlock()
	// The first timed-out peer closes; the survivor receives aborted and a new idle deadline.
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := a.c.Read(ctx)
	if err == nil {
		var event map[string]any
		if json.Unmarshal(data, &event) != nil || event["type"] != "aborted" || event["reason"] != "peer_left" || event["v"] != float64(protocolVersion) || event["seq"] != float64(a.outSeq+1) {
			t.Fatal("unexpected event before timeout close", string(data))
		}
		return
	}
	if ctx.Err() != nil {
		t.Fatal("timeout produced neither close nor abort", err)
	}
}

func TestStageAndResourceGuards(t *testing.T) {
	for _, guard := range []string{"handshake", "loading", "ahead", "bytes", "controls", "connections"} {
		t.Run(guard, func(t *testing.T) {
			s := newRelay()
			now := time.Now()
			a := &peer{out: make(chan []byte, 32), done: make(chan struct{}), build: strings.Repeat("a", 64), rateAt: now, nextTick: 6, deadline: now.Add(8 * time.Second)}
			b := &peer{out: make(chan []byte, 32), done: make(chan struct{}), build: a.build, nextTick: 6, deadline: now.Add(8 * time.Second)}
			r := &room{id: "r", code: "123456", phase: "playing", matchID: "m", players: [2]*peer{a, b}}
			a.room, b.room = r, r
			s.rooms[r.code] = r
			s.peers[a], s.peers[b] = true, true
			switch guard {
			case "handshake":
				a.build = ""
				a.room = nil
				r.players[0] = nil // An unhandshaken peer cannot also belong to the room.
				s.sweep(now.Add(9 * time.Second))
				if !a.closed {
					t.Fatal("handshake lease not enforced")
				}
			case "loading":
				r.phase = "loading"
				if err := s.handle(a, message{V: protocolVersion, Type: "loaded", Seq: 1, RoomID: "r", MatchID: "m"}, now); err != nil {
					t.Fatal(err)
				}
				if r.phase != "loading" || b.loaded {
					t.Fatal("began before both loaded")
				}
				s.sweep(now.Add(31 * time.Second))
				if !a.closed || len(s.rooms) != 0 {
					t.Fatal("loading lease not enforced")
				}
			case "ahead":
				a.nextTick = 127
				a.inputAt = now
				if err := s.handle(a, message{V: protocolVersion, Type: "input", Seq: 1, RoomID: "r", MatchID: "m", Tick: 127}, now); err == nil {
					t.Fatal("ahead stream accepted")
				}
			case "bytes":
				a.queuedBytes = queueBytes
				s.send(a, "test", map[string]any{})
				if !a.closed {
					t.Fatal("byte queue cap ignored")
				}
			case "controls":
				a.controls = 10
				if err := s.handle(a, message{V: protocolVersion, Type: "ready", Seq: 1, RoomID: "r", Ready: new(bool)}, now); err == nil {
					t.Fatal("control rate ignored")
				}
			case "connections":
				for len(s.peers) < maxConnections {
					s.peers[&peer{out: make(chan []byte, 1), done: make(chan struct{})}] = true
				}
				h := httptest.NewServer(s)
				defer h.Close()
				defer s.stop()
				resp, err := http.Get(h.URL + "/ws")
				if err != nil {
					t.Fatal(err)
				}
				defer resp.Body.Close()
				if resp.StatusCode != 503 {
					t.Fatal("connection cap ignored")
				}
			}
		})
	}
}

func TestBoundaryEndDeclarations(t *testing.T) {
	for _, tick := range []int{6750} {
		for _, result := range []int{1, 2, 3} {
			t.Run(fmt.Sprintf("%d/%d", tick, result), func(t *testing.T) {
				s, url := setup(t)
				a, b, r, m := playing(t, url)
				// Only the report boundary is tested here; Godot verifies actual victory rules.
				s.mu.Lock()
				for p := range s.peers {
					p.nextTick = tick + inputDelay
				}
				s.mu.Unlock()
				for _, c := range []*testClient{a, b} {
					c.send("finish", map[string]any{"room_id": r, "match_id": m, "tick": tick, "result": result})
				}
				a.read("ended")
				b.read("ended")
			})
		}
	}
}

// Existing input/room tests keep their free-squad setup; draft_test covers the default.
func disableDraft(a, b *testClient, rid string) {
	a.send("rules", map[string]any{"room_id": rid, "revision": a.revision + 1, "rules": matchRules{Mode: "score", Minutes: 5, Rounds: 1, DraftEnabled: false}})
	a.read("rules")
	b.read("rules")
}
