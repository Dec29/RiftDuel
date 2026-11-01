extends SceneTree
func _initialize() -> void:
	var script := load("res://view/battle_audio.gd") as GDScript
	if script==null or not script.can_instantiate():quit(1);return
	var audio: Node=script.new()
	var state := MatchState.new(188,{"hellagur":load("res://resources/operators/hellagur.tres")})
	var unit := UnitState.new(0,0,"hellagur",Vector2i(12,5),3825,0,36,0,0)
	unit.last_attack_tick=0;state.units=[unit];state.next_unit_id=1
	var before := state.state_hash()
	audio._attack(unit,"hellagur",false,null)
	if audio._pending_sounds.size()!=2 or audio._pending_sounds[0].cue!="p_atk_falchion_n":push_error("Normal original sword sound");audio.free();quit(1);return
	audio._pending_sounds.clear()
	audio._attack(unit,"hellagur",true,null)
	if audio._pending_sounds.size()!=2 or audio._pending_sounds[0].cue!="p_atk_falchion_h":push_error("Explicit S1 event mapping");audio.free();quit(1);return
	if state.state_hash()!=before:push_error("Audio modified sim");audio.free();quit(1);return
	audio._pending_sounds.clear();unit.skill_index=1;unit.skill_ticks_left=390;before=state.state_hash()
	audio._attack(unit,"hellagur",true,null)
	if not audio._pending_sounds.is_empty() or state.state_hash()!=before:push_error("Unverified S2 variant must stay explicitly unmapped");audio.free();quit(1);return
	audio.free();print("Hellagur mapped cues/explicit pending variants/readonly OK");quit(0)
