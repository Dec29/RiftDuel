class_name AttackActionData
extends RefCounted
const CATALOG=preload("res://data/attack_animation_catalog.gd")

const SURTR_TWILIGHT_BEGIN_TICKS := 18
const SURTR_TWILIGHT_IDLE_FRAMES := 80
# Source OnAttack evidence: tools/audit_attack_animation_events.gd (300Hz).
# Frames are authored at 30fps; no native callback is used during simulation.
static func profile(unit: UnitState, active: bool, healing: bool=false) -> Dictionary:
	match unit.operator_id:
		"surtr":
			if active and unit.skill_index==2:return {"clip":"Skill_3_Loop","frames":40,"release_frame":12}
			if active and unit.skill_index==1:return {"clip":"Skill_2_Down" if unit.facing==1 else "Skill_2","frames":40,"release_frame":13}
			return {"clip":"Attack","frames":39,"release_frame":12}
		"exusiai":return {"clip":"Attack","frames":30,"release_frame":9}
		"skadi":return {"clip":"Attack","frames":45,"release_frame":26}
		"jessica":return {"clip":"Attack","frames":30,"release_frame":13}
	return catalog_profile(unit,active,healing)

static func catalog_profile(unit: UnitState, active: bool, healing: bool=false) -> Dictionary:
	var entry: Dictionary=CATALOG.MAPPING[unit.operator_id]
	var side:=1 if unit.facing==3 else 0
	if active and unit.skill_index in entry.get("front_only_skills",[]):side=0
	var clip: String=entry.get("attack_clip","Attack")
	if unit.facing==1 and entry.has("down_clip"):clip=entry.down_clip
	if active and entry.has("skill_actions"):
		var actions: Dictionary=entry["skill_actions_back" if side==1 and entry.has("skill_actions_back") else "skill_actions"][unit.skill_index]
		if actions.has("attack"):clip=actions.down if unit.facing==1 and actions.has("down") else actions.attack
		elif active and actions.has("cast") and unit.operator_id in ["archetto","blemishine"] and unit.skill_index==0:
			var cast_clip: String=actions.cast_down if unit.facing==1 and actions.has("cast_down") else actions.cast
			if CATALOG.EVENTS[unit.operator_id].has(cast_clip) and CATALOG.EVENTS[unit.operator_id][cast_clip].has(str(side)):clip=cast_clip
	var prefix_frames:=0
	if entry.has("chain_seconds") and clip==entry.attack_clip:
		prefix_frames=roundi(float(str(entry.chain_seconds).split(",")[0])*30)
	if unit.operator_id=="texas":prefix_frames=15
	if unit.operator_id=="specter" and unit.facing==1:clip="Attack_Down"
	if active:
		match unit.operator_id:
			"flametail":
				if unit.dodge_attack_ready:clip="Skill_1"
				elif unit.skill_index==2:clip="Skill_2_Attack_2" if unit.facing==1 else "Skill_2_Loop"
			"mudrock":
				if unit.skill_index==2:clip="Skill_2_Attack"
			"mountain":clip=["Skill","Skill_2_Loop","Skill_3_Loop"][unit.skill_index]
			"mizuki":
				if unit.skill_index==0:clip="Skill_1"
				elif unit.skill_index==2:clip="Skill_2_Loop"
			"hellagur":clip=["Skill","Skill_2","Skill_3_Loop"][unit.skill_index]
	if active:
		match unit.operator_id:
			"liskarm":
				if unit.skill_index==1:clip="Skill_Down" if unit.facing==1 else "Skill";prefix_frames=0
			"skyfire":
				if unit.skill_index==1:clip="Skill"
			"amiya":
				if unit.skill_index>0:clip="Skill" if unit.skill_index==1 else "Skill_2";prefix_frames=5 if unit.skill_index==1 else 4
	if active:
		match unit.operator_id:
			"silverash":
				if unit.skill_index==2:clip="Skill"
			"bagpipe":
				if unit.skill_index==1:clip="Skill_Down" if unit.facing==1 else "Skill"
				elif unit.skill_index==2:clip="Skill_2_Loop_Down" if unit.facing==1 else "Skill_2_Loop"
			"angelina":
				if unit.skill_index>0:clip="Skill1_Loop" if unit.skill_index==1 else "Skill2_Loop"
			"ceobe":clip=["Skill_1","Skill_2_Loop","Skill_3"][unit.skill_index]
			"platinum":
				if unit.skill_index==1:clip="Skill"
			"schwarz":
				if unit.skill_index==2:clip="Skill_Loop"
			"suzuran":
				if unit.skill_index==1:clip="Skill2"
			"phantom":
				if unit.skill_index==1:clip="Attack_2"
	if active:
		match unit.operator_id:
			"cliffheart":clip="Skill_Start";prefix_frames=0
			"gladiia":
				if unit.skill_index==0:clip="Skill_1_Begin";prefix_frames=0
			"chen":
				if unit.skill_index==0:clip="Skill";prefix_frames=0
			"gnosis":
				if unit.skill_index==0:clip="Skill";prefix_frames=0
			"weedy":clip=["Skill","Skill_2_Attack_Down" if unit.facing==1 else "Skill_2_Attack","Skill_3_Down" if unit.facing==1 else "Skill_3"][unit.skill_index]
	if unit.operator_id=="mon3tr" and unit.mon3tr_mode in [2,3]:clip="Skill" if unit.mon3tr_mode==2 else "Skill_2"
	if unit.operator_id=="ling_soul3" and unit.ling_advanced:clip="Attack_02"
	if unit.operator_id=="flowing_shape" and not unit.flow_copy_id.is_empty():clip="A_Attack" if unit.flow_melee else "B_Attack"
	if unit.operator_id=="saria" and healing:clip="Attack_2"
	if unit.operator_id=="nearl" and healing and side==0:clip="Skill"
	if active and unit.operator_id=="nian" and unit.skill_index==0:clip="Skill_2_Loop"
	if active and unit.operator_id=="phantom" and unit.skill_index==1:clip="Attack_2"
	if active and unit.operator_id=="saga" and unit.skill_index==2:clip="Skill_2_Loop"
	if active and unit.operator_id=="typhon":
		if unit.skill_index==1:
			var prefix:="Skill_Down_2_" if unit.facing==1 and side==0 else "Skill_2_"
			clip=prefix+("2_Loop" if unit.skill_repeat_activation_count>=2 else "1_Loop")
		elif unit.skill_index==2:clip="Skill_3_Loop"
	if active and unit.operator_id in ["istina","pramanix"] and side==0:clip="Skill_Loop"
	if active and unit.operator_id=="mostima" and unit.skill_index==2:clip="Skill_2_Loop"
	if active and unit.operator_id=="lumen":
		if unit.skill_index==0:clip="Skill_1"
		elif unit.skill_index==2:clip="Skill_3_Loop"
	if active and unit.operator_id=="lappland" and unit.skill_elapsed_ticks<40 and unit.skill_started_tick>unit.attack_started_tick:clip="Skill"
	var source: Dictionary=CATALOG.EVENTS[unit.operator_id]
	if not source.has(clip) and clip.ends_with("_Loop"):
		var prefix:=clip.trim_suffix("_Loop")
		var first:=prefix+"_Begin"
		assert(source.has(first),"Missing native composite release: "+unit.operator_id+"/"+clip)
		var sequence:=PackedStringArray([first,clip]);var end:=prefix+"_End"
		if CATALOG.FRAMES[unit.operator_id].has(end):sequence.append(end)
		var total:=0
		for part in sequence:total+=int(CATALOG.FRAMES[unit.operator_id][part][str(side)])
		return {"clip":"|".join(sequence),"frames":total,"release_frame":int(source[first][str(side)][1][0]),"clip_offset":0,"side":side}
	assert(source.has(clip),"Missing native attack event: "+unit.operator_id+"/"+clip)
	if not source[clip].has(str(side)):
		push_error("Missing native attack side "+unit.operator_id+"/"+clip+"/"+str(side));return {}
	var frames: Array=source[clip][str(side)]
	var parts:=chain_parts(unit.operator_id,clip,side)
	var release_events:=PackedInt32Array()
	for event_frame in frames[1]:release_events.append(int(event_frame)+parts.lead)
	return {"clip":clip,"frames":int(frames[0])+parts.lead+parts.tail,"release_frame":int(frames[1][0])+parts.lead,"clip_offset":parts.lead,"side":side,"events":release_events}

