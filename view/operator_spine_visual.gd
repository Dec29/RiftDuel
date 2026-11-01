class_name OperatorSpineVisual
extends RefCounted

## 实时骨骼战斗小人的共享适配器。
##
## 由经已验收的 view/bagpipe_visual.gd 提炼而来：同一套单页 straight-alpha／normal
## blend 合批路径，但动作名、攻击结构与比例不再写死成风笛的数值，而是按
## OperatorSpineMap 中该干员的实际素材取值。
##
## 边界（与 Docs/spine_feasibility.md 一致）：仅支持已核定的单页、直通 alpha、
## normal blend 素材，以及已核定的远山加算插槽。多页、PMA 加载失败；新素材须独立核对源骨架插槽混合模式，
## 不能从 atlas 无 blend 字段推断为 normal，不得静默换成几何占位。

const CONFIG = preload("res://data/config.gd")
const MAP = preload("res://view/operator_spine_map.gd")

## 人物身体高度相对所在行格宽的目标比例。
##
## 判据来自实测而非 atlas 尺寸：已验收的风笛在棋盘上的可见身体约为 1.19 格高
## （按每模型自身可见身体边界计算），本常量取 1.2 既保持风笛现有观感，又让新
## 干员按各自身体边界等比缩放，而不是被武器最长边或 512×512 拼图尺寸带偏。
const BODY_CELL_RATIO := 1.2


static var _outline_textures: Dictionary = {}

var operator_id := ""
var mesh := ArrayMesh.new()
var texture: Texture2D
var last_error := ""
var clip := ""
var view_index := 0
var pose_seconds := 0.0
var body_bottom := 0.0
var body_height := 1.0
var _instances: Array[int] = []
var _clips := ["", ""]
var _entry: Dictionary = {}
var _chain_begin := 0.0
var _chain_loop := 0.0
var _chain_end := 0.0
var _flame_was_active := false
var _flame_end_at := -1.0
var _next_skill_was_active := false
var _next_skill_end_at := -1.0
var _sixstar_activation_count := 0
var _sixstar_cast_tick := -1.0
var _sixstar_was_active := false
var _sixstar_end_tick := -1.0
var _flow_body_clip := ""
var _prepared_view := -1
var _prepared_clip := ""
var _prepared_time := -1.0


func initialize(operator_id_value: String) -> bool:
	operator_id = operator_id_value
	if not MAP.has(operator_id):
		last_error = "OperatorSpineMap 未登记该干员的战斗骨骼：" + operator_id
		return false
	_entry = MAP.entry_for(operator_id)
	if _entry.has("chain_seconds"):
		# Begin / Loop / End 三段按各干员素材取值。
		var parts := str(_entry["chain_seconds"]).split(",")
		_chain_begin = float(parts[0])
		_chain_loop = float(parts[1])
		_chain_end = float(parts[2])
	var data_front := _source(0)
	# The verified provider supplies one normal-blend atlas page. Merging its
	# ordered attachment triangles into one draw is only valid for that shape.
	for index in 2:
		var data := _source(index)
		if not data.ensure_loaded() or data.get_page_count() != 1 or data.is_page_pma(0):
			last_error = "%s 需要已核定的单页直通 alpha 战斗素材：%s" % [operator_id, data.get_last_error()]
			return false
		var instance := data.create_instance()
		if instance == 0:
			last_error = data.get_last_error()
			return false
		_instances.append(instance)
	texture = data_front.get_page_texture(0)
	body_height = _measure_body_height()
	return last_error.is_empty()


## 该干员可见身体在骨架本地坐标中的高度；用于按行格宽等比缩放。
func _measure_body_height(idle_clip: String = "") -> float:
	var data := _source(0)
	var instance: int = _instances[0]
	if not data.clear_tracks(instance) or not data.set_animation(instance, 0, idle_clip if not idle_clip.is_empty() else str(_entry.get("idle_clip","Idle")), true):
		last_error = data.get_last_error()
		return 0.0
	if not _seek(data, instance, 0.0):
		return 0.0
	var bounds := _body_bounds(data, instance)
	if bounds.size.y <= 0.0:
		last_error = "无法从实际几何量取身体高度：" + operator_id
		return 0.0
	body_bottom = bounds.end.y
	return bounds.size.y


func _source(index: int) -> SpineSkeletonDataResource:
	return MAP.source(_entry, index)


