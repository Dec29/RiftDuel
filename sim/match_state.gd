class_name MatchState
extends RefCounted

const CONFIG := preload("res://data/config.gd")
const DEFAULT_BALL_DATA := preload("res://resources/ball/standard.tres")
const DEFAULT_ARENA := preload("res://resources/map/standard_arena.tres")
const ATTACK_RANGE := preload("res://sim/attack_range.gd")
const DRONE_IDS := ["magallan_drone_f", "magallan_drone_l", "magallan_drone_a"]
const DRONE_DATA := {
	"magallan_drone_f": preload("res://resources/summons/magallan_drone_f.tres"),
	"magallan_drone_l": preload("res://resources/summons/magallan_drone_l.tres"),
	"magallan_drone_a": preload("res://resources/summons/magallan_drone_a.tres"),
}
const MONSTR_RECONSTRUCTION_DATA: OperatorData = preload("res://resources/summons/mon3tr_reconstruction.tres")
const FLOW_DATA: OperatorData=preload("res://resources/summons/flowing_shape.tres")
const JESSICA_SHIELD_DATA: OperatorData=preload("res://resources/summons/jessica_shield.tres")
const STAINLESS_DATA := [preload("res://resources/summons/stainless_device_atk.tres"),preload("res://resources/summons/stainless_device_sp.tres"),preload("res://resources/summons/stainless_cannon.tres")]
const DUSK_FREELING_DATA: OperatorData = preload("res://resources/summons/dusk_freeling.tres")
const LING_DATA := {"ling_soul1":preload("res://resources/summons/ling_soul1.tres"),"ling_soul2":preload("res://resources/summons/ling_soul2.tres"),"ling_soul3":preload("res://resources/summons/ling_soul3.tres")}
const SILENCE_DRONE_DATA: OperatorData = preload("res://resources/summons/silence_alter_drone.tres")
const VIGIL_WOLF_DATA: OperatorData = preload("res://resources/summons/vigil_wolf.tres")
const TYPEWRITER_DATA: OperatorData = preload("res://resources/summons/pozyomka_typewriter.tres")
const CURSE_DOLL_DATA: OperatorData = preload("res://resources/summons/curse_doll.tres")
const MEDICAL_DRONE_DATA: OperatorData = preload("res://resources/summons/medical_drone.tres")
const SEABORN_DATA: OperatorData = preload("res://resources/summons/seaborn.tres")
const MON3TR_DATA: OperatorData = preload("res://resources/summons/mon3tr.tres")
const CANNON_DATA: OperatorData = preload("res://resources/summons/weedy_cannon.tres")
const CLONE_DATA: OperatorData = preload("res://resources/summons/phantom_clone.tres")
const PHANTOM_DATA: OperatorData = preload("res://resources/summons/nightingale_phantom.tres")

const RESULT_RUNNING := 0
const RESULT_BLUE_WIN := 1
const RESULT_RED_WIN := 2
const RESULT_DRAW := 3

var tick: int
var rng: RNG
var reed_blasts: Array[ReedBlast] = []
var units: Array[UnitState]
var ball: BallState
var sides: Array[SideState]
var result: int
var rules: MatchRules
var goals := PackedInt32Array([0,0])
var last_goal_tick := -1
var last_goal_side := -1
# Input frames continue during recovery; all battle timestamps remain on tick.
var recovery_side := -1
var recovery_ticks_left := 0
var recovery_input_ticks := 0
var input_tick: int:
	get: return tick + recovery_input_ticks
var next_unit_id: int
var _operator_data: Dictionary
var _ball_data: BallData
var _arena: ArenaData
var squad_ids: Array[PackedStringArray] = []
var squad_skills: Array[PackedInt32Array] = []
var tactical_boxes: Array[TacticalBox] = []
var next_box_id: int = 0
var box_spawn_counts_by_half := PackedInt32Array([0, 0])
var box_last_spawn_half := -1
var box_same_half_streak := 0
var next_box_spawn_tick: int = CONFIG.BOX_FIRST_SPAWN_TICKS
var box_warning_cell: Vector2i = Vector2i(-1, -1)
var platform_drop_count: int = 0
var platform_cells: Array[Vector2i] = []
var tactical_item_effects: Array[TacticalItemEffect] = []
var fiammetta_explosions: Array[FiammettaExplosion] = []
var chen_slimes: Array[ChenSlime] = []
var archetto_volleys: Array[ArchettoVolley] = []
var texas_rains: Array[TexasRain] = []
var attack_projectiles: Array[AttackProjectile] = []
var next_projectile_order := 0
var attack_skill_hits: Array[PackedInt32Array]=[]
var classic_attack_fields: Array[ClassicAttackField] = []
var lumen_rain_fields: Array[LumenRainField] = []
var next_lumen_field_id: int = 0
var w_bombs: Array[WExplosive] = []
var w_explosion_events: Array[PackedInt32Array] = []
var next_w_explosion_id: int = 0
var next_w_bomb_id: int = 0
var champagne_bombs: Array[ChampagneBomb] = []
var next_bomb_id: int = 0


func _init(
	match_seed: int = 1,
	match_operator_data: Dictionary = {},
	match_ball_data: BallData = DEFAULT_BALL_DATA,
	match_arena: ArenaData = DEFAULT_ARENA,
	match_squads: Array = [],
	match_skills: Array = [],
	match_rules: MatchRules = null,
) -> void:
	rules = MatchRules.new() if match_rules == null else match_rules.copy()
	tick = 0
	rng = RNG.new(match_seed)
	units = []
	ball = BallState.new()
	sides = [SideState.new(0), SideState.new(1)]
	result = RESULT_RUNNING
	next_unit_id = 0
	_operator_data = match_operator_data.duplicate()
	_operator_data[MONSTR_RECONSTRUCTION_DATA.operator_id]=MONSTR_RECONSTRUCTION_DATA
	_operator_data[FLOW_DATA.operator_id]=FLOW_DATA
	_operator_data[JESSICA_SHIELD_DATA.operator_id]=JESSICA_SHIELD_DATA
	for token: OperatorData in STAINLESS_DATA:_operator_data[token.operator_id]=token
	_operator_data[DUSK_FREELING_DATA.operator_id]=DUSK_FREELING_DATA
	_operator_data[SILENCE_DRONE_DATA.operator_id]=SILENCE_DRONE_DATA
	_operator_data["vigil_wolf"]=VIGIL_WOLF_DATA
	_operator_data[TYPEWRITER_DATA.operator_id]=TYPEWRITER_DATA
	_operator_data[CURSE_DOLL_DATA.operator_id]=CURSE_DOLL_DATA
	_operator_data[MEDICAL_DRONE_DATA.operator_id]=MEDICAL_DRONE_DATA
	_operator_data[SEABORN_DATA.operator_id]=SEABORN_DATA
	_operator_data[MON3TR_DATA.operator_id]=MON3TR_DATA
	_operator_data[PHANTOM_DATA.operator_id] = PHANTOM_DATA
	_operator_data[CLONE_DATA.operator_id] = CLONE_DATA
	_operator_data[CANNON_DATA.operator_id] = CANNON_DATA
	_operator_data.merge(DRONE_DATA, true)
	_operator_data.merge(LING_DATA,true)
	_ball_data = match_ball_data
	_arena = match_arena
	var all_ids := PackedStringArray(match_operator_data.keys())
	all_ids.sort()
	for side in 2:
		squad_ids.append(PackedStringArray(match_squads[side]) if not match_squads.is_empty() else all_ids.duplicate())
		var indices := PackedInt32Array(match_skills[side]) if not match_skills.is_empty() else PackedInt32Array()
		if match_skills.is_empty():
			indices.resize(squad_ids[side].size())
		squad_skills.append(indices)
		for id in squad_ids[side]:
			var talent: TalentResource=_operator_data[id].talent_1
			if talent.effect_type=="vanguard_cost":sides[side].vanguard_cost_discount=maxi(sides[side].vanguard_cost_discount,int(talent.effect_params["cost_reduction"]))
			if talent.effect_type=="initial_cost":sides[side].cost=mini(CONFIG.COST_MAX,sides[side].cost+int(talent.effect_params["cost_add"]))
		if "ling" in squad_ids[side]:sides[side].ling_stock=int(_operator_data["ling"].talent_1.effect_params["stock_count"])
		if "stainless" in squad_ids[side]:sides[side].stainless_stock=int(_operator_data.stainless.talent_1.effect_params.stock_count)
		if "magallan" in squad_ids[side]:sides[side].drone_stock=int((_operator_data["magallan"] as OperatorData).talent_1.effect_params["stock_count"])

	TacticianRules.refresh_costs(self)

