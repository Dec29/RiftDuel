class_name AttackRules
extends RefCounted


static func resolve(state: MatchState) -> void:
	for unit: UnitState in state.units.duplicate():
		if unit not in state.units or unit.hp <= 0:
			continue
		var attacker_data := state._operator_data[unit.operator_id] as OperatorData
		if attacker_data.branch_trait.effect_type in ["phantom","curse_doll"]:
			continue
		var skill := attacker_data.skills[unit.skill_index]
		if SkillRules.can_gain_sp(unit) and not unit.coin_firing and Mon3trRules.can_charge(state,unit,skill) and skill.sp_recharge_type == "time" and (unit.skill_ticks_left == 0 or skill.effect_type in ["lin_stance", "charge_shot", "fortress_charge_shot", "stance_defense_regen", "fighter_stance", "charge_multi_shot", "charge_magic_splash"]):
			if unit.sp < SkillRules.sp_limit(skill):
				var duelist_bonus := int(attacker_data.talent_2.effect_params["sp_bonus_percent"]) if attacker_data.talent_2.effect_type=="duelist_sp" and unit.silence_ticks_left==0 else 0
				var overcharge_bonus := int(attacker_data.talent_2.effect_params["sp_recharge_bonus_percent"]) if attacker_data.talent_2.effect_type=="overcharge_sp" and unit.silence_ticks_left==0 and unit.sp>=skill.sp_required else 0
				unit.sp_regen_accum += duelist_bonus+overcharge_bonus+unit.sp_recharge_bonus_percent if unit.skill_ticks_left == 0 or skill.effect_type in ["lin_stance","stance_defense_regen","fighter_stance"] else 0
				unit.sp_regen_ticks += 1 + unit.sp_regen_accum / 100
				unit.sp_regen_accum %= 100
				if unit.sp_regen_ticks >= state.CONFIG.TICK_RATE:
					unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + unit.sp_regen_ticks / state.CONFIG.TICK_RATE)
					unit.sp_regen_ticks %= state.CONFIG.TICK_RATE
		AttackTimeline.observe_skill(state,unit)
		AttackTimeline.cancel_incompatible(state,unit,attacker_data)
		if unit.titi_doze_owner_id>=0:
			if unit.attack_intent!=null:StatusRules.interrupt_basic(state,unit)
			continue
		if unit.operator_id in LingRules.IDS:LingRules.attack(state,unit,attacker_data);continue
		if unit.operator_id=="titi":TitiRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in ["mon3tr_operator","mon3tr_reconstruction"]:
			MonstrMedicRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in ["muelsyse","flowing_shape"]:
			TacticianRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in ["jessica_alter","jessica_shield"]:
			SentinelRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in VanguardDefenderRules.SIMPLE_IDS:
			VanguardDefenderRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in StainlessRules.IDS:
			if unit.operator_id=="stainless_cannon":StainlessRules.cannon_attack(state,unit,attacker_data)
			continue
		if unit.operator_id=="stainless":StainlessRules.attack(state,unit,attacker_data);continue
		if unit.operator_id=="gnosis":
			GnosisRules.attack(state,unit,attacker_data);continue
		if unit.operator_id=="silence_alter":
			SilenceAlterRules.attack(state,unit,attacker_data);continue
		if unit.operator_id=="silence_alter_drone":continue
		if unit.operator_id in ["vigil","vigil_wolf"]:
			VigilRules.attack(state,unit,attacker_data);continue
		if unit.operator_id=="ines":
			InesRules.attack(state,unit,attacker_data);continue
		if unit.operator_id in ["dusk","dusk_freeling"]:
			DuskRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id=="goldenglow":
			GoldenglowRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id=="chen_alter":
			ChenAlterRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id=="fiammetta":
			FiammettaRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id in ["pozyomka","pozyomka_typewriter"]:
			PozyomkaRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id=="lee":
			LeeRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id in GuardSpecialistRules.IDS:
			GuardSpecialistRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id in MedicAlterRules.IDS:
			MedicAlterRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="texas_tradition":
			TexasAlterRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="penance_barrier":
			PenanceRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_2.effect_type=="sleep_mercy":
			BlemishineRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="phalanx":
			PhalanxRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="mentor":
			PallasRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="sniper_offensive_sp":
			ArchettoRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="lord_neurotoxin":
			ThornsRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id in ClassicOperatorRules.ATTACK_IDS:
			ClassicOperatorRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="puller":
			CliffheartRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="medical_drone":
			MedicalDroneRules.heal(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="deployment_fortune":
			GitanoRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="explosive_attack":
			MeteoriteRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="healing_output_aura":
			NearlRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type in ["musha","unyield"]:
			MushaRules.attack(state,unit,attacker_data)
			continue
		if unit.operator_id in LaunchOperatorRules.IDS:
			LaunchOperatorRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="seaborn":continue
		if attacker_data.branch_trait.effect_type=="bard":
			BardRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="therapist":
			LumenRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="critical_wound":
			SagaRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="physical_splash":
			WArtilleryRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="mon3tr_control":
			Mon3trRules.heal(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type=="mon3tr":
			Mon3trRules.attack(state,unit,attacker_data)
			continue
		if SkillRules.active_ticks(unit)>0 and skill.effect_type in ["nian_copper","cuora_shell"]:continue
		if attacker_data.branch_trait.effect_type=="geek":
			AakRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type == "dual_strike":
			SwordRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type == "summoner_drone":
			DroneRules.attack(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type in ["pusher", "water_cannon"]:
			PusherRules.advance(state, unit, attacker_data)
			continue
		if attacker_data.talent_1.effect_type=="initial_cost":
			if unit.texas_cast_tick!=state.tick:PioneerRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.talent_2.effect_type == "adjacent_death_sp":
			PioneerRules.advance(state, unit, attacker_data)
			continue
		if attacker_data.branch_trait.effect_type == "guardian" and GuardianRules.advance(state, unit, attacker_data):
			continue
		if skill.trigger_type == "auto" and skill.effect_type not in ["guardian_aid", "guardian_medicine", "heal_barrier", "heal_magic_barrier"] and SkillRules.can_activate(unit, skill):
			SkillRules.activate(unit, attacker_data)
			if skill.effect_type=="medical_drone_supply":unit.medical_drone_stock=1;unit.skill_ticks_left=0
			if skill.effect_type in ["lappland_sundial","lappland_wolf"]:unit.lappland_skill_tick=state.tick
		if unit.operator_id in AttackTimeline.IDS and unit.operator_id!="surtr":AttackTimeline.attack(state,unit,attacker_data);continue
		if attacker_data.branch_trait.effect_type == "magic_splash":
			SplashCasterRules.advance(state, unit, attacker_data)
			continue
		if attacker_data.branch_trait.effect_type == "line_magic":
			FlameRules.advance(state,unit,attacker_data)
			continue
		if attacker_data.branch_trait.effect_type == "prioritize_heavy":
			SiegeRules.advance(state, unit, attacker_data)
			continue
		if skill.effect_type == "champagne_traps" and unit.silence_ticks_left == 0 and unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and state.tick >= unit.bomb_next_tick and unit.coins > 0:
			MerchantRules.plant_bomb(state, unit,attacker_data)
		if unit.coin_firing:
			unit.coin_fire_ticks_left = maxi(0, unit.coin_fire_ticks_left - 1)
			if unit.silence_ticks_left == 0 and unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and unit.coin_fire_ticks_left == 0:
				MerchantRules.fire_coin(state, unit,attacker_data)
			continue
		if SkillRules.active_ticks(unit) > 0 and skill.effect_type in ["cost_regen", "flag_heal", "flag_medicine"]:
			SkillRules.advance_cost_regen(state, unit, skill)
		if SkillRules.active_ticks(unit)>0 and skill.effect_type=="flag_medicine":
			MyrtleRules.heal(state,unit,attacker_data)
			continue
		if unit.skill_ticks_left > 0 and attacker_data.branch_trait.effect_type == "flag_bearer":
			continue
		if SkillRules.active_ticks(unit) > 0 and skill.effect_type == "foxfire_aura":
			continue
		if unit.skill_ticks_left > 0 and skill.effect_type == "ramp_burst":
			unit.skill_elapsed_ticks += 1
			if unit.silence_ticks_left == 0:
				var interval := int(skill.effect_params["pulse_interval_ticks"])
				var burst_tick := interval * int(skill.effect_params["ramp_steps"])
				if unit.skill_elapsed_ticks <= burst_tick and unit.skill_elapsed_ticks % interval == 0:
					var attack := SkillRules.attack_value(unit, attacker_data)
					var offsets := state.ATTACK_RANGE.effective_offsets(unit, attacker_data)
					if unit.skill_elapsed_ticks == burst_tick:
						var max_hp := SkillRules.max_health_value(unit, attacker_data)
						var loss := roundi(max_hp * int(skill.effect_params["hp_loss_percent"]) / 100.0)
						if unit.hp_lock_ticks_left > 0:
							loss = mini(loss, maxi(0, unit.hp - ceili(max_hp * int(attacker_data.talent_1.effect_params["lock_hp_percent"]) / 100.0)))
						loss = mini(loss, maxi(0, unit.hp - 1))
						if loss > 0:
							unit.hp -= loss
							unit.last_damage_tick = state.tick
							state._apply_emergency_heal(unit, attacker_data)
						attack = roundi(attack * int(skill.effect_params["burst_attack_percent"]) / 100.0)
						offsets = skill.burst_range_override
					var enemy_found := false
					for target in state.units:
						if unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and target.hp > 0 and StainlessRules.is_damage_target(unit,target) and state._is_in_attack_range(unit, target.cell, offsets):
							enemy_found = true
							var target_data: OperatorData = state._operator_data[target.operator_id]
							var damage := Combat.calculate_damage(attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), "physical", SkillRules.dodge_chance(target, target_data, "physical"), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, "physical"))
							state._apply_damage(target, target_data, damage, "physical", unit)
							unit.last_attack_tick = state.tick
							unit.last_attack_is_heal = false
							unit.last_attack_target_x = target.cell.x
							unit.last_attack_target_y = target.cell.y
					if unit.stun_ticks_left == 0 and unit.displacement_ticks_left == 0 and not enemy_found:
						var box_target: TacticalBox
						for box in state.tactical_boxes:
							if state._is_in_attack_range(unit, box.cell, offsets):
								box_target = box
								break
						if box_target != null:
							TacticalRules.strike_box(state, unit, box_target)
						elif state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, offsets):
							state.ball.add_push(unit.cell, attack, state._ball_data, state.ATTACK_RANGE.rotate_offset(Vector2i.RIGHT, unit.facing))
							unit.last_attack_tick = state.tick
							unit.last_attack_is_heal = false
							unit.last_attack_target_x = state.ball.cell.x
							unit.last_attack_target_y = state.ball.cell.y
				continue
		if unit.skill_ticks_left > 0 and skill.effect_type == "fortress_overload":
			unit.skill_elapsed_ticks += 1
			var elapsed := unit.skill_elapsed_ticks - int(skill.effect_params["overload_ticks"])
			var interval := int(skill.effect_params["hp_loss_interval_ticks"])
			if unit.silence_ticks_left == 0 and elapsed > 0 and elapsed % interval == 0:
				var ramp_ticks := roundi(skill.duration * state.CONFIG.TICK_RATE) - int(skill.effect_params["overload_ticks"])
				var divisor := 100 * state.CONFIG.TICK_RATE * ramp_ticks
				unit.skill_hp_regen_accum += SkillRules.max_health_value(unit, attacker_data) * int(skill.effect_params["hp_loss_max_percent"]) * mini(elapsed, ramp_ticks) * interval
				var loss := unit.skill_hp_regen_accum / divisor
				unit.skill_hp_regen_accum %= divisor
				state._apply_skill_life_loss(unit, attacker_data, loss)
				if unit.hp <= 0: continue
		if unit.sleep_ticks_left>0 or unit.displacement_ticks_left > 0 or (unit.silence_ticks_left == 0 and skill.effect_type in ["rapid_magic", "weightless_multi_target"] and unit.skill_ticks_left == 0):
			continue
		if unit.operator_id in AttackTimeline.ADAPTED_IDS:
			if not AttackTimeline.advance(state,unit):continue
		else:
			unit.attack_ticks_left = 0 if unit.skill_dump_pending and unit.silence_ticks_left == 0 else maxi(0, unit.attack_ticks_left - 1)
			if unit.frozen_ticks_left>0 or unit.bind_ticks_left > 0 or unit.stun_ticks_left > 0 or unit.attack_ticks_left > 0:
				continue

			unit.attack_ticks_left = SkillRules.attack_interval_ticks(unit, attacker_data)

		if SkillRules.active_ticks(unit) != 0 and skill.effect_type == "fortress_ammo":
			FortressRules.attack_ammo(state, unit, attacker_data)
			continue
		var damage_type := SkillRules.damage_type(unit, attacker_data)
		var attack := SkillRules.attack_output_value(unit, attacker_data)
		if unit.silence_ticks_left==0 and attacker_data.talent_1.effect_type=="charged_attack":
			var params := attacker_data.talent_1.effect_params
			var elapsed := state.tick-(unit.last_attack_tick if unit.last_attack_tick>=0 else unit.deployed_tick)
			var progress := clampi(elapsed-int(params["min_ticks"]),0,int(params["max_ticks"])-int(params["min_ticks"]))
			attack=roundi(attack*(1.0+(int(params["max_attack_percent"])-100)*progress/(100.0*(int(params["max_ticks"])-int(params["min_ticks"])))))
		if unit.silence_ticks_left == 0 and skill.effect_type == "passive_heal" and unit.coins > 0:
			var heal_target: UnitState
			var target_max_hp := 1
			for ally in state.units:
				if ally.side != unit.side or ally.hp <= 0 or ally.critical_ticks_left>0 or ally.unit_id == unit.unit_id or (state._operator_data[ally.operator_id] as OperatorData).branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","dusk_freeling","flowing_shape","jessica_shield","monstr_reconstruction","ling_summon","unyield","musha", "mon3tr", "phantom", "executor_clone", "water_cannon", "summoner_drone"]:
					continue
				var offset := ally.cell - unit.cell
				var radius := int(skill.effect_params["heal_radius"])
				var ally_data := state._operator_data[ally.operator_id] as OperatorData
				var ally_max := SkillRules.max_health_value(ally, ally_data)
				if absi(offset.x) > radius or absi(offset.y) > radius or ally.hp * 100 >= ally_max * int(skill.effect_params["hp_threshold_percent"]):
					continue
				if heal_target == null or ally.hp * target_max_hp < heal_target.hp * ally_max:
					heal_target = ally
					target_max_hp = ally_max
			if heal_target != null:
				heal_target.hp = mini(target_max_hp, heal_target.hp + SkillRules.healing_received(heal_target,state._operator_data[heal_target.operator_id],Combat.calculate_healing(attack, int(skill.effect_params["heal_percent"])),unit))
				unit.coins -= 1
				unit.last_coin_spend_tick = state.tick
				unit.last_attack_tick = state.tick
				unit.last_attack_target_x = heal_target.cell.x
				unit.last_attack_target_y = heal_target.cell.y
				unit.last_attack_is_heal = true
				heal_target.last_heal_tick = state.tick
				continue
		if damage_type == "healing":
			var timed_heal_targets: Array[UnitState]=[]
			if unit.operator_id in AttackTimeline.ADAPTED_IDS:
				var heal_count:=1 if attacker_data.branch_trait.effect_type=="single_target_heal" else int(attacker_data.branch_trait.effect_params.target_count)
				timed_heal_targets=AttackTimeline.healing_candidates(state,unit,attacker_data,heal_count)
				if timed_heal_targets.is_empty():continue
				if not AttackTimeline.windup(state,unit,attacker_data,timed_heal_targets,timed_heal_targets[0].cell,true):continue
			var healed_ids: Array[int] = []
			var magic_barrier_ready := skill.effect_type == "heal_magic_barrier" and SkillRules.can_activate(unit, skill)
			var target_count := 1 if attacker_data.branch_trait.effect_type == "single_target_heal" else int(attacker_data.branch_trait.effect_params["target_count"])
			for _target in target_count:
				var heal_target: UnitState
				var target_max_hp := 1
				for ally in state.units:
					if (unit.operator_id in AttackTimeline.ADAPTED_IDS and ally not in timed_heal_targets) or ally.side != unit.side or ally.hp <= 0 or ally.critical_ticks_left>0 or (state._operator_data[ally.operator_id] as OperatorData).branch_trait.effect_type in ["stainless_device_1","stainless_device_2","stainless_device_3","dusk_freeling","flowing_shape","jessica_shield","monstr_reconstruction","ling_summon","unyield","musha", "mon3tr", "phantom", "executor_clone", "water_cannon", "summoner_drone"] or ally.unit_id in healed_ids:
						continue
					var ally_data: OperatorData = state._operator_data[ally.operator_id]
					var ally_max := SkillRules.max_health_value(ally, ally_data)
					if ally.hp < ally_max and state._is_in_attack_range(unit, ally.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)) and (heal_target == null or ally.hp * target_max_hp < heal_target.hp * ally_max):
						heal_target = ally
						target_max_hp = ally_max
				if heal_target == null:
					break
				if skill.effect_type == "heal_barrier" and SkillRules.can_activate(unit, skill):
					unit.sp -= skill.sp_required
					unit.skill_activation_count+=1
					heal_target.barrier_hp.append(roundi(attack * int(skill.effect_params["shield_attack_percent"]) / 100.0))
					heal_target.barrier_ticks_left.append(int(skill.effect_params["barrier_duration_ticks"]))
					heal_target.barrier_defense_percent.append(int(skill.effect_params["defense_percent"]))
					heal_target.barrier_magic_only.append(0)
					heal_target.barrier_magic_resist_add.append(0)
				if magic_barrier_ready:
					if healed_ids.is_empty():
						unit.sp -= skill.sp_required
						unit.skill_activation_count+=1
					heal_target.barrier_hp.append(roundi(attack * int(skill.effect_params["shield_attack_percent"]) / 100.0))
					heal_target.barrier_ticks_left.append(int(skill.effect_params["barrier_duration_ticks"]))
					heal_target.barrier_defense_percent.append(0)
					heal_target.barrier_magic_only.append(1)
					heal_target.barrier_magic_resist_add.append(int(skill.effect_params["magic_resist_add"]))
				heal_target.hp = mini(target_max_hp, heal_target.hp + SkillRules.healing_received(heal_target,state._operator_data[heal_target.operator_id],Combat.calculate_healing(attack),unit))
				healed_ids.append(heal_target.unit_id)
				unit.last_attack_tick = state.tick
				unit.last_attack_is_heal = true
				unit.last_attack_target_x = heal_target.cell.x
				unit.last_attack_target_y = heal_target.cell.y
				heal_target.last_heal_tick = state.tick
			if not healed_ids.is_empty() and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			continue

		var attack_target: UnitState
		var box_target: TacticalBox
		for box in state.tactical_boxes:
			if state._is_in_attack_range(unit, box.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
				box_target = box
				break
		var target_taunt := -1
		for enemy in state.units:
			if state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit, enemy.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
				var enemy_data: OperatorData = state._operator_data[enemy.operator_id]
				var taunt := SkillRules.taunt_level(enemy,enemy_data)
				var replace_target := attack_target == null or taunt > target_taunt
				if taunt == target_taunt and attack_target != null and SkillRules.active_ticks(unit) > 0 and skill.effect_type in ["defense_priority_fast", "defense_priority_physical"]:
					var candidate_defense := SkillRules.defense_value(enemy, enemy_data)
					var current_defense := SkillRules.defense_value(attack_target, state._operator_data[attack_target.operator_id])
					replace_target = candidate_defense > current_defense if skill.effect_type == "defense_priority_fast" else candidate_defense < current_defense
				if replace_target:
					attack_target = enemy
					target_taunt = taunt
		var native_action:=unit.attack_intent
		if unit.operator_id in AttackTimeline.ADAPTED_IDS:
			var locked_candidates: Array[UnitState]=[]
			if unit.attack_intent!=null:
				locked_candidates=PusherRules.targets(state,unit,AttackRange.effective_offsets(unit,attacker_data),false)
			elif attack_target!=null:locked_candidates=AttackTimeline.generic_targets(state,unit,attacker_data,attack_target)
			locked_candidates=AttackTimeline.pinned(state,unit,locked_candidates)
			attack_target=locked_candidates[0] if not locked_candidates.is_empty() else null
			var center:=attack_target.cell if attack_target!=null else (box_target.cell if box_target!=null else state.ball.cell)
			if attack_target==null and box_target==null and (state.ball.move_ticks_left!=0 or not state._is_in_attack_range(unit,center,AttackRange.effective_offsets(unit,attacker_data))):continue
			if not AttackTimeline.windup(state,unit,attacker_data,locked_candidates,center):
				if native_action==null and unit.attack_intent!=null and not locked_candidates.is_empty():unit.attack_intent.requires_primary=AttackTimeline.generic_target_count(unit,attacker_data)==1
				continue
		if attack_target != null:
			if skill.trigger_type == "attack" and SkillRules.can_activate(unit, skill):
				SkillRules.activate(unit, attacker_data)
				unit.attack_action_triggered=true
				attack = SkillRules.attack_output_value(unit, attacker_data)
			if SkillRules.active_ticks(unit) != 0 and skill.effect_type == "charge_magic_splash":
				if unit.operator_id in AttackTimeline.GENERIC_RANGED_IDS:
					var burst:=AttackTimeline.generic_projectile(state,unit,attacker_data,attack_target,null,attack_target.cell,roundi(attack/2.0),"magical")
					burst.splash_radius_squared=int(skill.effect_params.splash_radius_squared);burst.splash_affects_objects=false
					AttackTimeline.generic_projectile(state,unit,attacker_data,attack_target,null,attack_target.cell,roundi(attack/2.0),"magical")
					PusherRules.mark_attack(state,unit,attack_target.cell)
					unit.skill_ticks_left=0
					continue
				attack_target.resist_break_ticks_left = int(skill.effect_params["resist_duration_ticks"])
				attack_target.resist_remaining_percent = int(skill.effect_params["resist_remaining_percent"])
				unit.last_attack_tick = state.tick
				unit.last_attack_is_heal = false
				unit.last_attack_target_x = attack_target.cell.x
				unit.last_attack_target_y = attack_target.cell.y
				var half_attack := roundi(attack / 2.0)
				for target in state.units:
					if target.hp > 0 and StainlessRules.is_damage_target(unit,target) and (target.cell - attack_target.cell).length_squared() <= int(skill.effect_params["splash_radius_squared"]):
						var target_data: OperatorData = state._operator_data[target.operator_id]
						var damage := Combat.calculate_damage(half_attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), "magical", SkillRules.dodge_chance(target, target_data, "magical"), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, "magical"), state._magical_damage_taken_percent(target))
						state._apply_damage(target, target_data, damage, "magical", unit)
				if attack_target.hp > 0 and unit.hp > 0:
					var target_data: OperatorData = state._operator_data[attack_target.operator_id]
					var damage := Combat.calculate_damage(half_attack, SkillRules.defense_value(attack_target, target_data), SkillRules.magic_resist_value(attack_target, target_data), "magical", SkillRules.dodge_chance(attack_target, target_data, "magical"), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(attack_target, "magical"), state._magical_damage_taken_percent(attack_target))
					state._apply_damage(attack_target, target_data, damage, "magical", unit)
				unit.skill_ticks_left = 0
				continue
			if skill.effect_type in ["charge_multi_shot", "burst_atk_def_boost"]:
				unit.last_attack_tick = state.tick
				unit.last_attack_is_heal = false
				unit.last_attack_target_x = attack_target.cell.x
				unit.last_attack_target_y = attack_target.cell.y
				var shots := int(skill.effect_params["shot_count"]) if SkillRules.active_ticks(unit) != 0 else 1
				var indices:=AttackTimeline.release_indices(unit,native_action,shots) if unit.operator_id=="bagpipe" else PackedInt32Array(range(shots))
				for _shot in indices:
					if attack_target.hp <= 0 or unit.hp <= 0:
						break
					var shot_attack := attack
					var targets: Array[UnitState] = [attack_target]
					if unit.silence_ticks_left == 0 and attacker_data.talent_1.effect_type == "attack_proc" and state.rng.next_percent() < int(attacker_data.talent_1.effect_params["chance_percent"]):
						shot_attack = roundi(shot_attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
						for enemy in state.units:
							if targets.size() >= int(attacker_data.talent_1.effect_params["target_count"]):
								break
							if enemy != attack_target and (native_action==null or enemy.unit_id in native_action.target_ids) and state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit, enemy.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
								targets.append(enemy)
					targets.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.unit_id < b.unit_id)
					for target in targets:
						var target_data: OperatorData = state._operator_data[target.operator_id]
						var damage := Combat.calculate_damage(shot_attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), damage_type, SkillRules.dodge_chance(target, target_data, damage_type), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, damage_type), state._magical_damage_taken_percent(target))
						state._apply_damage(target, target_data, damage, damage_type, unit)
						if target.hp <= 0 and attacker_data.branch_trait.effect_type == "refund_on_kill":
							state.sides[unit.side].cost = mini(state.CONFIG.COST_MAX, state.sides[unit.side].cost + int(attacker_data.branch_trait.effect_params["refund_amount"]))
				if SkillRules.active_ticks(unit) == -1 and unit.attack_intent==null:
					unit.skill_ticks_left = 0
				continue
			var armor_break := state._roll_armor_break(unit, attacker_data)
			if armor_break:
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
			var targets: Array[UnitState] = [attack_target]
			var target_count := attacker_data.block_count if attacker_data.branch_trait.effect_type == "attack_all_blocked" else 1
			if SkillRules.active_ticks(unit) != 0 and skill.effect_type in ["lappland_wolf", "permanent_multi_target", "multi_target_boost", "weightless_multi_target"]:
				target_count = int(skill.effect_params["target_count"])
			var attack_proc:=false
			if skill.effect_type not in ["charge_multi_shot","burst_atk_def_boost"] and unit.silence_ticks_left==0 and attacker_data.talent_1.effect_type=="attack_proc":
				if unit.operator_id=="bagpipe" and unit.attack_action_event_index>0:attack_proc=unit.attack_action_proc
				else:
					attack_proc=state.rng.next_percent()<int(attacker_data.talent_1.effect_params.chance_percent)
					unit.attack_action_proc=attack_proc
			if attack_proc:
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
				target_count = int(attacker_data.talent_1.effect_params["target_count"])
			if SkillRules.active_ticks(unit) > 0 and skill.effect_type == "cleave_atk_def_boost":
				target_count = state.units.size()
			for enemy in state.units:
				if targets.size() >= target_count:
					break
				if enemy != attack_target and (native_action==null or enemy.unit_id in native_action.target_ids) and state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit, enemy.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
					targets.append(enemy)
			if SkillRules.active_ticks(unit)>0 and skill.effect_type=="random_multi_target" and native_action!=null:
				targets.clear()
				for id in native_action.target_ids:
					var enemy:=WArtilleryRules.owner(state,id)
					if enemy!=null and state.enemy_is_targetable(unit.side,enemy,unit) and state._is_in_attack_range(unit,enemy.cell,AttackRange.effective_offsets(unit,attacker_data)):targets.append(enemy)
				if targets.is_empty():continue
				attack_target=targets[0]
			elif SkillRules.active_ticks(unit)>0 and skill.effect_type=="random_multi_target":
					var candidates: Array[UnitState] = []
					for enemy in state.units:
						if state.enemy_is_targetable(unit.side, enemy) and state._is_in_attack_range(unit, enemy.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
							candidates.append(enemy)
					targets.clear()
					var limit := int(skill.effect_params["target_count"])
					# Keep existing taunt priority; randomly choose only an overflowing priority group.
					for priority in [1, 0, -1]:
						var group: Array[UnitState] = []
						for enemy in candidates:
							var enemy_data: OperatorData = state._operator_data[enemy.operator_id]
							var enemy_priority := SkillRules.taunt_level(enemy,enemy_data)
							if enemy_priority == priority: group.append(enemy)
						var slots := limit - targets.size()
						if group.size() <= slots:
							targets.append_array(group)
						else:
							for pick in slots:
								var index := state.rng.next_u32() % group.size()
								targets.append(group[index])
								group.remove_at(index)
					targets.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.unit_id < b.unit_id)
					attack_target = targets[0]
			if attacker_data.branch_trait.effect_type == "fortress" and attack_target.cell != unit.cell:
				targets = FortressRules.targets(state, unit, attacker_data, attack_target.cell)
			if SkillRules.active_ticks(unit) > 0 and skill.effect_type in ["lappland_wolf", "multi_target_boost", "cleave_atk_def_boost", "weightless_multi_target"]:
				targets.sort_custom(func(a: UnitState, b: UnitState) -> bool: return a.unit_id < b.unit_id)
			unit.last_attack_tick = state.tick
			unit.last_attack_is_heal = false
			unit.last_attack_target_x = attack_target.cell.x
			unit.last_attack_target_y = attack_target.cell.y
			if attacker_data.branch_trait.effect_type=="fortress" and attack_target.cell!=unit.cell:
				var radius:=int(skill.effect_params.splash_radius_squared) if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="fortress_charge_shot" else int(attacker_data.branch_trait.effect_params.splash_radius_squared)
				var blast:=AttackTimeline.area_projectile(state,unit,attacker_data,attack_target.cell,attack,damage_type,radius)
				blast.splash_affects_objects=false
				if skill.sp_recharge_type=="on_hit" and unit.skill_ticks_left==0:SagaRules.reward(state,unit,1)
				if unit.skill_ticks_left==-1:unit.skill_ticks_left=0
				continue
			var shot_count := int(skill.effect_params["shot_count"]) if SkillRules.active_ticks(unit) != 0 and skill.effect_type in ["multi_shot", "sustained_multi_shot", "charge_multi_shot", "burst_atk_def_boost", "coin_barrage"] else 1
			var release_phase:=unit.attack_action_event_index
			var strike_indices:=AttackTimeline.release_indices(unit,native_action,shot_count) if unit.operator_id=="bagpipe" else PackedInt32Array(range(shot_count))
			var hit := false
			for target in targets:
				var target_data: OperatorData = state._operator_data[target.operator_id]
				for _shot in strike_indices:
					if target.hp <= 0 or unit.hp <= 0:
						break
					if unit.operator_id in AttackTimeline.GENERIC_RANGED_IDS:
						AttackTimeline.generic_projectile(state,unit,attacker_data,target,null,target.cell,attack,damage_type,armor_break)
						hit=true
						continue
					if SkillRules.active_ticks(unit) > 0 and skill.effect_type == "defense_priority_physical":
						StatusRules.apply_silence(state, target, int(skill.effect_params["silence_ticks"]))
					var dodge_chance := SkillRules.dodge_chance(target, target_data, damage_type)
					var damage := Combat.calculate_damage(attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), damage_type, dodge_chance, state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, damage_type), state._magical_damage_taken_percent(target))
					var landed := state._apply_damage(target, target_data, damage, damage_type, unit)
					if landed and target.hp>0 and unit.silence_ticks_left==0 and attacker_data.talent_1.effect_type=="attack_silence":StatusRules.apply_silence(state,target,int(attacker_data.talent_1.effect_params["duration_ticks"]))
					if landed and unit.hp > 0 and target.hp > 0 and SkillRules.active_ticks(unit) != 0 and skill.effect_type == "shift_attack":
						DisplacementRules.apply_unit(state, unit, target, DisplacementRules.direction(unit, target.cell, skill.effect_params["shift_mode"]), int(skill.effect_params["shift_force"]))
						AuraRules.refresh(state)
					if landed and target.hp > 0 and armor_break:
						target.armor_break_ticks_left = int(attacker_data.talent_1.effect_params["duration_ticks"])
						target.armor_break_defense_percent = int(attacker_data.talent_1.effect_params["defense_remaining_percent"])
					if landed and target.hp > 0 and attacker_data.branch_trait.effect_type == "slow_on_hit":
						StatusRules.add_control(state,target,"slow",roundi(float(attacker_data.branch_trait.effect_params["slow_duration"]) * state.CONFIG.TICK_RATE))
					if landed and SkillRules.active_ticks(unit) != 0 and skill.effect_type == "charge_shot":
						StatusRules.add_control(state,target,"bind",roundi(float(skill.effect_params["bind_duration"]) * state.CONFIG.TICK_RATE))
					hit = hit or landed
					if unit.hp > 0 and target.hp > 0 and unit.silence_ticks_left == 0 and attacker_data.talent_1.effect_type == "defense_damage":
						var extra_attack := roundi(SkillRules.defense_value(target, target_data) * int(attacker_data.talent_1.effect_params["defense_damage_percent"]) / 100.0)
						if extra_attack > 0:
							var extra_damage := Combat.calculate_damage(extra_attack, 0, SkillRules.magic_resist_value(target, target_data), "magical", SkillRules.dodge_chance(target, target_data, "magical"), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, "magical"), state._magical_damage_taken_percent(target))
							hit = state._apply_damage(target, target_data, extra_damage, "magical") or hit
					if target.hp <= 0 and attacker_data.branch_trait.effect_type == "refund_on_kill":
						state.sides[unit.side].cost = mini(state.CONFIG.COST_MAX, state.sides[unit.side].cost + int(attacker_data.branch_trait.effect_params["refund_amount"]))
			if release_phase==0 and not unit.attack_action_triggered and (hit or attacker_data.talent_1.effect_type=="attack_silence") and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			if SkillRules.active_ticks(unit) == -1 and unit.attack_intent==null:
				unit.skill_ticks_left = 0
		elif box_target != null:
			if skill.trigger_type == "attack" and SkillRules.can_activate(unit, skill):
				SkillRules.activate(unit, attacker_data)
				unit.attack_action_triggered=true
				attack=SkillRules.attack_output_value(unit,attacker_data)
			var box_shots := int(skill.effect_params["shot_count"]) if SkillRules.active_ticks(unit) != 0 and skill.effect_type in ["multi_shot", "sustained_multi_shot", "charge_multi_shot", "burst_atk_def_boost", "coin_barrage"] else 1
			var object_phase:=unit.attack_action_event_index
			var indices:=AttackTimeline.release_indices(unit,native_action,box_shots) if unit.operator_id=="bagpipe" else PackedInt32Array(range(box_shots))
			for _shot in indices:
				if unit.operator_id in AttackTimeline.GENERIC_RANGED_IDS:
					AttackTimeline.generic_projectile(state,unit,attacker_data,null,box_target,box_target.cell,attack,damage_type)
					continue
				TacticalRules.strike_box(state, unit, box_target)
				if box_target.hits_left == 0:
					break
			if object_phase==0 and not unit.attack_action_triggered and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			if SkillRules.active_ticks(unit) == -1 and unit.attack_intent==null:
				unit.skill_ticks_left = 0
		elif state.ball.move_ticks_left == 0 and state._is_in_attack_range(unit, state.ball.cell, state.ATTACK_RANGE.effective_offsets(unit, attacker_data)):
			if skill.trigger_type == "attack" and SkillRules.can_activate(unit, skill):
				SkillRules.activate(unit, attacker_data)
				unit.attack_action_triggered=true
				attack=SkillRules.attack_output_value(unit,attacker_data)
				attack = SkillRules.attack_output_value(unit, attacker_data)
			if skill.effect_type not in ["charge_multi_shot", "burst_atk_def_boost"] and unit.silence_ticks_left == 0 and attacker_data.talent_1.effect_type == "attack_proc" and state.rng.next_percent() < int(attacker_data.talent_1.effect_params["chance_percent"]):
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
			if state._roll_armor_break(unit, attacker_data):
				attack = roundi(attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
			unit.last_attack_tick = state.tick
			unit.last_attack_is_heal = false
			unit.last_attack_target_x = state.ball.cell.x
			unit.last_attack_target_y = state.ball.cell.y
			var shot_count := int(skill.effect_params["shot_count"]) if SkillRules.active_ticks(unit) != 0 and skill.effect_type in ["multi_shot", "sustained_multi_shot", "charge_multi_shot", "burst_atk_def_boost", "coin_barrage"] else 1
			var object_phase:=unit.attack_action_event_index
			var indices:=AttackTimeline.release_indices(unit,native_action,shot_count) if unit.operator_id=="bagpipe" else PackedInt32Array(range(shot_count))
			for _shot in indices:
				if state.ball.move_ticks_left > 0:
					break
				if unit.operator_id in AttackTimeline.GENERIC_RANGED_IDS:
					AttackTimeline.generic_projectile(state,unit,attacker_data,null,null,state.ball.cell,attack,damage_type)
					if attacker_data.branch_trait.effect_type=="fortress" and state.ball.cell!=unit.cell:
						var radius:=int(skill.effect_params.splash_radius_squared) if SkillRules.active_ticks(unit)!=0 and skill.effect_type=="fortress_charge_shot" else int(attacker_data.branch_trait.effect_params.splash_radius_squared)
						var blast:=AttackTimeline.area_projectile(state,unit,attacker_data,state.ball.cell,attack,damage_type,radius)
						blast.splash_affects_objects=false
					continue
				var shot_attack := attack
				if skill.effect_type in ["charge_multi_shot", "burst_atk_def_boost"] and unit.silence_ticks_left == 0 and attacker_data.talent_1.effect_type == "attack_proc" and state.rng.next_percent() < int(attacker_data.talent_1.effect_params["chance_percent"]):
					shot_attack = roundi(shot_attack * int(attacker_data.talent_1.effect_params["attack_percent"]) / 100.0)
				if SkillRules.active_ticks(unit) != 0 and skill.effect_type == "shift_attack":
					DisplacementRules.apply_ball(state, DisplacementRules.direction(unit, state.ball.cell, skill.effect_params["shift_mode"]), int(skill.effect_params["shift_force"]))
				else:
					state.ball.add_push(unit.cell, shot_attack, state._ball_data, state.ATTACK_RANGE.rotate_offset(Vector2i.RIGHT, unit.facing))
			if attacker_data.branch_trait.effect_type == "fortress" and state.ball.cell != unit.cell:
				for target in FortressRules.targets(state, unit, attacker_data, state.ball.cell):
					var target_data: OperatorData = state._operator_data[target.operator_id]
					var damage := Combat.calculate_damage(attack, SkillRules.defense_value(target, target_data), SkillRules.magic_resist_value(target, target_data), damage_type, SkillRules.dodge_chance(target, target_data, damage_type), state.rng, SkillRules.damage_profession_id(attacker_data), state._damage_taken_percent(target, damage_type), state._magical_damage_taken_percent(target))
					state._apply_damage(target, target_data, damage, damage_type, unit)
			if object_phase==0 and not unit.attack_action_triggered and skill.sp_recharge_type == "on_hit" and unit.skill_ticks_left == 0:
				unit.sp = mini(SkillRules.sp_limit(skill), unit.sp + 1)
			if SkillRules.active_ticks(unit) == -1 and unit.attack_intent==null:
				unit.skill_ticks_left = 0

		if unit.silence_ticks_left == 0 and skill.effect_type == "deploy_attack_stacks" and unit.last_attack_tick == state.tick:
			unit.attack_boost_stacks = maxi(0, unit.attack_boost_stacks - 1)

static func projectile_hit(state: MatchState, shot: AttackProjectile, source: UnitState, target: UnitState) -> void:
	var data: OperatorData=state._operator_data[shot.operator_id]
	var td: OperatorData=state._operator_data[target.operator_id]
	var skill:=data.skills[shot.skill_index]
	if shot.cold_ticks>0:
		var ticks:=shot.cold_ticks
		if StatusRules.has_resistance(state,target):ticks=maxi(1,ticks*state.CONFIG.STATUS_RESISTANCE_DURATION_PERCENT/100)
		StatusRules.add_control(state,target,"cold",ticks,source)
	var attack_value:=shot.primary_attack if target.unit_id==shot.target_id and shot.primary_attack>=0 else shot.attack
	if shot.inner_attack>=0 and (target.cell-shot.target_cell).length_squared()<=shot.inner_radius_squared:attack_value=shot.inner_attack
	var first_skill_hit:=shot.first_hit_bonus_percent>0
	if first_skill_hit:
		if source.skill_activation_count==shot.skill_use and target.unit_id in source.skill_hit_ids:first_skill_hit=false
		for previous in state.attack_skill_hits:
			if previous==PackedInt32Array([shot.source_id,shot.skill_use,target.unit_id]):first_skill_hit=false;break
		if first_skill_hit:attack_value=roundi(attack_value*shot.first_hit_bonus_percent/100.0)
	var defense:=maxi(0,roundi(SkillRules.defense_value(target,td)*shot.defense_remaining_percent/100.0)-shot.defense_ignore_flat)
	if not shot.silenced and data.talent_1.effect_type=="heavy_penetration" and DisplacementRules.effective_weight(state,target)>=int(data.talent_1.effect_params.weight_threshold):defense=roundi(defense*(100-int(data.talent_1.effect_params.defense_ignore_percent))/100.0)

	if shot.active and skill.effect_type=="defense_priority_physical":StatusRules.apply_silence(state,target,int(skill.effect_params.silence_ticks))
	if shot.active and skill.effect_type=="charge_magic_splash":
		target.resist_break_ticks_left=int(skill.effect_params.resist_duration_ticks);target.resist_remaining_percent=int(skill.effect_params.resist_remaining_percent)
	var damage_taken: float=state._damage_taken_percent(target,shot.damage_type)
	if shot.operator_id=="dusk" and shot.active and skill.effect_type=="dusk_ink" and target.hp*100<SkillRules.max_health_value(target,td)*int(skill.effect_params.hp_threshold_percent):damage_taken=damage_taken*int(skill.effect_params.low_health_damage_percent)/100.0
	var damage:=Combat.calculate_damage(attack_value,defense,maxi(0,SkillRules.magic_resist_value(target,td)-shot.resist_ignore),shot.damage_type,SkillRules.dodge_chance(target,td,shot.damage_type),state.rng,SkillRules.damage_profession_id(data),damage_taken,state._magical_damage_taken_percent(target),shot.minimum_percent)
	var landed:=state._apply_damage(target,td,damage,shot.damage_type,source,shot.attack_event)
	if landed and target.hp>0 and shot.extra_magic_attack>0:
		var extra:=Combat.calculate_damage(shot.extra_magic_attack,defense,SkillRules.magic_resist_value(target,td),"magical",SkillRules.dodge_chance(target,td,"magical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
		state._apply_damage(target,td,extra,"magical",source)
	if landed and first_skill_hit:
		state.attack_skill_hits.append(PackedInt32Array([shot.source_id,shot.skill_use,target.unit_id]))
		if source.hp>0 and source.skill_activation_count==shot.skill_use and target.unit_id not in source.skill_hit_ids:source.skill_hit_ids.append(target.unit_id)
		if shot.first_hit_slow_ticks>0:StatusRules.add_control(state,target,"slow",shot.first_hit_slow_ticks,source)
	if landed and target.hp>0:
		if shot.shell_ticks>0:target.shell_defense_reduce=shot.shell_defense_reduce;target.shell_ticks_left=shot.shell_ticks
		if shot.stun_ticks>0:SwordRules.stun(state,target,shot.stun_ticks,source)
		if shot.slow_ticks>0:StatusRules.add_control(state,target,"slow",shot.slow_ticks,source)
		if shot.bind_ticks>0:StatusRules.add_control(state,target,"bind",shot.bind_ticks,source)
		if shot.armor_ticks>0:target.armor_break_ticks_left=shot.armor_ticks;target.armor_break_defense_percent=shot.armor_remaining_percent
		if shot.typewriter_ticks>0:target.typewriter_defense_until_tick=state.tick+shot.typewriter_ticks;target.typewriter_defense_remaining_percent=shot.typewriter_remaining_percent
		if shot.shift_force>=0:
			var marker:=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0,0,0,shot.facing)
			DisplacementRules.apply_unit(state,marker,target,DisplacementRules.direction(marker,target.cell,"pull" if shot.shift_pull else "push"),shot.shift_force)
		if not shot.silenced and data.talent_1.effect_type=="lord_neurotoxin":
			var params:=data.talent_1.effect_params
			if target.thorns_poison_until_tick<=state.tick:target.thorns_poison_next_tick=state.tick+state.CONFIG.TICK_RATE
			target.thorns_poison_until_tick=state.tick+int(params.duration_ticks);target.thorns_poison_source_id=shot.source_id
			var ranged:=td.profession_id in ["sniper","caster","medic","supporter"] or td.branch_trait.effect_type in ["ranged_attack","summoner"]
			target.thorns_poison_damage=int(params.ranged_damage if ranged else params.damage)
		if not shot.silenced and data.talent_1.effect_type=="attack_silence":StatusRules.apply_silence(state,target,int(data.talent_1.effect_params.duration_ticks))
		if shot.armor_break:
			target.armor_break_ticks_left=int(data.talent_1.effect_params.duration_ticks);target.armor_break_defense_percent=int(data.talent_1.effect_params.defense_remaining_percent)
		if data.branch_trait.effect_type=="slow_on_hit":StatusRules.add_control(state,target,"slow",roundi(float(data.branch_trait.effect_params.slow_duration)*state.CONFIG.TICK_RATE))
		if shot.active and skill.effect_type=="charge_shot":StatusRules.add_control(state,target,"bind",roundi(float(skill.effect_params.bind_duration)*state.CONFIG.TICK_RATE))
		if shot.active and skill.effect_type=="shift_attack":
			var marker:=UnitState.new(shot.source_id,shot.source_side,shot.operator_id,shot.source_cell,0,0,0,shot.facing)
			DisplacementRules.apply_unit(state,marker,target,DisplacementRules.direction(marker,target.cell,skill.effect_params.shift_mode),int(skill.effect_params.shift_force));AuraRules.refresh(state)
	if target.hp>0 and not shot.silenced and data.talent_1.effect_type=="defense_damage":
		var extra:=roundi(SkillRules.defense_value(target,td)*int(data.talent_1.effect_params.defense_damage_percent)/100.0)
		if extra>0:
			var extra_damage:=Combat.calculate_damage(extra,0,SkillRules.magic_resist_value(target,td),"magical",SkillRules.dodge_chance(target,td,"magical"),state.rng,SkillRules.damage_profession_id(data),state._damage_taken_percent(target,"magical"),state._magical_damage_taken_percent(target))
			state._apply_damage(target,td,extra_damage,"magical")