func prepare(unit: UnitState, visual_tick: float, attack_interval_ticks: int) -> bool:
	if operator_id=="flowing_shape":
		var body_clip := ("A_Idle" if unit.flow_melee else "B_Idle") if not unit.flow_copy_id.is_empty() else "Idle_1"
		if body_clip!=_flow_body_clip:
			_source(0).destroy_instance(_instances[0]);_instances[0]=_source(0).create_instance()
			body_height=_measure_body_height(body_clip)
			if body_height<=0.0:return false
			_flow_body_clip=body_clip;_clips=["",""];_prepared_view=-1
	# 世界朝向 0=右 1=下 2=左 3=上；北向使用背面、其余使用正面。
	# 左右(facing 0/2)同为正面素材，由 MatchView 做水平翻转。
	view_index = 1 if unit.facing == 3 else 0
	if unit.skill_index in _entry.get("front_only_skills",[]) and SkillRules.active_ticks(unit)!=0:view_index=0
	var data := _source(view_index)
	var instance: int = _instances[view_index]
	clip = str(_entry.get("idle_clip","Idle"))
	var idle_seconds := float(_entry["idle_seconds_back"]) if view_index==1 and _entry.has("idle_seconds_back") else (float(_entry["idle_seconds"]) if _entry.has("idle_seconds") else 2.0)
	var deployed_seconds := maxf(0.0, visual_tick - unit.deployed_tick) / CONFIG.TICK_RATE
	# Nightingale's cage Idle is a native zero-duration pose, not a missing clip.
	pose_seconds = fposmod(deployed_seconds, idle_seconds) if idle_seconds > 0.0 else 0.0
	var age := (visual_tick - unit.last_attack_tick) / CONFIG.TICK_RATE
	if unit.last_attack_tick <= unit.last_basic_interrupt_tick:age = -1.0
	# New timelines provide the complete attack pose below; legacy selectors keep only casts/channels/idle.
	if operator_id in AttackTimeline.ADAPTED_IDS:age=-1.0
	var interval := float(attack_interval_ticks) / CONFIG.TICK_RATE
	if unit.last_attack_tick >= 0 and age >= 0.0 and unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and (not bool(_entry.get("attack_only_active",false)) or SkillRules.active_ticks(unit)!=0):
		if _entry.has("chain_seconds"):
			# Composite chain (Begin -> Loop -> End): the whole chain is mapped onto
			# the real attack window, which shrinks with the actual attack interval.
			# Chain lengths come from the parsed asset, so a longer chain such as
			# Schwarz's (1.833 s) is not squeezed into bagpipe's 1.0 s.
			var window := minf(0.7, interval * 0.85)
			var chain_total := _chain_begin + _chain_loop + _chain_end
			if age < window:
				var time := age * chain_total / window
				if time < _chain_begin:
					clip = "Attack_Begin"
					pose_seconds = time
				elif time < _chain_begin + _chain_loop:
					clip = str(_entry["down_clip"]) if unit.facing == 1 and _entry.has("down_clip") else MAP.attack_clip(_entry, view_index)
					pose_seconds = time - _chain_begin
				else:
					clip = "Attack_End"
					pose_seconds = time - _chain_begin - _chain_loop
		else:
			# Fit the complete source action into the real attack interval.
			# Faster attacks, including Exusiai S3, must not endlessly restart a long clip.
			# Name and duration are declared per operator per side from the parsed asset.
			# A separate whole-arc downward clip (Attack_Down) is used when the asset
			# really has one and the unit attacks downward.
			var attack_clip: String = MAP.attack_clip(_entry, view_index)
			var duration := MAP.attack_seconds(_entry, view_index)
			if unit.facing == 1 and _entry.has("down_clip"):
				attack_clip = _entry["down_clip"]
				duration = MAP.down_seconds(_entry)
			if _entry.has("melee_clip") and Vector2i(unit.last_attack_target_x, unit.last_attack_target_y) == unit.cell:
				attack_clip = _entry["melee_clip"]
				duration = float(_entry["melee_seconds_back"] if view_index == 1 else _entry["melee_seconds"])
			var window := minf(duration, interval * 0.85)
			if age < window:
				clip = attack_clip
				pose_seconds = age * duration / window
	if _entry.has("skill_actions"):_prepare_six_star(unit,visual_tick,interval,age)
	if operator_id=="w_mine" and unit.last_attack_tick>=0 and age>=0.0 and age<1.5:
		clip="Attack";pose_seconds=age
	if operator_id in ["myrtle","hellagur","nearl","meteorite","silence","cliffheart"]:_prepare_next_eight(unit,visual_tick,interval,age)
	if operator_id in LaunchOperatorRules.IDS:_prepare_launch_operators(unit,visual_tick,interval,age)
	if operator_id in ["platinum","specter","perfumer","cuora"]:_prepare_classic_four(unit,visual_tick,interval,age)
	if operator_id in ["texas","lappland","ptilopsis"]:_prepare_texas_batch(unit,visual_tick,interval,age)
	if operator_id in ["chen","aak","nian","mon3tr"]:_prepare_new_operators(unit,visual_tick,interval,age)
	if operator_id in ["w","saga","lumen","skadi_alter","seaborn"]:_prepare_w_saga_lumen_bard(unit,visual_tick,interval,age)
	if operator_id == "typhon":_prepare_typhon(unit,visual_tick,interval,age)
	if operator_id == "ifrit":_prepare_ifrit(unit,visual_tick)
	if operator_id == "saria":_prepare_saria(unit,interval,age)
	if operator_id == "mostima":_prepare_mostima(unit,visual_tick,interval,age)
	if operator_id in ["weedy","weedy_cannon"]:_prepare_weedy(unit,visual_tick,interval,age)
	if operator_id == "magallan":
		if clip == "Idle":pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,2.0 if view_index==0 else 1.0)
		# A single native Skill action, shared across the three module activations.
		if unit.skill_ticks_left>0 and unit.silence_ticks_left==0 and unit.skill_elapsed_ticks<CONFIG.TICK_RATE:
			clip="Skill"
			pose_seconds=unit.skill_elapsed_ticks/float(CONFIG.TICK_RATE)
	if operator_id in MatchState.DRONE_IDS and clip=="Idle":pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,1.0)
	if _entry.has("deploy_seconds") and unit.displacement_ticks_left == 0 and unit.last_attack_tick <= unit.deployed_tick and deployed_seconds < float(_entry["deploy_seconds"]):
		clip = "Start"
		pose_seconds = deployed_seconds

	if operator_id=="ling_soul3":
		var advanced: bool=unit.get("ling_advanced")
		if advanced:
			if clip=="Idle":clip="Idle_02";pose_seconds=fposmod(deployed_seconds,2.0)
			elif clip=="Attack":clip="Attack_02";pose_seconds=age*(50.0/30.0)/minf(0.7,interval*0.85)
			elif clip=="Start":
				clip="Start_02" if deployed_seconds<20.0/30.0 else "Idle_02"
				pose_seconds=deployed_seconds if clip=="Start_02" else fposmod(deployed_seconds,2.0)
	if operator_id=="flowing_shape":
		if unit.flow_point_until_tick>0:clip="Idle_2";pose_seconds=0.0
		elif not unit.flow_copy_id.is_empty():
			var prefix := "A_" if unit.flow_melee else "B_"
			if clip in ["Idle_1","Attack","Start"]:clip=prefix+("Idle" if clip=="Idle_1" else clip)
	if operator_id in AttackTimeline.IDS:
		# Simulation start and frozen action window replace post-hit animation restarts.
		if operator_id=="surtr" and SkillRules.active_ticks(unit)!=0 and unit.skill_index==2:
			clip="Skill_3_Idle";pose_seconds=fposmod(deployed_seconds,AttackActionData.SURTR_TWILIGHT_IDLE_FRAMES/float(CONFIG.TICK_RATE))
			var cast_age := (visual_tick-unit.launch_started_tick)/CONFIG.TICK_RATE
			if unit.displacement_ticks_left==0 and cast_age>=0 and cast_age<AttackActionData.SURTR_TWILIGHT_BEGIN_TICKS/float(CONFIG.TICK_RATE):clip="Skill_3_Begin";pose_seconds=cast_age
		elif operator_id=="surtr" and unit.attack_started_tick>=0:
			clip="Idle";pose_seconds=fposmod(deployed_seconds,80.0/30.0)
		elif unit.attack_started_tick>=0:
			clip=str(_entry.get("idle_clip","Idle"));pose_seconds=fposmod(deployed_seconds,idle_seconds) if idle_seconds>0 else 0.0
		var action_age := visual_tick-unit.attack_started_tick
		if unit.displacement_ticks_left==0 and unit.attack_started_tick>unit.last_basic_interrupt_tick and action_age>=0 and action_age<unit.attack_action_window_ticks:
			clip=unit.attack_action_clip
			pose_seconds=action_age*unit.attack_action_source_frames/(float(CONFIG.TICK_RATE)*unit.attack_action_window_ticks)
			if unit.attack_intent!=null:
				# Interpolation cannot expose contact/muzzle pose before simulation releases it.
				pose_seconds=minf(pose_seconds,unit.attack_intent.release_frame/float(CONFIG.TICK_RATE)-0.000001)
	if operator_id in AttackTimeline.ADAPTED_IDS and unit.attack_started_tick>=0 and not (operator_id=="ptilopsis" and unit.skill_index==1 and SkillRules.active_ticks(unit)>0):
		var age_ticks:=visual_tick-unit.attack_started_tick
		if unit.displacement_ticks_left==0 and unit.attack_started_tick>unit.last_basic_interrupt_tick and age_ticks>=0 and age_ticks<unit.attack_action_window_ticks:
			view_index=unit.attack_action_view_index
			clip=unit.attack_action_clip
			var source_frame:=age_ticks*unit.attack_action_source_frames/unit.attack_action_window_ticks
			if unit.attack_intent!=null:source_frame=minf(source_frame,unit.attack_intent.release_frame-.000001)
			if "|" in clip:
				for part in clip.split("|"):
					var frames:=int(AttackActionData.CATALOG.FRAMES[operator_id][part][str(view_index)])
					if source_frame<frames:clip=part;pose_seconds=source_frame/30.0;break
					source_frame-=frames
			else:
				var parts:=AttackActionData.chain_parts(operator_id,clip,view_index)
				if source_frame<parts.lead:clip=parts.begin;pose_seconds=source_frame/30.0
				elif parts.tail>0 and source_frame>=unit.attack_action_source_frames-parts.tail:clip=parts.end;pose_seconds=(source_frame-unit.attack_action_source_frames+parts.tail)/30.0
				else:pose_seconds=(source_frame-parts.lead)/30.0

	if unit.frozen_ticks_left>0 or unit.stun_ticks_left > 0 or unit.sleep_ticks_left>0:
		clip = str(_entry.get("idle_clip","Idle"))
		pose_seconds = 0.0
		if bool(_entry.get("skill_idle_during_control",false)) and SkillRules.active_ticks(unit)!=0:
			var actions: Dictionary=_entry["skill_actions_back" if view_index==1 else "skill_actions"][unit.skill_index]
			if actions.has("idle"):clip=actions["idle"]
			elif actions.has("loop"):clip=actions["loop"]
		if operator_id=="surtr" and unit.skill_index==2 and SkillRules.active_ticks(unit)!=0:clip="Skill_3_Idle"
		if operator_id=="ling_soul3" and bool(unit.get("ling_advanced")):clip="Idle_02"
		if operator_id=="flowing_shape" and not unit.flow_copy_id.is_empty():clip="A_Idle" if unit.flow_melee else "B_Idle"
	# Only presentation is sampled: idle at 15 Hz, attacks at 30 Hz.
	# Reuse one completed mesh between samples; combat and UI remain full rate.
	data=_source(view_index);instance=_instances[view_index]
	var pose_rate := 15.0 if clip == "Idle" else 30.0
	var phase_offset := float(unit.unit_id % 4) / (4.0 * pose_rate)
	var sampled_time := maxf(0.0, floorf((pose_seconds + phase_offset) * pose_rate) / pose_rate - phase_offset)
	if _prepared_view == view_index and _prepared_clip == clip and _prepared_time == sampled_time:
		return true
	if _clips[view_index]!=clip or operator_id=="silence_alter":
		# Poses are sought from the simulation clock with zero update delta, so the
		# previous track must be disposed: its mixing chain cannot advance in this mode.
		# The3.8 provider cannot reset setup attachments; these summons hide slots during Start;
		# replace this side's instance only on clip changes to avoid carrying hidden slots into Idle.
		if bool(_entry.get("reset_on_clip_change",false)) or operator_id in AttackTimeline.ADAPTED_IDS or operator_id in ["vigil_wolf","pozyomka_typewriter","silence_alter_drone","mon3tr","w_mine","seaborn"]:
			data.destroy_instance(instance)
			instance=data.create_instance()
			_instances[view_index]=instance
			if instance==0:
				last_error=data.get_last_error()
				return false
		if not data.clear_tracks(instance) or not data.set_animation(instance, 0, clip, true):
			last_error = data.get_last_error()
			return false
		_clips[view_index] = clip
	if not _seek(data, instance, sampled_time):
		return false
	# Native animation events are presentation-only; never drive combat from them.
	data.drain_events(instance)
	texture = data.get_page_texture(0)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var commands := data.get_render_commands(instance)
	if _entry.has("additive_slots"):
		commands = []
		for row: Dictionary in data.get_slot_render_commands(instance):
			# Native metadata also includes hidden slots with no render command.
			if not row.has("command"):continue
			var command: Dictionary = row["command"].duplicate()
			if str(row["slot_name"]) in (_entry.get("additive_slots_back",_entry["additive_slots"]) if view_index==1 else _entry["additive_slots"]):
				var marked_uvs: PackedVector2Array = command["uvs"].duplicate()
				for uv_index in marked_uvs.size():marked_uvs[uv_index].x += 2.0
				command["uvs"] = marked_uvs
			commands.append(command)
	for command: Dictionary in commands:
		var offset := vertices.size()
		vertices.append_array(command["positions"])
		uvs.append_array(command["uvs"])
		colors.append_array(command["colors"])
		for index: int in command["indices"]:
			indices.append(offset + index)
	if vertices.is_empty() and ((operator_id in ["vigil_wolf","pozyomka_typewriter","silence_alter_drone","w_mine","seaborn"] and clip=="Start") or clip in _entry.get("empty_clips",[])):
		# These native summons start invisible while its birth attachment is revealed.
		mesh.clear_surfaces()
		return true
	if vertices.is_empty():
		last_error="Empty native pose %s/%s time%.6f view%d unit%d"%[operator_id,clip,sampled_time,view_index,unit.unit_id]
		return false
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	_prepared_view = view_index
	_prepared_clip = clip
	_prepared_time = sampled_time
	return true