func step(cmd_a: Array[InputCommand], cmd_b: Array[InputCommand]) -> void:
	if result != RESULT_RUNNING:
		return
	var recovery_deployment := recovery_side >= 0
	if recovery_deployment:
		var accepted := GoalRecoveryRules.commands(self, cmd_a, cmd_b)
		if accepted.is_empty():
			return
		var no_commands: Array[InputCommand] = []
		cmd_a = accepted if recovery_side == 0 else no_commands
		cmd_b = accepted if recovery_side == 1 else no_commands
	while not w_explosion_events.is_empty() and tick-w_explosion_events[0][4]>8:w_explosion_events.pop_front()
	var expired_silence_intervals := {}
	var new_guard_units: Array[UnitState] = []
	var new_burst_units: Array[UnitState] = []
	StatusRules.expire_before_commands(self, expired_silence_intervals)
	for side_state in sides:
		side_state.drone_cooldown_ticks = maxi(0, side_state.drone_cooldown_ticks - 1)
		side_state.cannon_cooldown_ticks = maxi(0, side_state.cannon_cooldown_ticks - 1)
		side_state.clone_cooldown_ticks = maxi(0, side_state.clone_cooldown_ticks - 1)
		side_state.phantom_cooldown_ticks = maxi(0, side_state.phantom_cooldown_ticks - 1)
		var cooldown_ids := side_state.cooldowns.keys()
		cooldown_ids.sort()
		for operator_id in cooldown_ids:
			side_state.cooldowns[operator_id] -= 1
			if side_state.cooldowns[operator_id] == 0:
				side_state.cooldowns.erase(operator_id)
		side_state.cost_regen_ticks += 1
		if side_state.cost_regen_ticks == CONFIG.COST_REGEN_TICKS:
			side_state.cost_regen_ticks = 0
			side_state.cost = mini(CONFIG.COST_MAX, side_state.cost + CONFIG.COST_REGEN_RATE)

	TacticalRules.advance_effects(self)

	CommandRules.apply(self, cmd_a, cmd_b, new_guard_units, new_burst_units)
	if recovery_deployment:
		recovery_side = -1
		recovery_ticks_left = 0

	var maintained_units: Array[UnitState] = []
	for unit in units:
		StatusRules.advance_controls(unit)
		unit.resist_break_ticks_left = maxi(0, unit.resist_break_ticks_left - 1)
		if unit.resist_break_ticks_left == 0:
			unit.resist_remaining_percent = 100
		unit.armor_break_ticks_left = maxi(0, unit.armor_break_ticks_left - 1)
		if unit.armor_break_ticks_left == 0:
			unit.armor_break_defense_percent = 100
		var operator := _operator_data[unit.operator_id] as OperatorData
		if not PusherRules.maintain_cannon(self, unit, operator):
			continue
		if not MerchantRules.maintain_unit(self, unit, operator):
			continue
		maintained_units.append(unit)
	units = maintained_units
	CliffheartRules.advance_hooks(self)
	SilenceAlterRules.maintain(self)
	GnosisRules.maintain(self)
	VigilRules.maintain(self)
	PozyomkaRules.maintain(self)
	LeeRules.advance(self)
	MedicalDroneRules.maintain(self)
	CurseDollRules.maintain(self)
	ClassicTacticalRules.advance_passives(self)
	BardRules.maintain_binding(self)
	Mon3trRules.maintain_binding(self)
	FiammettaRules.maintain(self)
	ChenAlterRules.maintain(self)
	StainlessRules.maintain(self)
	DuskRules.maintain(self)
	MushaRules.sample_speed(self)
	AuraRules.refresh(self)
	PenanceRules.initialize_barriers(self)
	WArtilleryRules.advance_bombs(self)
	MerchantRules.advance_bombs(self)
	StatusRules.restore_silence_intervals(self, expired_silence_intervals)
	for unit in new_guard_units:
		if unit in units:
			var data: OperatorData = _operator_data[unit.operator_id]
			if data.skills[unit.skill_index].effect_type=="gravel_barrier":
				unit.gravel_barrier_initial=roundi(SkillRules.max_health_value(unit,data)*int(data.skills[unit.skill_index].effect_params["shield_health_percent"])/100.0)
				unit.gravel_barrier_hp=unit.gravel_barrier_initial
				continue
			unit.physical_guard_ticks_left = roundi(data.skills[unit.skill_index].duration * CONFIG.TICK_RATE)
			unit.physical_shield_hp = roundi(SkillRules.max_health_value(unit, data) * int(data.skills[unit.skill_index].effect_params["shield_health_percent"]) / 100.0)

	for source in new_burst_units:
		if source not in units or source.hp <= 0 or source.silence_ticks_left > 0:
			continue
		var source_data: OperatorData = _operator_data[source.operator_id]
		var skill := source_data.skills[source.skill_index]
		if skill.effect_type=="red_wolf":LaunchOperatorRules.red_burst(self,source,source_data);continue
		source.deploy_control_kind = rng.next_u32() % 3
		source.last_attack_tick = tick
		source.last_attack_is_heal = false
		source.last_attack_target_x = source.cell.x
		source.last_attack_target_y = source.cell.y
		var attack := roundi(SkillRules.attack_value(source, source_data) * float(skill.effect_params["attack_mult"]))
		for enemy in units:
			if source.hp <= 0: break
			if enemy.hp <= 0 or enemy.side == source.side or not _is_in_attack_range(source, enemy.cell, skill.burst_range_override):
				continue
			var enemy_data: OperatorData = _operator_data[enemy.operator_id]
			source.last_attack_target_x = enemy.cell.x
			source.last_attack_target_y = enemy.cell.y
			var damage := Combat.calculate_damage(attack, SkillRules.defense_value(enemy, enemy_data), SkillRules.magic_resist_value(enemy, enemy_data), "physical", SkillRules.dodge_chance(enemy, enemy_data, "physical"), rng, SkillRules.damage_profession_id(source_data), _damage_taken_percent(enemy, "physical"))
			_apply_damage(enemy, enemy_data, damage, "physical", source)
			if enemy.hp <= 0: continue
			var duration := int(skill.effect_params["control_ticks"])
			if source.deploy_control_kind == 0:
				StatusRules.add_control(self,enemy,"slow",duration)
			elif source.deploy_control_kind == 1:
				StatusRules.add_control(self,enemy,"bind",duration)
			else:
				var resistant := StatusRules.has_resistance(self,enemy)
				StatusRules.add_control(self,enemy,"stun",duration * CONFIG.STATUS_RESISTANCE_DURATION_PERCENT / 100 if resistant else duration,source)
			DisplacementRules.apply_unit(self, source, enemy, DisplacementRules.direction(source, enemy.cell, "push"), int(skill.effect_params["shift_force"]))

	for source in units:
		var source_data: OperatorData = _operator_data[source.operator_id]
		if source.hp > 0 and SkillRules.active_ticks(source) > 0 and source_data.skills[source.skill_index].effect_type == "foxfire_aura":
			if source.skill_elapsed_ticks >= CONFIG.TICK_RATE and source.skill_elapsed_ticks % CONFIG.TICK_RATE == 0:
				source.skill_regen_attack = SkillRules.attack_value(source, source_data)
			for enemy in units:
				if enemy.hp > 0 and enemy.side != source.side and _is_in_attack_range(source, enemy.cell, ATTACK_RANGE.effective_offsets(source, source_data)):
					StatusRules.add_control(self,enemy,"slow",1)

	SoraRules.advance_sleep(self)
	FlagRules.advance(self)

	FlameRules.advance_burns(self)
	LumenRules.advance_rain(self)
	MonstrMedicRules.advance(self)
	MedicAlterRules.advance(self)
	StatusRules.regenerate(self)
	TitiRules.maintain_doze(self)

	SagaRules.advance_executions(self)
	SwordRules.advance_sp(self)
	SwordRules.resolve_casts(self)
	DroneRules.advance_control(self)
	PusherRules.resolve_nitrogen(self)
	AttackTimeline.advance_projectiles(self)
	AttackRules.resolve(self)
	TexasAlterRules.resolve_recasts(self)

	StainlessRules.finish_skills(self)
	if StatusRules.expire_skills(self):
		AuraRules.refresh(self)

	Mon3trRules.resolve_deaths(self)
	PioneerRules.reward_deaths(self)
	for unit in units.duplicate():
		if unit.hp<=0:
			LingRules.on_death(self,unit)
			TitiRules.on_death(self,unit)
			ClassicOperatorRules.on_death(self,unit)
	var alive_units: Array[UnitState] = []
	for unit in units:
		if unit.hp > 0:
			alive_units.append(unit)
		else:
			if unit.operator_id=="cliffheart":CliffheartRules.on_exit(self,unit)
			WArtilleryRules.on_exit(self,unit)
			var defeated_data := _operator_data[unit.operator_id] as OperatorData
			if unit.operator_id in StainlessRules.IDS:StainlessRules.recycle(self,unit)
			if unit.operator_id=="mon3tr_reconstruction":
				sides[unit.side].cooldowns[unit.operator_id]=roundi(defeated_data.redeploy_time*CONFIG.TICK_RATE)
			elif defeated_data.branch_trait.effect_type not in ["ling_summon","stainless_device_1","stainless_device_2","stainless_device_3","dusk_freeling","mon3tr", "phantom", "executor_clone", "water_cannon", "summoner_drone", "flowing_shape", "jessica_shield"]:
				sides[unit.side].cooldowns[unit.operator_id] = _redeploy_ticks(unit.side, defeated_data)
	units = alive_units
	StainlessRules.maintain(self,false)
	DuskRules.maintain(self)
	Mon3trRules.maintain_binding(self)
	DroneRules.remove_orphans(self)
	PusherRules.remove_orphan_cannons(self)
	MerchantRules.clean_bombs(self)
	AuraRules.refresh(self)

	ball.advance_move(ball.move_ticks_left == 1 and ball_move_is_blocked())

	tick += 1
	var scoring_side := 0 if ball.cell.x<=0 else (1 if ball.cell.x>=CONFIG.GRID_COLUMNS-1 else -1)
	if scoring_side>=0:
		goals[scoring_side]+=1
		last_goal_tick=tick
		last_goal_side=scoring_side
		if rules.mode=="single":result=RESULT_BLUE_WIN if scoring_side==0 else RESULT_RED_WIN
		else:_reset_scored_ball()
	if result==RESULT_RUNNING:
		if rules.mode=="score" and tick>=rules.duration_ticks():
			result=RESULT_DRAW if goals[0]==goals[1] else (RESULT_BLUE_WIN if goals[0]>goals[1] else RESULT_RED_WIN)
		elif rules.mode=="single" and (tick==rules.duration_ticks() or tick>=rules.max_ticks()):
			if ball.cell.x<CONFIG.BALL_START_CELL.x:result=RESULT_BLUE_WIN
			elif ball.cell.x>CONFIG.BALL_START_CELL.x:result=RESULT_RED_WIN
			elif tick>=rules.max_ticks():result=RESULT_DRAW
	TacticalRules.advance_boxes(self)
	if scoring_side >= 0 and rules.mode == "score":
		GoalRecoveryRules.begin(self, 1 - scoring_side)


# Detach marks from the scored ball without changing skill timers, ammo or fields.
func _reset_scored_ball() -> void:
	for unit in units:
		if unit.mark_kind==2:unit.mark_kind=3
	for bomb in w_bombs:
		if bomb.kind==3:bomb.kind=4
	ball=BallState.new()


func ball_move_is_blocked() -> bool:
	if ball.move_ticks_left == 0:
		return false
	var ball_target := ball.cell + ball.move_direction
	if ball_target.x < 0 or ball_target.x >= CONFIG.GRID_COLUMNS or ball_target.y < 0 or ball_target.y >= CONFIG.GRID_ROWS:
		return true
	if item_reserves_cell(ball_target):
		return true
	var terrain := terrain_at(ball_target)
	if terrain != "ground" and terrain != "ground_no_deploy":
		return true
	for box in tactical_boxes:
		if box.cell == ball_target:
			return true
	for unit in units:
		var blocker_data := _operator_data[unit.operator_id] as OperatorData
		if unit.hp > 0 and unit.cell == ball_target and SkillRules.block_count_value(unit, blocker_data) >= CONFIG.BLOCK_BALL_MIN:
			return true
	return false


