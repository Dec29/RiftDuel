class_name UnitInfo
extends RefCounted


static func draw(view: MatchView, selected: UnitState, own_color: Color, enemy_color: Color) -> void:
	if view._hud_visible():
		var hud := view._hud_origin()
		var enemy := selected != null and selected.side != view._local_input.side
		view.draw_rect(view._hud_rect(), Color(MatchView.PALETTE.HUD_SURFACE, 0.8))
		view.draw_rect(Rect2(hud, Vector2(4, view._hud_rect().size.y)), enemy_color if enemy else own_color)
		view._draw_text(hud + Vector2(20,30), "战术道具" if view._local_input.selected_item_kind >= 0 else ("敌方干员 · 作战信息" if enemy else "作战指令"),14,MatchView.PALETTE.MUTED_TEXT)
		var action := "拖动卡片部署"
		var cancel := "关闭信息"
		var ready := false
		if view._local_input.selected_item_kind >= 0:
			var kind := view._local_input.selected_item_kind
			view._draw_text(hud+Vector2(20,82),MatchView.ITEM_NAMES[kind],22,MatchView.PALETTE.TEXT)
			view._draw_text(hud+Vector2(20,110),"战术道具 · 免费",14,MatchView.PALETTE.ARROW)
			for i in MatchView.ITEM_DESCRIPTIONS[kind].size():
				view._draw_text(hud+Vector2(20,140+i*22),MatchView.ITEM_DESCRIPTIONS[kind][i],14,MatchView.PALETTE.MUTED_TEXT)
			action="确认起重机朝向" if view._deploy_phase==MatchView.DeployPhase.FACING else ("拖动到本方空域使用" if kind == MatchView.CONFIG.TACTICAL_ITEM_SUPPORT_DRONE else "拖动到合法地面使用")
		else:
			var operator: OperatorData = view._operator_data[selected.operator_id if selected != null else view._local_input.selected_operator_id]
			var skill := operator.skills[selected.skill_index if selected != null else view._state.carried_skill_index(view._local_input.side,operator.operator_id)]
			view._draw_text(hud+Vector2(20,64),operator.display_name,22,MatchView.PALETTE.TEXT)
			var attack := SkillRules.attack_value(selected,operator) if selected != null else operator.attack
			var defense := SkillRules.defense_value(selected,operator) if selected != null else operator.defense
			var resist := SkillRules.magic_resist_value(selected,operator) if selected != null else operator.magic_resist
			var block := SkillRules.block_count_value(selected,operator) if selected != null else operator.block_count
			var attributes := ["攻击 %d"%attack,"防御 %d"%defense,"法抗 %d%%"%resist,"阻挡 %d"%block]
			for index in attributes.size():
				view._draw_text(hud+Vector2(20+index*(MatchView.PALETTE.HUD_WIDTH-40)/4.0,156),attributes[index],12,MatchView.PALETTE.MUTED_TEXT)
			if selected==null:
				view._draw_text(hud+Vector2(20,90),"%s · 部署费用 %d"%[operator.profession,view._state.deploy_cost(view._local_input.side,operator.operator_id)],15,MatchView.PALETTE.TEXT)
				view._draw_text(hud+Vector2(20,126),"未部署 · 拖动卡片部署",14,MatchView.PALETTE.MUTED_TEXT)
				var cooldowns: Dictionary = view._state.sides[view._local_input.side].cooldowns
				action="拖动卡片部署" if view._operator_available(operator) else ("再部署冷却 %.1f 秒"%(float(cooldowns[operator.operator_id])/MatchView.CONFIG.TICK_RATE) if cooldowns.has(operator.operator_id) else "当前不可部署")
				if operator.operator_id=="phantom_clone" and view._state.sides[view._local_input.side].clone_cooldown_ticks>0:
					action="独立部署冷却 %.1f 秒"%(float(view._state.sides[view._local_input.side].clone_cooldown_ticks)/MatchView.CONFIG.TICK_RATE)
				if operator.operator_id=="weedy_cannon" and view._state.sides[view._local_input.side].cannon_cooldown_ticks>0:
					action="独立部署冷却 %.1f 秒"%(float(view._state.sides[view._local_input.side].cannon_cooldown_ticks)/MatchView.CONFIG.TICK_RATE)
				if operator.operator_id in MatchState.DRONE_IDS and view._state.sides[view._local_input.side].drone_cooldown_ticks>0:
					action="无人机部署冷却 %.1f 秒"%(view._state.sides[view._local_input.side].drone_cooldown_ticks/float(MatchView.CONFIG.TICK_RATE))
			else:
				var max_health := SkillRules.max_health_value(selected,operator)
				var barrier_health := selected.gravel_barrier_hp
				for health in selected.barrier_hp:barrier_health+=health
				var health_text := "生命  %d / %d"%[selected.hp,max_health]
				if barrier_health>0:health_text+=" · 屏障 %d"%barrier_health
				view._draw_text(hud+Vector2(20,90),health_text,15,MatchView.PALETTE.TEXT)
				var health := Rect2(hud+Vector2(20,100),Vector2(MatchView.PALETTE.HUD_WIDTH-40,4))
				view.draw_rect(health,MatchView.PALETTE.HUD_RULE)
				view.draw_rect(Rect2(health.position,Vector2(health.size.x*float(selected.hp)/max_health,4)),MatchView.PALETTE.RED if enemy else MatchView.PALETTE.BLUE)
				var status := "技力  %d / %d"%[selected.sp,SkillRules.sp_limit(skill) if skill.effect_type=="lumen_cleanse" else skill.sp_required]
				if view._skill_bar_uses_coins(selected,skill):
					status="金币  %d / %d"%[selected.coins,int(skill.effect_params["coin_limit"])]
				elif skill.effect_type in ["gravel_defense","gravel_barrier"]:status="部署防护 %.1f秒"%(selected.gravel_ticks_left/30.0) if selected.gravel_ticks_left>0 else "部署防护已结束"
				elif skill.effect_type=="red_wolf":status="部署范围攻击 · 已释放"
				elif skill.effect_type=="red_execute":status="部署强化 · 剩余 %.1f秒"%(selected.skill_ticks_left/30.0) if selected.skill_ticks_left>0 else "部署强化 · 已结束"
				elif skill.effect_type=="no_skill" and operator.operator_id!="nightingale_phantom":status="本体控制 · 无独立技能"
				elif skill.effect_type=="passive_thorns":status="荆棘 · 常驻反伤"
				elif skill.effect_type=="deploy_attack_stacks":status="强化层数 %d / %d"%[selected.attack_boost_stacks,int(skill.effect_params["stack_count"])]
				elif skill.effect_type=="deploy_control_burst":status="部署突袭已释放"
				elif skill.effect_type=="deploy_atk_boost":status="跃浪击 · 剩余 %.1f 秒"%(float(selected.skill_ticks_left)/MatchView.CONFIG.TICK_RATE) if selected.skill_ticks_left>0 else "跃浪击 · 已结束"
				elif skill.effect_type=="deploy_physical_shield":status="物盾 %d · 物闪 %d%%"%[selected.physical_shield_hp,int(skill.effect_params["dodge_physical_add"]) if selected.silence_ticks_left==0 and selected.physical_guard_ticks_left>0 else 0]
				elif operator.operator_id=="nightingale_phantom":status="嘲讽 +%d · 物理闪避 %d%%"%[int(operator.branch_trait.effect_params["taunt_level"]),operator.dodge_physical]
				elif selected.skill_ticks_left!=0 and skill.effect_type in ["marked_arrow_rain","lumen_lamp","jessica_bombardment"]:status="弹药  %d / %d"%[selected.skill_ammo_left,int(skill.effect_params["ammo_count"])]
				elif selected.skill_ticks_left==-2 and skill.effect_type!="stance_defense_regen":status="持续无限"
				elif selected.skill_ticks_left>0:status="持续时间  %.1f / %.0f 秒"%[maxf(0.0,selected.skill_ticks_left-view._simulation_fraction())/MatchView.CONFIG.TICK_RATE,skill.duration]
				if selected.operator_id=="flowing_shape":
					if selected.flow_is_split:status="分裂流形 · 无独立技能"
					elif selected.flow_point_until_tick>0:status="战术点 · 刷新等待中"
					elif selected.skill_ticks_left>0:status="复制窗口 %.1f秒 · 点亮框卡片复制"%(selected.skill_ticks_left/30.0)
				view._draw_text(hud+Vector2(20,126),status,15,MatchView.PALETTE.TEXT)
				if skill.effect_type!="no_skill" and not (selected.operator_id=="flowing_shape" and (selected.flow_is_split or selected.flow_point_until_tick>0)):
					var progress := Rect2(hud+Vector2(20,136),Vector2(MatchView.PALETTE.HUD_WIDTH-40,4))
					view.draw_rect(progress,MatchView.PALETTE.HUD_RULE)
					view.draw_rect(Rect2(progress.position,Vector2(progress.size.x*view._skill_bar_ratio(selected,skill),4)),view._skill_bar_color(selected,skill))
				var notes := PackedStringArray()
				if selected.critical_ticks_left>0:notes.append("重伤 %.1f秒 · 攻速-80%% · 禁止治疗"%(selected.critical_ticks_left/30.0))
				if selected.lumen_resistance_ticks>0:notes.append("抵抗 %.1f秒"%(selected.lumen_resistance_ticks/30.0))
				if selected.sleep_ticks_left>0:notes.append("沉睡 %.1f秒 · 无敌／不能行动或阻挡"%(selected.sleep_ticks_left/30.0))
				if selected.cold_ticks_left>0:notes.append("寒冷 %.1f秒 · 攻速-30"%(selected.cold_ticks_left/30.0))
				if selected.frozen_ticks_left>0:notes.append("冻结 %.1f秒 · 禁普攻/新开技能 · 阻挡0/法抗-15"%(selected.frozen_ticks_left/30.0))
				if selected.operator_id=="mon3tr_reconstruction":notes.append("每秒流失80生命 · 仅本体链式治疗")
				if MonstrMedicRules.transformed(selected):notes.append("近战形态 · 结束返回预留格")
				if selected.operator_id=="ling":notes.append("召唤库存%d/5 · 场上额度%d/3"%[view._state.sides[selected.side].ling_stock,LingRules.weighted_count(view._state,selected.side)])
				if selected.operator_id in LingRules.IDS:notes.append("高级形态 · 占两份额度" if selected.ling_advanced else "普通形态 · 占一份额度")
				if selected.operator_id=="stainless":notes.append("装置库存%d/3 · 场上上限2"%view._state.sides[selected.side].stainless_stock)
				if selected.operator_id=="stainless_cannon":notes.append("友军命中充能%d/5 · 仅工匠攻击修复"%selected.sp)
				if selected.operator_id=="jessica_shield":notes.append("盾牌寿命 %.1f秒 · 不可直接治疗"%(maxi(0,selected.jessica_expiry_tick-view._state.tick)/30.0))
				if selected.operator_id=="flowing_shape":
					if selected.flow_point_until_tick>0:notes.append("战术点 · %.1f秒后刷新"%(maxi(0,selected.flow_point_until_tick-view._state.tick)/30.0))
					elif selected.flow_is_split:notes.append("分裂体寿命 %.1f秒 · 无复制技能"%(maxi(0,selected.flow_expiry_tick-view._state.tick)/30.0))
					elif not selected.flow_copy_id.is_empty():notes.append("已复制：%s"%(view._operator_data[selected.flow_copy_id] as OperatorData).display_name)
				if selected.operator_id=="vigil_wolf":notes.append("狼影 %d/3 · 恢复 %.1f秒"%[selected.vigil_wolf_layers,maxi(0,selected.vigil_regrow_tick-view._state.tick)/30.0])
				if selected.operator_id=="pozyomka_typewriter":notes.append("打字机寿命 %.1f秒 · 不可受伤"%(maxi(0,750-view._state.tick+selected.deployed_tick)/30.0))
				if selected.operator_id=="silence_alter_drone":notes.append("3倍天赋庇护 · 随本体技能结束离场")
				if selected.operator_id=="silence_alter" and selected.skill_index==2:notes.append("协议已用 %d/2 · 本轮保护%s"%[view._state.sides[selected.side].silence_protocol_uses,"已触发" if selected.silence_grave_used else "未触发"])
				if selected.silence_grave_until_tick>view._state.tick:notes.append("濒死保护 %.1f秒"%((selected.silence_grave_until_tick-view._state.tick)/30.0))
				if selected.eyja_elemental_barrier>0:notes.append("元素屏障 %d · 当前无元素伤害，不吸收生命伤害"%selected.eyja_elemental_barrier)
				if selected.eyja_mist_stacks>0:notes.append("氤氲 %d/3层"%selected.eyja_mist_stacks)
				if selected.reed_cinder_source_id>=0:notes.append("灼痕 · 攻击-20%/法术脆弱30%")
				if selected.lee_control_charm:notes.append("却邪护符 · 抵消下次眩晕/冻结并反晕")
				if selected.operator_id=="curse_doll":notes.append("娃娃剩余 %.1f秒 · 不攻击／不挡球／不可受伤"%(maxi(0,450-view._state.tick+selected.deployed_tick)/30.0))
				if selected.operator_id=="shamare" and selected.skill_index==1:notes.append("娃娃库存 %d/1 · 满库存阻回"%selected.curse_doll_stock)
				if selected.operator_id=="sussurro" and selected.skill_index==1:notes.append("本局已使用 %d/2"%selected.limited_skill_uses)
				if selected.operator_id=="mudrock":notes.append("剩余护盾 %d/3"%selected.nian_shield_layers)
				if selected.fatal_until_tick>view._state.tick:notes.append("余烬退场倒计时 %.1f秒"%((selected.fatal_until_tick-view._state.tick)/30.0))
				if selected.operator_id=="medical_drone":notes.append("探机寿命 %.1f秒 · 不阻挡／不可受伤"%(maxi(0,300-view._state.tick+selected.deployed_tick)/30.0))
				if selected.operator_id=="silence" and selected.skill_index==1:notes.append("探机库存 %d/1 · 满库存阻回"%selected.medical_drone_stock)
				if selected.operator_id=="seaborn":notes.append("海嗣寿命 %.1f秒 · 不攻击／不阻挡／不可受伤"%(maxi(0,750-view._state.tick+selected.deployed_tick)/30.0))
				if skill.effect_type=="lumen_cleanse":notes.append("蓄力完成 · 解除眩晕／沉默／束缚／停顿" if selected.sp>=SkillRules.sp_limit(skill) else "二倍技力时蓄力")
				if selected.nian_shield_layers>0 and selected.operator_id!="mudrock":notes.append("护盾 %d层"%selected.nian_shield_layers)
				if selected.operator_id=="mon3tr":notes.append("治疗仅限凯尔希 · 范围外防御0" if selected.mon3tr_outside_range else "治疗仅限凯尔希 · 本体范围内")
				if selected.dodge_magical_bonus>0:notes.append("法术闪避 %d%%"%SkillRules.dodge_chance(selected,operator,"magical"))
				if skill.effect_type in ["chain_storm","percent_charge_heal","ambush_charge","guardian_aid", "pioneer_hammer", "flame_charge", "charge_shot","fortress_charge_shot","heal_barrier","heal_magic_barrier","charge_multi_shot","charge_magic_splash","saga_purge","lumen_cleanse"]:notes.append("充能 %d / %d"%[selected.sp/skill.sp_required,int(skill.effect_params["charge_count"])])
				if skill.effect_type=="passive_heal":notes.append("攻击 +%d%% · 单次治疗 %d"%[selected.coin_attack_stacks*int(operator.talent_1.effect_params["attack_percent_per_stack"]),SkillRules.healing_output(selected,Combat.calculate_healing(attack,int(skill.effect_params["heal_percent"])))])
				if operator.talent_2.effect_type=="bloodbath":notes.append("血战已触发 · 生命上限50%" if selected.bloodbath_used else "血战 · 本次部署尚未触发")
				if selected.operator_id=="weedy_cannon":notes.append("装置寿命 %.1f秒"%(maxi(0,int(operator.branch_trait.effect_params["lifetime_ticks"])-view._state.tick+selected.deployed_tick)/float(MatchView.CONFIG.TICK_RATE)))
				if selected.rupture_until_tick>view._state.tick:notes.append("移动创伤 %.1f秒"%((selected.rupture_until_tick-view._state.tick)/float(MatchView.CONFIG.TICK_RATE)))
				if selected.operator_id in MatchState.DRONE_IDS:
					var hidden := DroneRules.hidden_ticks_left(view._state,selected)
					if hidden>0:notes.append("隐匿 %.1f秒 · %s"%[hidden/float(MatchView.CONFIG.TICK_RATE),"已被反隐" if view._state.enemy_is_targetable(1-selected.side,selected) else "不可直接选中"])
				var note := " · ".join(notes)
				view._draw_text(hud+Vector2(20,174),note,mini(12,int(12*(MatchView.PALETTE.HUD_WIDTH-40)/maxf(1,ThemeDB.fallback_font.get_string_size(note,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x))),MatchView.PALETTE.MUTED_TEXT)
				ready=SkillRules.can_manually_activate(selected,skill) and not enemy
				action=("技能就绪" if enemy else "释放技能 · %s / 点击"%view.hotkey_label("skill")) if SkillRules.can_manually_activate(selected,skill) else "技力回复中"
				if skill.effect_type=="deploy_attack_stacks":action="攻击强化 · 剩余%d层"%selected.attack_boost_stacks
				elif skill.effect_type=="deploy_control_burst":action="部署突袭 · %s"%["停顿","束缚","眩晕"][selected.deploy_control_kind]
				elif skill.effect_type=="passive_heal":action="被动治疗 · 自动消耗金币"
				elif skill.effect_type=="champagne_traps":action="自动布置香槟炸弹"
				elif skill.effect_type=="red_wolf":action="部署被动 · 已释放，无需手动"
				elif skill.effect_type=="red_execute":action="部署被动 · 剩余 %.1f秒"%(selected.skill_ticks_left/30.0) if selected.skill_ticks_left>0 else "部署被动 · 已结束"
				elif skill.effect_type=="no_skill" and operator.operator_id!="nightingale_phantom":action="本体控制 · 无独立技能"
				elif skill.effect_type in ["gravel_defense","gravel_barrier"]:action="部署被动 · 剩余 %.1f秒"%(selected.gravel_ticks_left/30.0) if selected.gravel_ticks_left>0 else "部署被动 · 已结束"
				elif skill.effect_type=="passive_thorns":action="被动防御／反伤 · 无需释放"
				elif skill.effect_type=="deploy_physical_shield":action="部署被动 · 剩余 %.1f 秒"%(float(selected.physical_guard_ticks_left)/MatchView.CONFIG.TICK_RATE)
				elif operator.operator_id=="nightingale_phantom":action="幻影 · 不攻击 / 不可治疗"
				elif skill.effect_type=="stance_defense_regen":action=("切回初始状态" if selected.skill_ticks_left==-2 else "切换防御状态") if SkillRules.can_manually_activate(selected,skill) else ("防御状态 · 技力回复中" if selected.skill_ticks_left==-2 else "技力回复中")
				elif selected.skill_ticks_left>0:action="技能生效 · 剩余 %ds"%ceili(float(selected.skill_ticks_left)/MatchView.CONFIG.TICK_RATE)
				elif selected.skill_ticks_left==-2:action="技能生效 · 持续无限"
				elif selected.skill_ticks_left==-1:action="下次攻击已强化"
				elif SkillRules.is_auto_trigger(skill):action="技能就绪" if enemy and SkillRules.can_activate(selected,skill) else "自动触发 · 技力回复中"
				if selected.skill_ticks_left!=0 and skill.effect_type in ["fortress_ammo","marked_arrow_rain","lumen_lamp","jessica_bombardment"]:action="%s · 弹药 %d/%d"%["过载倾泻" if skill.effect_type=="fortress_ammo" and selected.skill_ammo_left<=int(skill.effect_params["overload_ammo"]) else "关闭技能",selected.skill_ammo_left,int(skill.effect_params["ammo_count"])]
				elif selected.skill_ticks_left>0 and skill.effect_type=="fortress_overload":action="过载失血 · 关闭技能" if selected.skill_elapsed_ticks>=int(skill.effect_params["overload_ticks"]) else "关闭技能"
				elif skill.effect_type=="coin_barrage":action="金币发射中 · 剩余%d枚"%selected.coins if selected.coin_firing else ("投出金币 · 主动关闭" if selected.skill_ticks_left!=0 else "自动开启 · 技力回复中")
				if selected.silence_ticks_left>0:
					action="沉默 %.1f秒 · 禁止施技／效果暂停"%(float(selected.silence_ticks_left)/MatchView.CONFIG.TICK_RATE)
					ready=false
				elif selected.stun_ticks_left>0:
					action="眩晕剩余 %.1f秒 · 停攻／阻挡0"%(selected.stun_ticks_left/float(MatchView.CONFIG.TICK_RATE))
					ready=false
				elif selected.displacement_ticks_left>0:
					action="位移剩余 %.1f秒 · 停攻"%(selected.displacement_ticks_left/float(MatchView.CONFIG.TICK_RATE))
					ready=false
				if selected.operator_id=="flowing_shape":
					if selected.flow_is_split or selected.flow_point_until_tick>0:
						ready=false;action="战术点刷新中" if selected.flow_point_until_tick>0 else "分裂体 · 无独立技能"
					elif selected.skill_ticks_left>0:
						action="点击本方未在场卡片复制 · 关闭窗口" if ready else action
					elif ready:action="开启复制窗口 · 20秒"
				if enemy:
					view._draw_text(hud+Vector2(20,187),action,10,MatchView.PALETTE.ARROW)
					action="敌方干员 · 仅查看"
					cancel="不可撤退"
				else:cancel="撤退"
			if view._hud_expanded():
				var paragraphs := PackedStringArray()
				if view._info_tab==MatchView.InfoTab.TRAIT:
					paragraphs.append_array(["职业：%s / %s"%[operator.profession,operator.branch],operator.branch_trait.trait_name,operator.branch_trait.description])
				elif view._info_tab==MatchView.InfoTab.TALENT:
					for talent in [operator.talent_1, operator.talent_2]:
						if talent.talent_name.is_empty():
							continue
						var status := ("已生效" if selected != null else "部署后生效") if SkillRules.talent_is_active(talent) else ("原作无此天赋" if talent.effect_type=="none" else "本作无适用机制")
						if talent.effect_type=="initial_cost":status="编队初始化生效"
						if talent.effect_type == "status_resistance":
							var warmup_ticks := int(talent.effect_params["warmup_seconds"]) * MatchView.CONFIG.TICK_RATE
							status = "部署%.0f秒后生效" % talent.effect_params["warmup_seconds"] if selected == null else ("已生效" if view._state.tick - selected.deployed_tick >= warmup_ticks else "生效倒计时 %.1f秒" % ((warmup_ticks - view._state.tick + selected.deployed_tick) / float(MatchView.CONFIG.TICK_RATE)))
						if selected != null and selected.silence_ticks_left > 0: status = "沉默期间失效"
						paragraphs.append_array([talent.talent_name + "（%s）" % status, talent.description])
				else:
					if skill.effect_type == "no_skill":
						paragraphs.append_array(["无主动技能 / 无技力", skill.description])
					else:
						paragraphs.append_array([skill.skill_name, "自动触发" if SkillRules.is_auto_trigger(skill) else ("被动 · 部署即生效" if skill.sp_recharge_type == "passive" else "手动触发"), ("无技力消耗 · 层数耗尽或撤退后结束" if skill.effect_type == "deploy_attack_stacks" else ("无技力消耗 · 一次突袭／控制%.1f秒" % (float(skill.effect_params["control_ticks"]) / MatchView.CONFIG.TICK_RATE) if skill.effect_type == "deploy_control_burst" else ("无技力消耗 · 部署起 %.0f 秒" % skill.duration if skill.duration > 0 else "无技力消耗 · 持续至撤退"))) if skill.sp_recharge_type == "passive" else ("每次切换消耗 %d 技力" % skill.sp_required if skill.effect_type in ["stance_defense_regen","fighter_stance"] else ("技力消耗 %d · 持续无限" % skill.sp_required if skill.duration < 0 else "技力消耗 %d   持续 %.0f 秒" % [skill.sp_required, skill.duration])), skill.description])
						if skill.effect_type=="red_wolf":paragraphs[-2]="无技力消耗 · 部署时瞬时释放"
					if selected != null:
						if skill.effect_type in ["passive_heal","champagne_traps","coin_barrage"]:
							var drain := operator.branch_trait.effect_params
							paragraphs.append("每%.0f秒扣%d费用 · 下次 %.1f秒"%[float(drain["drain_interval"]),int(drain["drain_amount"]),maxf(0.0,float(drain["drain_interval"])-(selected.cost_drain_ticks+view._simulation_fraction())/MatchView.CONFIG.TICK_RATE)])
						elif skill.effect_type in ["rapid_magic","weightless_multi_target"]:
							paragraphs.append("技能未开启 · 停攻／全队回复" if selected.skill_ticks_left==0 else ("快速法术攻击" if skill.effect_type=="rapid_magic" else "最多五目标 · 敌方重量−1"))
				if paragraphs != view._info_layout_paragraphs or view._info_layout_font != ThemeDB.fallback_font:
					view._info_layout_paragraphs = paragraphs
					view._info_layout_font = ThemeDB.fallback_font
					view._info_layout_lines.clear()
					view._info_layout_offsets.clear()
					view._info_layout_height = 0
					for paragraph in paragraphs:
						var line := ""
						for character in paragraph:
							if character == "\n" or (not line.is_empty() and ThemeDB.fallback_font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, MatchView.PALETTE.INFO_FONT_SIZE).x > MatchView.PALETTE.HUD_WIDTH - 40):
								view._info_layout_lines.append(line)
								view._info_layout_offsets.append(view._info_layout_height)
								view._info_layout_height += MatchView.PALETTE.INFO_LINE_HEIGHT
								line = ""
							if character != "\n":
								line += character
						view._info_layout_lines.append(line)
						view._info_layout_offsets.append(view._info_layout_height)
						view._info_layout_height += MatchView.PALETTE.INFO_LINE_HEIGHT + MatchView.PALETTE.INFO_PARAGRAPH_GAP
					view._info_layout_height -= MatchView.PALETTE.INFO_PARAGRAPH_GAP
				var body := view._info_body_rect()
				view._info_scroll=mini(view._info_scroll,maxi(0,view._info_layout_height-int(body.size.y)))
				view._info_scroll_display=minf(view._info_scroll_display,maxf(0,view._info_layout_height-body.size.y))
				for i in view._info_layout_lines.size():
					var y := body.position.y+17+view._info_layout_offsets[i]-view._info_scroll_display
					if y>=body.position.y+MatchView.PALETTE.INFO_FONT_SIZE and y<=body.end.y-4:
						view._draw_text(Vector2(body.position.x,y),view._info_layout_lines[i],MatchView.PALETTE.INFO_FONT_SIZE,MatchView.PALETTE.TEXT if i==0 else MatchView.PALETTE.MUTED_TEXT)
				if view._info_layout_height>body.size.y:
					var track := Rect2(Vector2(body.end.x+8,body.position.y),Vector2(2,body.size.y))
					var thumb_height := body.size.y*body.size.y/view._info_layout_height
					var thumb_y := (body.size.y-thumb_height)*view._info_scroll_display/(view._info_layout_height-body.size.y)
					view.draw_rect(track,MatchView.PALETTE.HUD_RULE)
					view.draw_rect(Rect2(track.position+Vector2(0,thumb_y),Vector2(2,thumb_height)),MatchView.PALETTE.MUTED_TEXT)
				for tab_index in [MatchView.InfoTab.SKILL,MatchView.InfoTab.TRAIT,MatchView.InfoTab.TALENT]:
					var tab := view._tab_rect(tab_index)
					view.draw_rect(tab,MatchView.PALETTE.HUD_INSET if view._info_tab==tab_index else MatchView.PALETTE.HUD_SURFACE)
					if view._info_tab==tab_index:view.draw_rect(Rect2(tab.position+Vector2(0,tab.size.y-2),Vector2(tab.size.x,2)),enemy_color if enemy else own_color)
					view._draw_text(tab.position+Vector2(12,20),{MatchView.InfoTab.SKILL:"技能",MatchView.InfoTab.TRAIT:"特性",MatchView.InfoTab.TALENT:"天赋"}[tab_index],14,MatchView.PALETTE.TEXT)
		if view._deploy_phase==MatchView.DeployPhase.FACING:
			action="确认起重机朝向" if view._local_input.selected_item_kind>=0 else "确认部署"
			ready=DeployInteraction.preview_is_legal(view)
			cancel="取消部署"
		var show_skill_action := selected==null or selected.operator_id!="flowing_shape" or (not selected.flow_is_split and selected.flow_point_until_tick==0)
		if show_skill_action:
			view.draw_rect(view._skill_rect(),MatchView.PALETTE.HUD_HOVER if ready and view._skill_rect().has_point(view._pointer_position) else MatchView.PALETTE.HUD_INSET)
			if ready:view.draw_rect(Rect2(view._skill_rect().position,Vector2(3,view._skill_rect().size.y)),own_color)
			var action_offset := 12
			if view._local_input.selected_item_kind<0 and view._deploy_phase!=MatchView.DeployPhase.FACING:
				var id: String = selected.operator_id if selected!=null else view._local_input.selected_operator_id
				var index: int = selected.skill_index if selected!=null else view._state.carried_skill_index(view._local_input.side,id)
				var icon := SkillIconVisual.texture(id,index)
				if icon!=null:
					view.draw_texture_rect(icon,Rect2(view._skill_rect().position+Vector2(6,5),Vector2.ONE*MatchView.PALETTE.SKILL_ACTION_ICON_SIZE),false,Color.WHITE if ready else Color(0.65,0.65,0.65))
					action_offset = 38
			view._draw_text(view._skill_rect().position+Vector2(action_offset,25),action,14,MatchView.PALETTE.TEXT if ready else MatchView.PALETTE.MUTED_TEXT)
		view.draw_rect(view._cancel_rect(),MatchView.PALETTE.HUD_INSET)
		view._draw_text(view._cancel_rect().position+Vector2(12,20),cancel,14,MatchView.PALETTE.MUTED_TEXT if enemy else MatchView.PALETTE.TEXT)
		for rect in [view._details_rect(),view._close_info_rect()]:view.draw_rect(rect,MatchView.PALETTE.HUD_HOVER if rect.has_point(view._pointer_position) else MatchView.PALETTE.HUD_INSET)
		view._draw_text(view._details_rect().position+Vector2(8,19),"收起" if view._hud_expanded() else "详情",12,MatchView.PALETTE.TEXT)
		view._draw_text(view._close_info_rect().position+Vector2(10,19),"×",16,MatchView.PALETTE.TEXT)
	elif view._deploy_phase == MatchView.DeployPhase.DRAGGING:
		view.draw_rect(view._cancel_rect(), MatchView.PALETTE.HUD_INSET)
		view._draw_text(view._cancel_rect().position + Vector2(10, 19), "取消", 14, MatchView.PALETTE.TEXT)
		view._draw_text(Vector2(32, 58), "战术道具" if view._local_input.selected_item_kind >= 0 else "拖动至合法格，松手后选择朝向", 14, MatchView.PALETTE.ARROW)