static func chain_parts(id: String, clip: String, side: int) -> Dictionary:
	var entry: Dictionary=CATALOG.MAPPING[id]
	var lead:=0;var tail:=0;var begin_clip:="";var end_clip:=""
	var frames: Dictionary=CATALOG.FRAMES[id]
	if entry.has("chain_seconds") and clip==entry.attack_clip:
		var values:=str(entry.chain_seconds).split(",")
		lead=roundi(float(values[0])*30);tail=roundi(float(values[2])*30)
		begin_clip="Attack_Begin";end_clip="Attack_End"
	elif id=="texas":lead=15;tail=15;begin_clip="Attack_Start";end_clip="Attack_End"
	elif id=="amiya" and clip in ["Skill","Skill_2"]:
		begin_clip=clip+"_Begin";end_clip=clip+"_End"
		lead=int(frames[begin_clip][str(side)]);tail=int(frames[end_clip][str(side)])
	elif entry.has("chain_seconds") and clip.ends_with("_Loop"):
		var prefix:=clip.trim_suffix("_Loop")
		begin_clip=prefix+"_Begin";end_clip=prefix+"_End"
		if frames.has(begin_clip) and frames[begin_clip].has(str(side)):lead=int(frames[begin_clip][str(side)])
		if frames.has(end_clip) and frames[end_clip].has(str(side)):tail=int(frames[end_clip][str(side)])
	return {"lead":lead,"tail":tail,"begin":begin_clip,"end":end_clip}

static func skill_begin_frames(unit: UnitState) -> int:
	if SkillRules.active_ticks(unit)==0:return 0
	if unit.operator_id=="weedy" and unit.skill_index==1:return 7
	if unit.operator_id in ["istina","pramanix"] and unit.facing!=3:return 11 if unit.operator_id=="istina" else 10
	if unit.operator_id=="mostima" and unit.skill_index==2:return 20
	if unit.operator_id=="lumen" and unit.skill_index==2:return 10
	var entry: Dictionary=CATALOG.MAPPING[unit.operator_id]
	if not entry.has("skill_actions"):return 0
	var side:=1 if unit.facing==3 else 0
	if unit.skill_index in entry.get("front_only_skills",[]):side=0
	var actions: Dictionary=entry["skill_actions_back" if side==1 and entry.has("skill_actions_back") else "skill_actions"][unit.skill_index]
	if not actions.has("begin"):return 0
	# Begin clips that carry their own release belong in the attack sequence, not in a second cast delay.
	if CATALOG.EVENTS[unit.operator_id].has(actions.begin):return 0
	return int(CATALOG.FRAMES[unit.operator_id][actions.begin][str(side)])