func state_hash() -> int:
	var hash_value := AttackTimeline.hash_projectiles(17,attack_projectiles)
	hash_value=(hash_value*31+next_projectile_order)&0x7fffffff
	hash_value=(hash_value*31+attack_skill_hits.size())&0x7fffffff
	for hit in attack_skill_hits:
		for item in hit:hash_value=(hash_value*31+item)&0x7fffffff
	hash_value=(hash_value*31+reed_blasts.size())&0x7fffffff
	for blast in reed_blasts:
		for value in [blast.source_id,blast.side,blast.cell.x,blast.cell.y,blast.attack,blast.due_tick]:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value=(hash_value*31+texas_rains.size())&0x7fffffff
	for rain in texas_rains:
		for value in [rain.source_id,rain.side,rain.source_cell.x,rain.source_cell.y,rain.facing,rain.attack,rain.due_tick,rain.stun_ticks,rain.ball_cell.x,rain.ball_cell.y,rain.goal_generation]:hash_value=(hash_value*31+value)&0x7fffffff
		hash_value=(hash_value*31+rain.target_ids.size())&0x7fffffff
		for id in rain.target_ids:hash_value=(hash_value*31+id)&0x7fffffff
		hash_value=(hash_value*31+rain.box_ids.size())&0x7fffffff
		for id in rain.box_ids:hash_value=(hash_value*31+id)&0x7fffffff
	hash_value=(hash_value*31+fiammetta_explosions.size())&0x7fffffff
	for field in fiammetta_explosions:
		for value in [field.source_id,field.side,field.source_cell.x,field.source_cell.y,field.facing,field.center_hundredths.x,field.center_hundredths.y,field.attack,field.radius_hundredths,field.due_tick]:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value=(hash_value*31+chen_slimes.size())&0x7fffffff
	for field in chen_slimes:
		for value in [field.source_id,field.side,field.due_tick,field.speed_remaining_percent,field.defense_reduce,field.cells.size()]:hash_value=(hash_value*31+value)&0x7fffffff
		for cell in field.cells:
			for value in [cell.x,cell.y]:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value=(hash_value*31+archetto_volleys.size())&0x7fffffff
	for field in archetto_volleys:
		for value in [field.source_id,field.side,field.source_cell.x,field.source_cell.y,field.facing,field.target_kind,field.target_id,field.cell.x,field.cell.y,field.attack,field.shots_left,field.segment_shots,field.total_shots,field.next_tick,field.start_tick,field.goal_generation]:hash_value=(hash_value*31+value)&0x7fffffff
		hash_value=(hash_value*31+field.visited_ids.size())&0x7fffffff
		for id in field.visited_ids:hash_value=(hash_value*31+id)&0x7fffffff
	for value in [int(rules.mode=="score"),rules.minutes,rules.rounds,goals[0],goals[1],last_goal_tick,last_goal_side,recovery_side,recovery_ticks_left,recovery_input_ticks]:hash_value=(hash_value*31+value)&0x7fffffff
	for field in classic_attack_fields:
		hash_value=(hash_value*31+field.kind)&0x7fffffff
		for offset in field.offsets:
			hash_value=(hash_value*31+offset.x)&0x7fffffff
			hash_value=(hash_value*31+offset.y)&0x7fffffff
		for value in [field.source_id,field.side,field.cell.x,field.cell.y,field.source_cell.x,field.source_cell.y,field.facing,field.attack,field.next_tick,field.end_tick,field.pulse_ticks,field.radius_squared]:hash_value=(hash_value*31+value)&0x7fffffff
	for side in sides:
		hash_value=(hash_value*31+side.sniper_cost_discount)&0x7fffffff
		hash_value=(hash_value*31+side.sussurro_skill_uses)&0x7fffffff
		hash_value=(hash_value*31+side.silence_protocol_uses)&0x7fffffff
		for value in [side.rhine_cost_reduction,side.rhine_first_cost_reduction,int(side.rhine_first_discount_used)]:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value = (hash_value * 31 + ball.displacement_steps_left) & 0x7fffffff
	for side in sides:
		var discount_ids := side.wildmane_discounts.keys();discount_ids.sort()
		hash_value=(hash_value*31+discount_ids.size())&0x7fffffff
		for id in discount_ids:
			for byte in str(id).to_utf8_buffer():hash_value=(hash_value*31+byte)&0x7fffffff
			hash_value=(hash_value*31+int(side.wildmane_discounts[id]))&0x7fffffff
	for unit in units:
		for value in [int(unit.eunectes_sp_enabled),unit.eunectes_regen_accum]:hash_value=(hash_value*31+value)&0x7fffffff
	for unit in units:
		for value in [unit.ling_owner_id,int(unit.ling_advanced),unit.ling_recycle_stacks,unit.ling_pulse_ticks,unit.ling_skill_mode]:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.titi_dot_next_tick,unit.titi_doze_owner_id,unit.titi_doze_mode,unit.titi_sanctuary_target_id]:hash_value=(hash_value*31+value)&0x7fffffff
		for values in [unit.titi_sleep_ids,unit.titi_sleep_elapsed]:
			hash_value=(hash_value*31+values.size())&0x7fffffff
			for value in values:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.mlynar_charge_ticks,unit.mlynar_charge_bonus_percent,int(unit.mlynar_skill_killed),unit.gavial_deferred_damage,unit.gavial_debt_total,unit.gavial_debt_ticks_left,unit.gavial_debt_accum,unit.gavial_debt_pulse_ticks,unit.gladiia_regen_accum,unit.gladiia_hook_ticks_left,unit.gladiia_vortex_cell.x,unit.gladiia_vortex_cell.y,unit.gladiia_vortex_started_tick,unit.gladiia_vortex_next_pulse,unit.gladiia_vortex_pulses,unit.gladiia_vortex_attack,unit.gladiia_vortex_slow_remaining_percent]:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.reed_cinder_source_id,unit.reed_cinder_until_tick,unit.reed_cinder_attack_reduce_percent,unit.reed_cinder_magic_fragile_percent,int(unit.reed_lifeseed_mark),unit.reed_dot_next_tick,int(unit.reed_explosion_queued),unit.reed_explosion_immunity_until_tick,unit.reed_fireball_started_tick,unit.eyja_mist_stacks,unit.eyja_mist_until_tick,unit.eyja_mist_next_tick,unit.eyja_mist_heal,unit.eyja_mist_source_id,unit.eyja_elemental_barrier,unit.eyja_elemental_barrier_until_tick]:hash_value=(hash_value*31+value)&0x7fffffff
		for values in [unit.reed_fireball_carriers,unit.reed_fireball_ready_ticks]:
			hash_value=(hash_value*31+values.size())&0x7fffffff
			for value in values:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [int(unit.ines_stolen_attack),int(unit.ines_attack_loss),int(unit.ines_speed_gain),int(unit.ines_speed_loss),int(unit.ines_shadow_slow),int(unit.ines_dot_until),int(unit.ines_dot_next),int(unit.ines_dot_attack),int(unit.ines_dot_source),int(unit.vigil_owner_id),int(unit.vigil_wolf_layers),int(unit.vigil_regrow_tick),int(unit.vigil_enhanced_attack),int(unit.vigil_enhanced_victim)]:hash_value=(hash_value*31+value)&0x7fffffff
		for values in [unit.ines_target_ids,unit.ines_target_speed]:
			hash_value=(hash_value*31+values.size())&0x7fffffff
			for value in values:hash_value=(hash_value*31+value)&0x7fffffff
	for side in sides:
		for value in [int(side.ines_first_shadow_used),side.ines_shadow_cell.x,side.ines_shadow_cell.y,side.ines_shadow_facing]:hash_value=(hash_value*31+value)&0x7fffffff
	for unit in units:
		for fields in [unit.golden_target_ids,unit.golden_target_x,unit.golden_target_y,unit.golden_goal_generation,unit.golden_trait_hits,unit.golden_explosion_stacks,unit.golden_cooldowns]:
			for value in fields:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.stainless_owner_id,unit.stainless_loss_accum,unit.stainless_sp_ticks,unit.dusk_owner_id,unit.dusk_expiry_tick,int(unit.dusk_first_attack_used),unit.dusk_kill_stacks,unit.fiammetta_vigor_percent,unit.chen_slime_defense_reduce]:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.typewriter_owner_id,unit.typewriter_defense_remaining_percent,unit.typewriter_defense_until_tick,int(unit.lee_marked),int(unit.lee_control_charm),unit.lee_mark_target_id,unit.lee_mark_until_tick,unit.lee_mark_stacks,unit.lee_mark_cell.x,unit.lee_mark_cell.y,int(unit.texas_first_kill_used),int(unit.texas_recast_pending),int(unit.texas_burst_pending),unit.texas_started_tick,unit.texas_rain_next_tick,unit.texas_rain_emissions,unit.texas_dot_until_tick,unit.texas_dot_next_tick,unit.texas_dot_source_id,unit.texas_resist_remaining_percent,unit.texas_resist_until_tick,unit.penance_barrier_hp,int(unit.penance_charged_mode),unit.blemishine_regen_accum,unit.lin_wall_owner_id,unit.lin_wall_ready_tick,int(unit.lin_wall_active),int(unit.carnelian_charged),unit.carnelian_mark_owner_id,unit.carnelian_mark_stacks,unit.carnelian_mark_until_tick,unit.pallas_vigor_next_tick,unit.pallas_vigor_percent,unit.pallas_blessing_next_tick,unit.pallas_blessing_vigor_percent,unit.thorns_last_active_attack_tick,unit.thorns_counter_ready_tick,unit.thorns_regen_accum,unit.thorns_poison_until_tick,unit.thorns_poison_next_tick,unit.thorns_poison_source_id,unit.thorns_poison_damage]:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.dodge_physical_bonus,int(unit.dodge_next_physical),int(unit.dodge_attack_ready),unit.dodge_aura_until_tick,unit.dodge_aura_next_tick,unit.attack_speed_remaining_percent,unit.speed_debuff_until_tick,unit.speed_debuff_remaining_percent,unit.recon_defense_remaining_percent,unit.curse_defense_remaining_percent,unit.curse_attack_remaining_percent,unit.bind_link_owner_id,unit.shield_charge_ticks,unit.curse_doll_stock,unit.curse_doll_owner_id,int(unit.death_sp_resolved)]:hash_value=(hash_value*31+value)&0x7fffffff
		for values in [unit.dodge_aura_ids,unit.analysis_target_ids,unit.analysis_expiry_ticks]:
			hash_value=(hash_value*31+values.size())&0x7fffffff
			for value in values:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.healing_received_bonus_percent,unit.max_health_bonus_add,unit.limited_skill_uses,unit.fatal_until_tick,unit.weaken_until_tick,unit.weaken_attack_remaining_percent,unit.blood_buff_until_tick,unit.blood_buff_attack_percent,unit.blood_buff_loss_percent,unit.blood_buff_next_tick]:hash_value=(hash_value*31+value)&0x7fffffff
		for value in [unit.launch_started_tick,unit.launch_end_tick,unit.poison_until_tick,unit.poison_next_tick,unit.poison_source_id,unit.poison_damage,unit.poison_pulse_ticks,unit.pramanix_defense_remaining_percent,unit.pramanix_resist_remaining_percent,int(unit.liskarm_shield_ready),int(unit.amiya_retreat_pending),unit.cuora_started_tick,unit.cuora_end_tick,unit.lappland_skill_tick,unit.ptilopsis_skill_tick,unit.ptilopsis_end_tick,unit.texas_cast_tick,unit.gravel_ticks_left,unit.gravel_barrier_initial,unit.gravel_barrier_hp,unit.gravel_decay_accum]:hash_value=(hash_value*31+value)&0x7fffffff
		for field in [unit.reconstruct_owner_id,unit.monstr_origin_cell.x,unit.monstr_origin_cell.y,int(unit.monstr_token_ready),unit.monstr_echo_tick,unit.monstr_echo_target_id,unit.monstr_echo_amount,unit.monstr_echo_synergy,unit.monstr_synergy_until_tick,unit.monstr_synergy_speed,unit.monstr_overload_until_tick,unit.monstr_overload_speed,unit.monstr_loss_accum,unit.monstr_return_guard_ticks]:hash_value=(hash_value*31+field)&0x7fffffff
		for value in [unit.flow_owner_id,unit.flow_root_id,int(unit.flow_is_split),unit.flow_copy_id.hash(),unit.flow_point_until_tick,unit.flow_expiry_tick,unit.flow_health,unit.flow_attack,unit.flow_defense,unit.flow_resist,unit.flow_block,unit.flow_interval_ticks,int(unit.flow_melee),int(unit.flow_magical),int(unit.flow_can_charge),unit.flow_attack_count,unit.flow_stolen_attack,unit.flow_stolen_defense,unit.flow_attack_loss,unit.flow_defense_loss,unit.flow_regen_accum,unit.flow_sanctuary_percent,unit.jessica_owner_id,unit.jessica_expiry_tick,int(unit.jessica_shield_extended),unit.jessica_original_facing,int(unit.jessica_bomb_pending),unit.jessica_bomb_tick,unit.jessica_bomb_cell.x,unit.jessica_bomb_cell.y]:hash_value=(hash_value*31+value)&0x7fffffff
		for array in [unit.flow_victim_ids,unit.flow_victim_attack,unit.flow_victim_defense]:
			hash_value=(hash_value*31+array.size())&0x7fffffff
			for value in array:hash_value=(hash_value*31+value)&0x7fffffff
		hash_value=(hash_value*31+unit.flow_range.size())&0x7fffffff
		for cell in unit.flow_range:
			hash_value=(hash_value*31+cell.x)&0x7fffffff;hash_value=(hash_value*31+cell.y)&0x7fffffff
		for field in [unit.cold_ticks_left,unit.frozen_ticks_left,unit.silence_grave_until_tick,int(unit.silence_grave_used),unit.silence_drone_stock,unit.silence_drone_owner_id,unit.silence_regen_accum]:hash_value=(hash_value*31+field)&0x7fffffff
		for field in [unit.bard_skill_started_tick,unit.bard_mode,unit.bard_owner_id,unit.inspire_attack_add,unit.inspire_defense_add,unit.bard_regen_accum,unit.bard_loss_accum,unit.bard_pulse_tick]:hash_value=(hash_value*31+field)&0x7fffffff
		for field in [unit.lumen_lamp_started_tick,unit.lumen_lamp_closed_tick,unit.lumen_resistance_ticks,unit.lumen_emergency_ready_tick,unit.lumen_special_tick,unit.lumen_cast_tick]:hash_value=(hash_value*31+field)&0x7fffffff
		for field in [unit.critical_speed_percent,unit.critical_sp_add,unit.critical_ticks_left,unit.critical_execute_tick,unit.critical_executor_id,unit.saga_focus_ticks,int(unit.saga_focus_used),unit.saga_regen_accum,unit.saga_cast_tick]:hash_value=(hash_value*31+field)&0x7fffffff
		for field in [int(unit.ambush_ready),unit.w_action_tick,unit.w_action_kind]:hash_value=(hash_value*31+field)&0x7fffffff
		for field in [unit.chen_slash_tick,unit.aak_injection_tick,unit.mon3tr_owner_id,unit.mon3tr_mode,int(unit.mon3tr_outside_range),int(unit.mon3tr_killed),int(unit.mon3tr_death_triggered),unit.mon3tr_decay_ticks_left,unit.mon3tr_decay_duration_ticks,unit.mon3tr_attack_peak_percent,unit.nian_shield_layers,unit.block_bonus,unit.status_resistance_bonus,unit.aak_attack_percent,unit.aak_speed_add,unit.aak_defense_percent,unit.aak_health_percent,unit.aak_buff_ticks,unit.aak_buff_index,unit.aak_buff_source_id,unit.chen_slashes_left,unit.chen_next_slash_tick,unit.chen_cast_tick,unit.chen_sheath_tick]:hash_value=(hash_value*31+field)&0x7fffffff
		hash_value = (hash_value * 31 + unit.drone_owner_id) & 0x7fffffff
		for field in [unit.rupture_until_tick, unit.rupture_source_id, unit.rupture_damage_per_cell, unit.nitrogen_shot_tick, unit.pusher_strike_tick, unit.pusher_mode_started_tick]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
		for field in [unit.talent_sp_ticks, unit.flame_resist_aura_percent, unit.flame_resist_ticks, unit.flame_resist_reduce, unit.burn_until_tick, unit.burn_next_tick, unit.burn_source_id, unit.burn_attack, unit.burn_attack_percent, unit.burn_defense_reduce]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
		for field in [unit.penetration_stacks, unit.penetration_last_tick, unit.mark_kind, unit.mark_id, unit.mark_cell.x, unit.mark_cell.y, unit.mark_refresh_ticks, unit.rain_arrows_left, unit.rain_next_tick, unit.skill_hit_ids.size()]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
		for id in unit.skill_hit_ids:
			hash_value = (hash_value * 31 + id) & 0x7fffffff
		for field in [unit.displacement_origin.x, unit.displacement_origin.y, unit.displacement_ticks_left, unit.displacement_duration_ticks, unit.skill_ammo_left, int(unit.skill_dump_pending), unit.attack_boost_stacks, unit.deploy_control_kind, unit.silence_ticks_left, unit.flag_cell.x, unit.flag_cell.y, unit.flag_landing_ticks_left, int(unit.flag_burst_pending), unit.flag_defense_bonus_percent, unit.bomb_next_tick, int(unit.coin_firing), unit.coin_fire_ticks_left]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
	hash_value = (hash_value * 31 + tick) & 0x7fffffff
	hash_value = (hash_value * 31 + rng.state) & 0x7fffffff
	hash_value = (hash_value * 31 + result) & 0x7fffffff
	hash_value = (hash_value * 31 + next_unit_id) & 0x7fffffff
	for field in [next_box_id, next_box_spawn_tick, box_warning_cell.x, box_warning_cell.y, platform_drop_count, tactical_boxes.size(), box_spawn_counts_by_half[0], box_spawn_counts_by_half[1], box_last_spawn_half, box_same_half_streak]:
		hash_value = (hash_value * 31 + field) & 0x7fffffff
	for box in tactical_boxes:
		for field in [box.box_id, box.cell.x, box.cell.y, box.hits_left]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
	hash_value = (hash_value * 31 + tactical_item_effects.size()) & 0x7fffffff
	for effect in tactical_item_effects:
		for field in [effect.item_kind, effect.side, effect.cell.x, effect.cell.y, effect.facing, effect.placed_tick, effect.effect_tick, int(effect.activated)]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
	hash_value = (hash_value * 31 + platform_cells.size()) & 0x7fffffff
	for cell in platform_cells:
		hash_value = (hash_value * 31 + cell.x) & 0x7fffffff
		hash_value = (hash_value * 31 + cell.y) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.cell.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.cell.y) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.accum.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.accum.y) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_ticks_left) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_direction.x) & 0x7fffffff
	hash_value = (hash_value * 31 + ball.move_direction.y) & 0x7fffffff

	for side_state in sides:
		hash_value = (hash_value * 31 + side_state.ling_stock) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.drone_stock) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.drone_cooldown_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.cannon_cooldown_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.side_id) & 0x7fffffff
		for skill_index in squad_skills[side_state.side_id]:
			hash_value = (hash_value * 31 + skill_index) & 0x7fffffff
		for id in squad_ids[side_state.side_id]:
			for codepoint in id.to_utf32_buffer():
				hash_value = (hash_value * 31 + codepoint) & 0x7fffffff
			hash_value = (hash_value * 31 + 1) & 0x7fffffff
		hash_value=(hash_value*31+side_state.stainless_stock)&0x7fffffff
		hash_value = (hash_value * 31 + side_state.cost) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.cost_regen_ticks) & 0x7fffffff
		var cooldown_ids := side_state.cooldowns.keys()
		cooldown_ids.sort()
		for operator_id in cooldown_ids:
			for codepoint in String(operator_id).to_utf32_buffer():
				hash_value = (hash_value * 31 + codepoint) & 0x7fffffff
			hash_value = (hash_value * 31 + side_state.cooldowns[operator_id]) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.clone_cooldown_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.phantom_count) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.phantom_cooldown_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.next_deploy_discount) & 0x7fffffff
		hash_value = (hash_value * 31 + side_state.vanguard_cost_discount) & 0x7fffffff
		for count in side_state.tactical_items:
			hash_value = (hash_value * 31 + count) & 0x7fffffff

	var previous_unit_id := -1
	for unit in units:
		assert(unit.unit_id > previous_unit_id, "units must stay sorted by unit_id")
		previous_unit_id = unit.unit_id
		hash_value = (hash_value * 31 + unit.unit_id) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.side) & 0x7fffffff
		for codepoint in unit.operator_id.to_utf32_buffer():
			hash_value = (hash_value * 31 + codepoint) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cell.x) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cell.y) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.facing) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_index) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.hp) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.deployed_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.stun_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.attack_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp_regen_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp_regen_accum) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.sp_recharge_bonus_percent) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_repeat_activation_count) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_activation_count) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_cost_accum) & 0x7fffffff
		for field in [unit.hook_owner_id, unit.hook_due_tick, unit.hook_stun_ticks, unit.sleep_ticks_left, unit.medical_drone_stock, unit.medical_drone_owner_id, unit.fortune_choice, unit.destiny_attack_stop_ticks, unit.shell_ticks_left, unit.shell_defense_reduce, unit.healing_output_percent, unit.musha_speed_accum, unit.musha_attack_speed, unit.skill_elapsed_ticks, unit.skill_regen_attack, unit.skill_hp_regen_accum]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.skill_defense_bonus_percent) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.barrier_hp.size()) & 0x7fffffff
		for index in unit.barrier_hp.size():
			for field in [unit.barrier_hp[index], unit.barrier_ticks_left[index], unit.barrier_defense_percent[index], unit.barrier_magic_only[index], unit.barrier_magic_resist_add[index]]:
				hash_value = (hash_value * 31 + field) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.bind_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.slow_ticks_left) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.slow_next_interrupt_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_basic_interrupt_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.bind_immunity_ticks_left) & 0x7fffffff
		hash_value=AttackTimeline.hash_intent(hash_value,unit.attack_intent)
		hash_value=(hash_value*31+unit.attack_action_view_index)&0x7fffffff
		for action_value in [unit.skill_started_tick,unit.skill_start_observed_count,unit.attack_action_event_index,int(unit.attack_action_triggered),int(unit.attack_action_proc),unit.attack_action_event_frames.size()]:hash_value=(hash_value*31+action_value)&0x7fffffff
		for action_value in unit.attack_action_event_frames:hash_value=(hash_value*31+action_value)&0x7fffffff
		for field in [unit.attack_started_tick,unit.attack_next_ready_tick,unit.attack_action_clip.hash(),unit.attack_action_window_ticks,unit.attack_action_source_frames]:hash_value=(hash_value*31+field)&0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_target_x) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_attack_target_y) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_damage_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_heal_tick) & 0x7fffffff
		for id in unit.coin_target_ids:
			hash_value = (hash_value * 31 + id) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.coin_target_ids.size()) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.coins) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.coin_attack_stacks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.cost_drain_ticks) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_coin_gain_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + unit.last_coin_spend_tick) & 0x7fffffff
		hash_value = (hash_value * 31 + int(unit.last_attack_is_heal)) & 0x7fffffff
		for field in [unit.physical_shield_hp, unit.physical_guard_ticks_left, unit.attack_bonus_percent, unit.defense_bonus_percent, unit.defense_bonus_add, unit.attack_speed_bonus, unit.magic_resist_bonus, unit.magic_resist_bonus_percent, unit.dodge_magical_bonus, unit.max_health_bonus_percent, unit.blessing_target_id, int(unit.emergency_heal_used), unit.hp_lock_ticks_left, unit.revive_cost, unit.hp_regen_accum, unit.last_damage_block_tick, unit.life_loss_ticks, int(unit.bloodbath_used), unit.last_bloodbath_tick, unit.armor_break_ticks_left, unit.armor_break_defense_percent, unit.resist_break_ticks_left, unit.resist_remaining_percent]:
			hash_value = (hash_value * 31 + field) & 0x7fffffff
	hash_value=(hash_value*31+next_lumen_field_id)&0x7fffffff
	hash_value=(hash_value*31+lumen_rain_fields.size())&0x7fffffff
	for field in lumen_rain_fields:
		for value in [field.field_id,field.source_id,field.side,field.cell.x,field.cell.y,field.source_cell.x,field.source_cell.y,field.facing,field.attack,field.pulses_left,field.next_pulse_tick,field.pulse_ticks,field.heal_percent]:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value=(hash_value*31+next_w_explosion_id)&0x7fffffff
	hash_value=(hash_value*31+w_explosion_events.size())&0x7fffffff
	for event in w_explosion_events:
		for value in event:hash_value=(hash_value*31+value)&0x7fffffff
	hash_value=(hash_value*31+next_w_bomb_id)&0x7fffffff
	hash_value=(hash_value*31+w_bombs.size())&0x7fffffff
	for bomb in w_bombs:
		for field in [bomb.bomb_id,bomb.source_id,bomb.side,bomb.kind,bomb.target_id,bomb.cell.x,bomb.cell.y,bomb.source_cell.x,bomb.source_cell.y,bomb.placed_tick,bomb.explode_tick,bomb.expire_tick,bomb.attack,bomb.stun_ticks,bomb.facing]:hash_value=(hash_value*31+field)&0x7fffffff
	hash_value = (hash_value * 31 + next_bomb_id) & 0x7fffffff
	for bomb in champagne_bombs:
		for value in [bomb.bomb_id,bomb.source_id,bomb.side,bomb.cell.x,bomb.cell.y,bomb.placed_tick,bomb.attack,bomb.triggered_tick]:
			hash_value = (hash_value * 31 + value) & 0x7fffffff
	hash_value = (hash_value * 31 + champagne_bombs.size()) & 0x7fffffff
	return hash_value


