package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"math"
)

const protocolVersion = 1
const inputDelay = 6
const maxTick = 10800

type message struct {
	V        int     `json:"v"`
	Type     string  `json:"type"`
	Seq      int     `json:"seq"`
	Build    string  `json:"build,omitempty"`
	Code     string  `json:"code,omitempty"`
	Invite   string  `json:"invite,omitempty"`
	RoomID   string  `json:"room_id,omitempty"`
	MatchID  string  `json:"match_id,omitempty"`
	Ready    *bool   `json:"ready,omitempty"`
	Tick     int     `json:"tick,omitempty"`
	Result   int     `json:"result,omitempty"`
	Commands [][]any `json:"commands,omitempty"`
}

// Reject duplicate keys, nested containers and trailing JSON before dispatch.
func decodeMessage(data []byte) (message, error) {
	var m message
	d := json.NewDecoder(bytes.NewReader(data))
	var scan func(int) error
	scan = func(depth int) error {
		if depth > 5 {
			return errors.New("json_depth")
		}
		t, err := d.Token()
		if err != nil {
			return err
		}
		switch t {
		case json.Delim('{'):
			seen := map[string]bool{}
			for d.More() {
				k, err := d.Token()
				if err != nil {
					return err
				}
				key, ok := k.(string)
				if !ok || seen[key] {
					return errors.New("duplicate_key")
				}
				seen[key] = true
				if err := scan(depth + 1); err != nil {
					return err
				}
			}
			_, err = d.Token()
			return err
		case json.Delim('['):
			for d.More() {
				if err := scan(depth + 1); err != nil {
					return err
				}
			}
			_, err = d.Token()
			return err
		}
		return nil
	}
	if err := scan(0); err != nil {
		return m, err
	}
	if _, err := d.Token(); err != io.EOF {
		return m, errors.New("trailing_json")
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil || fields == nil {
		return m, errors.New("message_object")
	}
	if err := json.Unmarshal(data, &m); err != nil {
		return m, err
	}
	extra := map[string]string{
		"hello": "build", "create": "", "join": "code invite", "ready": "room_id ready",
		"start": "room_id", "loaded": "room_id match_id", "input": "room_id match_id tick commands",
		"finish": "room_id match_id tick result", "leave": "room_id",
	}
	allowed, ok := extra[m.Type]
	if !ok {
		return m, errors.New("message_type")
	}
	keys := map[string]bool{"v": true, "type": true, "seq": true}
	for _, key := range bytes.Fields([]byte(allowed)) {
		keys[string(key)] = true
	}
	for key, value := range fields {
		if !keys[key] || bytes.Equal(value, []byte("null")) {
			return m, errors.New("message_fields")
		}
	}
	for key := range keys {
		if _, exists := fields[key]; !exists {
			return m, errors.New("missing_field")
		}
	}
	return m, nil
}

func integer(v any, lo, hi int) (int, bool) {
	f, ok := v.(float64)
	return int(f), ok && !math.IsNaN(f) && !math.IsInf(f, 0) && f == math.Trunc(f) && f >= float64(lo) && f <= float64(hi)
}

func validCommands(rows [][]any, tick int) bool {
	if len(rows) > 64 {
		return false
	}
	ids := map[string]bool{"angelina": true, "bagpipe": true, "blaze": true, "ceobe": true, "exusiai": true, "hoshiguma": true, "nightingale": true, "nightingale_phantom": true, "swire_alter": true}
	for _, row := range rows {
		if len(row) != 8 {
			return false
		}
		var n [8]int
		for _, i := range []int{0, 1, 3, 4, 5, 6, 7} {
			v, ok := integer(row[i], -1, 1000000000)
			if !ok {
				return false
			}
			n[i] = v
		}
		id, ok := row[2].(string)
		if !ok || n[0] != tick || n[1] < 0 || n[1] > 2 || n[7] < -1 || n[7] > 3 {
			return false
		}
		if n[1] == 0 {
			if !ids[id] || n[3] != -1 || n[4] < 0 || n[4] >= 21 || n[5] < 0 || n[5] >= 11 || n[6] != -1 {
				return false
			}
		} else {
			skill := -1
			if n[1] == 1 {
				skill = 0
			}
			if id != "" || n[3] < 0 || n[4] != 0 || n[5] != 0 || n[6] != skill || n[7] != -1 {
				return false
			}
		}
	}
	return true
}