func _seek(data: SpineSkeletonDataResource, instance: int, time: float) -> bool:
	if not data.set_track_time(instance, 0, time) \
			or not data.update_animation_state(instance, 0.0) \
			or not data.apply_animation_state(instance) \
			or not data.update_world_transform(instance, 0.0):
		last_error = data.get_last_error()
		return false
	return true


## 按所在行格宽等比缩放：以该模型实际可见身体高度换算，不使用 atlas 尺寸或武器最长边。
func scale_for_row(row_width: float) -> float:
	return row_width * (float(_entry["body_cell_ratio"]) if _entry.has("body_cell_ratio") else BODY_CELL_RATIO) / body_height


## 绘制时把可见身体底边对齐投影格中心，保持身体直立。
# Read-only attachment query; the native bridge uses the same y-down basis as rendered vertices.
func bone_attachment(bone_name: String, row_width: float) -> Transform2D:
	var world: Dictionary=_source(view_index).get_bone_world_transform(_instances[view_index],bone_name)
	assert(not world.is_empty(),"Missing original attachment bone: "+operator_id+"/"+bone_name)
	var scale:=scale_for_row(row_width)
	return Transform2D(Vector2(world.a,world.c).normalized(),Vector2(-world.b,-world.d).normalized(),anchor_offset(scale)+Vector2(world.x,world.y)*scale)