func item_reserves_cell(cell: Vector2i) -> bool:
	if MonstrMedicRules.reserves_cell(self,cell):return true
	for effect in tactical_item_effects:
		if not effect.activated and effect.cell == cell:
			return true
	return false


func box_reserves_cell(cell: Vector2i) -> bool:
	if cell == box_warning_cell:
		return true
	for box in tactical_boxes:
		if box.cell == cell:
			return true
	return false


func deploy_cost(side: int, operator_id: String) -> int:
	if operator_id=="ines" and carried_skill_index(side,operator_id)==2 and not sides[side].ines_first_shadow_used:return 0
	return DeployRules.actual_cost(_operator_data[operator_id],sides[side])


func can_deploy(side: int, operator_id: String, cell: Vector2i) -> bool:
	if result != RESULT_RUNNING or not _operator_data.has(operator_id): return false
	if recovery_side >= 0 and (side != recovery_side or operator_id not in squad_ids[side] or _operator_data[operator_id].profession_id == "summon"): return false
	if operator_id=="mon3tr_reconstruction" and not MonstrMedicRules.can_place(self,side,cell):return false
	if operator_id=="flowing_shape" and not TacticianRules.can_deploy(self,side,cell):return false
	if operator_id=="jessica_shield" and not SentinelRules.can_deploy(self,side,cell):return false
	if operator_id in StainlessRules.IDS and not StainlessRules.available(self,side,operator_id):return false
	if operator_id=="dusk_freeling":return false
	if operator_id in LingRules.IDS and not LingRules.available(self,side,operator_id):return false
	if operator_id=="silence_alter_drone" and not SilenceAlterRules.drone_available(self,side):return false
	if operator_id=="vigil_wolf":
		if not VigilRules.available(self,side):return false
		var source := VigilRules.owner(self,side)
		if not _is_in_attack_range(source,cell,_operator_data["vigil"].attack_range):return false
	if operator_id=="pozyomka_typewriter" and not PozyomkaRules.available(self,side):return false
	if operator_id=="curse_doll" and not CurseDollRules.available(self,side):return false
	if operator_id=="medical_drone" and not MedicalDroneRules.available(self,side):return false
	if operator_id=="seaborn" and not BardRules.available(self,side):return false
	if operator_id=="mon3tr" and not Mon3trRules.available(self,side):return false
	if operator_id == "weedy_cannon" and not cannon_available(side): return false
	if operator_id in DRONE_IDS and not drone_available(side,operator_id): return false
	var deployment_side := sides[side]
	if operator_id=="ines" and carried_skill_index(side,"ines")==2 and not sides[side].ines_first_shadow_used:
		deployment_side=SideState.new(side);deployment_side.cost=CONFIG.COST_MAX;deployment_side.cooldowns=sides[side].cooldowns.duplicate()
	return not box_reserves_cell(cell) and not item_reserves_cell(cell) and DeployRules.is_legal(side, _operator_data[operator_id], cell, ball.cell, units, deployment_side, _arena, platform_cells, recovery_side == side)


