package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
)

const maxRooms = 5
const maxConnections = 20
const queueMessages = 32
const queueBytes = 128 * 1024

type peer struct {
	conn                      *websocket.Conn
	out                       chan []byte
	done                      chan struct{}
	closed                    bool
	queuedBytes               int
	seq, outSeq               int
	build                     string
	room                      *room
	side                      int
	ready, loaded             bool
	nextTick                  int
	finish                    *message
	deadline, inputAt, rateAt time.Time
	count, bytes, controls    int
}

type room struct {
	id, code, invite, matchID, phase string
	players                          [2]*peer
	expires                          time.Time
}

type relay struct {
	mu       sync.Mutex
	peers    map[*peer]bool
	rooms    map[string]*room
	stopping bool
}

func newRelay() *relay { return &relay{peers: map[*peer]bool{}, rooms: map[string]*room{}} }

func token(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func (s *relay) send(p *peer, kind string, fields map[string]any) {
	if p.closed {
		return
	}
	p.outSeq++
	fields["v"], fields["type"], fields["seq"] = protocolVersion, kind, p.outSeq
	data, err := json.Marshal(fields)
	if err != nil {
		panic(err)
	}
	if p.queuedBytes+len(data) > queueBytes {
		s.closePeer(p)
		return
	}
	select {
	case p.out <- data:
		p.queuedBytes += len(data)
	default:
		s.closePeer(p)
	}
}

func (s *relay) closePeer(p *peer) {
	if p.closed {
		return
	}
	p.closed = true
	close(p.done)
	delete(s.peers, p)
	if p.room != nil {
		r := p.room
		delete(s.rooms, r.code)
		for _, other := range r.players {
			if other != nil {
				other.room = nil
				other.deadline = time.Now().Add(30 * time.Second)
				if other != p {
					s.send(other, "aborted", map[string]any{"room_id": r.id, "reason": "peer_left"})
				}
			}
		}
	}
}

func (s *relay) broadcast(r *room, kind string, fields map[string]any) {
	for _, p := range r.players {
		if p != nil {
			copy := map[string]any{}
			for k, v := range fields {
				copy[k] = v
			}
			s.send(p, kind, copy)
		}
	}
}

func (s *relay) handle(p *peer, m message, now time.Time) error {
	if m.V != protocolVersion || m.Seq != p.seq+1 {
		return errors.New("version_or_sequence")
	}
	p.seq = m.Seq
	if now.Sub(p.rateAt) >= time.Second {
		p.rateAt = now
		p.count, p.bytes, p.controls = 0, 0, 0
	}
	if m.Type != "input" {
		p.controls++
		if p.controls > 10 {
			return errors.New("control_rate")
		}
	}
	if p.build == "" {
		if m.Type != "hello" || len(m.Build) != 64 {
			return errors.New("handshake")
		}
		if _, err := hex.DecodeString(m.Build); err != nil || strings.ToLower(m.Build) != m.Build {
			return errors.New("build")
		}
		p.build = m.Build
		p.deadline = now.Add(30 * time.Second)
		s.send(p, "hello", map[string]any{})
		return nil
	}
	if m.Type == "create" {
		if p.room != nil || len(s.rooms) >= maxRooms {
			return errors.New("room_capacity")
		}
		code := ""
		for code == "" || s.rooms[code] != nil {
			b := make([]byte, 3)
			if _, err := rand.Read(b); err != nil {
				panic(err)
			}
			code = fmt.Sprintf("%06d", (int(b[0])<<16|int(b[1])<<8|int(b[2]))%1000000)
		}
		r := &room{id: token(16), code: code, invite: token(16), phase: "waiting", expires: now.Add(10 * time.Minute)}
		r.players[0] = p
		p.room, p.side = r, 0
		p.ready, p.loaded = false, false
		s.rooms[code] = r
		p.deadline = r.expires
		s.send(p, "created", map[string]any{"room_id": r.id, "code": code, "invite": r.invite, "side": 0})
		return nil
	}
	if m.Type == "join" {
		r := s.rooms[m.Code]
		if p.room != nil || r == nil || !now.Before(r.expires) || r.phase != "waiting" || r.players[1] != nil || m.Invite != r.invite || p.build != r.players[0].build {
			return errors.New("join_rejected")
		}
		r.invite = ""
		r.players[1] = p
		p.room, p.side = r, 1
		p.ready, p.loaded = false, false
		p.deadline = r.expires
		s.send(p, "joined", map[string]any{"room_id": r.id, "side": 1})
		s.send(r.players[0], "joined", map[string]any{"room_id": r.id, "side": 0})
		return nil
	}
	r := p.room
	if r == nil || m.RoomID != r.id {
		return errors.New("room_binding")
	}
	if m.Type == "leave" {
		s.closePeer(p)
		return nil
	}
	switch m.Type {
	case "ready":
		if r.phase != "waiting" || m.Ready == nil {
			return errors.New("ready_phase")
		}
		p.ready = *m.Ready
		s.broadcast(r, "ready", map[string]any{"room_id": r.id, "side": p.side, "ready": p.ready})
	case "start":
		if r.phase != "waiting" || p.side != 0 || r.players[1] == nil || !p.ready || !r.players[1].ready {
			return errors.New("start_phase")
		}
		r.phase, r.matchID = "loading", token(16)
		b := make([]byte, 4)
		if _, err := rand.Read(b); err != nil {
			panic(err)
		}
		seed := (int64(b[0])<<24 | int64(b[1])<<16 | int64(b[2])<<8 | int64(b[3])) & 0x7fffffff
		if seed == 0 {
			seed = 1
		}
		for _, q := range r.players {
			q.deadline = now.Add(30 * time.Second)
			q.loaded = false
		}
		s.broadcast(r, "load", map[string]any{"room_id": r.id, "match_id": r.matchID, "seed": seed, "input_delay": inputDelay})
	case "loaded":
		if r.phase != "loading" || m.MatchID != r.matchID || p.loaded {
			return errors.New("loaded_phase")
		}
		p.loaded = true
		if r.players[0].loaded && r.players[1].loaded {
			r.phase = "playing"
			for _, q := range r.players {
				q.nextTick = inputDelay
				q.finish = nil
				q.inputAt = now
				q.deadline = now.Add(8 * time.Second)
			}
			s.broadcast(r, "begin", map[string]any{"room_id": r.id, "match_id": r.matchID, "input_delay": inputDelay})
		}
	case "input":
		if r.phase != "playing" || m.MatchID != r.matchID || m.Tick != p.nextTick || m.Tick > maxTick+inputDelay-1 || !validCommands(m.Commands, m.Tick) {
			return errors.New("input_invalid")
		}
		other := r.players[1-p.side]
		if m.Tick > other.nextTick+120 || now.Sub(p.inputAt) > 8*time.Second {
			return errors.New("input_window")
		}
		if p.finish != nil && m.Tick >= p.finish.Tick+inputDelay {
			return errors.New("input_after_finish")
		}
		p.nextTick++
		p.inputAt = now
		// Both streams must advance; a noisy single stream cannot extend a stalled match.
		if p.nextTick <= other.nextTick {
			for _, q := range r.players {
				if q.finish == nil {
					q.deadline = now.Add(8 * time.Second)
				}
			}
		}
		s.send(other, "input", map[string]any{"room_id": r.id, "match_id": r.matchID, "side": p.side, "tick": m.Tick, "commands": m.Commands})
	case "finish":
		if r.phase != "playing" || m.MatchID != r.matchID || p.finish != nil || m.Tick < 1 || m.Tick > maxTick || m.Tick > p.nextTick || m.Result < 1 || m.Result > 3 {
			return errors.New("finish_invalid")
		}
		p.finish = &m
		p.deadline = now.Add(8 * time.Second)
		other := r.players[1-p.side]
		if other.finish != nil {
			if other.finish.Tick != m.Tick || other.finish.Result != m.Result {
				return errors.New("finish_mismatch")
			}
			r.phase = "ended"
			s.broadcast(r, "ended", map[string]any{"room_id": r.id, "match_id": r.matchID, "tick": m.Tick, "result": m.Result})
			delete(s.rooms, r.code)
			for _, q := range r.players {
				q.room = nil
				q.deadline = now.Add(30 * time.Second)
			}
		}
	default:
		return errors.New("phase_message")
	}
	return nil
}

func (s *relay) ServeHTTP(w http.ResponseWriter, req *http.Request) {
	if req.URL.Path == "/healthz" && req.Method == "GET" {
		s.mu.Lock()
		stopping := s.stopping
		s.mu.Unlock()
		if stopping {
			http.Error(w, "stopping", 503)
			return
		}
		w.Write([]byte("ok\n"))
		return
	}
	if req.URL.Path != "/ws" || req.Method != "GET" || req.URL.RawQuery != "" {
		http.NotFound(w, req)
		return
	}
	s.mu.Lock()
	if s.stopping || len(s.peers) >= maxConnections {
		s.mu.Unlock()
		http.Error(w, "capacity", 503)
		return
	}
	// Reserve capacity before upgrading. Browser origins are rejected; native Godot sends no Origin.
	p := &peer{out: make(chan []byte, queueMessages), done: make(chan struct{}), deadline: time.Now().Add(8 * time.Second), rateAt: time.Now()}
	s.peers[p] = true
	s.mu.Unlock()
	if req.Header.Get("Origin") != "" {
		s.mu.Lock()
		s.closePeer(p)
		s.mu.Unlock()
		http.Error(w, "native clients only", 403)
		return
	}
	c, err := websocket.Accept(w, req, &websocket.AcceptOptions{CompressionMode: websocket.CompressionDisabled})
	if err != nil {
		s.mu.Lock()
		s.closePeer(p)
		s.mu.Unlock()
		return
	}
	s.mu.Lock()
	p.conn = c
	closed := p.closed
	s.mu.Unlock()
	if closed {
		c.CloseNow()
		return
	}
	c.SetReadLimit(32768)
	ctx, cancel := context.WithCancel(req.Context())
	writerDone := make(chan struct{})
	go func() {
		defer close(writerDone)
		defer cancel()
		defer c.CloseNow()
		for {
			select {
			case <-p.done:
				return
			case <-ctx.Done():
				return
			case data := <-p.out:
				writeCtx, stop := context.WithTimeout(ctx, 2*time.Second)
				err := c.Write(writeCtx, websocket.MessageText, data)
				stop()
				s.mu.Lock()
				p.queuedBytes -= len(data)
				s.mu.Unlock()
				if err != nil {
					return
				}
			}
		}
	}()
	defer func() {
		s.mu.Lock()
		s.closePeer(p)
		s.mu.Unlock()
		cancel()
		c.CloseNow()
		<-writerDone
	}()
	for {
		kind, data, err := c.Read(ctx)
		if err != nil {
			return
		}
		if kind != websocket.MessageText {
			return
		}
		m, err := decodeMessage(data)
		if err != nil {
			return
		}
		s.mu.Lock()
		now := time.Now()
		if now.Sub(p.rateAt) >= time.Second {
			p.rateAt = now
			p.count, p.bytes, p.controls = 0, 0, 0
		}
		p.count++
		p.bytes += len(data)
		if p.closed || !now.Before(p.deadline) || p.count > 90 || p.bytes > 256*1024 {
			s.mu.Unlock()
			return
		}
		err = s.handle(p, m, now)
		s.mu.Unlock()
		if err != nil {
			return
		}
	}
}

func (s *relay) sweep(now time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for p := range s.peers {
		if !now.Before(p.deadline) {
			s.closePeer(p)
		}
	}
}

func (s *relay) stop() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopping = true
	for p := range s.peers {
		s.closePeer(p)
	}
}