func anchor_offset(scale: float) -> Vector2:
	return Vector2(0.0, -body_bottom * scale)


## 可见身体边界：按插槽名排除武器类插槽，避免用武器最长边决定比例。
func _body_bounds(data: SpineSkeletonDataResource, instance: int) -> Rect2:
	var bounds := Rect2()
	var started := false
	for row: Dictionary in data.get_slot_render_commands(instance):
		if _is_weapon_slot(str(row.get("slot_name", ""))) or _is_weapon_slot(str(row.get("bone_name", ""))):
			continue
		var command: Dictionary = row.get("command", {})
		for point: Vector2 in command.get("positions", PackedVector2Array()):
			if not started:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
			else:
				bounds = bounds.expand(point)
	return bounds


func _is_weapon_slot(name: String) -> bool:
	var lowered := name.to_lower()
	for token: String in ["weapon", "wpn", "gun", "bow", "arrow", "spear", "sword",
			"blade", "shield", "staff", "wand", "cannon", "halberd", "axe", "lance", "ammo"]:
		if lowered.contains(token):
			return true
	return false


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _instances.is_empty() or _entry.is_empty():
		return
	for index in _instances.size():
		MAP.source(_entry, index).destroy_instance(_instances[index])


func outline_texture() -> Texture2D:
	# Derive a white alpha mask once per atlas; never change the source resource.
	var key := texture.get_rid()
	if not _outline_textures.has(key):
		var image := texture.get_image()
		if image.is_compressed():
			var error := image.decompress()
			if error != OK:
				last_error = "Cannot decode battle atlas alpha: " + operator_id
				return null
		image.convert(Image.FORMAT_RGBA8)
		var pixels := image.get_data()
		for index in range(0,pixels.size(),4):
			pixels[index]=255
			pixels[index+1]=255
			pixels[index+2]=255
		_outline_textures[key]=ImageTexture.create_from_image(Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,pixels))
	return _outline_textures[key]


