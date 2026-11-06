class_name SkillIconVisual
extends RefCounted

const PALETTE := preload("res://view/palette.gd")
const OPERATOR_DB := preload("res://data/operator_db.gd")
# Original skill IDs/icon IDs; bindings and fixed sources are in the asset manifest.
const ICON_IDS := {
 "aak": [
  "skchr_haak_1",
  "skchr_haak_2",
  "skchr_haak_3"
 ],
 "amiya": [
  "skcom_magic_rage[3]",
  "skchr_amiya_2",
  "skchr_amiya_3"
 ],
 "angelina": [
  "skchr_aglina_1",
  "skchr_aglina_2",
  "skchr_aglina_3"
 ],
 "archetto": [
  "skchr_archet_1",
  "skchr_archet_2",
  "skchr_archet_3"
 ],
 "bagpipe": [
  "skcom_quickattack[3]",
  "skchr_bpipe_2",
  "skchr_bpipe_3"
 ],
 "blaze": [
  "skcom_powerstrike[3]",
  "skchr_huang_2",
  "skchr_huang_3"
 ],
 "blemishine": [
  "skchr_blemsh_1",
  "skchr_blemsh_2",
  "skchr_blemsh_3"
 ],
 "blue_poison": [
  "skchr_bluep_1",
  "skchr_bluep_2"
 ],
 "carnelian": [
  "skchr_billro_1",
  "skchr_billro_2",
  "skchr_billro_3"
 ],
 "ceobe": [
  "skchr_cerber_1",
  "skchr_cerber_2",
  "skchr_cerber_3"
 ],
 "chen": [
  "skchr_chen_1",
  "skchr_chen_2",
  "skchr_chen_3"
 ],
 "chen_alter": [
  "skchr_chen2_1",
  "skchr_chen2_2",
  "skchr_chen2_3"
 ],
 "cliffheart": [
  "skchr_slchan_1",
  "skchr_slchan_2"
 ],
 "cuora": [
  "skcom_def_up[2]",
  "skchr_snakek_2"
 ],
 "dusk": [
  "skchr_dusk_1",
  "skchr_dusk_2",
  "skchr_dusk_3"
 ],
 "elysium": [
  "skcom_assist_cost[3]",
  "skchr_elysm_2"
 ],
 "eunectes": [
  "skchr_zumama_1",
  "skchr_zumama_2",
  "skchr_zumama_3"
 ],
 "exusiai": [
  "skchr_angel_1",
  "skchr_angel_2",
  "skchr_angel_3"
 ],
 "eyjafjalla": [
  "skchr_amgoat_1",
  "skchr_amgoat_2",
  "skchr_amgoat_3"
 ],
 "eyjafjalla_alter": [
  "skchr_agoat2_1",
  "skchr_agoat2_2",
  "skchr_agoat2_3"
 ],
 "feater": [
  "skchr_panda_1",
  "skchr_panda_2"
 ],
 "fiammetta": [
  "skchr_phenxi_1",
  "skchr_phenxi_2",
  "skchr_phenxi_3"
 ],
 "flametail": [
  "skchr_flamtl_1",
  "skchr_flamtl_2",
  "skchr_flamtl_3"
 ],
 "gavial_alter": [
  "skchr_gvial2_1",
  "skchr_gvial2_2",
  "skchr_gvial2_3"
 ],
 "gitano": [
  "skcom_magic_rage[2]",
  "skchr_fmout_2"
 ],
 "gladiia": [
  "skchr_glady_1",
  "skchr_glady_2",
  "skchr_glady_3"
 ],
 "gnosis": [
  "skchr_gnosis_1",
  "skchr_gnosis_2",
  "skchr_gnosis_3"
 ],
 "goldenglow": [
  "skchr_gdglow_1",
  "skchr_gdglow_2",
  "skchr_gdglow_3"
 ],
 "gravel": [
  "skchr_gravel_1",
  "skchr_gravel_2"
 ],
 "gummy": [
  "skchr_sunbr_1",
  "skchr_sunbr_2"
 ],
 "haze": [
  "skcom_atk_up[2]",
  "skchr_nights_2"
 ],
 "hellagur": [
  "skchr_helage_1",
  "skchr_helage_2",
  "skchr_helage_3"
 ],
 "horn": [
  "skchr_horn_1",
  "skchr_horn_2",
  "skchr_horn_3"
 ],
 "hoshiguma": [
  "skchr_hsguma_1",
  "skchr_hsguma_2",
  "skchr_hsguma_3"
 ],
 "ifrit": [
  "skchr_ifrit_1",
  "skchr_ifrit_2",
  "skchr_ifrit_3"
 ],
 "ines": [
  "skchr_ines_1",
  "skchr_ines_2",
  "skchr_ines_3"
 ],
 "istina": [
  "skchr_glassb_1",
  "skchr_glassb_2"
 ],
 "jessica": [
  "skcom_powerstrike[2]",
  "skchr_jesica_2"
 ],
 "jessica_alter": [
  "skchr_jesca2_1",
  "skchr_jesca2_2",
  "skchr_jesca2_3"
 ],
 "kaltsit": [
  "skchr_kalts_1",
  "skchr_kalts_2",
  "skchr_kalts_3"
 ],
 "lappland": [
  "skchr_whitew_1",
  "skchr_whitew_2"
 ],
 "lee": [
  "skchr_lmlee_1",
  "skchr_lmlee_2",
  "skchr_lmlee_3"
 ],
 "lin": [
  "skchr_lin_1",
  "skchr_lin_2",
  "skchr_lin_3"
 ],
 "ling": [
  "skchr_ling_1",
  "skchr_ling_2",
  "skchr_ling_3"
 ],
 "liskarm": [
  "skchr_liskam_1",
  "skchr_liskam_2"
 ],
 "lumen": [
  "skchr_lumen_1",
  "skchr_lumen_2",
  "skchr_lumen_3"
 ],
 "magallan": [
  "skchr_mgllan_1",
  "skchr_mgllan_2",
  "skchr_mgllan_3"
 ],
 "meteorite": [
  "skchr_meteo_1",
  "skchr_meteo_2"
 ],
 "mizuki": [
  "skchr_mizuki_1",
  "skchr_mizuki_2",
  "skchr_mizuki_3"
 ],
 "mlynar": [
  "skchr_mlynar_1",
  "skchr_mlynar_2",
  "skchr_mlynar_3"
 ],
 "mon3tr_operator": [
  "skchr_monstr_1",
  "skchr_monstr_2",
  "skchr_monstr_3"
 ],
 "mostima": [
  "skcom_atk_up[3]",
  "skchr_mostma_2",
  "skchr_mostma_3"
 ],
 "mountain": [
  "skchr_f12yin_1",
  "skchr_f12yin_2",
  "skchr_f12yin_3"
 ],
 "mudrock": [
  "skcom_def_up[3]",
  "skchr_mudrok_2",
  "skchr_mudrok_3"
 ],
 "muelsyse": [
  "skchr_mlyss_1",
  "skchr_mlyss_2",
  "skchr_mlyss_3"
 ],
 "myrtle": [
  "skcom_assist_cost[2]",
  "skchr_myrtle_2"
 ],
 "nearl": [
  "skchr_nearl_1",
  "skchr_nearl_2"
 ],
 "nian": [
  "skchr_nian_1",
  "skchr_nian_2",
  "skchr_nian_3"
 ],
 "nightingale": [
  "skcom_heal_up[3]",
  "skchr_cgbird_2",
  "skchr_cgbird_3"
 ],
 "pallas": [
  "skchr_pallas_1",
  "skchr_pallas_2",
  "skchr_pallas_3"
 ],
 "passenger": [
  "skchr_pasngr_1",
  "skchr_pasngr_2",
  "skchr_pasngr_3"
 ],
 "penance": [
  "skchr_judge_1",
  "skchr_judge_2",
  "skchr_judge_3"
 ],
 "perfumer": [
  "skcom_heal_up[2]",
  "skchr_flower_2"
 ],
 "phantom": [
  "skchr_phatom_1",
  "skchr_phatom_2",
  "skchr_phatom_3"
 ],
 "platinum": [
  "skcom_atk_up[3]",
  "skchr_platnm_2"
 ],
 "podenco": [
  "skchr_podego_1",
  "skchr_podego_2"
 ],
 "pozyomka": [
  "skchr_bgsnow_1",
  "skchr_bgsnow_2",
  "skchr_bgsnow_3"
 ],
 "pramanix": [
  "skchr_slbell_1",
  "skchr_slbell_2"
 ],
 "projekt_red": [
  "skchr_red_1",
  "skchr_red_2"
 ],
 "ptilopsis": [
  "skcom_heal_up[3]",
  "skchr_plosis_2"
 ],
 "reed_alter": [
  "skcom_quickattack[3]",
  "skchr_reed2_2",
  "skchr_reed2_3"
 ],
 "rosa": [
  "skcom_atk_up[3]",
  "skchr_poca_2",
  "skchr_poca_3"
 ],
 "saga": [
  "skcom_charge_cost[3]",
  "skchr_saga_2",
  "skchr_saga_3"
 ],
 "saileach": [
  "skcom_assist_cost[3]",
  "skchr_sleach_2",
  "skchr_sleach_3"
 ],
 "saria": [
  "skchr_demkni_1",
  "skchr_demkni_2",
  "skchr_demkni_3"
 ],
 "schwarz": [
  "skchr_shwaz_1",
  "skchr_shwaz_2",
  "skchr_shwaz_3"
 ],
 "shamare": [
  "skchr_vodfox_1",
  "skchr_vodfox_2"
 ],
 "shaw": [
  "skchr_sqrrel_1",
  "skchr_sqrrel_2"
 ],
 "shining": [
  "skchr_shining_1",
  "skchr_shining_2",
  "skchr_shining_3"
 ],
 "siege": [
  "skcom_charge_cost[3]",
  "skchr_siege_2",
  "skchr_siege_3"
 ],
 "silence": [
  "skcom_heal_up[3]",
  "skchr_silent_2"
 ],
 "silence_alter": [
  "skchr_slent2_1",
  "skchr_slent2_2",
  "skchr_slent2_3"
 ],
 "silverash": [
  "skcom_powerstrike[3]",
  "skchr_svrash_2",
  "skchr_svrash_3"
 ],
 "skadi": [
  "skcom_quickattack[3]",
  "skchr_skadi_2",
  "skchr_skadi_3"
 ],
 "skadi_alter": [
  "skchr_skadi2_1",
  "skchr_skadi2_2",
  "skchr_skadi2_3"
 ],
 "skyfire": [
  "skcom_atk_up[3]",
  "skchr_skfire_2"
 ],
 "sora": [
  "skchr_sora_1",
  "skchr_sora_2"
 ],
 "specter": [
  "skcom_atk_up[3]",
  "skchr_ghost_2"
 ],
 "stainless": [
  "skchr_ironmn_1",
  "skchr_ironmn_2",
  "skchr_ironmn_3"
 ],
 "surtr": [
  "skchr_surtr_1",
  "skchr_surtr_2",
  "skchr_surtr_3"
 ],
 "sussurro": [
  "skcom_heal_up[2]",
  "skchr_susuro_2"
 ],
 "suzuran": [
  "skchr_lisa_1",
  "skchr_lisa_2",
  "skchr_lisa_3"
 ],
 "swire_alter": [
  "skchr_swire2_1",
  "skchr_swire2_2",
  "skchr_swire2_3"
 ],
 "texas": [
  "skcom_charge_cost[3]",
  "skchr_texas_2"
 ],
 "texas_alter": [
  "skchr_texas2_1",
  "skchr_texas2_2",
  "skchr_texas2_3"
 ],
 "thorns": [
  "skcom_atk_up[3]",
  "skchr_thorns_2",
  "skchr_thorns_3"
 ],
 "titi": [
  "skchr_titi_1",
  "skchr_titi_2",
  "skchr_titi_3"
 ],
 "typhon": [
  "skcom_quickattack[3]",
  "skchr_typhon_2",
  "skchr_typhon_3"
 ],
 "vigil": [
  "skchr_vigil_1",
  "skchr_vigil_2",
  "skchr_vigil_3"
 ],
 "w": [
  "skchr_cqbw_1",
  "skchr_cqbw_2",
  "skchr_cqbw_3"
 ],
 "warfarin": [
  "skchr_bldsk_1",
  "skchr_bldsk_2"
 ],
 "weedy": [
  "skchr_weedy_1",
  "skchr_weedy_2",
  "skchr_weedy_3"
 ],
 "wildmane": [
  "skchr_wildmn_1",
  "skchr_wildmn_2"
 ],
 "zima": [
  "skcom_charge_cost[3]",
  "skchr_headbr_2"
 ]
}
static var _textures: Dictionary = {}

static func texture(operator_id: String, skill_index: int) -> Texture2D:
	# Summons have no separately drafted ordinary-operator skill icon.
	# get_data() contains ordinary operators only; use the shared summon registry.
	if OPERATOR_DB.SUMMON_OWNERS.has(operator_id):
		return null
	if not ICON_IDS.has(operator_id):
		push_error(operator_id+": missing ordinary operator skill icon mapping")
		Engine.get_main_loop().quit(1)
		return null
	var id: String = ICON_IDS[operator_id][skill_index]
	if not _textures.has(id):
		var path := "res://assets/icons/skills/%s.png" % id
		var icon := load(path) as Texture2D
		if icon == null:
			push_error(path+": missing registered skill icon")
			Engine.get_main_loop().quit(1)
			return null
		_textures[id] = icon
	return _textures[id]

static func configure_button(button: Button, operator_id: String, index: int, valid: bool) -> void:
	button.icon = texture(operator_id,index) if valid else null
	button.expand_icon = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.x = 0
	button.add_theme_constant_override("icon_max_width",PALETTE.SKILL_BUTTON_ICON_SIZE)
	button.add_theme_constant_override("h_separation",4)
