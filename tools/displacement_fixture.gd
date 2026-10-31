extends RefCounted


static func definitions(mode: String) -> Dictionary:
	var data := {}
	for id in ["bagpipe", "phantom"]:
		data[id] = load("res://resources/operators/%s.tres" % id).duplicate(true)
		data[id].talent_1.effect_type = ""
		data[id].talent_2.effect_type = ""
	var op: OperatorData = data.bagpipe
	op.display_name = "推拉测试员"
	op.attack_range.clear()
	for column in 7: op.attack_range.append(Vector2i(column, 0))
	op.skills.resize(1)
	var skill := op.skills[0]
	skill.skill_name = "推拉验收"
	skill.effect_type = "shift_attack"
	skill.effect_params = {"attack_mult": 1.0, "shift_force": 4, "shift_mode": mode}
	skill.trigger_type = "attack"
	skill.sp_recharge_type = "time"
	skill.sp_required = 1
	skill.initial_sp = 1
	skill.duration = 0.0
	skill.description = "测试技能：力度4，距离等于力度减组合重量。"
	return data


static func create_match(mode: String) -> MatchState:
	var state := MatchState.new(123, definitions(mode))
	state.ball.cell = Vector2i(12, 5)
	state.sides[0].cost = 99
	state.sides[1].cost = 99
	return state


static func deploy_blue(tick: int) -> Array[InputCommand]:
	return [InputCommand.new(tick, 0, "bagpipe", -1, Vector2i(14, 5), -1, 2)]


static func deploy_red(tick: int) -> Array[InputCommand]:
	return [InputCommand.new(tick, 0, "bagpipe", -1, Vector2i(12, 5), -1, 0), InputCommand.new(tick, 0, "phantom", -1, Vector2i(11, 5), -1, 0)]
