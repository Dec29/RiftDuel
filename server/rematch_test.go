package main

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestRetainedRoomReturnRematchAndLeave(t *testing.T) {
	for _, first := range []int{0, 1} {
		t.Run(fmt.Sprint(first), func(t *testing.T) {
			s, url := setup(t)
			a, b, roomID, matchID := playing(t, url)
			clients := []*testClient{a, b}
			for _, c := range clients {
				c.send("finish", map[string]any{"room_id": roomID, "match_id": matchID, "tick": 6, "result": 3})
			}
			for _, c := range clients {
				c.read("ended")
			}
			clients[first].send("return_room", map[string]any{"room_id": roomID, "match_id": matchID})
			for _, c := range clients {
				if c.read("returned")["side"] != float64(first) {
					t.Fatal("wrong return side")
				}
			}
			s.mu.Lock()
			for _, r := range s.rooms {
				if r.id != roomID || r.phase != "ended" || !r.players[first].returned || r.players[1-first].returned {
					t.Error("one return changed room/barrier")
				}
			}
			if len(s.rooms) != 1 {
				t.Error("room lost after first return")
			}
			s.mu.Unlock()
			clients[1-first].send("return_room", map[string]any{"room_id": roomID, "match_id": matchID})
			for _, c := range clients {
				c.read("returned")
				if c.read("room")["room_id"] != roomID {
					t.Fatal("room identity changed")
				}
			}
			s.mu.Lock()
			for _, r := range s.rooms {
				if r.phase != "waiting" || r.matchID != "" || r.players[0].ready || r.players[1].ready || r.players[0].finish != nil || r.players[1].finish != nil {
					t.Error("rematch state not reset")
				}
			}
			s.mu.Unlock()
			// Preserve the existing ten control messages per second boundary.
			time.Sleep(1100 * time.Millisecond)
			for _, c := range clients {
				c.send("ready", map[string]any{"room_id": roomID, "ready": true})
			}
			for _, c := range clients {
				c.read("ready")
				c.read("ready")
			}
			a.send("start", map[string]any{"room_id": roomID})
			load := a.read("load")
			b.read("load")
			newMatch := load["match_id"].(string)
			if newMatch == matchID || load["room_id"] != roomID {
				t.Fatal("rematch must keep room and replace match")
			}
			for _, c := range clients {
				c.send("loaded", map[string]any{"room_id": roomID, "match_id": newMatch})
			}
			for _, c := range clients {
				c.read("begin")
			}
			input(a, roomID, newMatch, 6, []any{})
			if b.read("input")["tick"] != float64(6) {
				t.Fatal("rematch input did not restart")
			}
			input(b, roomID, newMatch, 6, []any{})
			a.read("input")
			for _, c := range clients {
				c.send("finish", map[string]any{"room_id": roomID, "match_id": newMatch, "tick": 7, "result": 1})
			}
			for _, c := range clients {
				c.read("ended")
			}
			clients[first].send("leave", map[string]any{"room_id": roomID})
			clients[1-first].read("aborted")
			s.mu.Lock()
			if len(s.rooms) != 0 {
				t.Error("one peer leaving must release room")
			}
			s.mu.Unlock()
			clients[1-first].send("create", map[string]any{})
			clients[1-first].read("created")
		})
	}
}

func TestPreviousProtocolVersionsRejected(t *testing.T) {
	for _, version := range []int{1, 2, 3, 4} {
		t.Run(fmt.Sprint(version), func(t *testing.T) {
			_, url := setup(t)
			client := dial(t, url)
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			data := []byte(fmt.Sprintf(`{"v":%d,"type":"hello","seq":1,"build":"%s"}`, version, strings.Repeat("a", 64)))
			if err := client.c.Write(ctx, websocket.MessageText, data); err != nil {
				t.Fatal(err)
			}
			client.rejected()
		})
	}
}

func TestReturnRoomGuards(t *testing.T) {
	for _, kind := range []string{"before_end", "wrong_match", "wrong_room", "duplicate", "extra_field"} {
		t.Run(kind, func(t *testing.T) {
			_, url := setup(t)
			a, b, roomID, matchID := playing(t, url)
			fields := map[string]any{"room_id": roomID, "match_id": matchID}
			if kind != "before_end" {
				for _, c := range []*testClient{a, b} {
					c.send("finish", map[string]any{"room_id": roomID, "match_id": matchID, "tick": 6, "result": 3})
				}
				a.read("ended")
				b.read("ended")
			}
			switch kind {
			case "wrong_match":
				fields["match_id"] = "wrong"
			case "wrong_room":
				fields["room_id"] = "wrong"
			case "extra_field":
				fields["state"] = 1
			case "duplicate":
				a.send("return_room", fields)
				a.read("returned")
				b.read("returned")
			}
			a.send("return_room", fields)
			a.rejected()
		})
	}
}
