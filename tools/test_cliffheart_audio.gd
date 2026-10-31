extends SceneTree
func _initialize() -> void:
 var audio := BattleAudio.new()
 var state := MatchState.new(173,{"cliffheart":load("res://resources/operators/cliffheart.tres")})
 var unit := UnitState.new(0,0,"cliffheart",Vector2i(14,5),1970,0,54,0,0)
 state.units=[unit];state.next_unit_id=1;unit.last_attack_tick=4;unit.skill_ticks_left=100;unit.pusher_strike_tick=0
 var before := state.state_hash();audio._attack(unit,"cliffheart",false,null)
 if audio._pending_sounds.size()!=1 or audio._pending_sounds[0].cue!="p_atk_chain_n":push_error("Ordinary chain cue during SP channel");audio.free();quit(1);return
 for index in [0,1]:
  unit.skill_index=index;unit.pusher_strike_tick=unit.last_attack_tick;audio._pending_sounds.clear();before=state.state_hash();audio._attack(unit,"cliffheart",true,null)
  if audio._pending_sounds.size()!=1 or audio._pending_sounds[0].cue!="p_atk_cowboy_h" or state.state_hash()!=before:push_error("Explicit hook prefab cue and readonly");audio.free();quit(1);return
 audio.free();print("Cliffheart normal/channel/hook cues and readonly OK");quit(0)
