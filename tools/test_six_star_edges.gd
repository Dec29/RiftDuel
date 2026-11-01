extends SceneTree

var failures := 0
var data := {}


func _initialize() -> void:
	for id in ["vigil","ines","lee","gnosis","w","texas_alter","reed_alter","swire_alter","bagpipe","lumen"]:data[id]=load("res://resources/operators/%s.tres"%id)
	var dummy := (data.bagpipe as OperatorData).duplicate(true) as OperatorData
	dummy.operator_id="target";dummy.max_health=100000;dummy.defense=0;dummy.magic_resist=0;dummy.talent_1.effect_type="none";dummy.talent_1.effect_params={};dummy.talent_2.effect_type="none";dummy.talent_2.effect_params={};data.target=dummy
	check(MatchState.CONFIG.UNIT_DAMAGE_PERCENT_BY_PROFESSION.medic==30 and Combat.calculate_damage(1000,0,0,"magical",0,RNG.new(1),"medic")==300 and Combat.calculate_healing(1000)==500,"Confirmed medic30% output and unchanged50% healing")
	var recall := fresh("ines",2);recall.sides[0].cost=99
	recall.step([InputCommand.new(0,0,"ines",-1,Vector2i(13,5),-1,2)],[])
	var near := add(recall,1,"target",Vector2i(14,5));var far := add(recall,1,"target",Vector2i(7,3))
	recall.step([InputCommand.new(recall.tick,0,"ines",-1,Vector2i(13,5),-1,2)],[])
	check(near.hp<100000 and far.hp==100000 and recall.units[-1].cell==Vector2i(13,5),"Zero-length sentinel recall is a local point, never a map-wide attack")
	var stolen := fresh("ines",1);var spy := add(stolen,0,"ines",Vector2i(12,5));spy.skill_ticks_left=100;var slowed := add(stolen,1,"target",Vector2i(13,5));AuraRules.refresh(stolen);spy.attack_ticks_left=30;slowed.attack_ticks_left=43
	InesRules.land(stolen,spy,data.ines,slowed,1,"physical")
	check(spy.attack_ticks_left==28 and slowed.attack_ticks_left==46,"Ines immediate AS steal rescales existing attack clocks, actual %d/%d"%[spy.attack_ticks_left,slowed.attack_ticks_left])
	var controls := fresh("lee",1);var lee := add(controls,0,"lee",Vector2i(12,5));var gnosis := add(controls,1,"gnosis",Vector2i(13,5))
	lee.lee_control_charm=true;GnosisRules.cold(controls,gnosis,lee,120)
	check(lee.cold_ticks_left==120 and lee.lee_control_charm,"Cold alone does not consume charm")
	GnosisRules.cold(controls,gnosis,lee,120)
	check(lee.frozen_ticks_left==0 and lee.cold_ticks_left==120 and not lee.lee_control_charm and gnosis.stun_ticks_left==90,"Second cold intercepted before freeze, old cold retained, actual source reflected")
	gnosis.stun_ticks_left=0;lee.lee_control_charm=true;SwordRules.stun(controls,lee,60,gnosis)
	check(lee.stun_ticks_left==0 and gnosis.stun_ticks_left==90,"Existing stun wrapper carries actual source into reflection")
	var frozen := fresh("w",0);var artillery := add(frozen,0,"w",Vector2i(12,5));var target := add(frozen,1,"target",Vector2i(13,5));artillery.frozen_ticks_left=30;artillery.attack_ticks_left=0
	frozen.step([],[])
	check(artillery.last_attack_tick<0 and target.hp==100000,"W's direct basic-attack gate respects frozen")
	var reed := fresh("reed_alter",2);var source := add(reed,0,"reed_alter",Vector2i(13,4));target=add(reed,1,"target",Vector2i(12,4));source.skill_ticks_left=60;source.frozen_ticks_left=30
	target.reed_cinder_source_id=source.unit_id;target.reed_cinder_until_tick=-1;target.reed_lifeseed_mark=true;target.reed_cinder_magic_fragile_percent=30;target.reed_dot_next_tick=0
	reed.step([],[])
	check(target.hp<100000 and source.frozen_ticks_left==29 and source.skill_ticks_left==59,"Already released ReedDOT and skill timer continue under frozen")
	var rescued := fresh("lee",1);source=add(rescued,0,"lee",Vector2i(12,5));source.skill_index=1;source.sp=7
	var merchant := add(rescued,1,"swire_alter",Vector2i(13,5));rescued.sides[1].cost=99;LeeRules.cast(rescued,source,data.lee)
	var marked := source.lee_mark_target_id;rescued._apply_damage(merchant,data.swire_alter,100000,"true",source)
	check(merchant.hp>0 and source.lee_mark_target_id==marked and source.lee_mark_stacks==1,"Existing fatal revival completes before Lee mark death detection")
	data.vigil_wolf=MatchState.VIGIL_WOLF_DATA
	var killer_data := dummy.duplicate(true) as OperatorData;killer_data.operator_id="killer";killer_data.attack=1000;killer_data.block_count=0;killer_data.branch_trait.effect_type="magical_attack";killer_data.branch_trait.effect_params={};killer_data.damage_type="magical";data.killer=killer_data
	var lifecycle := fresh("vigil",0);var owner := add(lifecycle,0,"vigil",Vector2i(13,2));owner.hp=1
	var wolf := add(lifecycle,0,"vigil_wolf",Vector2i(12,3));wolf.vigil_owner_id=owner.unit_id;wolf.vigil_wolf_layers=2;wolf.vigil_regrow_tick=750
	var killer := add(lifecycle,1,"killer",Vector2i(13,3));killer.facing=3;killer.attack_ticks_left=0
	var follower := add(lifecycle,0,"bagpipe",Vector2i(14,3));follower.facing=2;follower.attack_ticks_left=0
	var killer_hp := killer.hp;lifecycle.step([],[])
	check(owner.hp<=0 and wolf not in lifecycle.units and follower.last_attack_tick==0 and killer.hp<killer_hp,"Owner death removes summon without skipping a later unit's same-tick attack")
	data.pozyomka_typewriter=MatchState.TYPEWRITER_DATA;data.silence_alter_drone=MatchState.SILENCE_DRONE_DATA
	var devices := fresh("lee",0);var holder := add(devices,0,"lee",Vector2i(12,5));holder.lee_control_charm=true
	var caster := add(devices,1,"gnosis",Vector2i(13,5));StatusRules.add_control(devices,holder,"stun",30,caster)
	check(holder.stun_ticks_left==0 and caster.stun_ticks_left==90,"Direct control reflects actual caster")
	holder.lee_control_charm=true;caster.stun_ticks_left=0
	var item := TacticalItemEffect.new(devices.CONFIG.TACTICAL_ITEM_STUN,1,Vector2i(12,4),0,0);item.effect_tick=0;devices.tactical_item_effects.append(item)
	for id in ["pozyomka_typewriter","silence_alter_drone"]:
		var device := add(devices,0,id,Vector2i(11,4));StatusRules.apply_silence(devices,device,30);StatusRules.add_control(devices,device,"stun",30,caster)
		check(device.silence_ticks_left==0 and device.stun_ticks_left==0 and SkillRules.block_count_value(device,data[id])==0 and DisplacementRules.apply_unit(devices,caster,device,Vector2i.LEFT,8)==0,"Untargetable device silence/control/block/displacement "+id)
	TacticalRules.advance_effects(devices)
	check(holder.stun_ticks_left==0 and not holder.lee_control_charm and caster.stun_ticks_left==0,"Unattributed item consumes charm without guessing a caster")
	for device in devices.units:
		if device.operator_id in ["pozyomka_typewriter","silence_alter_drone"]:check(device.stun_ticks_left==0,"Device ignores tactical stun "+device.operator_id)
	wolf.frozen_ticks_left=30
	check(SkillRules.block_count_value(wolf,data.vigil_wolf)==0,"Frozen wolf blocks zero despite wolf layers")
	var hashed := fresh("lee",0);source=add(hashed,0,"lee",Vector2i(12,5))
	for field in ["cold_ticks_left","frozen_ticks_left","silence_grave_until_tick","silence_drone_stock","silence_drone_owner_id","silence_regen_accum","typewriter_owner_id","typewriter_defense_remaining_percent","typewriter_defense_until_tick","lee_mark_target_id","lee_mark_until_tick","lee_mark_stacks","reed_cinder_source_id","reed_cinder_until_tick","reed_cinder_attack_reduce_percent","reed_cinder_magic_fragile_percent","reed_dot_next_tick","reed_explosion_immunity_until_tick","reed_fireball_started_tick","eyja_mist_stacks","eyja_mist_until_tick","eyja_mist_next_tick","eyja_mist_heal","eyja_mist_source_id","eyja_elemental_barrier","eyja_elemental_barrier_until_tick"]:
		var before := hashed.state_hash();source.set(field,source.get(field)+1);check(before!=hashed.state_hash(),"New shared state hash sensitivity "+field)
	for field in ["silence_grave_used","lee_marked","lee_control_charm","reed_lifeseed_mark","reed_explosion_queued"]:
		var before := hashed.state_hash();source.set(field,not source.get(field));check(before!=hashed.state_hash(),"New bool hash sensitivity "+field)
	for field in ["reed_fireball_carriers","reed_fireball_ready_ticks"]:
		var before := hashed.state_hash();var values: PackedInt32Array=source.get(field);values.append(17);source.set(field,values);check(before!=hashed.state_hash(),"New array hash sensitivity "+field)
	print("SIX_STAR_EDGES_OK medic coefficient, zero-length recall, cold/charm/caster, W freeze, independentDOT, lethal rescue order, all shared new scalar/array hashes; failures=",failures)
	quit(0 if failures==0 else 1)


func fresh(id: String,index: int) -> MatchState:
	var state := MatchState.new(719,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[[id],["target"]],[[index],[0]])
	state.ball.cell=Vector2i(5,10);return state


func add(state: MatchState,side: int,id: String,cell: Vector2i) -> UnitState:
	var op: OperatorData=data[id];var unit := UnitState.new(state.next_unit_id,side,id,cell,op.max_health,0,100000,0,state.squad_skills[0][0] if side==0 else 0)
	state.next_unit_id+=1;state.units.append(unit);return unit


func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