func terrain_at(cell: Vector2i) -> String:
	return "high" if cell in platform_cells else _arena.terrain_at(cell)


func can_use_item(side: int, item_kind: int, cell: Vector2i, facing: int = -1) -> bool:
	if result != RESULT_RUNNING or recovery_side >= 0 or item_kind not in range(CONFIG.TACTICAL_ITEM_COUNT) or sides[side].tactical_items[item_kind] <= 0:
		return false
	if cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return false
	if item_kind == CONFIG.TACTICAL_ITEM_SUPPORT_DRONE:
		if (side == 0 and cell.x < ball.cell.x) or (side == 1 and cell.x > ball.cell.x): return false
		for effect in tactical_item_effects:
			if effect.item_kind == item_kind and effect.cell == cell: return false
		return facing == -1
	if cell.x == CONFIG.BALL_START_CELL.x or terrain_at(cell) != "ground" or box_reserves_cell(cell) or item_reserves_cell(cell) or cell == ball.cell:
		return false
	if ball.move_ticks_left > 0 and cell == ball.cell + ball.move_direction:
		return false
	if item_kind != CONFIG.TACTICAL_ITEM_STUN and ((side == 0 and cell.x < ball.cell.x) or (side == 1 and cell.x > ball.cell.x)):
		return false
	for unit in units:
		if unit.cell == cell:
			return false
	return item_kind != CONFIG.TACTICAL_ITEM_CRANE or _crane_target(side, cell, facing) != null


