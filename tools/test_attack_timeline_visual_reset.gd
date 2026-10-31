extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for facing in 4:
		for mode in ["silenced_s3","frozen_s3","expired_s2"]:
			var model:=OperatorSpineVisual.new();assert(model.initialize("surtr"))
			var unit:=UnitState.new(0,0,"surtr",Vector2i(11,5),7916,0,0,facing,2)
			unit.skill_ticks_left=-2;unit.launch_started_tick=0
			unit.attack_started_tick=18;unit.attack_action_clip="Skill_3_Loop";unit.attack_action_source_frames=40;unit.attack_action_window_ticks=32
			if mode=="expired_s2":unit.skill_index=1;unit.skill_ticks_left=200;unit.attack_action_clip="Skill_2_Down" if facing==1 else "Skill_2"
			assert(model.prepare(unit,28.0,38))
			var tick:=60.0
			if mode=="silenced_s3":unit.silence_ticks_left=30
			elif mode=="frozen_s3":unit.frozen_ticks_left=30;unit.last_basic_interrupt_tick=28;tick=28.0
			else:unit.skill_ticks_left=0
			assert(model.prepare(unit,tick,38))
			var fresh:=OperatorSpineVisual.new();assert(fresh.initialize("surtr"));assert(fresh.prepare(unit,tick,38))
			var reused:=model.mesh.surface_get_arrays(0);var canonical:=fresh.mesh.surface_get_arrays(0)
			if reused!=canonical:failures+=1;push_error("Source attachment reset differs from fresh instance: "+mode)
			print("SURTR_NATIVE_RESET ",mode," facing=",facing," exact_parity=",reused==canonical," clip=",model.clip)
	print("ATTACK_NATIVE_RESET_OK failures=",failures)
	quit(0 if failures==0 else 1)