# The three native skill families are verified against this model, not inferred for other operators.
func _prepare_typhon(unit: UnitState,visual_tick: float,interval: float,age: float) -> void:
	var active := SkillRules.active_ticks(unit)!=0
	var permanent := active and unit.skill_index==1 and unit.skill_repeat_activation_count>=2
	var rain := active and unit.skill_index==2
	var prefix := "Attack"
	var begin := 1.0/6.0
	var loop := 2.4
	var end := 1.0/3.0
	var idle_seconds := 6.0 if view_index==0 else 2.0
	if active and unit.skill_index==1:
		prefix="Skill_2_2" if permanent else "Skill_2_1"
		if permanent:
			begin=2.0/3.0;end=0.0
			clip="Skill_2_2_Idle";idle_seconds=8.0 if view_index==0 else 2.0
	if rain:
		clip="Skill_3_Idle";idle_seconds=8.0 if view_index==0 else 8.0/3.0
		prefix="Skill_3";begin=0.0;loop=4.8;end=0.0
	elif unit.facing==1:
		prefix="Skill_Down_2_2" if permanent else ("Skill_Down_2_1" if active and unit.skill_index==1 else "Attack_Down")
	if clip.begins_with("Attack") or clip.begins_with("Skill_2_1"):clip="Idle"
	pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,idle_seconds)
	if unit.last_attack_tick<0 or age<0.0 or unit.stun_ticks_left>0 or unit.displacement_ticks_left>0:return
	var total := begin+loop+end
	var window := minf(total,interval*0.85)
	if age>=window:return
	var time := age*total/window
	if time<begin:clip=prefix+"_Begin";pose_seconds=time
	elif time<begin+loop:clip=prefix+"_Loop";pose_seconds=time-begin
	else:clip=prefix+"_End";pose_seconds=time-begin-loop


func _prepare_ifrit(unit: UnitState,visual_tick: float) -> void:
	var active := SkillRules.active_ticks(unit)>0 and unit.skill_index==2
	var prefix := "Skill_Down_2" if unit.facing==1 else "Skill_2"
	if _flame_was_active and not active:_flame_end_at=visual_tick
	_flame_was_active=active
	if active and unit.displacement_ticks_left==0:
		var elapsed := float(unit.skill_elapsed_ticks)/CONFIG.TICK_RATE
		clip=prefix+"_Begin" if elapsed<0.7 else prefix+"_Loop"
		pose_seconds=elapsed if elapsed<0.7 else fposmod(elapsed-0.7,0.4)
	elif _flame_end_at>=0.0 and visual_tick-_flame_end_at<0.5*CONFIG.TICK_RATE:
		clip=prefix+"_End";pose_seconds=(visual_tick-_flame_end_at)/CONFIG.TICK_RATE
	elif clip=="Idle":pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,3.0 if view_index==0 else 1.0)


func _prepare_saria(unit: UnitState, interval: float, age: float) -> void:
	if unit.displacement_ticks_left > 0:
		return
	if SkillRules.active_ticks(unit) > 0 and unit.skill_index == 2:
		if view_index == 0:
			var elapsed := float(unit.skill_elapsed_ticks) / CONFIG.TICK_RATE
			clip = "Skill_Begin" if elapsed < 0.7 else "Skill_Loop"
			pose_seconds = elapsed if elapsed < 0.7 else fposmod(elapsed - 0.7, 0.4)
		else:
			# Native back skeleton has no maintained skill family.
			clip = "Idle"
		return
	if unit.last_attack_is_heal and age >= 0.0 and age < minf(1.0, interval * 0.85):
		clip = "Attack_2"
		pose_seconds = age / minf(1.0, interval * 0.85)


func _prepare_mostima(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if unit.displacement_ticks_left > 0:
		return
	var active := SkillRules.active_ticks(unit) > 0
	if active and unit.skill_index == 1:
		var elapsed := float(unit.skill_elapsed_ticks) / CONFIG.TICK_RATE
		clip = "Skill_Begin" if elapsed < 25.0 / 30.0 else "Skill_Loop"
		pose_seconds = elapsed if elapsed < 25.0 / 30.0 else fposmod(elapsed - 25.0 / 30.0, 80.0 / 30.0)
	elif active and unit.skill_index == 2:
		var elapsed := float(unit.skill_elapsed_ticks) / CONFIG.TICK_RATE
		if elapsed < 20.0 / 30.0:
			clip = "Skill_2_Begin"
			pose_seconds = elapsed
		elif unit.last_attack_tick >= 0 and age >= 0.0 and age < minf(53.0 / 30.0, interval * 0.85):
			clip = "Skill_2_Loop"
			pose_seconds = age * (53.0 / 30.0) / minf(53.0 / 30.0, interval * 0.85)
		else:
			clip = "Skill_2_Idle"
			pose_seconds = fposmod(elapsed, 4.0)
	elif clip == "Idle":
		pose_seconds = fposmod(maxf(0.0, visual_tick - unit.deployed_tick) / CONFIG.TICK_RATE, 8.0)


func _prepare_weedy(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if unit.displacement_ticks_left > 0:return
	if operator_id == "weedy_cannon":
		if unit.attack_started_tick<0 and unit.nitrogen_shot_tick >= 0 and visual_tick-unit.nitrogen_shot_tick >= 0.0 and visual_tick-unit.nitrogen_shot_tick < (26.0/30.0)*CONFIG.TICK_RATE:
			clip = "Skill_Down" if unit.facing == 1 else "Skill"
			pose_seconds = (visual_tick-unit.nitrogen_shot_tick)/CONFIG.TICK_RATE
		elif unit.facing == 1 and clip in ["Attack_Begin","Attack_End"]:
			clip = "Attack_Down_Begin" if clip == "Attack_Begin" else "Attack_Down_End"
		elif clip == "Idle":
			pose_seconds = fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,5.4 if view_index == 0 else 3.4)
		return
	if unit.attack_started_tick<0 and unit.nitrogen_shot_tick >= 0 and visual_tick-unit.nitrogen_shot_tick >= 0.0 and visual_tick-unit.nitrogen_shot_tick < 1.1666666666666667*CONFIG.TICK_RATE:
		clip = "Skill_3_Down" if unit.facing == 1 else "Skill_3"
		pose_seconds = (visual_tick-unit.nitrogen_shot_tick)/CONFIG.TICK_RATE
	elif SkillRules.active_ticks(unit) != 0 and unit.skill_index == 1:
		var elapsed := maxf(0.0,visual_tick-unit.pusher_mode_started_tick)/CONFIG.TICK_RATE
		if elapsed < 7.0/30.0:
			clip = "Skill_2_Begin"
			pose_seconds = elapsed
		elif age >= 0.0 and age < minf(1.0,interval*0.85):
			clip = "Skill_2_Attack_Down" if unit.facing == 1 else "Skill_2_Attack"
			pose_seconds = age*1.0/minf(1.0,interval*0.85)
		else:
			clip = "Skill_2_Idle"
			pose_seconds = fposmod(elapsed,3.0)
	elif unit.skill_index == 0 and unit.pusher_strike_tick == unit.last_attack_tick and age >= 0.0 and age < minf(1.2,interval*0.85):
		clip = "Skill"
		pose_seconds = age*1.2/minf(1.2,interval*0.85)
	elif clip == "Idle":
		pose_seconds = fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,3.0)


