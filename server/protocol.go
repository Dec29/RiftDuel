package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"math"
	"regexp"
)

const protocolVersion = 8
const inputDelay = 6

type matchRules struct {
	Mode         string `json:"mode"`
	Minutes      int    `json:"minutes"`
	Rounds       int    `json:"rounds"`
	DraftEnabled bool   `json:"draft_enabled"`
}

func (r matchRules) valid() bool {
	return (r.Mode == "score" || r.Mode == "single") && r.Minutes >= 1 && r.Minutes <= 30 && r.Rounds >= 1 && r.Rounds <= 9
}
func (r matchRules) maxTicks() int {
	if r.Mode == "single" {
		return r.Minutes*1350 + 1350
	}
	return r.Minutes * 1350 * (338 + 1)
}

var operatorIDPattern = regexp.MustCompile(`^[a-z][a-z0-9_]{0,63}$`)
var roomCodePattern = regexp.MustCompile(`^[0-9]{6}$`)

type message struct {
	DraftID    string      `json:"draft_id,omitempty"`
	Stage      int         `json:"stage,omitempty"`
	OperatorID string      `json:"operator_id,omitempty"`
	Rules      *matchRules `json:"rules,omitempty"`
	Revision   int         `json:"revision,omitempty"`
	V          int         `json:"v"`
	Type       string      `json:"type"`
	Seq        int         `json:"seq"`
	Build      string      `json:"build,omitempty"`
	Code       string      `json:"code,omitempty"`
	RoomID     string      `json:"room_id,omitempty"`
	MatchID    string      `json:"match_id,omitempty"`
	Ready      *bool       `json:"ready,omitempty"`
	Tick       int         `json:"tick,omitempty"`
	Result     int         `json:"result,omitempty"`
	Commands   [][]any     `json:"commands,omitempty"`
	Operators  []string    `json:"operators,omitempty"`
	Skills     []int       `json:"skills,omitempty"`
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
		"draft_ban": "room_id draft_id stage operator_id", "draft_update": "room_id draft_id stage operators skills", "draft_submit": "room_id draft_id stage operators skills", "draft_cancel": "room_id draft_id stage",
		"hello": "build", "create": "", "join": "code", "ready": "room_id ready revision",
		"start": "room_id revision", "rules": "room_id rules revision", "loaded": "room_id match_id", "input": "room_id match_id tick commands",
		"finish": "room_id match_id tick result", "leave": "room_id", "return_room": "room_id match_id",
		"squad": "room_id operators skills revision",
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
	if m.Type == "rules" {
		decoder := json.NewDecoder(bytes.NewReader(fields["rules"]))
		decoder.DisallowUnknownFields()
		var rules matchRules
		var ruleFields map[string]json.RawMessage
		if json.Unmarshal(fields["rules"], &ruleFields) != nil || len(ruleFields) != 4 || (string(ruleFields["draft_enabled"]) != "true" && string(ruleFields["draft_enabled"]) != "false") || decoder.Decode(&rules) != nil || !rules.valid() {
			return m, errors.New("rules_invalid")
		}
		m.Rules = &rules
	}
	if (m.Type == "rules" || m.Type == "ready" || m.Type == "squad" || m.Type == "start") && (m.Revision < 1 || m.Revision > 1000000000) {
		return m, errors.New("rules_revision")
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
	ids := map[string]bool{"aak": true, "amiya": true, "angelina": true, "archetto": true, "bagpipe": true, "blaze": true, "blemishine": true, "blue_poison": true, "carnelian": true, "ceobe": true, "chen": true, "chen_alter": true, "cliffheart": true, "cuora": true, "curse_doll": true, "dusk": true, "dusk_freeling": true, "elysium": true, "eunectes": true, "exusiai": true, "eyjafjalla": true, "eyjafjalla_alter": true, "feater": true, "fiammetta": true, "flametail": true, "flowing_shape": true, "gavial_alter": true, "gitano": true, "gladiia": true, "gnosis": true, "goldenglow": true, "gravel": true, "gummy": true, "haze": true, "hellagur": true, "horn": true, "hoshiguma": true, "ifrit": true, "ines": true, "istina": true, "jessica": true, "jessica_alter": true, "jessica_shield": true, "kaltsit": true, "lappland": true, "lee": true, "lin": true, "ling": true, "ling_soul1": true, "ling_soul2": true, "ling_soul3": true, "liskarm": true, "lumen": true, "magallan": true, "magallan_drone_a": true, "magallan_drone_f": true, "magallan_drone_l": true, "medical_drone": true, "meteorite": true, "mizuki": true, "mlynar": true, "mon3tr": true, "mon3tr_operator": true, "mon3tr_reconstruction": true, "mostima": true, "mountain": true, "mudrock": true, "muelsyse": true, "myrtle": true, "nearl": true, "nian": true, "nightingale": true, "nightingale_phantom": true, "pallas": true, "passenger": true, "penance": true, "perfumer": true, "phantom": true, "phantom_clone": true, "platinum": true, "podenco": true, "pozyomka": true, "pozyomka_typewriter": true, "pramanix": true, "projekt_red": true, "ptilopsis": true, "reed_alter": true, "rosa": true, "saga": true, "saileach": true, "saria": true, "schwarz": true, "seaborn": true, "shamare": true, "shaw": true, "shining": true, "siege": true, "silence": true, "silence_alter": true, "silence_alter_drone": true, "silverash": true, "skadi": true, "skadi_alter": true, "skyfire": true, "sora": true, "specter": true, "stainless": true, "stainless_cannon": true, "stainless_device_atk": true, "stainless_device_sp": true, "surtr": true, "sussurro": true, "suzuran": true, "swire_alter": true, "texas": true, "texas_alter": true, "thorns": true, "titi": true, "typhon": true, "vigil": true, "vigil_wolf": true, "w": true, "warfarin": true, "weedy": true, "weedy_cannon": true, "wildmane": true, "zima": true}
	summons := map[string]bool{"curse_doll": true, "dusk_freeling": true, "flowing_shape": true, "jessica_shield": true, "ling_soul1": true, "ling_soul2": true, "ling_soul3": true, "magallan_drone_a": true, "magallan_drone_f": true, "magallan_drone_l": true, "medical_drone": true, "mon3tr": true, "mon3tr_reconstruction": true, "nightingale_phantom": true, "phantom_clone": true, "pozyomka_typewriter": true, "seaborn": true, "silence_alter_drone": true, "stainless_cannon": true, "stainless_device_atk": true, "stainless_device_sp": true, "vigil_wolf": true, "weedy_cannon": true}
	for _, row := range rows {
		if len(row) != 9 {
			return false
		}
		var n [9]int
		for _, i := range []int{0, 1, 3, 4, 5, 6, 7, 8} {
			v, ok := integer(row[i], -1, 1000000000)
			if !ok {
				return false
			}
			n[i] = v
		}
		id, ok := row[2].(string)
		if !ok || n[0] != tick || n[1] < 0 || n[1] > 6 || n[7] < -1 || n[7] > 3 {
			return false
		}
		if n[1] != 3 && n[8] != -1 {
			return false
		}
		if n[1] == 0 || n[1] == 6 {
			if !ids[id] || n[3] != -1 || n[4] < 0 || n[4] >= 21 || n[5] < 0 || n[5] >= 11 || n[6] != -1 {
				return false
			}
		} else if n[1] == 5 {
			if id != "" || n[3] != -1 || n[4] != 0 || n[5] != 0 || n[6] != -1 || n[7] != -1 {
				return false
			}
		} else if n[1] == 4 {
			if !ids[id] || summons[id] || n[3] < 0 || n[4] != 0 || n[5] != 0 || n[6] != -1 || n[7] < 0 {
				return false
			}
		} else if n[1] == 3 {
			if id != "" || n[3] != -1 || n[4] < 0 || n[4] >= 21 || n[5] < 0 || n[5] >= 11 || n[6] != -1 || n[8] < 0 || n[8] > 3 {
				return false
			}
			if (n[8] == 0 && n[7] < 0) || (n[8] != 0 && n[7] != -1) {
				return false
			}
		} else {
			validSkill := (n[1] == 1 && n[6] >= 0 && n[6] <= 2) || (n[1] == 2 && n[6] == -1)
			if id != "" || n[3] < 0 || n[4] != 0 || n[5] != 0 || !validSkill || n[7] != -1 {
				return false
			}
		}
	}
	return true
}
