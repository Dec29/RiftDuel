extends SceneTree
func _initialize() -> void:
	var script := load("res://view/battle_audio.gd") as GDScript
	if script==null or not script.can_instantiate():quit(1);return
	var audio: Node=script.new()
	var state := MatchState.new(219,{"meteorite":load("res://resources/operators/meteorite.tres")})
	var unit := UnitState.new(0,0,"meteorite",Vector2i(14,4),1505,0,84,0,0)
	unit.last_attack_tick=0;state.units=[unit];state.next_unit_id=1
	var before := state.state_hash();audio._attack(unit,"meteorite",false,null)
	if audio._pending_sounds.size()!=1 or audio._pending_sounds[0].cue!="p_atk_grenade_n":push_error("Normal original grenade cue");audio.free();quit(1);return
	for index in [0,1]:
		audio._pending_sounds.clear();unit.skill_index=index;before=state.state_hash();audio._attack(unit,"meteorite",true,null)
		if audio._pending_sounds.size()!=1 or audio._pending_sounds[0].cue!="p_atk_grenade_h" or state.state_hash()!=before:push_error("Explicit skill-prefab grenade cue/readonly");audio.free();quit(1);return
	audio.free();print("Meteorite explicit normal/skill-prefab cues and readonly OK");quit(0)
