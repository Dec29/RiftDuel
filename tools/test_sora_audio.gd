extends SceneTree
class Recorder extends BattleAudio:
 var calls: Array[String]=[]
 func _play_sound(cue: String,_ui: bool) -> void:calls.append(cue)
func _initialize() -> void:
 var recorder := Recorder.new()
 var state := MatchState.new(101,{"sora":load("res://resources/operators/sora.tres")})
 var before := state.state_hash()
 recorder._cue("sora",0)
 if recorder.calls!=["p_skill_sleepsong"]:push_error("Original sleep-song cue");recorder.free();quit(1);return
 recorder.calls.clear();recorder._cue("sora",1)
 if recorder.calls!=["p_skill_battlesong","b_char_atkboost"] or BattleAudio.ATTACK_CUES.has("sora") or state.state_hash()!=before:push_error("Original battle-song cues, no invented attack, readonly");recorder.free();quit(1);return
 recorder.free();print("Sora two explicit original song cues and readonly OK");quit(0)