func _crane_target(side: int, cell: Vector2i, facing: int) -> UnitState:
	var target_cell := cell + ATTACK_RANGE.rotate_offset(Vector2i.RIGHT, facing)
	for unit in units:
		if unit.side == side and unit.hp > 0 and unit.cell == target_cell and (_operator_data[unit.operator_id] as OperatorData).profession_id != "summon":
			return unit
	return null


func _retreat_unit(unit: UnitState) -> void:
	if unit.operator_id=="mon3tr_operator":MonstrMedicRules.remove_owned(self,unit)
	if unit.operator_id=="mon3tr_reconstruction":MonstrMedicRules.exit_token(self,unit);return
	if unit.operator_id in LingRules.IDS:LingRules.remove(self,unit,false,false);return
	if unit.operator_id=="ling":LingRules.remove_owned(self,unit)
	if unit.operator_id=="titi":TitiRules.finish(self,unit,_operator_data[unit.operator_id],true)
	if unit.operator_id=="muelsyse":TacticianRules.remove_owned(self,unit)
	if unit.operator_id=="flowing_shape":
		if unit.flow_is_split:units.erase(unit)
		else:TacticianRules.point(self,unit)
		return
	if unit.operator_id=="jessica_alter":SentinelRules.remove_owned(self,unit)
	if unit.operator_id=="jessica_shield":SentinelRules.remove_shield(self,unit);return
	if unit.operator_id=="stainless":StainlessRules.remove_owned(self,unit)
	if unit.operator_id in StainlessRules.IDS:
		StainlessRules.recycle(self,unit);units.erase(unit);return
	if unit.operator_id=="dusk":DuskRules.remove_owned(self,unit)
	if unit.operator_id=="dusk_freeling":units.erase(unit);return
	if unit.operator_id=="silence_alter":SilenceAlterRules.remove_owned(self,unit)
	if unit.operator_id=="silence_alter_drone":units.erase(unit);return
	if unit.operator_id=="ines":InesRules.on_exit(self,unit)
	if unit.operator_id=="vigil":VigilRules.remove_owned(self,unit)
	if unit.operator_id=="vigil_wolf":
		sides[unit.side].cooldowns["vigil_wolf"]=300;units.erase(unit);return
	LeeRules.on_exit(self,unit,false)
	if unit.operator_id=="pozyomka_typewriter":PozyomkaRules.remove_token(self,unit);return
	if unit.operator_id=="pozyomka":PozyomkaRules.remove_owned(self,unit)
	MedicAlterRules.on_exit(self,unit)
	if unit.operator_id=="cliffheart":CliffheartRules.on_exit(self,unit)
	if unit.operator_id=="curse_doll":units.erase(unit);return
	if unit.operator_id=="shamare":CurseDollRules.remove_owned(self,unit)
	if unit.operator_id=="rosa":ClassicTacticalRules.close_links(self,unit)
	if unit.operator_id=="medical_drone":units.erase(unit);return
	if unit.operator_id=="seaborn":BardRules.remove_token(self,unit);return
	if unit.operator_id=="skadi_alter":BardRules.remove_owned(self,unit)
	if unit.operator_id=="mon3tr":
		Mon3trRules.remove_token(self,unit)
		WArtilleryRules.on_exit(self,unit)
		return
	if unit.operator_id=="kaltsit":Mon3trRules.remove_owned(self,unit)
	if unit.operator_id in DRONE_IDS:
		units.erase(unit)
		WArtilleryRules.on_exit(self,unit)
		return
	if unit.operator_id == "magallan":DroneRules.remove_owned(self,unit,false)
	if unit.operator_id == "weedy_cannon":
		sides[unit.side].cannon_cooldown_ticks = roundi(CANNON_DATA.redeploy_time * CONFIG.TICK_RATE)
		units.erase(unit)
		WArtilleryRules.on_exit(self,unit)
		return
	var data: OperatorData = _operator_data[unit.operator_id]
	if data.branch_trait.effect_type not in ["cost_drain", "phantom", "executor_clone"]:
		sides[unit.side].cost = mini(CONFIG.COST_MAX, sides[unit.side].cost + (DeployRules.permanent_cost(data,sides[unit.side]) if data.branch_trait.effect_type == "refund_on_kill" else roundi(DeployRules.permanent_cost(data,sides[unit.side]) * CONFIG.RETREAT_REFUND_RATIO)))
	if data.branch_trait.effect_type not in ["phantom", "executor_clone"]:
		sides[unit.side].cooldowns[unit.operator_id] = _redeploy_ticks(unit.side, data)
	units.erase(unit)
	if unit.operator_id == "weedy":PusherRules.remove_orphan_cannons(self)
	WArtilleryRules.on_exit(self,unit)
	MerchantRules.clean_bombs(self)
	if data.talent_1.effect_type=="sniper_support":AuraRules.refresh(self)


func clone_visible(side: int) -> bool:
	if "phantom" not in squad_ids[side]:
		return false
	var parent_present := false
	for unit in units:
		if unit.side == side and unit.hp > 0:
			if unit.operator_id == CLONE_DATA.operator_id:
				return false
			if unit.operator_id == "phantom" and unit.silence_ticks_left == 0:
				parent_present = true
	return parent_present


func clone_available(side: int) -> bool:
	return result == RESULT_RUNNING and clone_visible(side) and sides[side].clone_cooldown_ticks == 0 and sides[side].cost >= CLONE_DATA.deploy_cost


func clone_can_deploy(side: int, cell: Vector2i) -> bool:
	return clone_available(side) and can_deploy(side, CLONE_DATA.operator_id, cell)


func phantom_available(side: int) -> bool:
	if result != RESULT_RUNNING or sides[side].phantom_count <= 0 or sides[side].phantom_cooldown_ticks > 0 or sides[side].cost < PHANTOM_DATA.deploy_cost:
		return false
	for unit in units:
		if unit.side == side and unit.operator_id == "nightingale" and unit.hp > 0 and unit.silence_ticks_left == 0:
			return true
	return false


func phantom_can_deploy(side: int, cell: Vector2i) -> bool:
	if recovery_side >= 0: return false
	if not phantom_available(side) or box_reserves_cell(cell) or item_reserves_cell(cell) or cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS:
		return false
	if terrain_at(cell) != PHANTOM_DATA.terrain_requirement or (side == 0 and cell.x < ball.cell.x) or (side == 1 and cell.x > ball.cell.x):
		return false
	for unit in units:
		if unit.cell == cell:
			return false
	return true


func _squad_talents_enabled(side: int, operator_id: String) -> bool:
	for unit in units:
		if unit.side == side and unit.operator_id == operator_id and unit.hp > 0:
			return unit.silence_ticks_left == 0
	return true


func _apply_emergency_heal(target: UnitState, data: OperatorData) -> void:
	if target.critical_ticks_left>0:return
	var max_hp := SkillRules.max_health_value(target, data)
	if target.silence_ticks_left == 0 and data.talent_1.effect_type == "emergency_heal" and not target.emergency_heal_used:
		target.hp = maxi(1, target.hp)
		var params := data.talent_1.effect_params
		if target.hp * 100 <= max_hp * int(params["hp_threshold_percent"]):
			target.emergency_heal_used = true
			target.hp = mini(max_hp, target.hp + roundi(max_hp * int(params["heal_percent"]) / 100.0))
			target.hp_lock_ticks_left = roundi(float(params["lock_duration"]) * CONFIG.TICK_RATE)
			target.last_heal_tick = tick


