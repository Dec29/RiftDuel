class_name CommandRules
extends RefCounted


static func apply(state: MatchState, cmd_a: Array[InputCommand], cmd_b: Array[InputCommand], new_guard_units: Array[UnitState], new_burst_units: Array[UnitState]) -> void:
	var commands_by_side := [cmd_a, cmd_b]
	for side in 2:
		for command in commands_by_side[side]:
			assert(command.tick == state.input_tick, "command tick does not match MatchState.tick")
			if command.kind == InputCommand.Kind.SKIP_RECOVERY or (command.kind == InputCommand.Kind.RECOVERY_DEPLOY and state.recovery_side < 0): continue
			if command.kind in [InputCommand.Kind.DEPLOY, InputCommand.Kind.RECOVERY_DEPLOY]:
				assert(state._operator_data.has(command.operator_id), "unknown operator_id")
				assert(command.facing >= -1 and command.facing <= 3, "unknown deployment facing")
				var deploy_data := state._operator_data[command.operator_id] as OperatorData
				var is_phantom: bool = command.operator_id == state.PHANTOM_DATA.operator_id
				var is_clone: bool = command.operator_id == state.CLONE_DATA.operator_id
				var is_cannon: bool = command.operator_id == state.CANNON_DATA.operator_id
				var is_reconstruction: bool=command.operator_id=="mon3tr_reconstruction"
				var is_flow: bool=command.operator_id=="flowing_shape"
				var is_jessica_shield: bool=command.operator_id=="jessica_shield"
				var is_silence_drone: bool=command.operator_id=="silence_alter_drone"
				var is_wolf: bool=command.operator_id=="vigil_wolf"
				var is_stainless: bool=command.operator_id in StainlessRules.IDS
				var is_typewriter: bool = command.operator_id=="pozyomka_typewriter"
				var is_doll: bool=command.operator_id=="curse_doll"
				var is_medical: bool=command.operator_id=="medical_drone"
				var is_seaborn: bool = command.operator_id=="seaborn"
				var is_mon3tr: bool = command.operator_id=="mon3tr"
				var is_ling: bool = command.operator_id in LingRules.IDS
				var is_drone: bool = command.operator_id in state.DRONE_IDS
				if not is_stainless and not is_flow and not is_jessica_shield and not is_reconstruction and not is_ling and not is_typewriter and not is_wolf and not is_silence_drone and not is_doll and not is_medical and not is_phantom and not is_clone and not is_cannon and not is_drone and not is_mon3tr and not is_seaborn and command.operator_id not in state.squad_ids[side]:
					continue
				if (state.phantom_can_deploy(side, command.cell) if is_phantom else (state.clone_can_deploy(side, command.cell) if is_clone else state.can_deploy(side, command.operator_id, command.cell))):
					var paid_cost := 0 if command.operator_id=="ines" and state.carried_skill_index(side,"ines")==2 and not state.sides[side].ines_first_shadow_used else DeployRules.actual_cost(deploy_data, state.sides[side])
					var unit := UnitState.new(
						state.next_unit_id,
						side,
						command.operator_id,
						command.cell,
						deploy_data.max_health,
						deploy_data.skills[state.carried_skill_index(side, command.operator_id)].initial_sp,
						roundi(deploy_data.attack_interval * state.CONFIG.TICK_RATE),
						command.facing,
						state.carried_skill_index(side, command.operator_id),
					)
					unit.deployed_tick = state.tick
					if unit.operator_id=="fiammetta":unit.fiammetta_vigor_percent=50
					if deploy_data.talent_1.effect_type=="texas_tradition":TexasAlterRules.deployed(state,unit,deploy_data)
					if deploy_data.talent_1.effect_type=="penance_barrier":unit.penance_barrier_hp=-1
					if deploy_data.talent_1.effect_type=="regenerating_shield":unit.nian_shield_layers=int(deploy_data.talent_1.effect_params["initial_layers"])
					if command.operator_id=="sussurro":unit.limited_skill_uses=state.sides[side].sussurro_skill_uses
					if deploy_data.talent_1.effect_type=="deployment_fortune":unit.fortune_choice=state.rng.next_u32()%3
					if deploy_data.skills[unit.skill_index].effect_type=="red_execute":unit.skill_ticks_left=roundi(deploy_data.skills[unit.skill_index].duration*state.CONFIG.TICK_RATE);unit.launch_started_tick=state.tick
					if deploy_data.skills[unit.skill_index].effect_type=="red_wolf":new_burst_units.append(unit)
					if deploy_data.skills[unit.skill_index].effect_type in ["gravel_defense","gravel_barrier"]:
						unit.gravel_ticks_left=int(deploy_data.skills[unit.skill_index].effect_params["decay_ticks"])
						if deploy_data.skills[unit.skill_index].effect_type=="gravel_barrier":new_guard_units.append(unit)
					if deploy_data.talent_2.effect_type=="shield_break_sp":unit.nian_shield_layers=int(deploy_data.talent_2.effect_params["shield_count"])
					if deploy_data.talent_2.effect_type=="deploy_shield_layers":unit.nian_shield_layers=int(deploy_data.talent_2.effect_params["shield_count"])
					if deploy_data.skills[unit.skill_index].effect_type == "deploy_atk_boost":
						unit.skill_ticks_left = roundi(deploy_data.skills[unit.skill_index].duration * state.CONFIG.TICK_RATE)
					if deploy_data.skills[unit.skill_index].effect_type == "champagne_traps":
						unit.bomb_next_tick = state.tick + int(deploy_data.skills[unit.skill_index].effect_params["first_plant_ticks"])
					if deploy_data.skills[unit.skill_index].effect_type in ["passive_heal", "champagne_traps"]:
						unit.coins = mini(int(deploy_data.skills[unit.skill_index].effect_params["coin_limit"]), int(deploy_data.talent_1.effect_params["initial_coins"]))
						unit.last_coin_gain_tick = state.tick
					if deploy_data.skills[unit.skill_index].effect_type == "deploy_physical_shield":
						new_guard_units.append(unit)
					if deploy_data.skills[unit.skill_index].effect_type == "deploy_attack_stacks":
						unit.attack_boost_stacks = int(deploy_data.skills[unit.skill_index].effect_params["stack_count"])
					if deploy_data.skills[unit.skill_index].effect_type == "deploy_control_burst":
						new_burst_units.append(unit)
					if is_stainless:StainlessRules.deployed(state,unit)
					elif is_flow:
						TacticianRules.deployed(state,unit)
					elif is_jessica_shield:
						SentinelRules.deployed(state,unit)
					elif is_reconstruction:
						MonstrMedicRules.deployed(state,unit)
					elif is_silence_drone:
						var owner := SilenceAlterRules.drone_owner(state,side)
						unit.silence_drone_owner_id=owner.unit_id;owner.silence_drone_stock-=1
						state.sides[side].cooldowns["silence_alter_drone"]=150
					elif is_wolf:
						VigilRules.deployed(state,unit)
					elif is_typewriter:
						PozyomkaRules.deployed(state,unit)
					elif is_doll:
						var source := CurseDollRules.owner(state,side)
						unit.curse_doll_owner_id=source.unit_id;source.curse_doll_stock-=1
						state.sides[side].cooldowns["curse_doll"]=roundi(deploy_data.redeploy_time*state.CONFIG.TICK_RATE)
					elif is_medical:
						var owner := MedicalDroneRules.owner(state,side)
						unit.medical_drone_owner_id=owner.unit_id;owner.medical_drone_stock-=1
						state.sides[side].cooldowns["medical_drone"]=150
					elif is_seaborn:
						unit.bard_owner_id=BardRules.owner(state,side).unit_id
					elif is_mon3tr:
						unit.mon3tr_owner_id=Mon3trRules.owner(state,side).unit_id
					elif is_drone:
						unit.drone_owner_id=DroneRules.owner(state,side).unit_id
						state.sides[side].drone_stock-=1
						state.sides[side].drone_cooldown_ticks=roundi(deploy_data.redeploy_time*state.CONFIG.TICK_RATE)
					elif is_ling:
						pass # Ledger/cooldown and merge need the new unit appended first.
					elif is_cannon:
						pass # Independent cooldown starts on exit, never deployment.
					elif is_clone:
						state.sides[side].clone_cooldown_ticks = roundi((state.CLONE_DATA.redeploy_time - int(state.CLONE_DATA.talent_2.effect_params["reduction_seconds"])) * state.CONFIG.TICK_RATE)
					elif is_phantom:
						state.sides[side].phantom_count -= 1
						state.sides[side].phantom_cooldown_ticks = roundi(state.PHANTOM_DATA.redeploy_time * state.CONFIG.TICK_RATE)
					else:
						if deploy_data.group_id=="rhine" and state.sides[side].rhine_cost_reduction>0:state.sides[side].rhine_first_discount_used=true
						state.sides[side].next_deploy_discount = 0
						for talent in [deploy_data.talent_1, deploy_data.talent_2]:
							if talent.effect_type == "next_deploy_discount":
								state.sides[side].next_deploy_discount = int(talent.effect_params["deploy_cost_reduction"])
							if talent.effect_type == "random_initial_sp":
								var params: Dictionary = talent.effect_params
								var added_sp := int(params["sp_min"]) + state.rng.next_u32() % (int(params["sp_max_exclusive"]) - int(params["sp_min"]))
								unit.sp = mini(SkillRules.sp_limit(deploy_data.skills[unit.skill_index]), unit.sp + added_sp)
						var member_ids := state.squad_ids[side].duplicate()
						member_ids.sort()
						for id in member_ids:
							if not state._squad_talents_enabled(side, id): continue
							var member: OperatorData = state._operator_data[id]
							if member.talent_2.effect_type == "initial_sp_aura" and deploy_data.profession_id == member.talent_2.effect_params["profession_id"]:
								unit.sp = mini(SkillRules.sp_limit(deploy_data.skills[unit.skill_index]), unit.sp + int(member.talent_2.effect_params["initial_sp_add"]))
						if deploy_data.talent_2.effect_type == "summon_phantom":
							var params := deploy_data.talent_2.effect_params
							state.sides[side].phantom_count = mini(int(params["stock_limit"]), state.sides[side].phantom_count + int(params["stock_per_deploy"]))
					state.next_unit_id += 1
					state.units.append(unit)
					if deploy_data.talent_1.effect_type=="sniper_support":state.sides[side].sniper_cost_discount=maxi(state.sides[side].sniper_cost_discount,int(deploy_data.talent_1.effect_params["cost_reduction"]))
					state.sides[side].cost -= paid_cost
					VanguardDefenderRules.deployed(state,unit,deploy_data)
					if is_ling:LingRules.deployed(state,unit)
					if unit.operator_id=="ines":InesRules.deployed(state,unit,deploy_data)
			elif command.kind == InputCommand.Kind.COPY:
				TacticianRules.copy(state,side,command.unit_id,command.operator_id,command.facing)
			elif command.kind == InputCommand.Kind.USE_ITEM:
				assert(command.item_kind in range(state.CONFIG.TACTICAL_ITEM_COUNT), "unknown tactical item kind")
				assert(command.facing in range(4) if command.item_kind == state.CONFIG.TACTICAL_ITEM_CRANE else command.facing == -1, "invalid tactical item facing")
				if not state.can_use_item(side, command.item_kind, command.cell, command.facing):
					continue
				TacticalRules.use_item(state, side, command)
			elif command.kind == InputCommand.Kind.RETREAT:
				for index in state.units.size():
					var retreating := state.units[index]
					if retreating.unit_id == command.unit_id and retreating.side == side:
						state._retreat_unit(retreating)
						break
			else:
				assert(command.kind == InputCommand.Kind.SKILL, "unknown command kind")
				for unit in state.units:
					if unit.unit_id == command.unit_id and unit.side == side:
						var operator := state._operator_data[unit.operator_id] as OperatorData
						if unit.operator_id!="pozyomka_typewriter" and command.skill_index == unit.skill_index and SkillRules.can_manually_activate(unit, operator.skills[unit.skill_index]):
							var skill := operator.skills[unit.skill_index]
							if unit.operator_id=="stainless":StainlessRules.cast(state,unit,operator)
							elif unit.operator_id=="mon3tr_operator":
								MonstrMedicRules.cast(state,unit,operator)
							elif unit.operator_id=="ling":LingRules.cast(state,unit,operator)
							elif unit.operator_id=="titi":TitiRules.cast(state,unit,operator)
							elif unit.operator_id in GuardSpecialistRules.IDS:
								GuardSpecialistRules.cast(state,unit,operator)
							elif unit.operator_id in ["muelsyse","flowing_shape"]:TacticianRules.cast(state,unit,operator)
							elif unit.operator_id=="jessica_alter":SentinelRules.cast(state,unit,operator)
							elif unit.operator_id=="gnosis":
								GnosisRules.cast(state,unit,operator)
							elif unit.operator_id=="silence_alter":
								SilenceAlterRules.cast(state,unit,operator)
							elif unit.operator_id=="vigil":VigilRules.cast(state,unit,operator)
							elif unit.operator_id=="goldenglow":
								GoldenglowRules.cast(state,unit,operator)
							elif unit.operator_id=="chen_alter":
								ChenAlterRules.cast(state,unit,operator)
							elif unit.operator_id=="fiammetta":
								FiammettaRules.cast(state,unit,operator)
							elif unit.operator_id=="pozyomka":
								PozyomkaRules.cast(state,unit,operator)
							elif unit.operator_id=="lee":
								LeeRules.cast(state,unit,operator)
							elif unit.operator_id in MedicAlterRules.IDS:
								MedicAlterRules.cast(state,unit,operator)
							elif operator.talent_1.effect_type=="penance_barrier":
								PenanceRules.cast(state,unit,operator)
							elif operator.talent_2.effect_type=="sleep_mercy":
								BlemishineRules.cast(state,unit,operator)
							elif operator.talent_1.effect_type=="glass_wall":
								LinRules.cast(state,unit,operator)
							elif operator.talent_1.effect_type=="charged_skill_heal":
								PhalanxRules.cast(state,unit,operator)
							elif operator.talent_1.effect_type=="sniper_offensive_sp":
								ArchettoRules.cast(state,unit,operator)
							elif unit.operator_id in ClassicOperatorRules.IDS:
								ClassicOperatorRules.cast(state,unit,operator)
							elif skill.effect_type=="pull_chain":
								CliffheartRules.cast(state,unit,operator)
							elif skill.effect_type in ["bard_sleep","bard_song"]:
								SoraRules.activate(state,unit,operator)
							elif skill.effect_type=="defense_shell":
								MeteoriteRules.cast(state,unit,operator)
							elif skill.effect_type=="texas_sword_rain":
								TexasRules.activate(state,unit,operator)
							elif skill.effect_type in ["bard_share","bard_tide"]:
								BardRules.activate(state,unit,operator)
							elif skill.effect_type in ["lumen_cleanse","lumen_lamp"]:
								LumenRules.activate(state,unit,operator)
							elif skill.effect_type=="saga_purge":
								SagaRules.activate_purge(state,unit,operator)
							elif skill.effect_type in ["w_grenade","w_marks"]:
								WArtilleryRules.activate(state,unit,operator)
							elif skill.effect_type in ["kaltsit_guard","kaltsit_tactical","kaltsit_meltdown"]:
								Mon3trRules.activate(state,unit,operator)
							elif skill.effect_type in ["aak_defense","aak_offense"]:
								AakRules.activate(state,unit,operator)
							elif skill.effect_type in ["sword_draw","sword_slashes"]:
								SwordRules.activate(state,unit,operator)
							elif skill.effect_type == "marked_arrow_rain":
								if unit.skill_ticks_left != 0:SiegeRules.close_skill(unit,operator)
								elif SiegeRules.mark_target(state,unit,operator):SkillRules.activate(unit,operator)
							elif skill.effect_type == "coin_barrage":
								unit.skill_ticks_left = 0
								unit.coin_firing = unit.coins > 0
								unit.coin_fire_ticks_left = 0
								unit.coin_target_ids.clear()
								var front := unit.cell + state.ATTACK_RANGE.rotate_offset(Vector2i.RIGHT,unit.facing)
								for enemy in state.units:
									if state.enemy_is_targetable(side, enemy) and enemy.cell == front:
										unit.coin_target_ids.append(enemy.unit_id)
							elif unit.skill_ticks_left != 0 and skill.effect_type in ["fortress_ammo", "fortress_overload"]:
								if skill.effect_type == "fortress_ammo" and unit.skill_ammo_left <= int(skill.effect_params["overload_ammo"]):
									unit.skill_dump_pending = true
								else:
									FortressRules.close_skill(state, unit, operator)
							else:
								SkillRules.activate(unit, operator)
								if unit.operator_id in LaunchOperatorRules.IDS:LaunchOperatorRules.started(state,unit,operator)
								if skill.effect_type=="ptilopsis_healing":unit.ptilopsis_skill_tick=state.tick
								if skill.effect_type=="cuora_shell":unit.cuora_started_tick=state.tick
								if skill.effect_type in ["flag_heal", "flag_burst"]:
									FlagRules.activate(state, unit, skill, side)
						break
