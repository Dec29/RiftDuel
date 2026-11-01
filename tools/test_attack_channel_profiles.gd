extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var cases:=0
 for facing in 4:
  for spec in [["istina",1,"Skill_Loop" if facing!=3 else "Attack"],["pramanix",0,"Skill_Loop" if facing!=3 else "Attack"],["mostima",2,"Skill_2_Loop"],["lumen",0,"Skill_1"],["lumen",2,"Skill_3_Loop"],["archetto",0,"Skill_1"],["blemishine",0,"Skill_1"]]:
   var unit:=UnitState.new(0,0,spec[0],Vector2i.ZERO,1000,0,0,facing,spec[1])
   var profile:=AttackActionData.profile(unit,true)
   if profile.clip!=spec[2]:push_error("Authored skill profile mismatch "+str(spec)+" got"+profile.clip);quit(1);return
   cases+=1
  var white:=UnitState.new(0,0,"ptilopsis",Vector2i.ZERO,1000,0,0,facing,1);white.skill_ticks_left=1000;white.ptilopsis_skill_tick=0;white.deployed_tick=-300
  var model:=OperatorSpineVisual.new()
  if not model.initialize("ptilopsis") or not model.prepare(white,100,30) or model.clip!="Skill_Loop":push_error("Ptilopsis keeps authored maintained healing loop");quit(1);return
  white.frozen_ticks_left=10
  if not model.prepare(white,101,30) or model.clip!="Idle":push_error("Ptilopsis control interrupts visible channel");quit(1);return
  cases+=1
 print("ATTACK_CHANNEL_PROFILES_OK cases=",cases," verified authored attack families and maintained healing loop")
 quit(0)
