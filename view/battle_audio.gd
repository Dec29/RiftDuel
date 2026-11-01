class_name BattleAudio
extends Node

# Empty cues explicitly mean no verified start sound; attack/hit/loops are separate.
const START_CUES := {
	"wildmane":[["b_char_atkboost"], ["b_char_atkboost"]],
	"gavial_alter":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"eunectes":[[], ["b_char_atkboost"], ["b_char_atkboost"]],
	"chen_alter":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"goldenglow":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"mon3tr_operator":[["p_atk_kxdtctm_d"], ["b_char_healboost"], ["b_char_atkboost"]],
	"stainless":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"gladiia":[["p_atk_seasword_h"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"muelsyse":[["b_char_tactboost"], ["b_char_tactboost"], ["b_char_tactboost"]],
	"mlynar":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"jessica_alter":[["b_char_atkboost"], ["b_char_atkboost"], ["p_skill_navalgunready"]],
	"fiammetta":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"dusk":[["p_atk_ancientsword_d"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"titi":[["b_char_atkboost"], ["b_char_atkboost"], ["p_skill_sdycrtl_s"]],
	"ling":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"shaw":[[], ["b_char_atkboost"]],

	"vigil":[["p_atk_vwgun_d"], ["p_atk_vwgun_d_1"], ["b_char_atkboost"]],
	"thorns":[["b_char_atkboost"], ["b_char_defboost"], ["p_skill_torture", "b_char_atkboost"]],
	"texas_alter":[["b_char_atkboost"], ["p_skill_reticentsword_h"], []],
	"silence_alter":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"reed_alter":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"pozyomka":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost", "p_atk_penarrow_s"]],
	"penance":[["p_atk_gavel_d"], ["b_char_defboost"], ["b_char_defboost"]],
	"pallas":[[], ["b_char_atkboost"], ["b_char_atkboost"]],
	"lin":[["b_char_tactboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"lee":[["b_char_atkboost"], ["b_char_atkboost", "p_skill_paperon"], ["b_char_atkboost", "p_skill_paperboost"]],
	"ines":[["p_atk_insasn_n_1"], ["b_char_atkboost"], []],
	"gnosis":[[], ["b_char_atkboost"], ["b_char_atkboost", "p_skill_iceprickbuff3"]],
	"eyjafjalla_alter":[["p_skill_gtshpbrnch_d"], ["p_skill_gtshpbrnch_h"], ["p_skill_gtshpbrnch_s"]],
	"carnelian":[["b_char_atkboost"], ["b_char_atkboost"], ["b_char_atkboost"]],
	"blemishine":[[], ["b_char_atkboost"], ["b_char_atkboost", "p_skill_glowboost1"]],
	"archetto":[["p_atk_archet_h_cast"], ["b_char_atkboost", "p_skill_archet"], ["b_char_atkboost"]],
	"haze":[[], []],
	"jessica":[[], []],
	"sussurro":[[], []],
	"gummy":[[], []],
	"podenco":[[], []],
	"elysium":[[], []],
	"warfarin":[[], []],
	"shamare":[[], []],
	"feater":[[], []],
	"rosa":[[], [], []],
	"flametail":[[], [], []],
	"passenger":[[], [], []],
	"mizuki":[[], [], []],
	"mudrock":[[], [], []],
	"mountain":[[], [], []],
	"surtr":[[], [], []],

	"cliffheart":[[],["b_char_atkboost"]],
	"sora":[["p_skill_sleepsong"],["p_skill_battlesong","b_char_atkboost"]],
	"silence":[[],["b_char_botready"]],
	"gitano":[[],["b_char_atkboost"]],
	"meteorite":[[],["b_char_atkboost"]],
	"nearl":[[],["b_char_healboost"]],
	"hellagur":[[],["b_char_atkboost"],["b_char_atkboost"]],
	"myrtle":[["b_char_tactboost"],["b_char_healboost"]],
	"zima":[[], ["b_char_tactboost"]],
	"liskarm":[["b_char_addshield"], ["b_char_atkboost"]],
	"blue_poison":[[], ["b_char_atkboost"]],
	"projekt_red":[["b_char_atkboost"], ["p_skill_wolfroar"]],
	"amiya":[[], ["p_skill_spiritexplo"], ["b_char_atkboost"]],
	"skyfire":[["b_char_atkboost"], ["b_char_tactboost"]],
	"istina":[["b_char_atkboost"], ["b_char_tactboost"]],
	"pramanix":[["b_char_tactboost", "p_field_recallbell"], ["b_char_tactboost", "p_field_recallbell"]],

	"platinum":[["b_char_atkboost"],["b_char_tactboost","p_skill_skyeyeopen"]],
	"specter":[["b_char_atkboost"],["b_char_atkboost"]],
	"perfumer":[["b_char_healboost"],["b_char_healboost"]],
	"cuora":[["b_char_defboost"],["b_char_defboost"]],
	"texas":[[],["p_skill_swordrain"]],
	"lappland":[["p_skill_soulwolf"],["p_skill_soulwolf"]],
	"ptilopsis":[["b_char_healboost"],["b_char_healboost"]],
	"gravel":[["b_char_defboost"],["b_char_defboost"]],
	"w":[["b_char_atkboost"],["p_skill_scarebox"],["b_char_atkboost","e_skill_wcountdown"]],
	"saga":[[],["b_char_atkboost","p_skill_ninjasword","p_skill_ninjasword_imp"],["b_char_atkboost","p_skill_ninjaswordboost"]],
	"lumen":[["p_atk_fishheal_g"],["b_char_healboost","p_atk_fishheal_h","p_imp_fishheal_h"],["b_char_healboost"]],
	"skadi_alter":[["p_skill_samegoaldiffways"],["p_skill_burningdarkness"],["p_skill_tidesurging"]],
	"chen":[[],["b_char_atkboost"],["b_char_atkboost"]],
	"aak":[["b_char_tactboost"],["b_char_tactboost"],["b_char_tactboost"]],
	"nian":[["b_char_atkboost"],["b_char_defboost"],["p_skill_irondefense"]],
	"kaltsit":[["b_char_defboost"],["b_char_atkboost"],["p_skill_mon3trburst"]],
	"magallan":[["b_char_tactboost"],["b_char_tactboost"],["b_char_tactboost"]],
	"weedy":[[],["b_char_tactboost"],["b_char_atkboost"]],
	"mostima":[["b_char_atkboost"],["b_char_atkboost"],["b_char_atkboost"]],
	"saria":[[],["p_atk_heal_n"],["b_char_healboost"]],
	"siege":[["b_char_getcast"],[],["b_char_atkboost"]],
	"ifrit":[["b_char_atkboost"],[],["b_char_atkboost"]],
	"typhon":[["b_char_atkboost"],["b_char_atkboost"],["p_skill_mechaxbow_s_aimboost"]],
	"skadi":[["b_char_atkboost"],["b_char_atkboost"],["b_char_atkboost"]],
	"angelina":[["b_char_atkboost"],["p_skill_particulateboost"],["p_skill_particulateboost"]],
	"bagpipe":[["b_char_atkboost"],[],["b_char_tactboost"]],
	"blaze":[[],["b_char_atkboost"],["p_skill_chainsawulmextension_1_intro"]],
	"ceobe":[[],["b_char_atkboost"],["b_char_atkboost"]],
	"exusiai":[[],["b_char_atkboost"],["b_char_atkboost"]],
	"eyjafjalla":[["b_char_atkboost"],[],["b_char_atkboost"]],
	"horn":[["p_atk_blackcannoncast_d"],["b_char_atkboost"],["b_char_atkboost"]],
	"hoshiguma":[["b_char_defboost"],[],["b_char_atkboost"]],
	"nightingale":[["b_char_healboost"],["b_char_addshield"],["b_char_defboost"]],
	"phantom":[["p_skill_nightshade"],["p_skill_nightraid"],["p_skill_gorgeousshow"]],
	"saileach":[["b_char_tactboost"],["b_char_defboost"],["b_char_tactboost"]],
	"schwarz":[[],["b_char_atkboost"],["p_skill_militaryxbowchange","b_char_tactboost"]],
	"shining":[["b_char_healboost"],["b_char_addshield"],["b_char_defboost"]],
	"silverash":[[],["b_char_defboost"],["b_char_atkboost"]],
	"suzuran":[["b_char_atkboost"],["p_skill_specialboost"],["p_skill_specialboost"]],
	"swire_alter":[[],[],["b_char_atkboost"]],
}
const DEPLOY_CUE := "b_char_set"
# Cue and source delay in combat seconds; suffixes are not skill numbers.
const ATTACK_CUES := {
	"wildmane":[["p_atk_spearstab_n", 0.0], ["p_imp_spearstab_n", 0.0]],
	"gavial_alter":[["p_imp_crocsaw_n", 0.0]],
	"eunectes":[["p_atk_snakeknife_n", 0.0], ["p_imp_snakeknife_n", 0.0]],
	"chen_alter":[["p_atk_watergun_n_cast", 0.0], ["p_atk_watergun_n", 0.0], ["p_imp_watergun_n", 0.0]],
	"goldenglow":[["p_atk_sparklight_n", 0.0]],
	"mon3tr_operator":[["p_atk_kxdtctm_n", 0.0], ["p_atk_kxdtctmst_n", 0.0]],
	"stainless":[["p_atk_elecdrill_n", 0.2]],
	"gladiia":[["p_atk_seasword_n", 0.0]],
	"muelsyse":[["p_atk_watermag_n", 0.0]],
	"mlynar":[],
	"jessica_alter":[["p_atk_pistolup_n", 0.0]],
	"fiammetta":[["p_atk_fireboom_n", 0.0]],
	"dusk":[["p_atk_ancientsword_n", 0.0], ["p_imp_ancientsword_n", 0.0]],
	"titi":[["p_atk_sdycrtl_n", 0.0], ["p_atk_sdycrtlfr_n", 0.0]],
	"ling":[["p_atk_lantern_n", 0.0]],
	"shaw":[["p_atk_axe_n", 0.0], ["p_imp_axe_n", 0.0]],

	"vigil_wolf":[["p_atk_vwbite_d_1", 0.0]],
	"pozyomka_typewriter":[["p_atk_pencrossbow_d", 0.0]],

	"archetto":[["p_atk_archet_n", 0.0]],
	"blemishine":[["p_imp_glowsword_n", 0.0]],
	"carnelian":[["p_atk_goldexplo_n", 0.0], ["p_imp_goldexplo_n", 0.0]],
	"eyjafjalla_alter":[["p_atk_gtshpbrnch_n", 0.0]],
	"gnosis":[["p_atk_iceprick_n", 0.0]],
	"ines":[["p_atk_insasn_n_1", 0.0]],
	"lee":[["p_atk_coinsword_n", 0.0], ["p_imp_coinsword_n", 0.0]],
	"lin":[["p_atk_sandswd_d", 0.0], ["p_imp_sandswd_d", 0.0]],
	"pallas":[["p_imp_chainwhip_n", 0.0]],
	"penance":[["p_atk_gavel_n", 0.0], ["p_imp_gavel_n", 0.0]],
	"pozyomka":[["p_atk_penarrow_d", 0.0]],
	"reed_alter":[["p_atk_firespear_n", 0.0]],
	"silence_alter":[["p_atk_slbless_n", 0.0]],
	"texas_alter":[["p_atk_reticentsword_n", 0.0]],
	"thorns":[["p_atk_throwsabre_n", 0.0]],
	"vigil":[["p_atk_vwgun_n", 0.0]],

	"haze":[["p_atk_gmag_n", 0.0]],
	"jessica":[["p_atk_pistol_n", 0.0]],
	"sussurro":[["p_atk_heal_n", 0.0]],
	"gummy":[["p_imp_pot_n", 0.0]],
	"podenco":[["p_atk_flomag_n", 0.0], ["p_imp_flomag_n", 0.0]],
	"elysium":[["p_atk_sword_n", 0.0], ["p_imp_sword_n", 0.0]],
	"warfarin":[["p_atk_bloodheal_n", 0.0]],
	"shamare":[["p_atk_charm2_n", 0.0]],
	"feater":[["p_atk_tekken_n", 0.0], ["p_imp_tekken_n", 0.0]],
	"rosa":[["p_atk_bound_n", 0.0], ["p_atk_bound_n_cast", 0.0]],
	"flametail":[["p_atk_lightsword_n", 0.0], ["p_imp_lightsword_n", 0.0]],
	"passenger":[["p_atk_thunder_n", 0.0]],
	"mizuki":[["p_atk_tentacle_n", 0.3], ["p_imp_tentacle_n", 0.0]],
	"mudrock":[["p_atk_hammer_n", 0.0], ["p_imp_bighammer_n", 0.0]],
	"mountain":[["p_imp_tigerpunch_n", 0.0]],
	"surtr":[["p_atk_firesword_n", 0.0], ["p_imp_firesword_n", 0.0]],

	"cliffheart":[["p_atk_chain_n",0.0]],
	"silence":[["p_atk_bottle_n",0.0]],
	"gitano":[["p_atk_anmag_n",0.0],["p_aoe_nmag_n",0.0]],
	"meteorite":[["p_atk_grenade_n",0.0]],
	"nearl":[["p_atk_blunt_n",0.47],["p_imp_blunt_n",0.0]],
	"hellagur":[["p_atk_falchion_n",0.0],["p_imp_falchion_n",0.0]],
	"myrtle":[["p_atk_flag_n",0.0],["p_imp_flag_n",0.0]],
	"zima":[["p_atk_axe_n", 0.0], ["p_imp_axe_n", 0.0]],
	"liskarm":[["p_atk_pistol_n", 0.0]],
	"blue_poison":[["p_atk_crossbow_n", 0.5], ["p_imp_crossbow_n", 0.0]],
	"projekt_red":[["p_atk_knife_n", 0.25], ["p_imp_knife_n", 0.0]],
	"amiya":[["p_atk_amiyamag_n", 0.35], ["p_imp_amiyamag_n", 0.1]],
	"skyfire":[["p_aoe_firemag_n", 0.0]],
	"istina":[["p_atk_book_n", 0.2], ["p_imp_book_n", 0.0]],
	"pramanix":[["p_atk_shakebell_n", 0.0], ["p_imp_shakebell_n", 0.0]],

	"platinum":[["p_atk_arrow_n",0.0],["p_imp_arrow_n",0.0]],
	"specter":[["p_atk_saw_n",0.3],["p_imp_saw_n",0.0]],
	"perfumer":[["p_atk_heal_l",0.0]],
	"cuora":[["p_atk_bat_n",0.3],["p_imp_bat_n",0.0]],
	"texas":[["p_atk_sword_n",0.27],["p_imp_sword_n",0.0]],
	"lappland":[["p_atk_swordwave_n",0.0],["p_imp_swordwave_n",0.0]],
	"ptilopsis":[["p_atk_heal_n",0.0],["p_imp_heal_n",0.0]],
	"gravel":[["p_imp_knife_n",0.0]],
	"w":[["p_atk_grenade3_n",0.0],["p_imp_grenade3_n",0.0]],
	"saga":[["p_imp_ninjasword_n",0.0]],
	"lumen":[["p_atk_fishheal_n",0.0],["p_imp_fishheal_n",0.0]],
	"chen":[["p_atk_circlesword_n",0.6],["p_imp_circlesword_n",0.0]],
	"aak":[["p_atk_dartpistol_n",0.0],["p_imp_dartpistol_n",0.0]],
	"nian":[["p_atk_blade_n",0.05],["p_imp_blade_n",0.0]],
	"kaltsit":[["p_atk_healpistol_n",0.0]],
	"mon3tr":[["p_atk_mon3tr_n",0.0],["p_imp_prick_n",0.0]],
	"magallan":[["p_atk_icecamera_n",0.0],["p_imp_icecamera_n",0.0]],
	"magallan_drone_l":[["p_atk_uavlaser_n",0.0]],
	"magallan_drone_a":[["p_atk_uavvolley_n",0.0],["p_imp_uavvolley_n",0.0]],
	"weedy":[["p_atk_watercannon_n",0.0],["p_imp_watercannon_n",0.0]],
	"weedy_cannon":[["p_atk_watercannontoken_n",0.0],["p_imp_watercannontoken_n",0.0]],
	"mostima":[["p_atk_timewand_n",0.0],["p_imp_timewand_n",0.0]],
	"saria":[["p_atk_riotshield_n",0.0],["p_imp_riotshield_n",0.0]],
	"siege":[["p_atk_hammer_n",0.0],["p_imp_hammer_n",0.0]],
	"ifrit":[["p_atk_flamethrower_n",0.0]],
	"typhon":[["p_atk_mechaxbow_n",0.0],["p_imp_mechaxbow_n",0.0]],
	"skadi":[["p_atk_sword_n",0.0],["p_imp_sword_n",0.0]],
	"angelina":[["p_atk_aglinamag_n",0.0],["p_imp_aglinamag_n",0.0]],
	"bagpipe":[["p_atk_gunlance_n",0.0],["p_imp_gunlance_n",0.0]],
	"blaze":[["p_atk_chainsaw_n",0.0],["p_imp_chainsaw_n",0.1]],
	"ceobe":[["p_atk_phydark_n",0.0]],
	"exusiai":[["p_atk_smg_n",0.0]],
	"eyjafjalla":[["p_atk_firemag_n",0.5]],
	"horn":[["p_atk_heavygun_n",0.0]],
	"hoshiguma":[["p_imp_slice_n",0.0],["p_atk_rebound_n",0.2]],
	"nightingale":[["p_atk_heal_l",0.3],["p_imp_heal_n",0.0]],
	"phantom":[["p_atk_knife_n",0.0],["p_imp_knife_n",0.0]],
	"saileach":[["p_imp_flagsword_n",0.0]],
	"schwarz":[["p_atk_militaryxbow_n",0.0],["p_imp_militaryxbow_n",0.0]],
	"shining":[["p_atk_heal_n",0.0],["p_imp_heal_n",0.0]],
	"silverash":[["p_atk_silver_n",0.25],["p_imp_sword_n",0.0]],
	"suzuran":[["p_atk_magspell_n",0.0]],
	"swire_alter":[["p_atk_richfan_n",0.0],["p_imp_richfan_n",0.0]],
}
const SKILL_ATTACK_CUES := {
	"archetto":[[], [], []],
	"blemishine":[[], [], []],
	"carnelian":[[], [], []],
	"eyjafjalla_alter":[[], [], []],
	"gnosis":[[["p_atk_iceprick_d", 0.0]], [["p_atk_iceprick_h", 0.0]], []],
	"ines":[[], [], []],
	"lee":[[], [], []],
	"lin":[[], [], []],
	"pallas":[[["p_imp_chainwhip_d", 0.0]], [], []],
	"penance":[[], [], []],
	"pozyomka":[[], [["p_atk_penarrow_h", 0.0]], []],
	"reed_alter":[[], [], []],
	"silence_alter":[[], [], []],
	"texas_alter":[[], [], []],
	"thorns":[[], [], []],
	"vigil":[[], [], []],

	"cliffheart":[[["p_atk_cowboy_h",0.0]],[["p_atk_cowboy_h",0.0]]],
	"meteorite":[[["p_atk_grenade_h",0.0]],[["p_atk_grenade_h",0.0]]],
	"hellagur":[[["p_atk_falchion_h",0.0],["p_imp_falchion_n",0.0]],[],[]],
	"liskarm":[[], [["p_atk_lightning_n", 0.0], ["p_imp_lightning_n", 0.0]]],
	"blue_poison":[[["p_atk_arrow_h", 0.0], ["p_imp_arrow_h", 0.0]], []],
	"amiya":[[], [], [["p_skill_chimera", 0.0]]],
	"skyfire":[[], [["p_skill_aerolitecast", 0.0], ["p_skill_aeroliteexplo", 0.0]]],

	"platinum":[[],[["p_atk_platnm_n",0.0],["p_imp_arrow_n",0.0]]],
	"lappland":[[],[["p_atk_katanawave_n",0.0],["p_imp_katanawave_n",0.0]]],
	"magallan":[[],[["p_atk_icecamera_h",0.0],["p_imp_icecamera_h",0.0]],[["p_atk_icecamera_h",0.0],["p_imp_icecamera_h",0.0]]],
	"weedy":[[["p_atk_watercannon_h",0.0],["p_imp_watercannon_h",0.0]],[["p_atk_watercannon_s",0.0]],[["p_skill_bigwatercannon",0.0],["p_imp_bigwatercannon",0.0]]],
	"mostima":[[],[["p_skill_blacktimewand_shot",0.0],["p_imp_blacktimewand_s",0.0]],[["p_skill_whitetimewand",0.1],["p_atk_whitetimewand_s",0.0]]],
	"siege":[[],[["p_skill_jumphammer_1",0.17],["p_skill_jumphammer_2",0.0]],[]],
	"ifrit":[[],[["p_skill_flameexplo_1",0.1],["p_skill_flameexplo_3",0.0]],[]],
	"typhon":[[],[["p_atk_mechaxbow_h",0.1],["p_imp_mechaxbow_h",0.0]],[["p_atk_mechaxbow_s",0.0],["p_imp_mechaxbow_s_end",1.1]]],
	"skadi":[[],[["p_atk_sword_n",0.0],["p_imp_skadi_h",0.0]],[["p_atk_sword_n",0.0],["p_imp_skadi_h",0.0]]],
	"bagpipe":[[],[["p_atk_gunlance_n",0.0],["p_imp_gunlance_h",0.0]],[]],
	"ceobe":[[["p_atk_axethrow_s",0.0]],[["p_atk_firedagger_s",0.0]],[]],
	"exusiai":[[["p_atk_smg_h",0.0]],[],[]],
	"eyjafjalla":[[],[["p_atk_firemag_n",0.5]],[]],
	"horn":[[["p_atk_blackcannon_d",0.0]],[],[]],
	"schwarz":[[["p_atk_militaryxbow_h",0.0],["p_imp_militaryxbow_h",0.0]],[],[]],
	"silverash":[[["p_atk_silver_n",0.25],["p_atk_hawk_h",0.2]],[],[]],
}
const SFX_OWNERS := {"phantom_clone":"phantom"}
const SKILL_SFX_CHANNELS := 4
const ATTACK_SFX_CHANNELS := 8
const SKILL_VOICE_TAGS := {"myrtle":["025","026","027"]}

const VOICE_GAIN := 0.35
const SFX_GAIN := 0.2
const SKILL_VOICE_COOLDOWN_SECONDS := 20.0
const PREFERENCES := preload("res://preferences.gd")
var rng := RandomNumberGenerator.new()
var voice_volume := PREFERENCES.DEFAULT_VOLUME
var sfx_volume := PREFERENCES.DEFAULT_VOLUME
var voice_sides := "both"
var local_side := 0
var last_voice_tag := ""
var voice_events := 0
var sfx_events := 0
var _voices: Dictionary={}
var _sfx: Dictionary={}
var _counts: Dictionary={}
var _attack_marks: Dictionary={}
var _pending_sounds: Array[Dictionary]=[]
var _voice_players: Array[AudioStreamPlayer]=[]
var _sfx_players: Array[AudioStreamPlayer]=[]
var _voice_cursor := 0
var _sfx_cursor := 0
var _attack_cursor := 0
var _voice_owners: Array[int] = [0,0]
var _next_skill_voice: Dictionary = {}
var _active_seconds := 0.0
var _flame_loops := {}
var _drone_pulse_marks := {}
var _last_w_explosion_id := -1
var _running := false


func _ready() -> void:
	rng.randomize()
	process_mode=Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voice_players.append(player)
	for index in SKILL_SFX_CHANNELS+ATTACK_SFX_CHANNELS:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voices/source_manifest.json"))
	if typeof(manifest)!=TYPE_DICTIONARY or typeof(manifest.get("files"))!=TYPE_ARRAY:
		_fail("voices/source_manifest.json.files: expected array")
		return
	for file in manifest.files:
		if typeof(file)!=TYPE_DICTIONARY or typeof(file.get("operator_id"))!=TYPE_STRING or typeof(file.get("tag"))!=TYPE_STRING or typeof(file.get("path"))!=TYPE_STRING:
			_fail("voices/source_manifest.json.files: invalid operator_id/tag/path")
			return
		var id: String=file.operator_id
		var tag: String=file.tag
		if id not in START_CUES or tag not in (["023","024"] + SKILL_VOICE_TAGS.get(id,["025","026","027","028"])) or file.path!="assets/audio/voices/%s/cn_%s.mp3"%[id,tag]:
			_fail("voices/source_manifest.json: invalid clip "+file.path)
			return
		if not _voices.has(id):_voices[id]={}
		if _voices[id].has(tag):
			_fail("voices/source_manifest.json: duplicate "+id+"/"+tag)
			return
		_voices[id][tag]=_stream("res://"+file.path)
	for id in START_CUES:
		if not _voices.has(id) or _voices[id].size()!=2+SKILL_VOICE_TAGS.get(id,["025","026","027","028"]).size():
			_fail("voices/source_manifest.json: expected original voice set for "+id)
			return
	for cues in START_CUES.values():
		for skill in cues:
			for cue in skill:_cache_sound(cue)
	_cache_sound("p_aoe_flamethrower_loop")
	_cache_sound("p_atk_uavlaser_h")
	_cache_sound("p_field_uavfreeze_n")
	_cache_sound("p_field_uavfreeze_h")
	_cache_sound("p_imp_uavvolley_h")
	_cache_sound(DEPLOY_CUE)
	for cue in ["b_char_tokenset","p_atk_grenade3_h","e_skill_wc4explo","b_char_spskadi1"]:_cache_sound(cue)
	for cue in ["b_char_mon3tr","p_imp_blunt_h","p_skill_chixiaobadao","p_skill_jueying_1","p_skill_jueying_2","p_skill_fulminatingpotionx","p_skill_fulminatingpotiony","p_aoe_mon3tr_n","p_aoe_mon3tr2_n"]:_cache_sound(cue)
	_cache_sound("p_imp_blackshield_n")
	_cache_sound("p_imp_blackshield_d")
	for cues in ATTACK_CUES.values():
		for cue in cues:_cache_sound(cue[0])
	for skills in SKILL_ATTACK_CUES.values():
		for cues in skills:
			for cue in cues:_cache_sound(cue[0])


func begin(state: MatchState, side: int) -> void:
	stop()
	_last_w_explosion_id=state.next_w_explosion_id-1
	local_side=side
	_next_skill_voice.clear()
	_active_seconds=0.0
	_running=true
	_counts.clear()
	_drone_pulse_marks.clear()
	_attack_marks.clear()
	for unit in state.units:
		_counts[unit.unit_id]=unit.skill_activation_count
		_attack_marks[unit.unit_id]=unit.last_attack_tick


func observe(state: MatchState, operators: Dictionary) -> void:
	if state.result!=MatchState.RESULT_RUNNING:
		stop()
		return
	var alive: Array[int]=[]
	var flaming: Array[int]=[]
	for unit in state.units:
		alive.append(unit.unit_id)
		if unit.operator_id=="ifrit" and unit.skill_index==2 and SkillRules.active_ticks(unit)>0 and unit.stun_ticks_left==0 and unit.displacement_ticks_left==0:
			flaming.append(unit.unit_id)
			if not _flame_loops.has(unit.unit_id):
				var player := AudioStreamPlayer.new()
				var stream := _sfx["p_aoe_flamethrower_loop"].duplicate() as AudioStreamMP3
				stream.loop=true;player.stream=stream
				player.volume_linear=SFX_GAIN*float(sfx_volume)/100.0
				add_child(player);_flame_loops[unit.unit_id]=player
				if AudioServer.get_driver_name()!="Dummy":player.play()
		if unit.operator_id=="magallan_drone_f" or (unit.operator_id=="magallan" and unit.skill_index==0):
			var controller := unit if unit.operator_id=="magallan" else DroneRules.owner_for(state,unit)
			if controller!=null and unit.silence_ticks_left==0:
				var active := controller.skill_index==0 and SkillRules.active_ticks(controller)>0
				var elapsed := controller.skill_elapsed_ticks-1 if active else state.tick-1-unit.deployed_tick
				if elapsed>=0 and (active or elapsed>0) and elapsed%90==0 and int(_drone_pulse_marks.get(unit.unit_id,-1))!=state.tick:
					_play_sound("p_field_uavfreeze_h" if active else "p_field_uavfreeze_n",false)
					_drone_pulse_marks[unit.unit_id]=state.tick
		var owner: String=SFX_OWNERS[unit.operator_id] if SFX_OWNERS.has(unit.operator_id) else unit.operator_id
		if not _counts.has(unit.unit_id):
			_play_sound("b_char_tokenset" if unit.operator_id=="medical_drone" else ("b_char_mon3tr" if unit.operator_id=="mon3tr" else ("b_char_spskadi1" if unit.operator_id=="skadi_alter" else DEPLOY_CUE)),true)
			if _voices.has(unit.operator_id):_request_voice(unit,false)
			_counts[unit.unit_id]=0
			_attack_marks[unit.unit_id]=-1
			if owner in START_CUES and operators[unit.operator_id].skills[unit.skill_index].sp_recharge_type=="passive":_cue(owner,unit.skill_index)
		var activations := unit.skill_activation_count-int(_counts[unit.unit_id])
		for _event in activations:
			if _voices.has(unit.operator_id):_request_voice(unit,true)
			if owner in START_CUES:_cue(owner,unit.skill_index)
		if owner in ATTACK_CUES and unit.last_attack_tick>=0 and unit.last_attack_tick!=int(_attack_marks[unit.unit_id]):
			_attack(unit,owner,activations>0,DroneRules.owner_for(state,unit))
		_attack_marks[unit.unit_id]=unit.last_attack_tick
		_counts[unit.unit_id]=unit.skill_activation_count
	for id in _flame_loops.keys():
		if id not in flaming:
			_flame_loops[id].stop();_flame_loops[id].queue_free();_flame_loops.erase(id)
	for id in _counts.keys():
		if id not in alive:
			_counts.erase(id)
			_attack_marks.erase(id)
	for event in state.w_explosion_events:
		if event[0]>_last_w_explosion_id:
			_play_sound("e_skill_wc4explo",true)
			_last_w_explosion_id=event[0]
	var waiting: Array[Dictionary]=[]
	for sound in _pending_sounds:
		if sound.unit_id not in alive:continue
		if sound.tick<=state.tick:_play_sound(sound.cue,false)
		else:waiting.append(sound)
	_pending_sounds=waiting


func apply_preferences(preferences: RefCounted) -> void:
	voice_volume=preferences.voice_volume
	sfx_volume=preferences.sfx_volume
	voice_sides=preferences.voice_sides
	for index in _voice_players.size():
		_voice_players[index].volume_linear=VOICE_GAIN*float(voice_volume)/100.0
		if voice_sides=="local" and _voice_owners[index]!=local_side:_voice_players[index].stop()
	for player in _sfx_players:player.volume_linear=SFX_GAIN*float(sfx_volume)/100.0
	for player in _flame_loops.values():player.volume_linear=SFX_GAIN*float(sfx_volume)/100.0


func _request_voice(unit: UnitState, skill: bool) -> void:
	if voice_sides=="local" and unit.side!=local_side:return
	if skill:
		var key := "%d:%s"%[unit.side,unit.operator_id]
		if _next_skill_voice.has(key) and _active_seconds<float(_next_skill_voice[key]):return
		_next_skill_voice[key]=_active_seconds+SKILL_VOICE_COOLDOWN_SECONDS
	_voice(unit.operator_id,skill,unit.side)


func _voice(id: String, skill: bool, side: int) -> void:
	var choices: Array = SKILL_VOICE_TAGS.get(id,["025","026","027","028"]) if skill else ["023","024"]
	last_voice_tag=choices[rng.randi_range(0,choices.size()-1)]
	voice_events+=1
	var player := _voice_players[_voice_cursor]
	_voice_owners[_voice_cursor]=side
	_voice_cursor=(_voice_cursor+1)%_voice_players.size()
	player.stop()
	player.stream=_voices[id][last_voice_tag]
	player.volume_linear=VOICE_GAIN*float(voice_volume)/100.0
	if AudioServer.get_driver_name()!="Dummy":player.play()


func _cue(id: String, index: int) -> void:
	for cue in START_CUES[id][index]:_play_sound(cue,true)


func _attack(unit: UnitState, owner: String, activated: bool, controller: UnitState = null) -> void:
	if owner=="w" and unit.w_action_tick==unit.last_attack_tick:
		if unit.w_action_kind==0:
			_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick,"cue":"p_atk_grenade3_h"})
			_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick,"cue":"p_imp_grenade3_n"})
		return
	if owner=="saga" and unit.saga_cast_tick==unit.last_attack_tick:return
	if owner=="lumen" and unit.skill_index==0 and unit.lumen_cast_tick==unit.last_attack_tick:return
	if owner=="chen":
		if unit.chen_sheath_tick==unit.last_attack_tick:
			_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick,"cue":"p_imp_blunt_h"});return
		if unit.chen_cast_tick==unit.last_attack_tick and unit.skill_index==1:
			_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick+12,"cue":"p_skill_chixiaobadao"});return
		if unit.skill_index==2 and unit.chen_slash_tick==unit.last_attack_tick:
			_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick,"cue":"p_skill_jueying_2" if unit.chen_slashes_left==0 else "p_skill_jueying_1"});return
	if owner=="aak" and unit.aak_injection_tick==unit.last_attack_tick:
		_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick,"cue":"p_skill_fulminatingpotionx" if unit.skill_index==1 else "p_skill_fulminatingpotiony"});return
	if owner=="ifrit" and unit.skill_index==2 and SkillRules.active_ticks(unit)>0:return
	var cues: Array=ATTACK_CUES[owner]
	var skill_active := (activated and unit.silence_ticks_left==0) or SkillRules.active_ticks(unit)!=0
	# Original .attack.1/.attack.2 variants await prefab/animation verification; do not substitute normal cues.
	if owner in ["hellagur","gitano"] and skill_active and unit.skill_index>0:return
	if unit.last_attack_is_heal:
		if owner in ["myrtle","nearl"]:cues=[["p_atk_heal_n",0.0],["p_imp_heal_n",0.0]]
		elif owner not in ["silence","shining","nightingale","kaltsit","lumen","ptilopsis","perfumer"]:cues=[["p_imp_heal_n",0.0]]
	elif skill_active and (owner!="cliffheart" or unit.pusher_strike_tick==unit.last_attack_tick) and SKILL_ATTACK_CUES.has(owner) and not SKILL_ATTACK_CUES[owner][unit.skill_index].is_empty():
		cues=SKILL_ATTACK_CUES[owner][unit.skill_index]
	if owner=="horn" and Vector2i(unit.last_attack_target_x,unit.last_attack_target_y)==unit.cell:
		cues=[["p_imp_blackshield_d" if skill_active and unit.skill_index==0 else "p_imp_blackshield_n",0.0]]
	if owner=="weedy_cannon" and unit.nitrogen_shot_tick==unit.last_attack_tick:cues=SKILL_ATTACK_CUES["weedy"][2]
	if owner=="mon3tr":
		if unit.mon3tr_mode==2:cues=[["p_aoe_mon3tr_n",0.1],["p_imp_prick_n",0.0]]
		elif unit.mon3tr_mode==3:cues=[["p_atk_mon3tr_n",0.0],["p_aoe_mon3tr2_n",0.0]]
	if controller!=null and SkillRules.active_ticks(controller)>0:
		if owner=="magallan_drone_l":cues=[["p_atk_uavlaser_h",0.0]]
		elif owner=="magallan_drone_a":cues=[["p_atk_uavvolley_n",0.0],["p_imp_uavvolley_h",0.0]]
	for cue in cues:
		_pending_sounds.append({"unit_id":unit.unit_id,"tick":unit.last_attack_tick+ceili(float(cue[1])*Config.TICK_RATE),"cue":cue[0]})


