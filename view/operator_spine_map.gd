class_name OperatorSpineMap
extends RefCounted

## 已接入实时骨骼的干员映射（104 名普通干员、23类可部署召唤物、W地雷与香槟瓶附属物）。
##
## 每个值都来自本轮实际解析过的素材（3.8 二进制逐模型读取），不是猜测：
##   attack_clip        整段攻击动作名（该模型没有 Begin/Loop/End 复合链时使用）
##   attack_seconds     该动作在素材中的原生时长（秒）
##   *_back             背面与正面不同名/不同时长时的覆盖值（仅当素材真的不同）
##   chain_seconds      仅当骨架真的具备 Begin/Loop/End 复合链时给出，
##                      数值为 Begin、Loop、End 三段的原生时长
##   down_clip          向下的攻击变体（仅当该模型真的有这个动作）
##
## 未登记的干员一律继续走原有几何表现；这里不做兜底、不做静默替换。

const ENTRIES := {
	"champagne_bottle":{"front":preload("res://assets/operators/champagne_bottle/single/champagne_bottle.res"),"back":preload("res://assets/operators/champagne_bottle/single/champagne_bottle.res"),"attack_clip":"Attack","attack_seconds":0.2,"idle_seconds":2.0,"deploy_seconds":20.0/30.0,"body_cell_ratio":0.5,"empty_clips":["Start","Attack"],"reset_on_clip_change":true},
	"wildmane":{"front":preload("res://assets/operators/wildmane/front/wildmane.res"),"back":preload("res://assets/operators/wildmane/back/wildmane.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0,"idle_seconds_back":1.0,"down_clip":"Attack_Down","down_seconds":1.0,"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End","down":"Skill_1_Loop_Down"},{"attack":"Skill_2","down":"Skill_2_Down"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"attack":"Skill_2"}],"animation_seconds":{"front":{"Attack":1.0,"Attack_Down":1.0,"Default":0.0,"Die":1.26666666666667,"Idle":2.0,"Skill_1_Begin":0.1,"Skill_1_End":0.1,"Skill_1_Idle":1.0,"Skill_1_Loop":1.0,"Skill_1_Loop_Down":1.0,"Skill_2":1.2,"Skill_2_Down":1.2,"Start":1.0},"back":{"Attack":1.0,"Default":0.0,"Idle":1.0,"Skill_1_Begin":0.1,"Skill_1_End":0.1,"Skill_1_Idle":1.0,"Skill_1_Loop":1.0,"Skill_2":1.2,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"gavial_alter":{"front":preload("res://assets/operators/gavial_alter/front/gavial_alter.res"),"back":preload("res://assets/operators/gavial_alter/back/gavial_alter.res"),"attack_clip":"Attack","attack_seconds":1.16666666666667,"idle_seconds":2.66666666666667,"deploy_seconds":1.0,"idle_seconds_back":2.66666666666667,"skill_actions":[{"attack":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End","down":"Skill_2_Loop_Down"},{"cast":"Skill_3"}],"skill_actions_back":[{"attack":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"cast":"Skill_3"}],"animation_seconds":{"front":{"Attack":1.16666666666667,"Default":0.0,"Die":1.0,"Idle":2.66666666666667,"Skill_1":1.16666666666667,"Skill_2_Begin":0.766666666666667,"Skill_2_End":0.4,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":1.56666666666667,"Skill_2_Loop_Down":1.56666666666667,"Skill_3":1.0,"Start":1.0},"back":{"Attack":1.16666666666667,"Default":0.0,"Idle":2.66666666666667,"Skill_1":1.16666666666667,"Skill_2_Begin":0.766666666666667,"Skill_2_End":0.4,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":1.56666666666667,"Skill_3":1.0,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"eunectes":{"front":preload("res://assets/operators/eunectes/front/eunectes.res"),"back":preload("res://assets/operators/eunectes/back/eunectes.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":3.5,"deploy_seconds":1.0,"idle_seconds_back":1.16666666666667,"down_clip":"Attack_Down","down_seconds":1.6,"skill_actions":[{},{"attack":"Skill"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End","down":"Skill_2_Loop_Down"}],"skill_actions_back":[{},{"attack":"Skill"},{}],"animation_seconds":{"front":{"Attack":1.6,"Attack_Down":1.6,"Default":0.0,"Die":1.0,"Idle":3.5,"Skill":1.6,"Skill_2_Begin":1.5,"Skill_2_Die":1.0,"Skill_2_End":0.666666666666667,"Skill_2_Idle":2.0,"Skill_2_Loop":1.5,"Skill_2_Loop_Down":1.5,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":1.16666666666667,"Skill":1.6,"Start":1.0}},"reset_on_clip_change":true,"front_only_skills":[2],"skill_idle_during_control":true},
	"chen_alter":{"front":preload("res://assets/operators/chen_alter/front/chen_alter.res"),"back":preload("res://assets/operators/chen_alter/back/chen_alter.res"),"attack_clip":"Attack","attack_seconds":2.3,"idle_seconds":2.0,"deploy_seconds":1.0,"idle_seconds_back":2.0,"down_clip":"Attack_Down","down_seconds":2.3,"skill_actions":[{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End","down":"Skill_Loop_Down"},{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End","down":"Skill_1_Loop_Down"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End","down":"Skill_2_Loop_Down"}],"skill_actions_back":[{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End"},{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"}],"animation_seconds":{"front":{"Attack":2.3,"Attack_Down":2.3,"Default":0.0,"Die":1.0,"Idle":2.0,"Skill_1_Begin":0.1,"Skill_1_Daze":0.5,"Skill_1_End":0.1,"Skill_1_Idle":1.0,"Skill_1_Loop":2.3,"Skill_1_Loop_Down":2.3,"Skill_2_Begin":0.1,"Skill_2_Daze":0.5,"Skill_2_End":0.1,"Skill_2_Idle":1.0,"Skill_2_Loop":2.3,"Skill_2_Loop_Down":2.3,"Skill_Begin":0.1,"Skill_Daze":0.5,"Skill_End":0.1,"Skill_Idle":1.0,"Skill_Loop":2.3,"Skill_Loop_Down":2.3,"Start":1.0},"back":{"Attack":2.3,"Default":0.0,"Idle":2.0,"Skill_1_Begin":0.1,"Skill_1_End":0.1,"Skill_1_Idle":1.0,"Skill_1_Loop":2.3,"Skill_2_Begin":0.1,"Skill_2_End":0.1,"Skill_2_Idle":1.0,"Skill_2_Loop":2.3,"Skill_Begin":0.1,"Skill_End":0.1,"Skill_Idle":1.0,"Skill_Loop":2.3,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"goldenglow":{"front":preload("res://assets/operators/goldenglow/front/goldenglow.res"),"back":preload("res://assets/operators/goldenglow/back/goldenglow.res"),"attack_clip":"Attack","attack_seconds":1.3,"idle_seconds":8.0,"deploy_seconds":1.0,"idle_seconds_back":8.0,"skill_actions":[{"begin":"Skill_Start","idle":"Skill_Idle","attack":"Skill_Attack","end":"Skill_End"},{"begin":"Skill2_Start","idle":"Skill2_Idle","attack":"Skill2_Loop"},{"begin":"Skill3_Start","loop":"Skill3_Loop","end":"Skill3_End"}],"skill_actions_back":[{"begin":"Skill_Start","idle":"Skill_Idle","attack":"Skill_Attack","end":"Skill_End"},{"begin":"Skill2_Start","idle":"Skill2_Idle","attack":"Skill2_Loop"},{}],"animation_seconds":{"front":{"Attack":1.3,"Attack_End":0.333333333333333,"Attack_Start":0.166666666666667,"Default":0.0,"Die":1.0,"Idle":8.0,"Skill2_Idle":4.0,"Skill2_Loop":1.3,"Skill2_Start":0.333333333333333,"Skill3_End":0.666666666666667,"Skill3_Loop":4.0,"Skill3_Start":0.333333333333333,"Skill_Attack":1.3,"Skill_End":0.333333333333333,"Skill_Idle":8.0,"Skill_Start":0.166666666666667,"Start":1.0},"back":{"Attack":1.3,"Attack_End":0.333333333333333,"Attack_Start":0.166666666666667,"Default":0.0,"Idle":8.0,"Skill2_Idle":4.0,"Skill2_Loop":1.3,"Skill2_Start":0.333333333333333,"Skill_Attack":1.3,"Skill_End":0.333333333333333,"Skill_Idle":8.0,"Skill_Start":0.166666666666667,"Start":1.0}},"reset_on_clip_change":true,"front_only_skills":[2],"skill_idle_during_control":true},
	"mon3tr_operator":{"empty_clips":["Skill_3_Back"],"front":preload("res://assets/operators/mon3tr_operator/front/mon3tr_operator.res"),"back":preload("res://assets/operators/mon3tr_operator/back/mon3tr_operator.res"),"attack_clip":"Attack","attack_seconds":2.83333333333333,"idle_seconds":2.66666666666667,"deploy_seconds":1.0,"idle_seconds_back":2.66666666666667,"skill_actions":[{"cast":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_Back"}],"skill_actions_back":[{"cast":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","end":"Skill_3_Back"}],"animation_seconds":{"front":{"Attack":2.83333333333333,"Default":0.0,"Die":1.0,"Idle":2.66666666666667,"Skill_1":2.83333333333333,"Skill_2_Begin":0.266666666666667,"Skill_2_End":0.2,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":2.83333333333333,"Skill_3_Back":0.833333333333333,"Skill_3_Begin":0.666666666666667,"Skill_3_End":0.333333333333333,"Skill_3_Idle":2.4,"Skill_3_Loop":1.5,"Skill_3_ReStart":1.0,"Start":1.0},"back":{"Attack":2.83333333333333,"Default":0.0,"Idle":2.66666666666667,"Skill_1":2.83333333333333,"Skill_2_Begin":0.266666666666667,"Skill_2_End":0.2,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":2.83333333333333,"Skill_3_Back":0.833333333333333,"Skill_3_Begin":0.666666666666667,"Start":1.0}},"reset_on_clip_change":true,"front_only_skills":[2],"skill_idle_during_control":true},
	"stainless":{"front":preload("res://assets/operators/stainless/front/stainless.res"),"back":preload("res://assets/operators/stainless/back/stainless.res"),"attack_clip":"Attack","attack_seconds":1.5,"idle_seconds":6.66666666666667,"deploy_seconds":1.0,"idle_seconds_back":6.66666666666667,"skill_actions":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"cast":"Skill_3"}],"skill_actions_back":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"cast":"Skill_3"}],"animation_seconds":{"front":{"Attack":1.5,"Default":0.0,"Die":1.0,"Idle":6.66666666666667,"Skill_1":1.5,"Skill_2":1.5,"Skill_3":1.5,"Start":1.0},"back":{"Attack":1.5,"Default":0.0,"Idle":6.66666666666667,"Skill_1":1.5,"Skill_2":1.5,"Skill_3":1.5,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"gladiia":{"empty_clips":["Start"],"front":preload("res://assets/operators/gladiia/front/gladiia.res"),"back":preload("res://assets/operators/gladiia/back/gladiia.res"),"attack_clip":"Attack","attack_seconds":1.8,"idle_seconds":5.33333333333333,"deploy_seconds":1.0,"idle_seconds_back":5.33333333333333,"skill_actions":[{"cast_sequence":["Skill_1_Begin","Skill_1_Loop","Skill_1_End"]},{"begin":"Skill_2_Startup","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Startup","loop":"Skill_3_Chant","end":"Skill_3_End"}],"skill_actions_back":[{"cast_sequence":["Skill_1_Begin","Skill_1_Loop","Skill_1_End"]},{"begin":"Skill_2_Startup","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Startup","loop":"Skill_3_Chant","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.8,"Default":0.0,"Die":1.0,"Idle":5.33333333333333,"Skill_1_Begin":0.633333333333333,"Skill_1_End":1.16666666666667,"Skill_1_Loop":1.33333333333333,"Skill_2_Begin":0.566666666666667,"Skill_2_End":0.666666666666667,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":1.33333333333333,"Skill_2_Startup":0.5,"Skill_3_Begin":0.633333333333333,"Skill_3_Chant":1.33333333333333,"Skill_3_End":1.16666666666667,"Skill_3_Loop":1.33333333333333,"Skill_3_Startup":0.5,"Start":1.0},"back":{"Attack":1.8,"Default":0.0,"Idle":5.33333333333333,"Skill_1_Begin":0.633333333333333,"Skill_1_End":1.16666666666667,"Skill_1_Loop":1.33333333333333,"Skill_2_Begin":0.566666666666667,"Skill_2_End":0.666666666666667,"Skill_2_Idle":2.66666666666667,"Skill_2_Loop":1.33333333333333,"Skill_2_Startup":0.5,"Skill_3_Begin":0.633333333333333,"Skill_3_Chant":1.33333333333333,"Skill_3_End":1.16666666666667,"Skill_3_Loop":1.33333333333333,"Skill_3_Startup":0.5,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"muelsyse":{"empty_clips":["Start"],"front":preload("res://assets/operators/muelsyse/front/muelsyse.res"),"back":preload("res://assets/operators/muelsyse/back/muelsyse.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":3.0,"deploy_seconds":1.0,"idle_seconds_back":3.0,"skill_actions":[{"cast":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_loop","end":"Skill_3_End"}],"skill_actions_back":[{"cast":"Skill_1"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":3.0,"Skill_1":1.0,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":1.0,"Skill_2_Loop":1.0,"Skill_3_Begin":0.166666666666667,"Skill_3_End":0.166666666666667,"Skill_3_Idle":1.0,"Skill_3_loop":1.0,"Start":1.0},"back":{"Attack":1.0,"Default":0.0,"Idle":3.0,"Skill_1":1.0,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":1.0,"Skill_2_Loop":1.0,"Skill_3_Begin":0.166666666666667,"Skill_3_End":0.166666666666667,"Skill_3_Idle":1.0,"Skill_3_loop":1.0,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"mlynar":{"front":preload("res://assets/operators/mlynar/front/mlynar.res"),"back":preload("res://assets/operators/mlynar/back/mlynar.res"),"attack_clip":"Skill_1_Loop","attack_seconds":1.2,"idle_seconds":2.0,"deploy_seconds":1.0,"idle_seconds_back":2.0,"skill_actions":[{"begin":"Skill_1_Start","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Start","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Start","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"skill_actions_back":[{"begin":"Skill_1_Start","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Start","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Start","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Default":0.0,"Die":1.0,"Idle":2.0,"Idle_2":1.0,"Skill_1_End":0.333333333333333,"Skill_1_Idle":1.0,"Skill_1_Loop":1.2,"Skill_1_Start":0.333333333333333,"Skill_2_End":0.333333333333333,"Skill_2_Idle":1.0,"Skill_2_Loop":1.6,"Skill_2_Start":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":1.0,"Skill_3_Loop":1.2,"Skill_3_Start":0.333333333333333,"Start":1.0},"back":{"Default":0.0,"Die":1.0,"Idle":2.0,"Idle_2":1.0,"Skill_1_End":0.333333333333333,"Skill_1_Idle":1.0,"Skill_1_Loop":1.2,"Skill_1_Start":0.333333333333333,"Skill_2_End":0.333333333333333,"Skill_2_Idle":1.0,"Skill_2_Loop":1.6,"Skill_2_Start":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":1.0,"Skill_3_Loop":1.2,"Skill_3_Start":0.333333333333333,"Start":1.0}},"reset_on_clip_change":true,"attack_only_active":true,"skill_idle_during_control":true},
	"jessica_alter":{"front":preload("res://assets/operators/jessica_alter/front/jessica_alter.res"),"back":preload("res://assets/operators/jessica_alter/back/jessica_alter.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":2.0,"deploy_seconds":1.0,"idle_seconds_back":2.0,"down_clip":"Attack_Down","down_seconds":1.2,"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","down":"Skill_Down_1_Loop"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End","down":"Skill_Down_2_Loop"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End","down":"Skill_Down_3_Loop","bomb":"Skill_3_Skill","bomb_down":"Skill_Down_3_Skill"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End","bomb":"Skill_3_Skill"}],"animation_seconds":{"front":{"Attack":1.2,"Attack_Down":1.2,"Default":0.0,"Die":1.0,"Idle":2.0,"Skill_1_Begin":0.333333333333333,"Skill_1_Idle":2.0,"Skill_1_Loop":1.2,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":2.0,"Skill_2_Loop":0.366666666666667,"Skill_3_Begin":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":2.0,"Skill_3_Loop":1.8,"Skill_3_Skill":1.8,"Skill_Down_1_Loop":1.2,"Skill_Down_2_Loop":0.366666666666667,"Skill_Down_3_Begin":0.333333333333333,"Skill_Down_3_End":0.333333333333333,"Skill_Down_3_Idle":2.0,"Skill_Down_3_Loop":1.8,"Skill_Down_3_Skill":1.8,"Start":1.0},"back":{"Attack":1.2,"Default":0.0,"Idle":2.0,"Skill_1_Begin":0.333333333333333,"Skill_1_Idle":2.0,"Skill_1_Loop":1.2,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":2.0,"Skill_2_Loop":0.366666666666667,"Skill_3_Begin":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":2.0,"Skill_3_Loop":1.8,"Skill_3_Skill":1.8,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"fiammetta":{"front":preload("res://assets/operators/fiammetta/front/fiammetta.res"),"back":preload("res://assets/operators/fiammetta/back/fiammetta.res"),"attack_clip":"Attack","attack_seconds":1.46666666666667,"idle_seconds":2.66666666666667,"deploy_seconds":1.0,"idle_seconds_back":2.66666666666667,"skill_actions":[{},{"cast_sequence":["Skill_Begin","Skill_Loop","Skill_End"]},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"}],"skill_actions_back":[{},{"cast_sequence":["Skill_Begin","Skill_Loop","Skill_End"]},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"}],"animation_seconds":{"front":{"Attack":1.46666666666667,"Default":0.0,"Die":1.0,"Idle":2.66666666666667,"Skill_2_Begin":0.2,"Skill_2_End":0.566666666666667,"Skill_2_Idle":1.33333333333333,"Skill_2_Loop":0.666666666666667,"Skill_Begin":0.233333333333333,"Skill_End":0.566666666666667,"Skill_Idle":2.66666666666667,"Skill_Loop":1.46666666666667,"Start":1.0},"back":{"Attack":1.46666666666667,"Default":0.0,"Idle":2.66666666666667,"Skill_2_Begin":0.2,"Skill_2_End":0.566666666666667,"Skill_2_Idle":1.33333333333333,"Skill_2_Loop":0.666666666666667,"Skill_Begin":0.233333333333333,"Skill_End":0.566666666666667,"Skill_Idle":2.66666666666667,"Skill_Loop":1.46666666666667,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"dusk":{"front":preload("res://assets/operators/dusk/front/dusk.res"),"back":preload("res://assets/operators/dusk/back/dusk.res"),"attack_clip":"Attack","attack_seconds":2.86666666666667,"idle_seconds":8.0,"deploy_seconds":1.0,"idle_seconds_back":8.0,"skill_actions":[{},{"begin":"Skill2_Begin","attack":"Skill2_Loop","end":"Skill2_End"},{"attack":"Skill3_Attack"}],"skill_actions_back":[{},{"begin":"Skill2_Begin","attack":"Skill2_Loop","end":"Skill2_End"},{"attack":"Skill3_Attack"}],"animation_seconds":{"front":{"Attack":2.86666666666667,"Default":0.0,"Die":1.0,"Idle":8.0,"Skill2_Begin":0.166666666666667,"Skill2_End":1.0,"Skill2_Loop":1.33333333333333,"Skill3_Attack":3.43333333333333,"Start":1.0},"back":{"Attack":2.86666666666667,"Default":0.0,"Idle":8.0,"Skill2_Begin":0.166666666666667,"Skill2_End":1.0,"Skill2_Loop":1.33333333333333,"Skill3_Attack":3.43333333333333,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"titi":{"empty_clips":["Start"],"front":preload("res://assets/operators/titi/front/titi.res"),"back":preload("res://assets/operators/titi/back/titi.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":4.0,"deploy_seconds":1.0,"idle_seconds_back":4.0,"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.6,"Default":0.0,"Die":1.0,"Idle":4.0,"Skill_1_Begin":0.333333333333333,"Skill_1_End":0.5,"Skill_1_Idle":4.0,"Skill_1_Loop":1.6,"Skill_2_Begin":0.333333333333333,"Skill_2_End":0.5,"Skill_2_Idle":2.0,"Skill_3_Begin":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":4.0,"Skill_3_Loop":1.6,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":4.0,"Skill_1_Begin":0.333333333333333,"Skill_1_End":0.5,"Skill_1_Idle":4.0,"Skill_1_Loop":1.6,"Skill_2_Begin":0.333333333333333,"Skill_2_End":0.5,"Skill_2_Idle":2.0,"Skill_3_Begin":0.333333333333333,"Skill_3_End":0.333333333333333,"Skill_3_Idle":4.0,"Skill_3_Loop":1.6,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"ling":{"front":preload("res://assets/operators/ling/front/ling.res"),"back":preload("res://assets/operators/ling/back/ling.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":10.0,"deploy_seconds":1.0,"idle_seconds_back":10.0,"skill_actions":[{},{"cast":"Skill_02"},{"begin":"Skill_03_Begin","idle":"Skill_03_Idle","attack":"Skill_03_Loop","end":"Skill_03_End"}],"skill_actions_back":[{},{"cast":"Skill_02"},{"begin":"Skill_03_Begin","idle":"Skill_03_Idle","attack":"Skill_03_Loop","end":"Skill_03_End"}],"animation_seconds":{"front":{"Attack":1.6,"Default":0.0,"Die":1.0,"Idle":10.0,"Skill_02":1.2,"Skill_03_Begin":0.5,"Skill_03_End":0.5,"Skill_03_Idle":6.33333333333333,"Skill_03_Loop":1.63333333333333,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":10.0,"Skill_02":1.2,"Skill_03_Begin":0.5,"Skill_03_End":0.5,"Skill_03_Idle":6.33333333333333,"Skill_03_Loop":1.63333333333333,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"shaw":{"front":preload("res://assets/operators/shaw/front/shaw.res"),"back":preload("res://assets/operators/shaw/back/shaw.res"),"attack_clip":"Attack_Loop","attack_seconds":0.833333333333333,"idle_seconds":1.66666666666667,"deploy_seconds":1.0,"idle_seconds_back":1.66666666666667,"chain_seconds":"0.166666666666667,0.833333333333333,0.166666666666667","skill_actions":[{"cast":"Skill_Right","cast_down":"Skill_Down"},{"cast":"Skill_Right","cast_down":"Skill_Down"}],"skill_actions_back":[{"cast":"Skill_Right","cast_up":"Skill_Up"},{"cast":"Skill_Right","cast_up":"Skill_Up"}],"animation_seconds":{"front":{"Attack_Begin":0.166666666666667,"Attack_End":0.166666666666667,"Attack_Loop":0.833333333333333,"Default":0.0,"Die":1.0,"Idle":1.66666666666667,"Skill_Down":1.33333333333333,"Skill_Right":1.33333333333333,"Start":1.0},"back":{"Attack_Begin":0.166666666666667,"Attack_End":0.166666666666667,"Attack_Loop":0.833333333333333,"Default":0.0,"Idle":1.66666666666667,"Skill_Right":1.33333333333333,"Skill_Up":1.33333333333333,"Start":1.0}},"reset_on_clip_change":true,"skill_idle_during_control":true},
	"mon3tr_reconstruction":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/mon3tr_reconstruction/single/mon3tr_reconstruction.res"),"back":preload("res://assets/operators/mon3tr_reconstruction/single/mon3tr_reconstruction.res"),"idle_clip":"Idle","idle_seconds":2.0,"attack_clip":"Attack","attack_seconds":1.33333333333333,"deploy_seconds":1.0,"animation_seconds":{"front":{"Attack":1.33333333333333,"Default":0.0,"Die":1.0,"Idle":2.0,"Skill_3":0.0,"Skill_3_Begin":0.666666666666667,"Start":1.0},"back":{"Attack":1.33333333333333,"Default":0.0,"Die":1.0,"Idle":2.0,"Skill_3":0.0,"Skill_3_Begin":0.666666666666667,"Start":1.0}}},
	"ling_soul1":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/ling_soul1/single/ling_soul1.res"),"back":preload("res://assets/operators/ling_soul1/single/ling_soul1.res"),"idle_clip":"Idle","idle_seconds":1.33333333333333,"attack_clip":"Attack","attack_seconds":1.0,"deploy_seconds":1.0,"animation_seconds":{"front":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":1.33333333333333,"Start":1.0,"Stun":1.0},"back":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":1.33333333333333,"Start":1.0,"Stun":1.0}}},
	"ling_soul2":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/ling_soul2/single/ling_soul2.res"),"back":preload("res://assets/operators/ling_soul2/single/ling_soul2.res"),"idle_clip":"Idle","idle_seconds":1.33333333333333,"attack_clip":"Attack","attack_seconds":1.0,"deploy_seconds":1.0,"animation_seconds":{"front":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":1.33333333333333,"Skill":1.16666666666667,"Start":1.0,"Stun":1.0},"back":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":1.33333333333333,"Skill":1.16666666666667,"Start":1.0,"Stun":1.0}}},
	"ling_soul3":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/ling_soul3/single/ling_soul3.res"),"back":preload("res://assets/operators/ling_soul3/single/ling_soul3.res"),"idle_clip":"Idle","idle_seconds":1.33333333333333,"attack_clip":"Attack","attack_seconds":1.0,"deploy_seconds":1.0,"animation_seconds":{"front":{"Attack":1.0,"Attack_02":1.66666666666667,"Default":0.0,"Die":1.0,"Die_02":1.0,"Die_Skill":0.333333333333333,"Idle":1.33333333333333,"Idle_02":2.0,"Start":1.0,"Start_02":0.666666666666667,"Stun":1.0,"Stun_02":1.0},"back":{"Attack":1.0,"Attack_02":1.66666666666667,"Default":0.0,"Die":1.0,"Die_02":1.0,"Die_Skill":0.333333333333333,"Idle":1.33333333333333,"Idle_02":2.0,"Start":1.0,"Start_02":0.666666666666667,"Stun":1.0,"Stun_02":1.0}},"advanced_idle_clip":"Idle_02","advanced_attack_clip":"Attack_02","advanced_start_clip":"Start_02"},
	"flowing_shape":{"empty_clips":["Start","A_Start","B_Start","Idle_2"],"reset_on_clip_change":true,"front":preload("res://assets/operators/flowing_shape/single/flowing_shape.res"),"back":preload("res://assets/operators/flowing_shape/single/flowing_shape.res"),"idle_clip":"Idle_1","idle_seconds":2.0,"attack_clip":"Attack","attack_seconds":0.8,"deploy_seconds":1.0,"animation_seconds":{"front":{"A_Attack":0.8,"A_Combat":0.8,"A_Default":0.0,"A_Die":0.733333333333333,"A_Idle":1.0,"A_Start":1.0,"A_Stun":1.0,"Attack":0.8,"B_Attack":0.8,"B_Attack_2":0.8,"B_Combat":0.8,"B_Default":0.0,"B_Die":0.733333333333333,"B_Idle":1.0,"B_Start":1.0,"B_Stun":1.0,"Change_A":0.666666666666667,"Change_B":0.666666666666667,"Default":0.0,"Die":0.6,"Idle_1":2.0,"Idle_2":0.0,"Start":1.0,"Stun":2.0},"back":{"A_Attack":0.8,"A_Combat":0.8,"A_Default":0.0,"A_Die":0.733333333333333,"A_Idle":1.0,"A_Start":1.0,"A_Stun":1.0,"Attack":0.8,"B_Attack":0.8,"B_Attack_2":0.8,"B_Combat":0.8,"B_Default":0.0,"B_Die":0.733333333333333,"B_Idle":1.0,"B_Start":1.0,"B_Stun":1.0,"Change_A":0.666666666666667,"Change_B":0.666666666666667,"Default":0.0,"Die":0.6,"Idle_1":2.0,"Idle_2":0.0,"Start":1.0,"Stun":2.0}}},
	"jessica_shield":{"reset_on_clip_change":true,"front":preload("res://assets/operators/jessica_shield/single/jessica_shield.res"),"back":preload("res://assets/operators/jessica_shield/single/jessica_shield.res"),"idle_clip":"Idle","idle_seconds":1.0,"attack_clip":"Idle","attack_seconds":1.0,"deploy_seconds":1.0,"animation_seconds":{"front":{"Default":0.0,"Die":1.0,"Idle":1.0,"Start":1.0},"back":{"Default":0.0,"Die":1.0,"Idle":1.0,"Start":1.0}}},
	"dusk_freeling":{"reset_on_clip_change":true,"front":preload("res://assets/operators/dusk_freeling/single/dusk_freeling.res"),"back":preload("res://assets/operators/dusk_freeling/single/dusk_freeling.res"),"idle_clip":"Idle","idle_seconds":4.0,"attack_clip":"Attack","attack_seconds":1.0,"deploy_seconds":0.666666666666667,"animation_seconds":{"front":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":4.0,"Start":0.666666666666667,"Stun":1.0},"back":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":4.0,"Start":0.666666666666667,"Stun":1.0}}},
	"stainless_device_atk":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/stainless_device_atk/single/stainless_device_atk.res"),"back":preload("res://assets/operators/stainless_device_atk/single/stainless_device_atk.res"),"idle_clip":"Idle","idle_seconds":2.8,"attack_clip":"Idle","attack_seconds":2.8,"deploy_seconds":1.0,"animation_seconds":{"front":{"Default":0.0,"End":1.0,"Idle":2.8,"Start":1.0},"back":{"Default":0.0,"End":1.0,"Idle":2.8,"Start":1.0}}},
	"stainless_device_sp":{"empty_clips":["Start"],"reset_on_clip_change":true,"front":preload("res://assets/operators/stainless_device_sp/single/stainless_device_sp.res"),"back":preload("res://assets/operators/stainless_device_sp/single/stainless_device_sp.res"),"idle_clip":"Idle","idle_seconds":2.8,"attack_clip":"Idle","attack_seconds":2.8,"deploy_seconds":1.0,"animation_seconds":{"front":{"Default":0.0,"End":1.0,"Idle":2.8,"Start":1.0},"back":{"Default":0.0,"End":1.0,"Idle":2.8,"Start":1.0}}},
	"stainless_cannon":{"reset_on_clip_change":true,"front":preload("res://assets/operators/stainless_cannon/single/stainless_cannon.res"),"back":preload("res://assets/operators/stainless_cannon/single/stainless_cannon.res"),"idle_clip":"Idle","idle_seconds":1.0,"attack_clip":"Attack","attack_seconds":0.333333333333333,"deploy_seconds":1.0,"animation_seconds":{"front":{"Attack":0.333333333333333,"Default":0.0,"Die":1.0,"Idle":1.0,"Start":1.0},"back":{"Attack":0.333333333333333,"Default":0.0,"Die":1.0,"Idle":1.0,"Start":1.0}}},
	"vigil_wolf":{"front":preload("res://assets/operators/vigil_wolf/single/vigil_wolf.res"),"back":preload("res://assets/operators/vigil_wolf/single/vigil_wolf.res"),"idle_clip":"Idle_1","idle_seconds":2.0,"attack_clip":"Attack","attack_seconds":1.26666666666667,"deploy_seconds":1.0},
	"pozyomka_typewriter":{"front":preload("res://assets/operators/pozyomka_typewriter/single/pozyomka_typewriter.res"),"back":preload("res://assets/operators/pozyomka_typewriter/single/pozyomka_typewriter.res"),"idle_clip":"Idle","idle_seconds":0.333333333333333,"attack_clip":"Attack","attack_seconds":1.6,"deploy_seconds":0.666666666666667,"down_clip":"Attack_Down","down_seconds":1.6},
	"silence_alter_drone":{"front":preload("res://assets/operators/silence_alter_drone/single/silence_alter_drone.res"),"back":preload("res://assets/operators/silence_alter_drone/single/silence_alter_drone.res"),"idle_clip":"Idle","idle_seconds":1.2,"attack_clip":"Idle","attack_seconds":1.2,"deploy_seconds":1.0},
	"archetto":{"front":preload("res://assets/operators/archetto/front/archetto.res"),"back":preload("res://assets/operators/archetto/back/archetto.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":4.0,"deploy_seconds":1.0,"skill_actions":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"attack":"Skill_3"}],"skill_actions_back":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"attack":"Skill_3"}],"animation_seconds":{"front":{"Attack":1.2,"Default":0.0,"Die":1.0,"Idle":4.0,"Skill_1":1.2,"Skill_2":1.33333333333333,"Skill_3":1.23333333333333,"Start":1.0},"back":{"Attack":1.2,"Default":0.0,"Idle":4.0,"Skill_1":1.2,"Skill_2":1.33333333333333,"Skill_3":1.23333333333333,"Start":1.0}}},
	"blemishine":{"front":preload("res://assets/operators/blemishine/front/blemishine.res"),"back":preload("res://assets/operators/blemishine/back/blemishine.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":3.0,"deploy_seconds":1.0,"down_clip":"Attack_Down","down_seconds":1.2,"skill_actions":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"attack":"Skill_3"}],"skill_actions_back":[{"cast":"Skill_1"},{"cast":"Skill_2"},{"attack":"Skill_3"}],"animation_seconds":{"front":{"Attack":1.2,"Attack_Down":1.2,"Default":0.0,"Die":1.0,"Idle":3.0,"Skill_1":1.2,"Skill_2":1.0,"Skill_3":1.2,"Start":1.0},"back":{"Attack":1.2,"Default":0.0,"Idle":3.0,"Skill_1":1.2,"Skill_2":1.0,"Skill_3":1.2,"Start":1.0}}},
	"carnelian":{"front":preload("res://assets/operators/carnelian/front/carnelian.res"),"back":preload("res://assets/operators/carnelian/back/carnelian.res"),"attack_clip":"Skill_Loop","attack_seconds":1.06666666666667,"idle_seconds":4.0,"deploy_seconds":1.0,"skill_actions":[{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End"},{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"}],"skill_actions_back":[{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End"},{"begin":"Skill_Begin","idle":"Skill_Idle","attack":"Skill_Loop","end":"Skill_End"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"}],"animation_seconds":{"front":{"Default":0.0,"Die":1.03333333333333,"Idle":4.0,"Skill_2_Begin":0.5,"Skill_2_End":0.5,"Skill_2_Idle":3.33333333333333,"Skill_2_Loop":1.06666666666667,"Skill_Begin":0.5,"Skill_End":0.5,"Skill_Idle":3.33333333333333,"Skill_Loop":1.06666666666667,"Start":1.0},"back":{"Default":0.0,"Idle":4.0,"Skill_2_Begin":0.5,"Skill_2_End":0.5,"Skill_2_Idle":3.33333333333333,"Skill_2_Loop":1.06666666666667,"Skill_Begin":0.5,"Skill_End":0.5,"Skill_Idle":3.33333333333333,"Skill_Loop":1.06666666666667,"Start":1.0}}},
	"eyjafjalla_alter":{"empty_clips":["Start"],"front":preload("res://assets/operators/eyjafjalla_alter/front/eyjafjalla_alter.res"),"back":preload("res://assets/operators/eyjafjalla_alter/back/eyjafjalla_alter.res"),"attack_clip":"Attack","attack_seconds":1.33333333333333,"idle_seconds":2.66666666666667,"deploy_seconds":1.0,"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop"},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop"},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.33333333333333,"Default":0.0,"Die":0.666666666666667,"Idle":2.66666666666667,"Skill_1_Begin":0.5,"Skill_1_Idle":2.66666666666667,"Skill_1_Loop":1.33333333333333,"Skill_2":1.0,"Skill_3_Begin":0.4,"Skill_3_End":0.333333333333333,"Skill_3_Idle":2.66666666666667,"Skill_3_Loop":2.83333333333333,"Start":1.0},"back":{"Attack":1.33333333333333,"Default":0.0,"Idle":2.66666666666667,"Skill_1_Begin":0.5,"Skill_1_Idle":2.66666666666667,"Skill_1_Loop":1.33333333333333,"Skill_2":1.0,"Skill_3_Begin":0.4,"Skill_3_End":0.333333333333333,"Skill_3_Idle":2.66666666666667,"Skill_3_Loop":2.83333333333333,"Start":1.0}}},
	"gnosis":{"front":preload("res://assets/operators/gnosis/front/gnosis.res"),"back":preload("res://assets/operators/gnosis/back/gnosis.res"),"attack_clip":"Attack","attack_seconds":1.26666666666667,"idle_seconds":6.0,"deploy_seconds":1.0,"idle_seconds_back":2.0,"skill_actions":[{"cast":"Skill"},{"cast":"Skill_2"},{"begin":"Skill_4_Begin","loop":"Skill_4_Loop","end":"Skill_4_End"}],"skill_actions_back":[{"cast":"Skill"},{"cast":"Skill_2"},{"begin":"Skill_4_Begin","loop":"Skill_4_Loop","end":"Skill_4_End"}],"animation_seconds":{"front":{"Attack":1.26666666666667,"Default":0.0,"Die":1.23333333333333,"Idle":6.0,"Skill":0.833333333333333,"Skill_2":1.16666666666667,"Skill_3":1.16666666666667,"Skill_4_Begin":0.333333333333333,"Skill_4_End":0.666666666666667,"Skill_4_Loop":2.66666666666667,"Start":1.0},"back":{"Attack":1.26666666666667,"Default":0.0,"Idle":2.0,"Skill":0.833333333333333,"Skill_2":1.16666666666667,"Skill_3":1.16666666666667,"Skill_4_Begin":0.333333333333333,"Skill_4_End":0.666666666666667,"Skill_4_Loop":2.66666666666667,"Start":1.0}}},
	"ines":{"front":preload("res://assets/operators/ines/front/ines.res"),"back":preload("res://assets/operators/ines/back/ines.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":4.0,"deploy_seconds":1.0,"skill_actions":[{},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Attack","end":"Skill_2_End"},{}],"skill_actions_back":[{},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Attack","end":"Skill_2_End"},{}],"animation_seconds":{"front":{"Attack":1.0,"Combat":1.0,"Default":0.0,"Die":1.0,"Idle":4.0,"Skill_2_Attack":1.0,"Skill_2_Begin":0.166666666666667,"Skill_2_Combat":1.0,"Skill_2_End":0.666666666666667,"Skill_2_Idle":4.0,"Start":1.0,"Start_Skill":1.0},"back":{"Attack":1.0,"Combat":1.0,"Default":0.0,"Idle":4.0,"Skill_2_Attack":1.0,"Skill_2_Begin":0.166666666666667,"Skill_2_Combat":1.0,"Skill_2_End":0.666666666666667,"Skill_2_Idle":4.0,"Start":1.0,"Start_Skill":1.0}}},
	"lee":{"empty_clips":["Start"],"front":preload("res://assets/operators/lee/front/lee.res"),"back":preload("res://assets/operators/lee/back/lee.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":3.6,"deploy_seconds":1.0,"skill_actions":[{},{"cast":"Skill_2_Start","attack":"Skill_2_Attack"},{"begin":"Skill_3_Start","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"skill_actions_back":[{},{"cast":"Skill_2_start","attack":"Skill_2_Attack"},{"begin":"Skill_3_Start","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":3.6,"Skill_2_Attack":1.0,"Skill_2_Start":0.333333333333333,"Skill_3_End":0.1,"Skill_3_Idle":1.0,"Skill_3_Loop":1.0,"Skill_3_Start":0.333333333333333,"Start":1.0},"back":{"Attack":1.0,"Default":0.0,"Die":1.0,"Idle":3.6,"Skill_2_Attack":1.0,"Skill_2_start":0.333333333333333,"Skill_3_End":0.1,"Skill_3_Idle":1.0,"Skill_3_Loop":1.0,"Skill_3_Start":0.333333333333333,"Start":1.0}}},
	"lin":{"empty_clips":["Start"],"front":preload("res://assets/operators/lin/front/lin.res"),"back":preload("res://assets/operators/lin/back/lin.res"),"attack_clip":"Skill_1_Loop","attack_seconds":3.0,"idle_seconds":3.0,"deploy_seconds":1.0,"additive_slots":["C_FX_Light"],"additive_slots_back":["C_FX_Light"],"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","loop":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Attack_A","end":"Skill_3_End"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","loop":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Attack_A","end":"Skill_3_End"}],"animation_seconds":{"front":{"Default":0.0,"Die":1.0,"Idle":3.0,"Skill_1_Begin":0.333333333333333,"Skill_1_End":2.0,"Skill_1_Idle":3.0,"Skill_1_Loop":3.0,"Skill_2_Begin":0.333333333333333,"Skill_2_End":1.0,"Skill_2_Loop":2.33333333333333,"Skill_3_Attack_A":2.0,"Skill_3_Attack_B":2.0,"Skill_3_Attack_C":2.0,"Skill_3_Begin":0.266666666666667,"Skill_3_End":2.0,"Skill_3_Idle":3.0,"Start":1.0},"back":{"Default":0.0,"Idle":3.0,"Skill_1_Begin":0.333333333333333,"Skill_1_End":2.0,"Skill_1_Idle":3.0,"Skill_1_Loop":3.0,"Skill_2_Begin":0.333333333333333,"Skill_2_End":1.0,"Skill_2_Loop":2.33333333333333,"Skill_3_Attack_A":2.0,"Skill_3_Attack_B":2.0,"Skill_3_Attack_C":2.0,"Skill_3_Begin":0.266666666666667,"Skill_3_End":2.0,"Skill_3_Idle":3.0,"Start":1.0}}},
	"pallas":{"empty_clips":["Start"],"front":preload("res://assets/operators/pallas/front/pallas.res"),"back":preload("res://assets/operators/pallas/back/pallas.res"),"attack_clip":"Attack","attack_seconds":1.33333333333333,"idle_seconds":4.0,"deploy_seconds":1.0,"down_clip":"Attack_Down","down_seconds":1.33333333333333,"skill_actions":[{},{"attack":"Skill_02","down":"Skill_02_Down"},{"begin":"Skill_03_Begin","idle":"Skill_03_Idle","attack":"Skill_03_Loop","down":"Skill_03_Loop_Down","end":"Skill_03_End"}],"skill_actions_back":[{},{"attack":"Skill_02"},{"begin":"Skill_03_Begin","idle":"Skill_03_Idle","attack":"Skill_03_Loop","end":"Skill_03_End"}],"animation_seconds":{"front":{"Attack":1.33333333333333,"Attack_Down":1.33333333333333,"Default":0.0,"Die":1.16666666666667,"Idle":4.0,"Skill_02":1.33333333333333,"Skill_02_Down":1.33333333333333,"Skill_03_Begin":0.5,"Skill_03_End":0.5,"Skill_03_Idle":1.33333333333333,"Skill_03_Loop":1.33333333333333,"Skill_03_Loop_Down":1.33333333333333,"Start":1.0},"back":{"Attack":1.33333333333333,"Default":0.0,"Idle":4.0,"Skill_02":1.33333333333333,"Skill_03_Begin":0.5,"Skill_03_End":0.5,"Skill_03_Idle":1.33333333333333,"Skill_03_Loop":1.33333333333333,"Start":1.0}}},
	"penance":{"front":preload("res://assets/operators/penance/front/penance.res"),"back":preload("res://assets/operators/penance/back/penance.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":4.0,"deploy_seconds":1.0,"idle_seconds_back":1.33333333333333,"down_clip":"Attack_Down","down_seconds":1.6,"additive_slots":["F_Weapon_e"],"additive_slots_back":["F_Weapon_e2"],"skill_actions":[{"cast":"Skill_1_Begin","attack":"Skill_1_Attack"},{"begin":"Skill_2_Begin","loop":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Attack","down":"Skill_Down_3_Attack","end":"Skill_3_End"}],"skill_actions_back":[{"cast":"Skill_1_Begin","attack":"Skill_1_Attack"},{},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Attack","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.6,"Attack_Down":1.6,"Default":0.0,"Die":1.0,"Idle":4.0,"Skill_1_Attack":1.16666666666667,"Skill_1_Begin":0.333333333333333,"Skill_1_Idle":1.33333333333333,"Skill_2_Begin":0.333333333333333,"Skill_2_End":0.333333333333333,"Skill_2_Loop":1.0,"Skill_3_Attack":1.6,"Skill_3_Begin":0.266666666666667,"Skill_3_End":0.266666666666667,"Skill_3_Idle":1.0,"Skill_Down_3_Attack":1.6,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":1.33333333333333,"Skill_1_Attack":1.16666666666667,"Skill_1_Begin":0.333333333333333,"Skill_1_Idle":1.33333333333333,"Skill_3_Attack":1.6,"Skill_3_Begin":0.266666666666667,"Skill_3_End":0.266666666666667,"Skill_3_Idle":1.0,"Start":1.0}}},
	"pozyomka":{"empty_clips":["Start"],"front":preload("res://assets/operators/pozyomka/front/pozyomka.res"),"back":preload("res://assets/operators/pozyomka/back/pozyomka.res"),"attack_clip":"Attack_Loop","attack_seconds":1.6,"idle_seconds":2.0,"deploy_seconds":1.0,"chain_seconds":"0.5,1.6,0.5","down_clip":"Attack_Loop_Down","down_seconds":1.6,"skill_actions":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop","down":"Skill_1_Loop_Down"},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","down":"Skill_3_Loop_Down","end":"Skill_3_End"}],"skill_actions_back":[{"begin":"Skill_1_Begin","idle":"Skill_1_Idle","attack":"Skill_1_Loop"},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack_Begin":0.5,"Attack_End":0.5,"Attack_Loop":1.6,"Attack_Loop_Down":1.6,"Default":0.0,"Die":1.0,"Idle":2.0,"Skill_1_Begin":0.5,"Skill_1_Idle":2.0,"Skill_1_Loop":1.6,"Skill_1_Loop_Down":1.6,"Skill_2":1.6,"Skill_2_Down":1.6,"Skill_3_Begin":0.666666666666667,"Skill_3_End":0.5,"Skill_3_Idle":2.0,"Skill_3_Loop":1.0,"Skill_3_Loop_Down":1.0,"Start":1.0},"back":{"Attack_Begin":0.5,"Attack_End":0.5,"Attack_Loop":1.6,"Default":0.0,"Idle":2.0,"Skill_1_Begin":0.5,"Skill_1_End":0.5,"Skill_1_Idle":2.0,"Skill_1_Loop":1.6,"Skill_2":1.6,"Skill_3_Begin":0.666666666666667,"Skill_3_End":0.5,"Skill_3_Idle":2.0,"Skill_3_Loop":1.0,"Start":1.0}}},
	"reed_alter":{"front":preload("res://assets/operators/reed_alter/front/reed_alter.res"),"back":preload("res://assets/operators/reed_alter/back/reed_alter.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":6.0,"deploy_seconds":1.0,"additive_slots":["F_Cheat_Star2", "Tail_fire_e2"],"additive_slots_back":["Tail_fire_e"],"skill_actions":[{},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Loop","attack":"Skill_3_Attack","end":"Skill_3_End"}],"skill_actions_back":[{},{"cast":"Skill_2"},{"begin":"Skill_3_Begin","idle":"Skill_3_Loop","attack":"Skill_3_Attack","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":1.6,"Default":0.0,"Die":1.0,"Idle":6.0,"Skill_2":0.5,"Skill_3_Attack":1.6,"Skill_3_Begin":0.333333333333333,"Skill_3_End":1.0,"Skill_3_Loop":3.0,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":6.0,"Skill_2":0.5,"Skill_3_Attack":1.6,"Skill_3_Begin":0.333333333333333,"Skill_3_End":1.0,"Skill_3_Loop":3.0,"Start":1.0}}},
	"silence_alter":{"front":preload("res://assets/operators/silence_alter/front/silence_alter.res"),"back":preload("res://assets/operators/silence_alter/back/silence_alter.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":4.0,"deploy_seconds":1.0,"skill_actions":[{"attack":"Skill"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"attack":"Skill"}],"skill_actions_back":[{"attack":"Skill"},{"begin":"Skill_2_Begin","idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"attack":"Skill"}],"animation_seconds":{"front":{"Attack":1.6,"Default":0.0,"Die":1.0,"Idle":4.0,"Skill":1.6,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":2.0,"Skill_2_Loop":1.6,"Start":1.0},"back":{"Attack":1.6,"Default":0.0,"Idle":4.0,"Skill":1.6,"Skill_2_Begin":0.166666666666667,"Skill_2_End":0.166666666666667,"Skill_2_Idle":2.0,"Skill_2_Loop":1.6,"Start":1.0}}},
	"texas_alter":{"front":preload("res://assets/operators/texas_alter/front/texas_alter.res"),"back":preload("res://assets/operators/texas_alter/back/texas_alter.res"),"attack_clip":"Attack","attack_seconds":0.933333333333333,"idle_seconds":3.0,"deploy_seconds":1.0,"skill_actions":[{},{"idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"skill_actions_back":[{},{"idle":"Skill_2_Idle","attack":"Skill_2_Loop","end":"Skill_2_End"},{"idle":"Skill_3_Idle","attack":"Skill_3_Loop","end":"Skill_3_End"}],"animation_seconds":{"front":{"Attack":0.933333333333333,"Default":0.0,"Default_2":0.0,"Default_3":0.0,"Die":1.0,"Idle":3.0,"Skill_2_End":0.1,"Skill_2_Idle":3.0,"Skill_2_Loop":0.933333333333333,"Skill_3_End":0.4,"Skill_3_Idle":3.0,"Skill_3_Loop":0.933333333333333,"Start":1.0,"Start_2":1.0,"Start_3":1.0,"Start_3_2":1.0},"back":{"Attack":0.933333333333333,"Default":0.0,"Default_2":0.0,"Default_3":0.0,"Idle":3.0,"Skill_2_End":0.1,"Skill_2_Idle":3.0,"Skill_2_Loop":0.933333333333333,"Skill_3_End":0.4,"Skill_3_Idle":3.0,"Skill_3_Loop":0.933333333333333,"Start":1.0,"Start_2":1.0,"Start_3":1.0,"Start_3_2":1.0}}},
	"thorns":{"front":preload("res://assets/operators/thorns/front/thorns.res"),"back":preload("res://assets/operators/thorns/back/thorns.res"),"attack_clip":"Attack_1","attack_seconds":1.2,"idle_seconds":3.33333333333333,"deploy_seconds":1.0,"skill_actions":[{},{"begin":"Skill1_1","loop":"Skill1_2","end":"Skill1_3"},{"begin":"Skill2_1","attack":"Attack_2"}],"skill_actions_back":[{},{"begin":"Skill1_1","loop":"Skill1_2","end":"Skill1_3"},{"begin":"Skill2_1","attack":"Attack_2"}],"animation_seconds":{"front":{"Attack_1":1.2,"Attack_2":1.2,"Default":0.0,"Die":0.866666666666667,"Idle":3.33333333333333,"Skill1_1":0.166666666666667,"Skill1_2":3.33333333333333,"Skill1_3":0.233333333333333,"Skill2_1":0.8,"Skill2_2":0.8,"Start":1.0},"back":{"Attack_1":1.2,"Attack_2":1.2,"Default":0.0,"Idle":3.33333333333333,"Skill1_1":0.166666666666667,"Skill1_2":3.33333333333333,"Skill1_3":0.233333333333333,"Skill2_1":0.8,"Start":1.0}}},
	"vigil":{"front":preload("res://assets/operators/vigil/front/vigil.res"),"back":preload("res://assets/operators/vigil/back/vigil.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":13.3333333333333,"deploy_seconds":1.0,"idle_seconds_back":2.66666666666667,"down_clip":"Attack_Down","down_seconds":1.0,"skill_actions":[{"cast":"Skill1"},{"cast":"Skill2"},{"cast":"Skill3_ABC_Idle_Into","idle":"Skill3_Idle","attack":"Skill3_Attack_A"}],"skill_actions_back":[{"cast":"Skill1"},{"cast":"Skill2"},{"cast":"Skill3_ABC_Idle_Into","idle":"Skill3_Idle","attack":"Skill3_Attack_A"}],"animation_seconds":{"front":{"Attack":1.0,"Attack_Begin":0.0333333333333333,"Attack_Down":1.0,"Attack_Down_Begin":0.0333333333333333,"Attack_Down_End":0.166666666666667,"Attack_End":0.166666666666667,"Default":0.0,"Die":1.0,"Idle":13.3333333333333,"Skill1":1.0,"Skill2":1.0,"Skill3_ABC_Idle_Into":1.0,"Skill3_Attack_A":1.0,"Skill3_Attack_B":1.0,"Skill3_Attack_C":1.0,"Skill3_Begin":0.0333333333333333,"Skill3_End":0.0333333333333333,"Skill3_Idle":2.66666666666667,"Start":1.0},"back":{"Attack":1.0,"Attack_Begin":0.0333333333333333,"Attack_End":0.166666666666667,"Default":0.0,"Idle":2.66666666666667,"Skill1":1.0,"Skill2":1.0,"Skill3_ABC_Idle_Into":1.0,"Skill3_Attack_A":1.0,"Skill3_Attack_B":1.0,"Skill3_Attack_C":1.0,"Skill3_Begin":0.0333333333333333,"Skill3_End":0.0333333333333333,"Skill3_Idle":2.66666666666667,"Start":1.0}}},
	"curse_doll":{"front":preload("res://assets/operators/curse_doll/single/curse_doll.res"),"back":preload("res://assets/operators/curse_doll/single/curse_doll.res"),"attack_clip":"Idle","attack_seconds":0.9333333333333333,"idle_seconds":0.9333333333333333,"deploy_seconds":1.0,"body_cell_ratio":0.65},
	"haze":{"front":preload("res://assets/operators/haze/front/haze.res"),"back":preload("res://assets/operators/haze/back/haze.res"),"attack_clip":"Attack_Loop","attack_seconds":0.833333333333333,"idle_seconds":2.0,"deploy_seconds":1.0,"chain_seconds":"0.166666666666667,0.833333333333333,0.166666666666667"},
	"jessica":{"front":preload("res://assets/operators/jessica/front/jessica.res"),"back":preload("res://assets/operators/jessica/back/jessica.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"sussurro":{"front":preload("res://assets/operators/sussurro/front/sussurro.res"),"back":preload("res://assets/operators/sussurro/back/sussurro.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"gummy":{"front":preload("res://assets/operators/gummy/front/gummy.res"),"back":preload("res://assets/operators/gummy/back/gummy.res"),"attack_clip":"Attack","attack_seconds":1.33333333333333,"idle_seconds":1.0,"deploy_seconds":1.0},
	"podenco":{"front":preload("res://assets/operators/podenco/front/podenco.res"),"back":preload("res://assets/operators/podenco/back/podenco.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0,"idle_seconds_back":1.0},
	"elysium":{"front":preload("res://assets/operators/elysium/front/elysium.res"),"back":preload("res://assets/operators/elysium/back/elysium.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":2.4,"deploy_seconds":1.0},
	"warfarin":{"front":preload("res://assets/operators/warfarin/front/warfarin.res"),"back":preload("res://assets/operators/warfarin/back/warfarin.res"),"attack_clip":"Attack","attack_seconds":1.16666666666667,"idle_seconds":2.0,"deploy_seconds":1.0},
	"shamare":{"front":preload("res://assets/operators/shamare/front/shamare.res"),"back":preload("res://assets/operators/shamare/back/shamare.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":1.0,"deploy_seconds":1.0},
	"feater":{"front":preload("res://assets/operators/feater/front/feater.res"),"back":preload("res://assets/operators/feater/back/feater.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":6.0,"deploy_seconds":1.2,"down_clip":"Attack_Down","down_seconds":1.2},
	"rosa":{"front":preload("res://assets/operators/rosa/front/rosa.res"),"back":preload("res://assets/operators/rosa/back/rosa.res"),"attack_clip":"Attack","attack_seconds":2.66666666666667,"idle_seconds":3.0,"deploy_seconds":1.0},
	"flametail":{"front":preload("res://assets/operators/flametail/front/flametail.res"),"back":preload("res://assets/operators/flametail/back/flametail.res"),"attack_clip":"Attack","attack_seconds":1.26666666666667,"idle_seconds":1.33333333333333,"deploy_seconds":1.0},
	"passenger":{"front":preload("res://assets/operators/passenger/front/passenger.res"),"back":preload("res://assets/operators/passenger/back/passenger.res"),"attack_clip":"Attack","attack_seconds":2.33333333333333,"idle_seconds":13.3333333333333,"deploy_seconds":1.0},
	"mizuki":{"front":preload("res://assets/operators/mizuki/front/mizuki.res"),"back":preload("res://assets/operators/mizuki/back/mizuki.res"),"attack_clip":"Attack","attack_seconds":1.43333333333333,"idle_seconds":13.3333333333333,"deploy_seconds":1.0},
	"mudrock":{"front":preload("res://assets/operators/mudrock/front/mudrock.res"),"back":preload("res://assets/operators/mudrock/back/mudrock.res"),"attack_clip":"Attack","attack_seconds":1.6,"idle_seconds":2.66666666666667,"deploy_seconds":1.0},
	"mountain":{"front":preload("res://assets/operators/mountain/front/mountain.res"),"back":preload("res://assets/operators/mountain/back/mountain.res"),"attack_clip":"Attack_A","attack_seconds":0.4,"idle_seconds":2.4,"deploy_seconds":1.0},
	"surtr":{"front":preload("res://assets/operators/surtr/front/surtr.res"),"back":preload("res://assets/operators/surtr/back/surtr.res"),"attack_clip":"Attack","attack_seconds":1.3,"idle_seconds":2.66666666666667,"deploy_seconds":1.0,"reset_on_clip_change":true},
	"myrtle":{"front":preload("res://assets/operators/myrtle/front/myrtle.res"),"back":preload("res://assets/operators/myrtle/back/myrtle.res"),"attack_clip":"Attack","attack_seconds":1.3333333333333333,"idle_seconds":3.3333333333333335,"deploy_seconds":1},
	"hellagur":{"front":preload("res://assets/operators/hellagur/front/hellagur.res"),"back":preload("res://assets/operators/hellagur/back/hellagur.res"),"attack_clip":"Attack","attack_seconds":1.3,"idle_seconds":3.2,"deploy_seconds":1},
	"nearl":{"front":preload("res://assets/operators/nearl/front/nearl.res"),"back":preload("res://assets/operators/nearl/back/nearl.res"),"attack_clip":"Attack","attack_seconds":1,"idle_seconds":2,"deploy_seconds":0.8333333333333334},
	"meteorite":{"front":preload("res://assets/operators/meteorite/front/meteorite.res"),"back":preload("res://assets/operators/meteorite/back/meteorite.res"),"attack_clip":"Attack","attack_seconds":0.9666666666666667,"idle_seconds":2,"deploy_seconds":1},
	"gitano":{"front":preload("res://assets/operators/gitano/front/gitano.res"),"back":preload("res://assets/operators/gitano/back/gitano.res"),"attack_clip":"Attack","attack_seconds":1,"idle_seconds":1.6,"deploy_seconds":1.1,"additive_slots":["F_Ball_Rotation","B_Ball_Rotation"]},
	"silence":{"front":preload("res://assets/operators/silence/front/silence.res"),"back":preload("res://assets/operators/silence/back/silence.res"),"attack_clip":"Attack","attack_seconds":2.8333333333333335,"idle_seconds":3,"deploy_seconds":1},
	"sora":{"front":preload("res://assets/operators/sora/front/sora.res"),"back":preload("res://assets/operators/sora/back/sora.res"),"attack_clip":"Idle","attack_seconds":10.633333333333333,"idle_seconds":10.633333333333333,"deploy_seconds":3.466666666666667},
	"cliffheart":{"front":preload("res://assets/operators/cliffheart/front/cliffheart.res"),"back":preload("res://assets/operators/cliffheart/back/cliffheart.res"),"attack_clip":"Attack","attack_seconds":1.5,"idle_seconds":2,"deploy_seconds":1},
	"medical_drone":{"front":preload("res://assets/operators/medical_drone/single/medical_drone.res"),"back":preload("res://assets/operators/medical_drone/single/medical_drone.res"),"attack_clip":"Idle","attack_seconds":1,"idle_seconds":1},
	"zima":{"front":preload("res://assets/operators/zima/front/zima.res"),"back":preload("res://assets/operators/zima/back/zima.res"),"attack_clip":"Attack","attack_seconds":1.4333333333333333,"idle_seconds":1.0,"deploy_seconds":1.0},
	"liskarm":{"front":preload("res://assets/operators/liskarm/front/liskarm.res"),"back":preload("res://assets/operators/liskarm/back/liskarm.res"),"attack_clip":"Attack_Loop","attack_seconds":1.2,"idle_seconds":2.0,"deploy_seconds":1.0,"chain_seconds":"0.3333333333333333,1.2,0.3333333333333333"},
	"blue_poison":{"front":preload("res://assets/operators/blue_poison/front/blue_poison.res"),"back":preload("res://assets/operators/blue_poison/back/blue_poison.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":4.0,"deploy_seconds":1.0},
	"projekt_red":{"front":preload("res://assets/operators/projekt_red/front/projekt_red.res"),"back":preload("res://assets/operators/projekt_red/back/projekt_red.res"),"attack_clip":"Attack","attack_seconds":1.1666666666666667,"idle_seconds":2.0,"deploy_seconds":1.0},
	"amiya":{"front":preload("res://assets/operators/amiya/front/amiya.res"),"back":preload("res://assets/operators/amiya/back/amiya.res"),"attack_clip":"Attack","attack_seconds":1.7666666666666666,"idle_seconds":1.0,"deploy_seconds":1.0,"chain_seconds":"0.13333333333333333,1.7666666666666666,0.13333333333333333"},
	"skyfire":{"front":preload("res://assets/operators/skyfire/front/skyfire.res"),"back":preload("res://assets/operators/skyfire/back/skyfire.res"),"attack_clip":"Attack","attack_seconds":2.6666666666666665,"idle_seconds":1.0,"deploy_seconds":1.0},
	"istina":{"front":preload("res://assets/operators/istina/front/istina.res"),"back":preload("res://assets/operators/istina/back/istina.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":2.0,"deploy_seconds":1.0},
	"pramanix":{"front":preload("res://assets/operators/pramanix/front/pramanix.res"),"back":preload("res://assets/operators/pramanix/back/pramanix.res"),"attack_clip":"Attack","attack_seconds":1.1666666666666667,"idle_seconds":2.0,"deploy_seconds":1.0},
	"platinum":{"front":preload("res://assets/operators/platinum/front/platinum.res"),"back":preload("res://assets/operators/platinum/back/platinum.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"specter":{"front":preload("res://assets/operators/specter/front/specter.res"),"back":preload("res://assets/operators/specter/back/specter.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"perfumer":{"front":preload("res://assets/operators/perfumer/front/perfumer.res"),"back":preload("res://assets/operators/perfumer/back/perfumer.res"),"attack_clip":"Attack","attack_seconds":3.0,"idle_seconds":3.0,"deploy_seconds":1.0},
	"cuora":{"front":preload("res://assets/operators/cuora/front/cuora.res"),"back":preload("res://assets/operators/cuora/back/cuora.res"),"attack_clip":"Attack","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"texas":{"front":preload("res://assets/operators/texas/front/texas.res"),"back":preload("res://assets/operators/texas/back/texas.res"),"attack_clip":"Attack_Loop","attack_seconds":1.0,"idle_seconds":2.0,"deploy_seconds":1.0},
	"lappland":{"front":preload("res://assets/operators/lappland/front/lappland.res"),"back":preload("res://assets/operators/lappland/back/lappland.res"),"attack_clip":"Attack","attack_seconds":1.3333333333333333,"idle_seconds":2.0,"deploy_seconds":0.8333333333333334},
	"ptilopsis":{"front":preload("res://assets/operators/ptilopsis/front/ptilopsis.res"),"back":preload("res://assets/operators/ptilopsis/back/ptilopsis.res"),"attack_clip":"Attack","attack_seconds":1.2,"idle_seconds":2.0,"deploy_seconds":1.0},
	"gravel":{"front":preload("res://assets/operators/gravel/front/gravel.res"),"back":preload("res://assets/operators/gravel/back/gravel.res"),"attack_clip":"Attack","attack_seconds":0.9666666666666667,"idle_seconds":2.0,"deploy_seconds":1.0},
	"w": {
		"front": preload("res://assets/operators/w/front/w.res"),
		"back": preload("res://assets/operators/w/back/w.res"),
		"attack_clip": "Attack", "attack_seconds": 1.4666666666666666,
		"idle_seconds": 2.6666666666666665, "deploy_seconds": 1,
		"down_clip": "Attack_Down", "down_seconds": 1.4666666666666666,
	},
	"saga": {
		"front": preload("res://assets/operators/saga/front/saga.res"),
		"back": preload("res://assets/operators/saga/back/saga.res"),
		"attack_clip": "Attack_Loop", "attack_seconds": 1,
		"idle_seconds": 4, "deploy_seconds": 1,
		"chain_seconds": "0.1333333333,1.0,0.1333333333",
	},
	"lumen": {
		"front": preload("res://assets/operators/lumen/front/lumen.res"),
		"back": preload("res://assets/operators/lumen/back/lumen.res"),
		"attack_clip": "Attack", "attack_seconds": 1.3333333333333333,
		"idle_seconds": 4, "deploy_seconds": 1,
	},
	"skadi_alter": {
		"front": preload("res://assets/operators/skadi_alter/front/skadi_alter.res"),
		"back": preload("res://assets/operators/skadi_alter/back/skadi_alter.res"),
		"attack_clip": "Idle", "attack_seconds": 8.766666666666667,
		"idle_seconds": 8.766666666666667, "deploy_seconds": 1,
	},
	"seaborn": {
		"front": preload("res://assets/operators/seaborn/single/seaborn.res"),
		"back": preload("res://assets/operators/seaborn/single/seaborn.res"),
		"attack_clip": "Skill", "attack_seconds": 1.0666666666666667,
		"idle_seconds": 1.3333333333333333, "deploy_seconds": 1,
		"body_cell_ratio": 0.7,
	},
	"w_mine": {
		"front": preload("res://assets/operators/w_mine/single/w_mine.res"),
		"back": preload("res://assets/operators/w_mine/single/w_mine.res"),
		"attack_clip": "Attack", "attack_seconds": 1.5,
		"idle_seconds": 0, "deploy_seconds": 0.5,
		"body_cell_ratio": 0.28,
	},
	"chen": {
		"front": preload("res://assets/operators/chen/front/chen.res"),
		"back": preload("res://assets/operators/chen/back/chen.res"),
		"attack_clip": "Attack", "attack_seconds": 1.5,
		"idle_seconds": 2.0, "deploy_seconds": 0.8333333333333334,
	},
	"aak": {
		"front": preload("res://assets/operators/aak/front/aak.res"),
		"back": preload("res://assets/operators/aak/back/aak.res"),
		"attack_clip": "Attack_Loop", "attack_seconds": 1.4,
		"idle_seconds": 3.2, "deploy_seconds": 1.0,
		"chain_seconds": "0.3333333333,1.4,0.2333333333",
		"down_clip": "Attack_Down_Loop", "down_seconds": 1.4,
	},
	"nian": {
		"front": preload("res://assets/operators/nian/front/nian.res"),
		"back": preload("res://assets/operators/nian/back/nian.res"),
		"attack_clip": "Attack_Loop", "attack_seconds": 1.5,
		"idle_seconds": 2.6666666666666665, "deploy_seconds": 1.0,
		"chain_seconds": "0.5,1.5,0.5",
	},
	"kaltsit": {
		"front": preload("res://assets/operators/kaltsit/front/kaltsit.res"),
		"back": preload("res://assets/operators/kaltsit/back/kaltsit.res"),
		"attack_clip": "Attack", "attack_seconds": 1.0,
		"idle_seconds": 9.0, "deploy_seconds": 1.0,
	},
	"mon3tr": {
		"front": preload("res://assets/operators/mon3tr/single/mon3tr.res"),
		"back": preload("res://assets/operators/mon3tr/single/mon3tr.res"),
		"attack_clip": "Attack", "attack_seconds": 0.9333333333333333,
		"idle_seconds": 1.3333333333333333, "deploy_seconds": 1.6666666666666667,
	},
	"nightingale_phantom": {
		"front": preload("res://assets/operators/nightingale_phantom/single/nightingale_phantom.res"),
		"back": preload("res://assets/operators/nightingale_phantom/single/nightingale_phantom.res"),
		"attack_clip": "Idle", "attack_seconds": 0.0,
		"idle_seconds": 0.0, "deploy_seconds": 1.3333333333,
		"body_cell_ratio": 0.9,
	},
	"phantom_clone": {
		"front": preload("res://assets/operators/phantom_clone/front/phantom_clone.res"),
		"back": preload("res://assets/operators/phantom_clone/back/phantom_clone.res"),
		"attack_clip": "Attack", "attack_seconds": 0.8666666667,
		"idle_seconds": 3.0, "deploy_seconds": 1.0,
	},
	"magallan": {
		"front": preload("res://assets/operators/magallan/front/magallan.res"),
		"back": preload("res://assets/operators/magallan/back/magallan.res"),
		"attack_clip": "Attack", "attack_seconds": 1.1,
	},
	"magallan_drone_f": {
		"front": preload("res://assets/operators/magallan_drone_f/magallan_drone_f.res"),
		"back": preload("res://assets/operators/magallan_drone_f/magallan_drone_f.res"),
		"attack_clip": "Idle", "attack_seconds": 1.0, "body_cell_ratio": 0.55,
	},
	"magallan_drone_l": {
		"front": preload("res://assets/operators/magallan_drone_l/magallan_drone_l.res"),
		"back": preload("res://assets/operators/magallan_drone_l/magallan_drone_l.res"),
		"attack_clip": "Attack", "attack_seconds": 1.0, "body_cell_ratio": 0.55,
	},
	"magallan_drone_a": {
		"front": preload("res://assets/operators/magallan_drone_a/magallan_drone_a.res"),
		"back": preload("res://assets/operators/magallan_drone_a/magallan_drone_a.res"),
		"attack_clip": "Attack", "attack_seconds": 1.0, "body_cell_ratio": 0.55,
	},
	"weedy": {
		"front": preload("res://assets/operators/weedy/front/weedy.res"),
		"back": preload("res://assets/operators/weedy/back/weedy.res"),
		"attack_clip": "Attack", "attack_seconds": 1.2,
	},
	"weedy_cannon": {
		"front": preload("res://assets/operators/weedy_cannon/front/weedy_cannon.res"),
		"back": preload("res://assets/operators/weedy_cannon/back/weedy_cannon.res"),
		"attack_clip": "Attack_Loop", "attack_seconds": 3.9666666667,
		"chain_seconds": "0.1666666667,3.9666666667,0.1666666667",
		"down_clip": "Attack_Down_Loop", "down_seconds": 3.9666666667,
		"body_cell_ratio": 0.65,
	},
	"mostima": {
		"front": preload("res://assets/operators/mostima/front/mostima.res"),
		"back": preload("res://assets/operators/mostima/back/mostima.res"),
		"attack_clip": "Attack", "attack_seconds": 1.7333333333,
	},
	"saria": {
		"front": preload("res://assets/operators/saria/front/saria.res"),
		"back": preload("res://assets/operators/saria/back/saria.res"),
		"attack_clip": "Attack", "attack_seconds": 1.1666666667,
	},
	"siege": {
		"front": preload("res://assets/operators/siege/front/siege.res"),
		"back": preload("res://assets/operators/siege/back/siege.res"),
		"attack_clip": "Attack", "attack_seconds": 1.5,
	},
	"ifrit": {
		"front": preload("res://assets/operators/ifrit/front/ifrit.res"),
		"back": preload("res://assets/operators/ifrit/back/ifrit.res"),
		"attack_clip": "Attack", "attack_seconds": 1.3,
		"down_clip": "Attack_Down", "down_seconds": 1.3,
	},
	"typhon": {
		"front": preload("res://assets/operators/typhon/front/typhon.res"),
		"back": preload("res://assets/operators/typhon/back/typhon.res"),
		"attack_clip": "Attack_Loop", "attack_seconds": 2.4,
		"down_clip": "Attack_Down_Loop", "down_seconds": 2.4,
		"chain_seconds": "0.1666666667,2.4,0.3333333333",
	},
	"skadi": {
		"front": preload("res://assets/operators/skadi/front/skadi.res"),
		"back": preload("res://assets/operators/skadi/back/skadi.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.5,
	},
	# 风笛（已验收基线）：复合攻击链，正面/背面 3.8.99。
	"bagpipe": {
		"front": preload("res://assets/operators/bagpipe/front/bagpipe.res"),
		"back": preload("res://assets/operators/bagpipe/back/bagpipe.res"),
		"attack_clip": "Attack_Loop",
		"down_clip": "Attack_Loop_Down",
		"chain_seconds": "0.1667,0.8333,0.1667",
	},
	"angelina": {
		"front": preload("res://assets/operators/angelina/front/angelina.res"),
		"back": preload("res://assets/operators/angelina/back/angelina.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.3333,
	},
	"blaze": {
		"front": preload("res://assets/operators/blaze/front/blaze.res"),
		"back": preload("res://assets/operators/blaze/back/blaze.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
		"down_clip": "Attack_Down",
		"down_seconds": 1.0,
	},
	"ceobe": {
		"front": preload("res://assets/operators/ceobe/front/ceobe.res"),
		"back": preload("res://assets/operators/ceobe/back/ceobe.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.6,
	},
	"exusiai": {
		"front": preload("res://assets/operators/exusiai/front/exusiai.res"),
		"back": preload("res://assets/operators/exusiai/back/exusiai.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
	},
	"eyjafjalla": {
		"front": preload("res://assets/operators/eyjafjalla/front/eyjafjalla.res"),
		"back": preload("res://assets/operators/eyjafjalla/back/eyjafjalla.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.2,
	},
	# 号角：远程 A 与近战 B 两套整段动作，正面 B 稍长（1.2s / 1.0667s）。
	"horn": {
		"front": preload("res://assets/operators/horn/front/horn.res"),
		"back": preload("res://assets/operators/horn/back/horn.res"),
		"attack_clip": "Attack_A",
		"attack_seconds": 1.0667,
		"melee_clip": "Attack_B",
		"melee_seconds": 1.2,
		"melee_seconds_back": 1.0667,
	},
	"hoshiguma": {
		"front": preload("res://assets/operators/hoshiguma/front/hoshiguma.res"),
		"back": preload("res://assets/operators/hoshiguma/back/hoshiguma.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
		"down_clip": "Attack_Down",
		"down_seconds": 1.0,
	},
	"nightingale": {
		"front": preload("res://assets/operators/nightingale/front/nightingale.res"),
		"back": preload("res://assets/operators/nightingale/back/nightingale.res"),
		"attack_clip": "Attack",
		"attack_seconds": 3.0,
	},
	# 傀影：Attack(0.8667s) 为普通攻击，Attack_2 属于技能强化动作，不作为普攻。
	"phantom": {
		"front": preload("res://assets/operators/phantom/front/phantom.res"),
		"back": preload("res://assets/operators/phantom/back/phantom.res"),
		"attack_clip": "Attack",
		"attack_seconds": 0.8667,
	},
	"saileach": {
		"front": preload("res://assets/operators/saileach/front/saileach.res"),
		"back": preload("res://assets/operators/saileach/back/saileach.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
		"idle_seconds": 160.0/30.0,
		"skill_actions": [{"begin":"Skill_1_Begin","loop":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","loop":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","loop":"Skill_3_Loop","end":"Skill_3_End"}],
		"skill_actions_back": [{"begin":"Skill_1_Begin","loop":"Skill_1_Loop","end":"Skill_1_End"},{"begin":"Skill_2_Begin","loop":"Skill_2_Loop","end":"Skill_2_End"},{"begin":"Skill_3_Begin","loop":"Skill_3_Loop","end":"Skill_3_End"}],
		"animation_seconds": {"front":{"Skill_1_Begin":0.5,"Skill_1_Loop":160.0/30.0,"Skill_1_End":7.0/30.0,"Skill_2_Begin":28.0/30.0,"Skill_2_Loop":160.0/30.0,"Skill_2_End":0.5,"Skill_3_Begin":25.0/30.0,"Skill_3_Loop":160.0/30.0,"Skill_3_End":0.5},"back":{"Skill_1_Begin":0.5,"Skill_1_Loop":160.0/30.0,"Skill_1_End":7.0/30.0,"Skill_2_Begin":28.0/30.0,"Skill_2_Loop":160.0/30.0,"Skill_2_End":0.5,"Skill_3_Begin":25.0/30.0,"Skill_3_Loop":160.0/30.0,"Skill_3_End":0.5}},
		"reset_on_clip_change": true,
	},
	# 黑：与风笛同为复合链，但时长不同（Begin 0.2333 + Loop 1.6）。
	"schwarz": {
		"front": preload("res://assets/operators/schwarz/front/schwarz.res"),
		"back": preload("res://assets/operators/schwarz/back/schwarz.res"),
		"attack_clip": "Attack_Loop",
		"chain_seconds": "0.2333,1.6,0.2333",
	},
	"shining": {
		"front": preload("res://assets/operators/shining/front/shining.res"),
		"back": preload("res://assets/operators/shining/back/shining.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
	},
	"silverash": {
		"front": preload("res://assets/operators/silverash/front/silverash.res"),
		"back": preload("res://assets/operators/silverash/back/silverash.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.3333,
	},
	"suzuran": {
		"front": preload("res://assets/operators/suzuran/front/suzuran.res"),
		"back": preload("res://assets/operators/suzuran/back/suzuran.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.4333,
	},
	"swire_alter": {
		"front": preload("res://assets/operators/swire_alter/front/swire_alter.res"),
		"back": preload("res://assets/operators/swire_alter/back/swire_alter.res"),
		"attack_clip": "Attack",
		"attack_seconds": 1.0,
	},
}


static func has(operator_id: String) -> bool:
	return ENTRIES.has(operator_id)


static func entry_for(operator_id: String) -> Dictionary:
	return ENTRIES[operator_id]


## 该干员该面使用的骨架数据资源；view_index 0 为正面、1 为背面。
static func source(entry: Dictionary, view_index: int) -> SpineSkeletonDataResource:
	return entry["front"] if view_index == 0 else entry["back"]


## 该面实际使用的整段攻击动作名；背面有独立命名时用 *_back 覆盖。
static func attack_clip(entry: Dictionary, view_index: int) -> String:
	if view_index == 1 and entry.has("attack_clip_back"):
		return entry["attack_clip_back"]
	return entry["attack_clip"]


## 该面整段攻击动作的原生时长（秒）。
static func attack_seconds(entry: Dictionary, view_index: int) -> float:
	if view_index == 1 and entry.has("attack_seconds_back"):
		return float(entry["attack_seconds_back"])
	return float(entry["attack_seconds"])


## 向下整段攻击动作的原生时长；未声明时按普通攻击时长处理（复合链的 Loop 段同理）。
static func down_seconds(entry: Dictionary) -> float:
	return float(entry["down_seconds"])
