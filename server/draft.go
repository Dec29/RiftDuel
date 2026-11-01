package main

import (
	"errors"
	"sort"
	"time"
)

const draftBanDuration = 20 * time.Second
const draftPickDuration = 100 * time.Second
const draftSkillDuration = 30 * time.Second

type draftState struct {
	id                    string
	stage, step           int
	bans, picks, pending  [2][]string
	skills, pendingSkills [2][]int
	locked                [2]bool
	banLimits             [2]int
	deadline              time.Time
}

func newDraft(now time.Time) *draftState {
	return &draftState{id: token(16), bans: [2][]string{{}, {}}, picks: [2][]string{{}, {}}, skills: [2][]int{{}, {}}, banLimits: [2]int{3, 3}, deadline: now.Add(draftBanDuration)}
}
func (d *draftState) duration() time.Duration {
	if d.stage == 0 || d.stage == 2 {
		return draftBanDuration
	}
	if d.stage == 1 || d.stage == 3 {
		return draftPickDuration
	}
	return draftSkillDuration
}
func hasID(ids []string, id string) bool {
	for _, value := range ids {
		if id == value {
			return true
		}
	}
	return false
}
func (d *draftState) banned(id string) bool { return hasID(d.bans[0], id) || hasID(d.bans[1], id) }
func (d *draftState) target() int {
	if d.stage == 1 {
		return 6
	}
	return 12
}
func (d *draftState) advance(now time.Time) {
	if !d.locked[0] || !d.locked[1] {
		return
	}
	if d.stage == 1 || d.stage == 3 || d.stage == 4 {
		for side := 0; side < 2; side++ {
			d.picks[side] = append([]string{}, d.pending[side]...)
			if d.stage == 4 {
				d.skills[side] = append([]int{}, d.pendingSkills[side]...)
			}
		}
	}
	d.stage++
	if d.stage == 2 {
		for side := 0; side < 2; side++ {
			d.banLimits[side] = len(d.bans[side]) + 2
		}
	}
	d.locked = [2]bool{d.stage == 5, d.stage == 5}
	d.pending = [2][]string{}
	d.pendingSkills = [2][]int{}
	d.deadline = now.Add(d.duration())
}
func (d *draftState) ban(side int, id string, now time.Time) error {
	_, known := draftSkillCounts[id]
	if (d.stage != 0 && d.stage != 2) || d.locked[side] || !known || d.banned(id) || hasID(d.picks[0], id) || hasID(d.picks[1], id) || len(d.bans[side]) >= d.banLimits[side] {
		return errors.New("该干员已被禁用、已被选取，或本轮禁用已结束")
	}
	d.bans[side] = append(d.bans[side], id)
	if len(d.bans[side]) == d.banLimits[side] {
		d.locked[side] = true
	}
	d.advance(now)
	return nil
}
func (d *draftState) selection(side int, ids []string, skills []int, complete bool, now time.Time) error {
	if d.locked[side] {
		return errors.New("本轮已确认")
	}
	if d.stage == 0 || d.stage == 2 {
		if !complete || len(ids) != 0 || len(skills) != 0 {
			return errors.New("结束禁用指令无效")
		}
		d.locked[side] = true
		d.advance(now)
		return nil
	}
	if d.stage < 0 || d.stage > 4 || len(ids) > d.target() || (complete && len(ids) != d.target()) {
		return errors.New("本轮干员数量不正确")
	}
	seen := map[string]bool{}
	for _, id := range ids {
		_, known := draftSkillCounts[id]
		if !known || seen[id] || d.banned(id) {
			return errors.New("阵容包含已禁用、重复或未知干员")
		}
		seen[id] = true
	}
	for _, id := range d.picks[side] {
		if !seen[id] {
			return errors.New("此前已选干员不能移除")
		}
	}
	if d.stage == 4 {
		if len(ids) != 12 || len(skills) != 12 {
			return errors.New("技能配置须保留完整阵容")
		}
		for i, id := range ids {
			if skills[i] < 0 || skills[i] >= draftSkillCounts[id] {
				return errors.New("携带技能尚未开放或无效")
			}
		}
	} else if len(skills) != 0 {
		return errors.New("选人阶段不接受技能配置")
	}
	d.pending[side] = append([]string{}, ids...)
	d.pendingSkills[side] = append([]int{}, skills...)
	if complete {
		d.locked[side] = true
		d.advance(now)
	}
	return nil
}
func preferenceSkill(p *peer, id string) int {
	for i, value := range p.squad {
		if value == id && i < len(p.skills) {
			return p.skills[i]
		}
	}
	return 0
}
func (d *draftState) expire(r *room, now time.Time) {
	all := make([]string, 0, len(draftSkillCounts))
	for id := range draftSkillCounts {
		all = append(all, id)
	}
	sort.Strings(all)
	for side, p := range r.players {
		if d.locked[side] {
			continue
		}
		if d.stage == 1 || d.stage == 3 {
			selected := append([]string{}, d.pending[side]...)
			if len(selected) == 0 {
				selected = append(selected, d.picks[side]...)
			}
			order := append(append([]string{}, p.squad...), all...)
			for _, id := range order {
				if len(selected) >= d.target() {
					break
				}
				if _, ok := draftSkillCounts[id]; ok && !d.banned(id) && !hasID(selected, id) {
					selected = append(selected, id)
				}
			}
			d.pending[side] = selected
		} else if d.stage == 4 && len(d.pendingSkills[side]) == 0 {
			d.pending[side] = append([]string{}, d.picks[side]...)
			for _, id := range d.picks[side] {
				d.pendingSkills[side] = append(d.pendingSkills[side], preferenceSkill(p, id))
			}
		}
		d.locked[side] = true
	}
	d.advance(now)
}
func (s *relay) publishDraft(r *room, now time.Time) {
	d := r.draft
	d.step++
	remaining := d.deadline.Sub(now).Milliseconds()
	if remaining < 0 || d.stage == 5 {
		remaining = 0
	}
	s.broadcast(r, "draft", map[string]any{"room_id": r.id, "draft": map[string]any{"draft_id": d.id, "stage": d.stage, "step": d.step, "bans": d.bans, "picks": d.picks, "skills": d.skills, "locked": d.locked, "remaining_ms": remaining}})
	for _, p := range r.players {
		p.deadline = d.deadline.Add(8 * time.Second)
	}
	if d.stage == 5 {
		for side, p := range r.players {
			p.squad = append([]string{}, d.picks[side]...)
			p.skills = append([]int{}, d.skills[side]...)
		}
		s.loadMatch(r, now)
	}
}
func (s *relay) handleDraft(p *peer, m message, now time.Time) error {
	r := p.room
	d := r.draft
	if d == nil || m.DraftID != d.id || m.Stage < 0 || m.Stage > 4 {
		return errors.New("draft_binding")
	}
	if r.phase == "draft" && !now.Before(d.deadline) {
		d.expire(r, now)
		s.publishDraft(r, now)
	}
	var rejected error
	if r.phase != "draft" || m.Stage != d.stage {
		rejected = errors.New("本阶段已结束，请按最新阶段操作")
	} else if m.Type == "draft_cancel" {
		r.phase = "waiting"
		r.draft = nil
		r.expires = now.Add(10 * time.Minute)
		for _, q := range r.players {
			q.ready = false
			q.deadline = r.expires
		}
		s.broadcast(r, "draft_cancelled", map[string]any{"room_id": r.id, "draft_id": d.id})
		return nil
	} else if m.Type == "draft_ban" {
		rejected = d.ban(p.side, m.OperatorID, now)
	} else {
		rejected = d.selection(p.side, m.Operators, m.Skills, m.Type == "draft_submit", now)
	}
	if rejected != nil {
		s.send(p, "draft_rejected", map[string]any{"room_id": r.id, "draft_id": d.id, "reason": rejected.Error()})
		return nil
	}
	if m.Type != "draft_update" {
		s.publishDraft(r, now)
	}
	return nil
}

