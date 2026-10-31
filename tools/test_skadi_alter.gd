extends SceneTree
var failures := 0
var data := {"skadi_alter":load("res://resources/operators/skadi_alter.tres"),"bagpipe":load("res://resources/operators/bagpipe.tres")}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var op: OperatorData=data.skadi_alter
	check(op.validation_error().is_empty() and op.attack==368 and op.max_health==1603 and MatchState.SEABORN_DATA.validation_error().is_empty(),"Bard and sea creature raw data/3skills")
	var ally: OperatorData=data.bagpipe.duplicate(true);ally.operator_id="ally_fixture";ally.max_health=10000;ally.attack=500;ally.defense=100;ally.talent_1.effect_type="none";ally.talent_2.effect_type="none";data.ally_fixture=ally
	var abyssal: OperatorData=ally.duplicate(true);abyssal.operator_id="abyssal_fixture";abyssal.group_id="abyssal";data.abyssal_fixture=abyssal
	var overlap := fixture(0);var target := add_unit(overlap,"ally_fixture",0,Vector2i(11,2),1000)
	overlap.sides[0].cost=20;overlap.sides[0].next_deploy_discount=2;overlap.step([sea(overlap)],[])
	var token := BardRules.token_for(overlap,overlap.units[0])
	check(token!=null and overlap.sides[0].cost==15 and overlap.sides[0].next_deploy_discount==2,"Sea5DP, one token, no squad slot or discount consumption")
	check(not overlap.enemy_is_targetable(1,token) and not overlap._apply_damage(token,MatchState.SEABORN_DATA,9999,"true") and token.hp==100 and SkillRules.block_count_value(token,MatchState.SEABORN_DATA)==0,"Sea is untargetable, invulnerable and zero-block")
	check(not BardRules.available(overlap,0) and not overlap.can_deploy(0,"seaborn",Vector2i(11,4)),"Cannot deploy second sea creature")
	for tick in 29:overlap.step([],[])
	check(target.hp==1019 and SkillRules.attack_value(overlap.units[0],op)==390,"Overlapping areas heal once:19.5 per second, other ally gives6percentATK")
	var deep := add_unit(overlap,"abyssal_fixture",0,Vector2i(13,2),1000);AuraRules.refresh(overlap)
	check(SkillRules.attack_value(overlap.units[0],op)==423,"Abyssal ally upgrades ownATK to15percent")
	overlap._retreat_unit(token)
	check(overlap.sides[0].cooldowns["seaborn"]==900 and not BardRules.available(overlap,0),"Manual sea exit starts independent30second cooldown")
	var lifetime := fixture(0);lifetime.step([sea(lifetime)],[]);var old_token := BardRules.token_for(lifetime,lifetime.units[0]);lifetime.tick=old_token.deployed_tick+750;lifetime.step([],[])
	check(BardRules.token_for(lifetime,lifetime.units[0])==null and lifetime.sides[0].cooldowns["seaborn"]==900,"Sea expires after25seconds then starts cooldown")
	var owner_exit := fixture(0);owner_exit.step([sea(owner_exit)],[]);owner_exit._retreat_unit(owner_exit.units[0])
	check(owner_exit.units.is_empty() and owner_exit.sides[0].cooldowns["seaborn"]==900,"Owner retreat removes sea creature")
	var share := fixture(0);var protected := add_unit(share,"ally_fixture",0,Vector2i(11,2),1000);share.units[0].hp=100;share.units[0].sp=50;share.step([cast(share,0)],[])
	check(share.units[0].hp==4328 and SkillRules.max_health_value(share.units[0],op)==4328,"S1 full recovery and170percent maximumHP")
	var protected_hp := protected.hp;share._apply_damage(protected,ally,101,"true")
	check(protected.hp==protected_hp-51 and share.units[0].hp==4278,"S1 floor50 transfer as unscaled life loss,51 damage retained")
	protected.physical_shield_hp=100;var bard_hp := share.units[0].hp;protected_hp=protected.hp;share._apply_damage(protected,ally,101,"physical")
	check(protected.hp==protected_hp-1 and share.units[0].hp==bard_hp,"S1 shares actual damage after physical shield")
	var inspire := fixture(1);var buffed := add_unit(inspire,"ally_fixture",0,Vector2i(11,2),1000);inspire.units[0].sp=56;inspire.step([],[])
	check(inspire.units[0].skill_ticks_left==-2 and buffed.inspire_attack_add==234 and buffed.inspire_defense_add==140 and SkillRules.attack_value(buffed,ally)==734 and SkillRules.defense_value(buffed,ally)==240 and inspire.units[0].inspire_attack_add==0,"S2 infinite,60percent current stat inspiration, bard excluded")
	buffed.attack_bonus_percent=100
	check(SkillRules.attack_value(buffed,ally)==1234,"Inspiration is a final stat add, not multiplied by allyATK buff")
	var tide := fixture(2);var ally2 := add_unit(tide,"ally_fixture",0,Vector2i(13,2),1000);tide.step([sea(tide)],[]);var enemy := add_unit(tide,"ally_fixture",1,Vector2i(11,2),10000);tide.units[0].sp=35;ally2.hp=1000;tide.step([cast(tide,2)],[])
	for tick in 29:tide.step([],[])
	check(enemy.hp==9890 and ally2.hp==1000 and tide.units[0].hp==1523 and ally2.inspire_attack_add==429,"S3 two55 true pulses overlap, no regen,5percent raw life loss and110percent inspiration")
	var ball := fixture(2);add_unit(ball,"ally_fixture",0,Vector2i(13,2),1000);ball.step([sea(ball)],[]);ball.ball.cell=Vector2i(11,2);ball.units[0].sp=35;ball.step([cast(ball,2)],[])
	for tick in 29:ball.step([],[])
	check(ball.ball.accum==Vector2i(-273,0),"No-enemy S3 ball fallback happens once across union with raw273 push")
	var remote := fixture(2);remote.step([sea(remote)],[]);remote.ball.cell=Vector2i(11,4);remote.units[0].sp=35;remote.step([cast(remote,2)],[])
	for tick in 29:remote.step([],[])
	check(remote.ball.accum==Vector2i(0,258),"Sea-only ball pulse originates at Sea, raw258 vertical force")
	var device := fixture(2);device.ball.cell=Vector2i(11,2);var hostile := add_unit(device,"seaborn",1,Vector2i(11,2),100)
	SkillRules.activate(device.units[0],op);device.units[0].skill_elapsed_ticks=29;BardRules.advance(device,device.units[0],op)
	check(hostile.hp==100 and device.ball.accum==Vector2i(-258,0),"Enemy invulnerable Sea does not suppress tide ball fallback")
	data.ifrit=load("res://resources/operators/ifrit.tres");var flame := fixture(0);flame.units[0].cell=Vector2i(15,2)
	var caster := add_unit(flame,"ifrit",0,Vector2i(12,2),1680);caster.facing=2;add_unit(flame,"seaborn",1,Vector2i(11,2),100);flame.ball.cell=Vector2i(10,2)
	caster.skill_index=2;SkillRules.activate(caster,data.ifrit);FlameRules.attack(flame,caster,data.ifrit,true)
	check(flame.ball.accum==Vector2i(-1218,0),"Enemy Sea cannot suppress related line-AoE ball fallback")
	var a := fixture(2);var b := fixture(2)
	for state in [a,b]:
		add_unit(state,"ally_fixture",0,Vector2i(13,2),1000)
		var deploys: Array[InputCommand]=[sea(state)]
		var empty: Array[InputCommand]=[]
		state.step(deploys,empty)
		state.units[0].sp=35
	for tick in 620:
		var commands: Array[InputCommand]=[]
		if tick==0:commands.append(cast(a,2))
		a.step(commands,[]);b.step(commands,[]);check(a.state_hash()==b.state_hash(),"Bard/sea lifecycle620tick deterministic replay")
	print("SKADI_ALTER_CORE_OK" if failures==0 else "SKADI_ALTER_FAILED %d"%failures);quit(0 if failures==0 else 1)
func fixture(index: int) -> MatchState:
	var ids := PackedStringArray(["skadi_alter"]);var skills := PackedInt32Array([index]);var state := MatchState.new(10,data,MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[skills,skills]);state.sides[0].cost=99;state.ball.cell=Vector2i(10,10);state._ball_data=MatchState.DEFAULT_BALL_DATA.duplicate(true);state._ball_data.kick_threshold=1000000
	state.step([InputCommand.new(0,InputCommand.Kind.DEPLOY,"skadi_alter",-1,Vector2i(12,2),-1,2)],[]);return state
func add_unit(state: MatchState,id: String,side: int,cell: Vector2i,hp: int) -> UnitState:
	var unit := UnitState.new(state.next_unit_id,side,id,cell,hp,0,100000);state.next_unit_id+=1;state.units.append(unit);return unit
func sea(state: MatchState) -> InputCommand:return InputCommand.new(state.tick,InputCommand.Kind.DEPLOY,"seaborn",-1,Vector2i(11,3),-1,2)
func cast(state: MatchState,index: int) -> InputCommand:return InputCommand.new(state.tick,InputCommand.Kind.SKILL,"",0,Vector2i.ZERO,index)
func check(value: bool,label: String) -> void:
	if not value:failures+=1;push_error(label)