func _play_sound(cue: String, important: bool) -> void:
	sfx_events+=1
	var index := _sfx_cursor if important else SKILL_SFX_CHANNELS+_attack_cursor
	if important:_sfx_cursor=(_sfx_cursor+1)%SKILL_SFX_CHANNELS
	else:_attack_cursor=(_attack_cursor+1)%ATTACK_SFX_CHANNELS
	var player := _sfx_players[index]
	player.stop()
	player.stream=_sfx[cue]
	player.volume_linear=SFX_GAIN*float(sfx_volume)/100.0
	if AudioServer.get_driver_name()!="Dummy":player.play()


func stop() -> void:
	_running=false
	_pending_sounds.clear()
	for player in _flame_loops.values():player.stop();player.queue_free()
	_flame_loops.clear()
	for player in _voice_players:player.stop()
	for player in _sfx_players:player.stop()


func _process(delta: float) -> void:
	if _running and not get_tree().paused:_active_seconds+=delta
	for player in _voice_players:player.stream_paused=get_tree().paused
	for player in _sfx_players:player.stream_paused=get_tree().paused
	for player in _flame_loops.values():player.stream_paused=get_tree().paused


func _exit_tree() -> void:stop()


func _stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream==null:_fail(path+": expected AudioStream")
	return stream


func _cache_sound(cue: String) -> void:
	if not _sfx.has(cue):_sfx[cue]=_stream("res://assets/audio/sfx/%s.mp3"%cue)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