func _apply_damage(target: UnitState, data: OperatorData, damage: int, damage_type: String, source: UnitState = null, attack_event: bool = true, applied_damage: Array[int] = []) -> bool:
	if target.titi_doze_owner_id>=0:return false
	if target.flow_point_until_tick>0:return false
	if target.operator_id in StainlessRules.IDS:return StainlessRules.receive_hit(self,target,source,damage)
	if data.branch_trait.effect_type=="pozyomka_typewriter":return false
	if damage>0 and LeeRules.source_dodges(self,target,data,source,damage_type):return false
	var was_alive := target.hp>0
	if data.branch_trait.effect_type=="silence_drone":return false
	if ClassicTacticalRules.is_resting(target,data):return false
	if (target.sleep_ticks_left>0 and not ((attack_event or (source!=null and source.operator_id=="titi")) and can_attack_sleeping(source))) or data.branch_trait.effect_type in ["curse_doll","medical_drone","water_cannon","seaborn"] or target.chen_slashes_left>0: return false
	var skill := data.skills[target.skill_index]
	if attack_event:GuardSpecialistRules.reflect(self,target,source)
	if attack_event:LinRules.received(self,target,data,source);PenanceRules.reflect(self,target,data,source)
	if attack_event and data.talent_1.effect_type=="lord_neurotoxin":ThornsRules.counter(self,target,data,source)
	if attack_event and source != null and source.hp > 0 and target.hp > 0 and source.side != target.side and target.silence_ticks_left == 0 and skill.effect_type == "passive_thorns":
		var source_data: OperatorData = _operator_data[source.operator_id]
		var reflect_attack := roundi(SkillRules.attack_value(target, data) * int(skill.effect_params["reflect_attack_percent"]) / 100.0)
		var reflected := Combat.calculate_damage(reflect_attack, SkillRules.defense_value(source, source_data), SkillRules.magic_resist_value(source, source_data), "physical", SkillRules.dodge_chance(source, source_data, "physical"), rng, SkillRules.damage_profession_id(data), _damage_taken_percent(source, "physical"))
		_apply_damage(source, source_data, reflected, "physical")
	if attack_event:NianRules.reflect(self,target,data,source)
	if damage == 0:
		ClassicTacticalRules.on_dodge(self,target,data,damage_type,source)
		return false
	damage=LinRules.absorb(self,target,damage,false)[0]
	if damage==0:return false
	if source!=null and data.talent_2.effect_type=="sarkaz_damage_reduction" and target.silence_ticks_left==0 and _operator_data[source.operator_id].race_id=="sarkaz":damage=roundi(damage*int(data.talent_2.effect_params["damage_remaining_percent"])/100.0)
	if target.liskarm_shield_ready and SkillRules.active_ticks(target)>0:
		target.liskarm_shield_ready=false;target.last_damage_block_tick=tick;return false
	if target.nian_shield_layers>0:
		target.nian_shield_layers-=1
		if target.nian_shield_layers==0 and data.talent_2.effect_type=="shield_break_sp" and target.silence_ticks_left==0:SagaRules.reward(self,target,int(data.talent_2.effect_params["sp_add"]))
		if data.talent_1.effect_type=="regenerating_shield" and target.silence_ticks_left==0:
			target.hp=mini(SkillRules.max_health_value(target,data),target.hp+Combat.calculate_healing(SkillRules.max_health_value(target,data),int(data.talent_1.effect_params["heal_percent"])))
			target.last_heal_tick=tick
		target.last_damage_block_tick=tick
		return false
	if damage_type=="physical" and SkillRules.active_ticks(target)!=0 and skill.effect_type in ["kaltsit_guard","lappland_sundial"] and rng.next_percent()<int(skill.effect_params["physical_block_percent"]):
		target.last_damage_block_tick=tick
		return false
	if target.silence_ticks_left == 0 and data.talent_1.effect_type == "damage_block" and rng.next_percent() < int(data.talent_1.effect_params["chance_percent"]):
		target.last_damage_block_tick = tick
		return false
	for index in target.barrier_hp.size():
		if target.barrier_magic_only[index] == 1 and damage_type != "magical":
			continue
		var absorbed := mini(damage, target.barrier_hp[index])
		target.barrier_hp[index] -= absorbed
		damage -= absorbed
		if damage == 0:
			return false
	if target.gravel_barrier_hp>0:
		var absorbed := mini(damage,target.gravel_barrier_hp)
		target.gravel_barrier_hp-=absorbed
		damage-=absorbed
		if damage==0:return false
	if damage_type == "physical" and target.physical_shield_hp > 0:
		var absorbed := mini(damage, target.physical_shield_hp)
		target.physical_shield_hp -= absorbed
		damage -= absorbed
		if damage == 0:
			return true
	damage=GuardSpecialistRules.defer_damage(target,data,damage)
	damage=ClassicOperatorRules.fatal_damage(self,target,data,damage)
	var max_hp := SkillRules.max_health_value(target, data)
	if target.hp_lock_ticks_left > 0:
		damage = mini(damage, maxi(0, target.hp - ceili(max_hp * int(data.talent_1.effect_params["lock_hp_percent"]) / 100.0)))
	if SkillRules.active_ticks(target)>0 and skill.effect_type=="specter_survival":damage=mini(damage,maxi(0,target.hp-1))
	if damage == 0:
		return false
	damage=BardRules.share_damage(self,target,damage)
	var nonlethal_saga: bool = source!=null and source.hp>0 and source.side!=target.side and source.silence_ticks_left==0 and _operator_data[source.operator_id].talent_1.effect_type=="critical_wound"
	var inflicted_critical := nonlethal_saga and damage>=target.hp
	if nonlethal_saga:damage=mini(damage,maxi(0,target.hp-1))
	var glass := LinRules.absorb(self,target,damage,true)
	damage=glass[0]
	if damage==0:return false
	damage=PenanceRules.absorb(self,target,data,damage,attack_event)
	if damage==0:return false
	var monstr_return := MonstrMedicRules.transformed(target) and damage>=target.hp
	if monstr_return or target.monstr_return_guard_ticks>0:damage=mini(damage,maxi(0,target.hp-1))
	damage=TitiRules.prevent_fatal(self,target,damage)
	damage=SilenceAlterRules.prevent_fatal(self,target,damage)
	if not applied_damage.is_empty():applied_damage[0]=damage
	target.hp -= damage
	if monstr_return:MonstrMedicRules.finish(self,target)
	GuardSpecialistRules.after_damage(self,target,source,damage,attack_event)
	if damage>0:SentinelRules.received(self,target)
	if target.hp<=0 and target.operator_id=="flowing_shape" and not target.flow_is_split:TacticianRules.point(self,target)
	VigilRules.fatal(self,target,data)
	if glass[1]==1 and target.hp>0:LinRules.burst(self,target,target.cell)
	target.last_damage_tick = tick
	ClassicOperatorRules.after_hit(self,target,source)
	if attack_event:LaunchOperatorRules.received(self,target,data)
	_apply_emergency_heal(target, data)
	if target.hp <= 0 and target.silence_ticks_left == 0 and data.talent_2.effect_type == "fatal_revive":
		var params := data.talent_2.effect_params
		var cost := target.revive_cost if target.revive_cost > 0 else int(params["initial_cost"])
		if sides[target.side].cost >= cost:
			sides[target.side].cost -= cost
			target.revive_cost = cost * int(params["cost_multiplier"])
			target.hp = roundi(max_hp * int(params["heal_percent"]) / 100.0)
			target.last_heal_tick = tick
	if target.hp <= 0 and target.silence_ticks_left == 0 and data.talent_2.effect_type == "bloodbath" and not target.bloodbath_used:
		var old_interval := SkillRules.attack_interval_ticks(target, data)
		target.bloodbath_used = true
		target.last_bloodbath_tick = tick
		target.hp = SkillRules.max_health_value(target, data)
		target.attack_ticks_left = ceili(float(target.attack_ticks_left) * SkillRules.attack_interval_ticks(target, data) / old_interval)
	if inflicted_critical and target.hp==1 and target.critical_ticks_left==0:SagaRules.mark_critical(self,target,source)
	SagaRules.trigger_focus(self,target,data)
	LeeRules.after_damage(self,target,source)
	if attack_event and skill.sp_recharge_type == "on_damaged" and target.skill_ticks_left == 0:
		target.sp = mini(SkillRules.sp_limit(skill), target.sp + 1)
	if target.hp<=0:
		if target.operator_id=="muelsyse":TacticianRules.remove_owned(self,target)
		if target.operator_id=="jessica_alter":SentinelRules.remove_owned(self,target)
		if target.operator_id=="jessica_shield":
			var owner := SentinelRules.owner_for(self,target)
			if owner!=null:owner.facing=owner.jessica_original_facing
		if target.operator_id=="ines":InesRules.on_exit(self,target)
		if target.operator_id=="vigil":VigilRules.remove_owned(self,target)
		LeeRules.on_exit(self,target,true)
		if target.operator_id=="pozyomka":PozyomkaRules.remove_owned(self,target)
		MedicAlterRules.on_death(self,target)
		MedicAlterRules.on_exit(self,target)
		ClassicOperatorRules.on_death(self,target)
		if source!=null and source.side!=target.side and source.hp>0:LaunchOperatorRules.reward_kill(self,source)
		if target.critical_ticks_left>0 and source!=null and source.side!=target.side:SagaRules.reward(self,source,target.critical_sp_add)
		if target.operator_id=="skadi_alter":BardRules.remove_owned(self,target)
		if target.operator_id=="cliffheart":CliffheartRules.on_exit(self,target)
		WArtilleryRules.on_exit(self,target)
		if target.operator_id=="mon3tr_operator":MonstrMedicRules.remove_owned(self,target)
		if target.operator_id=="silence_alter":SilenceAlterRules.remove_owned(self,target)
		if target.operator_id=="kaltsit":Mon3trRules.remove_owned(self,target)
		elif target.operator_id=="mon3tr":Mon3trRules.on_death(self,target)
		if source!=null and source.operator_id=="mon3tr" and source.side!=target.side and source.mon3tr_mode==3:source.mon3tr_killed=true
	if target.hp <= 0:
		AuraRules.refresh(self)
	if target.hp <= 0 and source != null and source.hp > 0:
		if was_alive:DuskRules.reward_kill(self,source,target);PenanceRules.reward_kill(self,source,target);TexasAlterRules.reward_kill(self,source,target)
		var source_data: OperatorData = _operator_data[source.operator_id]
		var source_skill := source_data.skills[source.skill_index]
		if SkillRules.active_ticks(source) != 0 and source_skill.effect_type == "coin_barrage":
			source.coins = mini(int(source_skill.effect_params["coin_limit"]),source.coins + 1)
			source.last_coin_gain_tick = tick
	return true


func _is_in_attack_range(unit: UnitState, target_cell: Vector2i, attack_range: Array[Vector2i]) -> bool:
	var relative := target_cell - unit.cell
	for offset in attack_range:
		if relative == ATTACK_RANGE.rotate_offset(offset, unit.facing):
			return true
	return false


func _redeploy_ticks(side: int, operator: OperatorData) -> int:
	var reduction := 0
	var seconds := operator.redeploy_time
	if operator.talent_2.effect_type == "redeploy_reduction" and _squad_talents_enabled(side, operator.operator_id):
		seconds -= int(operator.talent_2.effect_params["reduction_seconds"])
	var member_ids := squad_ids[side].duplicate()
	member_ids.sort()
	for id in member_ids:
		if not _squad_talents_enabled(side, id): continue
		var member: OperatorData = _operator_data[id]
		for talent in [member.talent_1, member.talent_2]:
			if talent.effect_type == "attack_redeploy_buff":
				reduction += int(talent.effect_params["redeploy_reduction_percent"])
	return roundi(seconds * CONFIG.TICK_RATE * (100 - reduction) / 100.0)


func _fragile_damage_percent(target: UnitState) -> int:
	var bonus := GnosisRules.fragile_percent(self,target)
	for source in units:
		var data: OperatorData=_operator_data[source.operator_id]
		var talent := data.talent_1
		if source.hp>0 and source.side!=target.side and source.silence_ticks_left==0 and talent.effect_type=="low_health_fragile" and target.hp*100<SkillRules.max_health_value(target,_operator_data[target.operator_id])*int(talent.effect_params["hp_threshold_percent"]) and _is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):bonus=maxi(bonus,roundi(int(talent.effect_params["fragile_percent"])*(float(data.skills[source.skill_index].effect_params["fragile_multiplier_percent"])/100.0 if SkillRules.active_ticks(source)!=0 and data.skills[source.skill_index].effect_type=="permanent_fragile_attack" else 1.0)))
	if target.hp > 0 and target.slow_ticks_left > 0:
		for source in units:
			var source_data: OperatorData = _operator_data[source.operator_id]
			if source.hp > 0 and source.silence_ticks_left == 0 and source.side != target.side and source_data.talent_2.effect_type == "slow_fragile_aura" and _is_in_attack_range(source, target.cell, ATTACK_RANGE.effective_offsets(source, source_data)):
				var source_bonus := int(source_data.talent_2.effect_params["damage_taken_bonus_percent"])
				if source.skill_ticks_left > 0 and source_data.skills[source.skill_index].effect_type == "foxfire_aura":
					source_bonus *= int(source_data.skills[source.skill_index].effect_params["fragile_multiplier"])
				bonus = maxi(bonus, source_bonus)
	if target.hp > 0:
		for source in units:
			var source_data: OperatorData = _operator_data[source.operator_id]
			var skill := source_data.skills[source.skill_index]
			if source.hp > 0 and source.side != target.side and SkillRules.active_ticks(source) > 0 and skill.effect_type == "flag_burst" and absi(target.cell.x - source.flag_cell.x) <= 1 and absi(target.cell.y - source.flag_cell.y) <= 1:
				bonus = maxi(bonus,int(skill.effect_params["fragile_percent"]))
	return 100 + bonus