var draftSkillCounts = map[string]int{
	"aak":              3,
	"amiya":            3,
	"angelina":         3,
	"archetto":         3,
	"bagpipe":          3,
	"blaze":            3,
	"blemishine":       3,
	"blue_poison":      2,
	"carnelian":        3,
	"ceobe":            3,
	"chen":             3,
	"chen_alter":       3,
	"cliffheart":       2,
	"cuora":            2,
	"dusk":             3,
	"elysium":          2,
	"eunectes":         3,
	"exusiai":          3,
	"eyjafjalla":       3,
	"eyjafjalla_alter": 3,
	"feater":           2,
	"fiammetta":        3,
	"flametail":        3,
	"gavial_alter":     3,
	"gitano":           2,
	"gladiia":          3,
	"gnosis":           3,
	"goldenglow":       3,
	"gravel":           2,
	"gummy":            2,
	"haze":             2,
	"hellagur":         3,
	"horn":             3,
	"hoshiguma":        3,
	"ifrit":            3,
	"ines":             3,
	"istina":           2,
	"jessica":          2,
	"jessica_alter":    3,
	"kaltsit":          3,
	"lappland":         2,
	"lee":              3,
	"lin":              3,
	"ling":             3,
	"liskarm":          2,
	"lumen":            3,
	"magallan":         3,
	"meteorite":        2,
	"mizuki":           3,
	"mlynar":           3,
	"mon3tr_operator":  3,
	"mostima":          3,
	"mountain":         3,
	"mudrock":          3,
	"muelsyse":         3,
	"myrtle":           2,
	"nearl":            2,
	"nian":             3,
	"nightingale":      3,
	"pallas":           3,
	"passenger":        3,
	"penance":          3,
	"perfumer":         2,
	"phantom":          3,
	"platinum":         2,
	"podenco":          2,
	"pozyomka":         3,
	"pramanix":         2,
	"projekt_red":      2,
	"ptilopsis":        2,
	"reed_alter":       3,
	"rosa":             3,
	"saga":             3,
	"saileach":         3,
	"saria":            3,
	"schwarz":          3,
	"shamare":          2,
	"shaw":             2,
	"shining":          3,
	"siege":            3,
	"silence":          2,
	"silence_alter":    3,
	"silverash":        3,
	"skadi":            3,
	"skadi_alter":      3,
	"skyfire":          2,
	"sora":             2,
	"specter":          2,
	"stainless":        3,
	"surtr":            3,
	"sussurro":         2,
	"suzuran":          3,
	"swire_alter":      3,
	"texas":            2,
	"texas_alter":      3,
	"thorns":           3,
	"titi":             3,
	"typhon":           3,
	"vigil":            3,
	"w":                3,
	"warfarin":         2,
	"weedy":            3,
	"wildmane":         2,
	"zima":             2,
}