func _prepare_new_operators(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if unit.silence_ticks_left>0 or unit.displacement_ticks_left>0:return
	if operator_id=="chen":
		if unit.skill_index==2 and unit.chen_slashes_left>0:
			# Native Skill_3 hides the body after20/30s for external teleport VFX.
			# The approved fixed-cell adaptation instead shows a full native attack per slash.
			if age>=0.0 and age<0.2:
				clip="Attack";pose_seconds=age/0.2*1.5
		elif unit.chen_cast_tick==unit.last_attack_tick and unit.skill_index==1 and age>=0.0 and age<minf(interval*0.85,35.0/30.0):
			clip="Skill_2" if view_index==0 else "Attack"
			pose_seconds=age/minf(interval*0.85,35.0/30.0)*(35.0/30.0 if view_index==0 else 1.5)
		elif unit.chen_sheath_tick==unit.last_attack_tick and age>=0.0 and age<minf(interval*0.85,1.0):
			clip="Skill";pose_seconds=age/minf(interval*0.85,1.0)
	elif operator_id=="aak" and unit.last_attack_tick==unit.aak_injection_tick and age>=0.0 and age<0.7:
		clip="Skill_Down" if view_index==0 and unit.facing==1 else "Skill"
		pose_seconds=age/0.7*38.0/30.0
	elif operator_id=="nian" and SkillRules.active_ticks(unit)>0:
		if unit.skill_index==1:
			# This family has no recurring OnAttack event; the source holds its shield.
			clip="Skill_1_Loop" if view_index==0 else "Idle"
			pose_seconds=fposmod(unit.skill_elapsed_ticks/30.0,80.0/30.0)
		elif unit.skill_index==0:
			# The alternate weapon family retains the actual attack-event structure.
			if clip=="Idle":clip="Skill_2_Idle"
			elif clip.begins_with("Attack_"):clip=clip.replace("Attack_","Skill_2_")
	elif operator_id=="mon3tr" and age>=0.0:
		var duration := 1.0 if unit.mon3tr_mode==2 else 38.0/30.0
		var window := minf(duration,interval*0.85)
		if unit.mon3tr_mode in [2,3] and age<window:
			clip="Skill" if unit.mon3tr_mode==2 else "Skill_2"
			pose_seconds=age/window*duration


func _prepare_w_saga_lumen_bard(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if unit.silence_ticks_left>0 or unit.displacement_ticks_left>0:return
	if operator_id=="w" and unit.w_action_tick>=0:
		var elapsed := (visual_tick-unit.w_action_tick)/30.0
		var duration := [44.0/30.0,2.8,58.0/30.0][unit.w_action_kind] as float
		var window := minf(duration,interval*0.85)
		if elapsed>=0.0 and elapsed<window:
			clip="Skill_%d"%(unit.w_action_kind+1)
			pose_seconds=elapsed/window*duration
	elif operator_id=="saga":
		var cast_age := (visual_tick-unit.saga_cast_tick)/30.0
		if unit.saga_cast_tick>=0 and cast_age>=0 and cast_age<25.0/30.0:
			clip="Skill";pose_seconds=cast_age
		elif SkillRules.active_ticks(unit)>0 and unit.skill_index==2:
			clip=clip.replace("Attack_","Skill_2_")
			if clip=="Idle":clip="Skill_2_Idle"
	elif operator_id=="lumen":
		if clip=="Idle" and view_index==1:pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/30.0,40.0/30.0)
		var special_age := (visual_tick-unit.lumen_cast_tick)/30.0
		if unit.skill_index==1 and unit.lumen_cast_tick>=0 and special_age>=0.0 and special_age<40.0/30.0:
			clip="Skill_2";pose_seconds=special_age
		elif unit.skill_index==0 and unit.last_attack_tick==unit.lumen_cast_tick and age>=0.0 and age<minf(interval*0.85,40.0/30.0):
			clip="Skill_1";pose_seconds=age/minf(interval*0.85,40.0/30.0)*40.0/30.0
		elif unit.skill_index==2 and SkillRules.active_ticks(unit)!=0:
			var elapsed := maxf(0.0,visual_tick-unit.lumen_lamp_started_tick)/30.0
			if elapsed<1.0/3.0:clip="Skill_3_Begin";pose_seconds=elapsed
			else:clip="Skill_3_Idle" if clip=="Idle" else "Skill_3_Loop"
		elif unit.skill_index==2 and unit.lumen_lamp_closed_tick>=0:
			var elapsed := (visual_tick-unit.lumen_lamp_closed_tick)/30.0
			if elapsed>=0.0 and elapsed<(1.0/3.0 if view_index==1 else 8.0/30.0):clip="Skill_3_End";pose_seconds=elapsed
	elif operator_id=="skadi_alter" and SkillRules.active_ticks(unit)!=0:
		var elapsed := maxf(0.0,visual_tick-unit.bard_skill_started_tick)/30.0
		var begin := [3.2,118.0/30.0,4.4][unit.skill_index] as float
		clip="Skill_%d_%s"%[unit.skill_index+1,"Begin" if elapsed<begin else "Loop"]
		pose_seconds=elapsed if elapsed<begin else fposmod(elapsed-begin,100.0/30.0 if unit.skill_index==1 else 263.0/30.0)
	elif operator_id=="seaborn" and unit.bard_mode==3 and unit.bard_pulse_tick>=0:
		var elapsed := (visual_tick-unit.bard_pulse_tick)/30.0
		if elapsed>=0.0 and elapsed<1.0:clip="Skill";pose_seconds=elapsed*32.0/30.0


func _prepare_texas_batch(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if unit.displacement_ticks_left>0:return
	if operator_id=="texas":
		var skill_age := (visual_tick-unit.texas_cast_tick)/30.0
		if unit.texas_cast_tick>=0 and skill_age>=0.0 and skill_age<minf(interval*0.85,65.0/30.0):
			var time := skill_age/minf(interval*0.85,65.0/30.0)
			if view_index==0:clip="Skill";pose_seconds=time*65.0/30.0
			else:_texas_chain(time*2.0)
		elif unit.last_attack_tick>=0 and age>=0.0 and age<minf(0.7,interval*0.85):_texas_chain(age/minf(0.7,interval*0.85)*2.0)
	elif operator_id=="lappland":
		var elapsed := (visual_tick-unit.lappland_skill_tick)/30.0
		if unit.silence_ticks_left==0 and unit.lappland_skill_tick>=0 and elapsed>=0.0 and elapsed<4.0/3.0:clip="Skill";pose_seconds=elapsed
	elif operator_id=="ptilopsis":
		if clip=="Idle" and view_index==1:pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/30.0,1.0)
		if SkillRules.active_ticks(unit)>0 and unit.skill_index==1:
			var elapsed := (visual_tick-unit.ptilopsis_skill_tick)/30.0
			if elapsed>=0.0 and elapsed<0.7:clip="Skill_Start";pose_seconds=elapsed
			else:clip="Skill_Loop";pose_seconds=fposmod(maxf(0.0,elapsed-.7),.4)
		elif unit.ptilopsis_end_tick>=0:
			var elapsed := (visual_tick-unit.ptilopsis_end_tick)/30.0
			if elapsed>=0.0 and elapsed<1.0/3.0:clip="Skill_End";pose_seconds=elapsed


func _texas_chain(time: float) -> void:
	if time<0.5:clip="Attack_Start";pose_seconds=time
	elif time<1.5:clip="Attack_Loop";pose_seconds=time-0.5
	else:clip="Attack_End";pose_seconds=time-1.5


func _prepare_classic_four(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if clip=="Idle" and view_index==1 and operator_id in ["specter","cuora"]:pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/30.0,1.0)
	if unit.displacement_ticks_left>0 or unit.stun_ticks_left>0:return
	if operator_id=="platinum" and unit.skill_index==1 and SkillRules.active_ticks(unit)!=0 and clip=="Attack":clip="Skill";pose_seconds=age/minf(0.7,interval*0.85)*1.5
	if operator_id=="specter" and unit.facing==1 and clip=="Attack":clip="Attack_Down"
	if operator_id=="cuora" and view_index==0:
		if unit.skill_index==1 and SkillRules.active_ticks(unit)>0:
			var elapsed := maxf(0.0,visual_tick-unit.cuora_started_tick)/30.0
			clip="Skill_Begin" if elapsed<0.4 else "Skill_Loop";pose_seconds=elapsed if elapsed<0.4 else fposmod(elapsed-0.4,0.8)
		elif unit.cuora_end_tick>=0:
			var elapsed := (visual_tick-unit.cuora_end_tick)/30.0
			if elapsed>=0.0 and elapsed<14.0/30.0:clip="Skill_End";pose_seconds=elapsed


func _prepare_launch_operators(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if operator_id=="blue_poison" and view_index==1 and clip=="Idle":pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/30.0,1.0)
	if unit.stun_ticks_left>0 or unit.displacement_ticks_left>0:return
	var active := SkillRules.active_ticks(unit)!=0
	if operator_id=="liskarm" and unit.skill_index==1 and active and unit.last_attack_tick>=0 and age>=0.0 and age<minf(0.7,interval*0.85):clip="Skill_Down" if unit.facing==1 else "Skill";pose_seconds=age/minf(0.7,interval*0.85)*26.0/30.0
	if operator_id=="skyfire" and unit.skill_index==1 and active and clip=="Attack":clip="Skill";pose_seconds=age/minf(0.7,interval*0.85)*2.0
	if operator_id=="amiya" and active and unit.skill_index>0 and unit.last_attack_tick>=0 and age>=0.0 and age<minf(0.7,interval*0.85):
		var prefix := "Skill" if unit.skill_index==1 else "Skill_2"
		var begin := 1.0/6.0 if unit.skill_index==1 else 4.0/30.0
		var loop := 1.0 if unit.skill_index==1 else 0.4
		var time := age/minf(0.7,interval*0.85)*(begin*2.0+loop)
		if time<begin:clip=prefix+"_Begin";pose_seconds=time
		elif time<begin+loop:clip=prefix;pose_seconds=time-begin
		else:clip=prefix+"_End";pose_seconds=time-begin-loop
	if operator_id in ["istina","pramanix"] and view_index==0:
		var start := 11.0/30.0 if operator_id=="istina" else 10.0/30.0
		var loop := 40.0/30.0 if operator_id=="istina" else 0.8
		if active:
			var elapsed := maxf(0.0,visual_tick-unit.launch_started_tick)/30.0
			clip="Skill_Start" if elapsed<start else "Skill_Loop";pose_seconds=elapsed if elapsed<start else fposmod(elapsed-start,loop)
		elif unit.launch_end_tick>=0:
			var elapsed := (visual_tick-unit.launch_end_tick)/30.0
			if elapsed>=0.0 and elapsed<11.0/30.0:clip="Skill_End";pose_seconds=elapsed


func _prepare_next_eight(unit: UnitState, visual_tick: float, interval: float, age: float) -> void:
	if clip=="Idle" and operator_id in ["silence","cliffheart"] and view_index==1:
		pose_seconds=fposmod(maxf(0.0,visual_tick-unit.deployed_tick)/CONFIG.TICK_RATE,1.0)
	if operator_id=="myrtle" and unit.skill_ticks_left>0:
		var elapsed := unit.skill_elapsed_ticks/float(CONFIG.TICK_RATE)
		if elapsed<0.6:clip="Skill_Begin";pose_seconds=elapsed
		else:clip="Skill_Loop";pose_seconds=fposmod(elapsed-0.6,10.0/3.0)
	if operator_id=="nearl" and unit.attack_started_tick<0 and view_index==0 and unit.last_attack_is_heal and unit.last_attack_tick>=0:
		var heal_age := (visual_tick-unit.last_attack_tick)/CONFIG.TICK_RATE
		if heal_age>=0.0 and heal_age<7.0/6.0:clip="Skill";pose_seconds=heal_age
	if operator_id=="cliffheart" and unit.pusher_strike_tick>=0:
		var hook_age := (visual_tick-(unit.attack_started_tick if unit.attack_action_clip=="Skill_Start" and unit.attack_started_tick>=0 else unit.pusher_strike_tick))/CONFIG.TICK_RATE
		if hook_age>=0.0 and hook_age<1.4:clip="Skill_Start";pose_seconds=hook_age
		elif unit.skill_ticks_left>24:clip="Skill_Loop";pose_seconds=fposmod(hook_age-1.4,0.6)
		elif hook_age>=1.4 and hook_age<2.2 and unit.skill_ticks_left==0:clip="Skill_End";pose_seconds=hook_age-1.4
		elif unit.skill_ticks_left>0:clip="Skill_End";pose_seconds=0.8-unit.skill_ticks_left/float(CONFIG.TICK_RATE)

	if operator_id=="myrtle":
		var active := unit.skill_ticks_left>0
		if _next_skill_was_active and not active:_next_skill_end_at=visual_tick
		_next_skill_was_active=active
		var end_age := (visual_tick-_next_skill_end_at)/CONFIG.TICK_RATE
		var duration := 7.0/30.0
		if _next_skill_end_at>=0.0 and end_age>=0.0 and end_age<duration:
			clip="Skill_End"
			pose_seconds=end_age


# These per-model action families and their durations come from the pinned native assets.
# Presentation reads skill counters and elapsed ticks; it never drives simulation.
func _prepare_six_star(unit: UnitState,visual_tick: float,interval: float,age: float) -> void:
	var active := SkillRules.active_ticks(unit)!=0
	var config: Dictionary=_entry["skill_actions_back" if view_index==1 else "skill_actions"][unit.skill_index]
	var durations: Dictionary=_entry["animation_seconds"]["back" if view_index==1 else "front"]
	if _sixstar_activation_count!=unit.skill_activation_count:
		_sixstar_activation_count=unit.skill_activation_count
		_sixstar_cast_tick=visual_tick-unit.skill_elapsed_ticks if active else float(unit.last_attack_tick)
	if _sixstar_was_active and not active:_sixstar_end_tick=visual_tick
	_sixstar_was_active=active
	var elapsed := maxf(0.0,visual_tick-_sixstar_cast_tick)/CONFIG.TICK_RATE
	if active:
		if config.has("loop"):
			clip=config["loop"];pose_seconds=fposmod(elapsed,float(durations[clip]))
		elif config.has("idle"):
			clip=config["idle"];pose_seconds=fposmod(elapsed,float(durations[clip]))
		if config.has("attack") and unit.last_attack_tick>=0 and age>=0.0:
			var selected: String=config["down"] if unit.facing==1 and config.has("down") else config["attack"]
			var duration := float(durations[selected]);var window := minf(duration,interval*0.85)
			if age<window:clip=selected;pose_seconds=age*duration/window
		if config.has("begin") and elapsed<float(durations[config["begin"]]):clip=config["begin"];pose_seconds=elapsed
	elif config.has("end") and _sixstar_end_tick>=0.0:
		var end_age := (visual_tick-_sixstar_end_tick)/CONFIG.TICK_RATE
		if end_age<float(durations[config["end"]]):clip=config["end"];pose_seconds=end_age

	var cast_clip: String=config.get("cast","")
	if unit.facing==1 and config.has("cast_down"):cast_clip=config["cast_down"]
	if unit.facing==3 and config.has("cast_up"):cast_clip=config["cast_up"]
	if not cast_clip.is_empty() and _sixstar_cast_tick>=0 and elapsed<float(durations[cast_clip]):clip=cast_clip;pose_seconds=elapsed
	if config.has("cast_sequence") and _sixstar_cast_tick>=0:
		var sequence_time := elapsed
		for action: String in config["cast_sequence"]:
			var duration := float(durations[action])
			if sequence_time<duration:clip=action;pose_seconds=sequence_time;break
			sequence_time-=duration
	if config.has("bomb"):
		var bomb_age := (visual_tick-unit.jessica_bomb_tick)/CONFIG.TICK_RATE
		var action: String=config["bomb_down"] if unit.facing==1 and config.has("bomb_down") else config["bomb"]
		if unit.jessica_bomb_tick>=0 and bomb_age>=0.0 and bomb_age<float(durations[action]):clip=action;pose_seconds=bomb_age

	if operator_id=="vigil_wolf":clip="Idle_1" if clip=="Idle" else clip
