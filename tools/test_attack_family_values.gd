extends "res://tools/test_attack_families.gd"
func run() -> void:
 var db=root.get_node("OperatorDB")
 for id in db.all_ids():content[id]=db.get_data(id)
 titi_value();cannon_value();horn_value();vigil_value();gnosis_value();multi_targets();friendly_cannon()
 print("ATTACK_FAMILY_VALUES_OK cases=",cases," failures=",failures,"; existing damage coefficients, landed effects and actual release/flight")
 quit(0 if failures==0 else 1)
func plain_target(state: MatchState, target: UnitState) -> void:
 var dummy: OperatorData=content.bagpipe.duplicate(true)
 dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={}
 state._operator_data.target=dummy;target.operator_id="target";target.hp=100000
func settle(state: MatchState, source: UnitState) -> void:
 var previous:=source.last_attack_tick;var deadline:=state.tick+240
 while state.tick<deadline:
  state.step([],[])
  if source.last_attack_tick!=previous and source.attack_intent==null and state.attack_projectiles.is_empty():return
 check(false,"Action did not finish "+source.operator_id)
func titi_value() -> void:
 var f:=fixture("titi");var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
 plain_target(s,t);u.hp=1000;settle(s,u)
 check(t.hp==99811,"Titi base164 plus nonmoving25 damage preserved: "+str(t.hp))
 check(u.hp==1047,"Titi damage-to-heal actual47 preserved: "+str(u.hp));cases+=1
func cannon_value() -> void:
 var f:=fixture("stainless_cannon");var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
 plain_target(s,t);u.hp=6000;u.sp=5
 var extra:=UnitState.new(3,1,"target",t.cell+Vector2i.UP,100000,0,99999);s.units.append(extra);s.next_unit_id=4
 settle(s,u)
 check(u.hp==5850 and u.sp==0,"Cannon exactly5SP and2.5percent life at release")
 check(t.hp==99644 and extra.hp==99822,"Cannon1779 primary/890 splash retain supporter20percent: %d/%d"%[t.hp,extra.hp]);cases+=1
func horn_value() -> void:
 var f:=fixture("horn");var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
 plain_target(s,t);u.cell=Vector2i(13,5);u.facing=0;u.skill_index=1;u.hp=1000;u.sp=25;t.cell=Vector2i(16,5)
 var extra:=UnitState.new(2,1,"target",Vector2i(15,5),100000,0,99999);s.units.append(extra);s.next_unit_id=3
 s.step([InputCommand.new(0,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[]);settle(s,u)
 check(u.skill_ammo_left==9 and t.hp==99542 and extra.hp==99542,"Horn first physical round/splash preserved after real windup and flight")
 u.skill_ammo_left=5;var hp:=u.hp;s.step([InputCommand.new(s.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,1)],[]);settle(s,u)
 check(u.hp==hp-hp*60/100 and u.skill_ticks_left==0 and u.skill_ammo_left==0,"Horn dump spends currentHP60percent and closes")
 check(t.hp==96677 and extra.hp==96677,"Horn dump five physical/magic packets preserve2865 damage: %d/%d"%[t.hp,extra.hp]);cases+=1
func vigil_value() -> void:
 var f:=fixture("vigil");var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
 plain_target(s,t);u.skill_index=2;u.skill_ticks_left=1000
 var wolf:=UnitState.new(2,0,"vigil_wolf",t.cell+Vector2i.DOWN,3000,0,99999);wolf.vigil_owner_id=0;wolf.vigil_wolf_layers=2;s.units.append(wolf);s.next_unit_id=3
 var op: OperatorData=s._operator_data.vigil
 var power:=roundi(SkillRules.attack_value(u,op)*int(op.branch_trait.effect_params.blocked_attack_percent)/100.0)
 var magic:=roundi(SkillRules.attack_value(u,op)*int(op.skills[2].effect_params.magic_attack_percent)/100.0)
 var expected:=3*(Combat.calculate_damage(power,0,0,"physical",0,RNG.new(1),"vanguard")+Combat.calculate_damage(magic,0,0,"magical",0,RNG.new(1),"vanguard"))
 settle(s,u);check(t.hp==100000-expected,"Vigil three native rifle stages retain landed physical and blocked magical followup: %d expected%d"%[100000-t.hp,expected]);cases+=1
func gnosis_value() -> void:
 var f:=fixture("gnosis");var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
 plain_target(s,t);u.sp=4;settle(s,u)
 check(u.sp==0 and u.skill_ticks_left==0 and t.frozen_ticks_left>0,"Gnosis charged pair freezes at impacts and finishes skill");cases+=1
func friendly_cannon() -> void:
 for id in ["bagpipe","chen","dusk","chen_alter","goldenglow","horn","fiammetta","mostima","meteorite","w"]:
  var f:=fixture(id);var s: MatchState=f.state;var u: UnitState=f.source
  s.units.erase(f.target);u.cell=Vector2i(13,5);u.facing=0
  if id in ["horn","fiammetta","w"]:u.cell=Vector2i(11,5)
  if id=="dusk":u.cell=Vector2i(12,5)
  var owner:=UnitState.new(2,0,"stainless",Vector2i(18,9),3000,0,99999,0,2)
  var cannon:=UnitState.new(3,0,"stainless_cannon",Vector2i(14,5),6000,0,99999);cannon.stainless_owner_id=2
  s.units.append(owner);s.units.append(cannon);s.next_unit_id=4
  settle(s,u)
  var expected:=2 if id in ["chen","goldenglow"] else 1
  check(cannon.sp==expected,"Actual staged/projectile friendly cannon charge %s expected%d got%d"%[id,expected,cannon.sp]);cases+=1

func multi_targets() -> void:
 for spec in [["saga",2],["typhon",1]]:
  var id: String=spec[0];var f:=fixture(id);var s: MatchState=f.state;var u: UnitState=f.source;var t: UnitState=f.target
  plain_target(s,t);u.skill_index=spec[1];u.skill_ticks_left=1000;t.cell=u.cell+AttackRange.rotate_offset(Vector2i(1,0) if id=="saga" else Vector2i(2,0),u.facing)
  var extra:=UnitState.new(2,1,"target",u.cell+AttackRange.rotate_offset(Vector2i(2,0) if id=="saga" else Vector2i(2,1),u.facing),100000,0,99999);s.units.append(extra);s.next_unit_id=3
  settle(s,u)
  check(t.hp<100000 and extra.hp<100000,"Actual ordinary multi-target skill locks both recipients "+id+" hp%d/%d"%[t.hp,extra.hp]);cases+=1
