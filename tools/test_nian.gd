extends SceneTree
var failures := 0
var data := {"nian":load("res://resources/operators/nian.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.nian
	var enemy: OperatorData=data.bagpipe.duplicate(true);enemy.operator_id="enemy_fixture";enemy.max_health=100000;enemy.defense=0;enemy.magic_resist=0;enemy.talent_1.effect_type="none";enemy.talent_2.effect_type="none";data.enemy_fixture=enemy
	check(op.validation_error().is_empty() and op.attack==619 and op.defense==726 and op.skills.size()==3,"Raw E2 and M3 data")
	var shield := fixture(0);var owner := shield.units[0]
	check(owner.hp==4291 and owner.nian_shield_layers==3,"Squad16percent HP and fresh three-layer shield")
	for dtype in ["physical","magical","true"]:check(not shield._apply_damage(owner,op,100,dtype),"Each layer blocks one damage instance of any type")
	check(owner.hp==4291 and owner.nian_shield_layers==0,"Exactly3 damage instances blocked")
	shield._apply_damage(owner,op,100,"true");check(owner.hp==4191,"Fourth hit reachesHP")
	var magic := fixture(0);add_enemy(magic);magic.units[0].sp=30;magic.units[0].attack_ticks_left=0;magic.step([cast(magic,0)],[])
	check(magic.units[1].hp==99847 and SkillRules.damage_type(magic.units[0],op)=="magical" and SkillRules.defense_value(magic.units[0],op)==1234,"S1 magic153 and DEF70percent")
	var copper := fixture(1);add_enemy(copper);copper.units[0].sp=50;copper.units[0].attack_ticks_left=0;copper.step([cast(copper,1)],[])
	check(copper.units[1].hp==100000 and SkillRules.defense_value(copper.units[0],op)==1670 and SkillRules.block_count_value(copper.units[0],op)==4,"S2 stops attacks, DEF130percent block4")
	copper._apply_damage(copper.units[0],op,100,"physical",copper.units[1])
	check(copper.units[1].hp==99905 and copper.units[1].silence_ticks_left==150 and copper.units[0].nian_shield_layers==2,"S2 shielded hit reflects95 magical and silences attacker")
	var iron := fixture(2);iron.units.append(UnitState.new(1,0,"bagpipe",Vector2i(12,5),data.bagpipe.max_health,0,100000));iron.units[0].sp=85;iron.step([cast(iron,2)],[])
	check(SkillRules.attack_value(iron.units[0],op)==1362 and SkillRules.defense_value(iron.units[0],op)==726 and SkillRules.block_count_value(iron.units[0],op)==3 and not StatusRules.has_resistance(iron,iron.units[0]),"S3 self only ATK120percent")
	check(SkillRules.block_count_value(iron.units[1],data.bagpipe)==data.bagpipe.block_count+1 and StatusRules.has_resistance(iron,iron.units[1]) and AttackRange.effective_offsets(iron.units[0],op).size()==2,"S3 ally block/resistance; does not expand ordinary attack range")
	SwordRules.stun(iron,iron.units[1],120);check(iron.units[1].stun_ticks_left==60,"External resistance halves a newly applied stun once")
	iron._retreat_unit(iron.units[0]);iron.step([],[]);check(not StatusRules.has_resistance(iron,iron.units[0]),"Aura removed with source")
	var shining: OperatorData=load("res://resources/operators/shining.tres");data.shining=shining
	var stacked := fixture(2);stacked.units.append(UnitState.new(1,0,"bagpipe",Vector2i(12,5),data.bagpipe.max_health,0,100000));stacked.units[0].sp=85;stacked.step([cast(stacked,2)],[])
	stacked.units.append(UnitState.new(2,0,"shining",Vector2i(12,2),shining.max_health,0,100000,1,2));stacked.units[2].skill_ticks_left=100;AuraRules.refresh(stacked)
	check(SkillRules.defense_value(stacked.units[1],data.bagpipe)==roundi((data.bagpipe.defense+60)*2.8),"Nian80percent and real Shining100percent defense buffs add independently")
	var a := fixture(1);var b := fixture(1)
	for state in [a,b]:add_enemy(state);state.units[0].sp=50
	for tick in 120:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,1))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Shield/reflect ordered replay")
	var blaze: OperatorData=load("res://resources/operators/blaze.tres");data.blaze=blaze
	var resistance := fixture(0);resistance.units.append(UnitState.new(1,0,"blaze",Vector2i(12,5),blaze.max_health,0,100000))
	check(not StatusRules.has_resistance(resistance,resistance.units[1]),"Existing Blaze resistance waits for warmup")
	resistance.tick=450
	check(StatusRules.has_resistance(resistance,resistance.units[1]),"Existing Blaze resistance remains active at15seconds")
	resistance.units[1].silence_ticks_left=30
	check(not StatusRules.has_resistance(resistance,resistance.units[1]),"Silence suppresses own resistance without external aura")
	print("NIAN_CORE_OK" if failures==0 else "NIAN_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["nian"]);var skills := PackedInt32Array([index]);var state := MatchState.new(30,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state.step([InputCommand.new(0,0,"nian",-1,Vector2i(13,5),-1,2)],[]);state.units[0].attack_ticks_left=100000;return state
func add_enemy(state: MatchState) -> void:state.units.append(UnitState.new(1,1,"enemy_fixture",Vector2i(12,5),100000,0,100000))
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,1,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
