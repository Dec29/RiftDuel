package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestV2CreatedCodesAndCodeOnlyJoin(t *testing.T) {
	_, url := setup(t)
	codes := map[string]bool{}
	rooms := map[string]bool{}
	for i := 0; i < maxRooms; i++ {
		a := dial(t, url)
		hello(a)
		a.send("create", map[string]any{})
		created := a.read("created")
		code, ok := created["code"].(string)
		if !ok || !roomCodePattern.MatchString(code) || codes[code] {
			t.Fatal("invalid or reused active code")
		}
		roomID, ok := created["room_id"].(string)
		if !ok || len(roomID) != 32 || rooms[roomID] {
			t.Fatal("invalid or reused room identifier")
		}
		if _, err := hex.DecodeString(roomID); err != nil {
			t.Fatal("invalid room identifier")
		}
		if len(created) != 6 || created["side"] != float64(0) {
			t.Fatal("unexpected created fields")
		}
		codes[code], rooms[roomID] = true, true
		b := dial(t, url)
		hello(b)
		b.send("join", map[string]any{"code": code})
		joined := b.read("joined")
		if len(joined) != 5 || joined["room_id"] != roomID || joined["side"] != float64(1) {
			t.Fatal("invalid joined event")
		}
		if a.read("joined")["room_id"] != roomID {
			t.Fatal("host joined event differs")
		}
	}
}

func TestV2JoinSchemaAndCodeGuards(t *testing.T) {
	for name, change := range map[string]func(map[string]any){
		"invite":  func(m map[string]any) { m["invite"] = "obsolete" },
		"side":    func(m map[string]any) { m["side"] = 1 },
		"extra":   func(m map[string]any) { m["other"] = true },
		"room_id": func(m map[string]any) { m["room_id"] = "unused" },
		"missing": func(m map[string]any) { delete(m, "code") },
		"null":    func(m map[string]any) { m["code"] = nil },
		"number":  func(m map[string]any) { m["code"] = 123456 },
		"short":   func(m map[string]any) { m["code"] = "12345" },
		"long":    func(m map[string]any) { m["code"] = "1234567" },
		"letter":  func(m map[string]any) { m["code"] = "12345a" },
		"space":   func(m map[string]any) { m["code"] = "123456 " },
		"unicode": func(m map[string]any) { m["code"] = "１２３４５６" },
	} {
		t.Run(name, func(t *testing.T) {
			_, url := setup(t)
			a, b := dial(t, url), dial(t, url)
			hello(a)
			hello(b)
			a.send("create", map[string]any{})
			created := a.read("created")
			fields := map[string]any{"code": created["code"]}
			change(fields)
			b.send("join", fields)
			b.rejected()
		})
	}
}

func TestV1RejectedAfterHandshake(t *testing.T) {
	for _, stage := range []string{"join", "input"} {
		t.Run(stage, func(t *testing.T) {
			_, url := setup(t)
			var a, b *testClient
			var fields map[string]any
			if stage == "join" {
				a, b = dial(t, url), dial(t, url)
				hello(a)
				hello(b)
				b.send("create", map[string]any{})
				fields = map[string]any{"code": b.read("created")["code"]}
			} else {
				var r, m string
				a, b, r, m = playing(t, url)
				fields = map[string]any{"room_id": r, "match_id": m, "tick": 6, "commands": []any{}}
			}
			a.seq++
			fields["v"], fields["type"], fields["seq"] = 1, stage, a.seq
			data, err := json.Marshal(fields)
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			if err := a.c.Write(ctx, websocket.MessageText, data); err != nil {
				t.Fatal(err)
			}
			if stage == "input" {
				b.read("aborted")
			}
			a.rejected()
		})
	}
}