func _apply_skill_life_loss(unit: UnitState, data: OperatorData, loss: int) -> void:
	var monstr_return := unit.hp>0 and MonstrMedicRules.transformed(unit) and loss>=unit.hp
	loss=MonstrMedicRules.clamp_life_loss(unit,loss)
	loss=TitiRules.prevent_fatal(self,unit,loss)
	if SkillRules.active_ticks(unit)>0 and data.skills[unit.skill_index].effect_type=="specter_survival":loss=mini(loss,maxi(0,unit.hp-1))
	if unit.hp_lock_ticks_left > 0:
		loss = mini(loss, maxi(0, unit.hp - ceili(SkillRules.max_health_value(unit, data) * int(data.talent_1.effect_params["lock_hp_percent"]) / 100.0)))
	if loss == 0 and not monstr_return: return
	unit.hp -= loss
	if monstr_return:MonstrMedicRules.finish(self,unit)
	unit.last_damage_tick = tick
	_apply_emergency_heal(unit, data)
	if unit.hp <= 0 and unit.silence_ticks_left == 0 and data.talent_2.effect_type == "bloodbath" and not unit.bloodbath_used:
		var old_interval := SkillRules.attack_interval_ticks(unit, data)
		unit.bloodbath_used = true
		unit.last_bloodbath_tick = tick
		unit.hp = SkillRules.max_health_value(unit, data)
		unit.attack_ticks_left = ceili(float(unit.attack_ticks_left) * SkillRules.attack_interval_ticks(unit, data) / old_interval)


func _roll_armor_break(unit: UnitState, data: OperatorData) -> bool:
	if unit.silence_ticks_left > 0 or data.talent_1.effect_type != "armor_break_proc":
		return false
	var chance := int(data.talent_1.effect_params["chance_percent"])
	if unit.skill_ticks_left != 0 and data.skills[unit.skill_index].effect_type in ["armor_break_single", "armor_break_boost"]:
		chance = int(data.skills[unit.skill_index].effect_params["talent_chance_percent"])
	return rng.next_percent() < chance


func carried_skill_index(side: int, operator_id: String) -> int:
	if operator_id=="pozyomka_typewriter":return squad_skills[side][squad_ids[side].find("pozyomka")]
	if operator_id=="phantom_clone":return squad_skills[side][squad_ids[side].find("phantom")]
	if _operator_data[operator_id].profession_id=="summon":return 0
	return squad_skills[side][squad_ids[side].find(operator_id)]



func bomb_is_mature(bomb: ChampagneBomb) -> bool:
	var owner: UnitState
	for source in units:
		if source.unit_id == bomb.source_id:
			owner = source
			break
	assert(owner != null, "An untriggered bomb must retain its owner")
	var skill := _operator_data[owner.operator_id].skills[owner.skill_index] as SkillResource
	return tick - bomb.placed_tick >= int(skill.effect_params["mature_ticks"])


func bomb_cell_is_available(source: UnitState, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= CONFIG.GRID_COLUMNS or cell.y < 0 or cell.y >= CONFIG.GRID_ROWS or terrain_at(cell) != "ground" or cell.x == CONFIG.BALL_START_CELL.x or box_reserves_cell(cell) or item_reserves_cell(cell): return false
	for ally in units:
		if ally.hp > 0 and ally.side == source.side and ally.cell == cell: return false
	for bomb in champagne_bombs:
		if bomb.triggered_tick < 0 and bomb.cell == cell: return false
	return true


func _magical_damage_taken_percent(target: UnitState) -> int:
	var percent := 100+target.reed_cinder_magic_fragile_percent
	if enemy_is_blocked(target):
		for unit in units:
			var talent: TalentResource=_operator_data[unit.operator_id].talent_1
			if unit.hp>0 and unit.side!=target.side and unit.silence_ticks_left==0 and talent.effect_type=="blocked_magic_vulnerability":percent=maxi(percent,100+int(talent.effect_params["damage_percent"]))
	for source in units:
		if source.hp <= 0 or source.side == target.side or SkillRules.active_ticks(source) <= 0:
			continue
		var data: OperatorData = _operator_data[source.operator_id]
		var skill := data.skills[source.skill_index]
		if skill.effect_type == "guardian_calcium" and _is_in_attack_range(source, target.cell, skill.attack_range_override):
			percent = maxi(percent, int(skill.effect_params["magic_damage_taken_percent"]))
	return percent


func cannon_visible(side: int) -> bool:
	if "weedy" not in squad_ids[side]: return false
	var owner_present := false
	for unit in units:
		if unit.side != side or unit.hp <= 0: continue
		if unit.operator_id == "weedy_cannon": return false
		if unit.operator_id == "weedy" and unit.silence_ticks_left == 0: owner_present = true
	return owner_present


func cannon_available(side: int) -> bool:
	return result == RESULT_RUNNING and cannon_visible(side) and sides[side].cannon_cooldown_ticks == 0 and sides[side].cost >= CANNON_DATA.deploy_cost


func can_attack_sleeping(source: UnitState) -> bool:
	return source!=null and source.hp>0 and source.silence_ticks_left==0 and (source.operator_id=="titi" or _operator_data[source.operator_id].talent_2.effect_type=="sleep_mercy")


func enemy_is_targetable(side: int, target: UnitState, attacker: UnitState = null, ignore_sleep: bool = false) -> bool:
	if target.titi_doze_owner_id>=0:return false
	if target.flow_point_until_tick>0:return false
	if target.operator_id in StainlessRules.IDS:return target.hp>0 and target.operator_id=="stainless_cannon" and target.side==side and target!=attacker
	if _operator_data[target.operator_id].branch_trait.effect_type=="silence_drone":return false
	if target.operator_id=="pozyomka_typewriter":return false
	if target.hp <= 0 or target.side == side or (target.sleep_ticks_left>0 and not ignore_sleep and not can_attack_sleeping(attacker)) or target.chen_slashes_left>0 or _operator_data[target.operator_id].branch_trait.effect_type in ["curse_doll","medical_drone","water_cannon","seaborn"]:return false
	if ClassicTacticalRules.is_resting(target,_operator_data[target.operator_id]):return false
	if InesRules.reveals(self,side,target):return true
	if ClassicTacticalRules.revealed(self,side,target):return true
	if target.operator_id=="ines" and target.skill_index==1 and SkillRules.active_ticks(target)>0 and not enemy_is_blocked(target):return false
	if DroneRules.hidden_ticks_left(self,target)==0:return true
	for source in units:
		if source.hp<=0 or source.side!=side or source.silence_ticks_left>0:continue
		var data: OperatorData=_operator_data[source.operator_id]
		if data.talent_2.effect_type=="reveal_invisible" and _is_in_attack_range(source,target.cell,AttackRange.effective_offsets(source,data)):return true
	return false


func drone_visible(side: int) -> bool:
	var source := DroneRules.owner(self,side)
	return source!=null and source.silence_ticks_left==0 and sides[side].drone_stock>0


func drone_available(side: int, id: String) -> bool:
	var source := DroneRules.owner(self,side)
	if result != RESULT_RUNNING or not drone_visible(side) or id!=DRONE_IDS[source.skill_index] or sides[side].drone_cooldown_ticks>0:return false
	if sides[side].cost < (DRONE_DATA[id] as OperatorData).deploy_cost:return false
	var count := 0
	for unit in units:
		if unit.hp>0 and unit.drone_owner_id==source.unit_id:count+=1
	return count < int((_operator_data[source.operator_id] as OperatorData).talent_1.effect_params["max_count"])


func _damage_taken_percent(target: UnitState, damage_type: String) -> float:
	var physical_percent := 100
	if damage_type=="physical" and target.stun_ticks_left>0:
		for source in units:
			var data: OperatorData=_operator_data[source.operator_id]
			if source.hp>0 and source.side!=target.side and source.silence_ticks_left==0 and data.talent_2.effect_type=="stunned_physical_aura" and _is_in_attack_range(source,target.cell,ATTACK_RANGE.effective_offsets(source,data)):
				physical_percent=maxi(physical_percent,100+int(data.talent_2.effect_params["damage_percent"]))
	var sanctuary := maxi(SkillRules.sanctuary_percent(target,_operator_data[target.operator_id]),SilenceAlterRules.protection(self,target)) if damage_type!="true" else 0
	var texas_percent := int(_operator_data[target.operator_id].talent_2.effect_params["damage_remaining_percent"]) if target.silence_ticks_left==0 and not target.texas_first_kill_used and _operator_data[target.operator_id].talent_2.effect_type=="texas_swordsmanship" else 100
	var roamer_percent := 100
	if target.operator_id=="mlynar" and target.silence_ticks_left==0 and GuardSpecialistRules.mlynar_surrounded(self,target):roamer_percent-=int(_operator_data[target.operator_id].talent_1.effect_params["damage_reduce_percent"])
	return (StainlessRules.physical_remaining(self,target) if damage_type=="physical" else 1.0)*_fragile_damage_percent(target)*physical_percent/100.0*(100-sanctuary)/100.0*texas_percent/100.0*roamer_percent/100.0


func enemy_is_blocked(target: UnitState, blocker_id: int = -1) -> bool:
	if target.sleep_ticks_left>0:return false
	for unit in units:
		if blocker_id >= 0 and unit.unit_id != blocker_id:continue
		if unit.hp<=0 or unit.side==target.side or unit.stun_ticks_left>0:continue
		var data: OperatorData=_operator_data[unit.operator_id]
		if data.branch_trait.effect_type in ["puller","pusher"] and terrain_at(unit.cell)!="ground":continue
		if (data.terrain_requirement!="high" or MonstrMedicRules.transformed(unit)) and SkillRules.block_count_value(unit,data)>0 and absi(unit.cell.x-target.cell.x)+absi(unit.cell.y-target.cell.y)==1:return true
	return false
