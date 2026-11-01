# Generates compressed SpineSkeletonDataResource files for an operator's default
# battle front/back. Generalizes the verified bagpipe import; the bagpipe entry
# point (tools/import_bagpipe_visual.gd) stays as-is so its verified behaviour and
# evidence remain valid.
#
# Usage: <godot> --headless --path <project> --script res://tools/import_operator_visual.gd
extends SceneTree

# operator_id -> char_id stem of its default-skin battle assets
const OPERATORS := {
	"shaw":"char_277_sqrrel",
	"ling":"char_2023_ling",
	"titi":"char_4056_titi",
	"dusk":"char_2015_dusk",
	"fiammetta":"char_300_phenxi",
	"jessica_alter":"char_1034_jesca2",
	"mlynar":"char_4064_mlynar",
	"muelsyse":"char_249_mlyss",
	"gladiia":"char_474_glady",
	"stainless":"char_4072_ironmn",
	"mon3tr_operator":"char_4179_monstr",
	"goldenglow":"char_377_gdglow",
	"chen_alter":"char_1013_chen2",
	"eunectes":"char_416_zumama",
	"gavial_alter":"char_1026_gvial2",
	"wildmane":"char_496_wildmn",
	"vigil":"char_427_vigil",

	"thorns":"char_293_thorns",

	"texas_alter":"char_1028_texas2",

	"silence_alter":"char_1031_slent2",

	"reed_alter":"char_1020_reed2",

	"pozyomka":"char_4055_bgsnow",

	"penance":"char_4065_judge",

	"pallas":"char_485_pallas",

	"lin":"char_4080_lin",

	"lee":"char_322_lmlee",

	"ines":"char_4087_ines",

	"gnosis":"char_206_gnosis",

	"eyjafjalla_alter":"char_1016_agoat2",

	"carnelian":"char_426_billro",

	"blemishine":"char_423_blemsh",

	"archetto":"char_332_archet",

	"curse_doll":"token_10006_vodfox_doll",
	"haze":"char_141_nights",
	"jessica":"char_235_jesica",
	"sussurro":"char_298_susuro",
	"gummy":"char_196_sunbr",
	"podenco":"char_258_podego",
	"elysium":"char_401_elysm",
	"warfarin":"char_171_bldsk",
	"shamare":"char_254_vodfox",
	"feater":"char_241_panda",
	"rosa":"char_197_poca",
	"flametail":"char_420_flamtl",
	"passenger":"char_472_pasngr",
	"mizuki":"char_437_mizuki",
	"mudrock":"char_311_mudrok",
	"mountain":"char_264_f12yin",
	"surtr":"char_350_surtr",

	"medical_drone":"token_10000_silent_healrb",
	"cliffheart":"char_173_slchan",
	"sora":"char_101_sora",
	"silence":"char_108_silent",
	"gitano":"char_109_fmout",
	"meteorite":"char_219_meteo",
	"nearl":"char_148_nearl",
	"hellagur":"char_188_helage",
	"myrtle":"char_151_myrtle",
	"zima":"char_115_headbr",
	"liskarm":"char_107_liskam",
	"blue_poison":"char_129_bluep",
	"projekt_red":"char_144_red",
	"amiya":"char_002_amiya",
	"skyfire":"char_166_skfire",
	"istina":"char_195_glassb",
	"pramanix":"char_174_slbell",

	"platinum":"char_204_platnm",
	"specter":"char_143_ghost",
	"perfumer":"char_181_flower",
	"cuora":"char_150_snakek",

	"texas":"char_102_texas",
	"lappland":"char_140_whitew",
	"ptilopsis":"char_128_plosis",
	"gravel":"char_237_gravel",

	"w": "char_113_cqbw",
	"saga": "char_362_saga",
	"lumen": "char_4042_lumen",
	"skadi_alter": "char_1012_skadi2",

	"chen": "char_010_chen",
	"aak": "char_225_haak",
	"nian": "char_2014_nian",
	"kaltsit": "char_003_kalts",
	"ifrit": "char_134_ifrit",
	"typhon": "char_2012_typhon",
	"skadi": "char_263_skadi",
	"angelina": "char_291_aglina",
	"blaze": "char_017_huang",
	"ceobe": "char_2013_cerber",
	"eyjafjalla": "char_180_amgoat",
	"horn": "char_4039_horn",
	"hoshiguma": "char_136_hsguma",
	"nightingale": "char_179_cgbird",
	"phantom": "char_250_phatom",
	"saileach": "char_479_sleach",
	"schwarz": "char_340_shwaz",
	"shining": "char_147_shining",
	"silverash": "char_172_svrash",
	"suzuran": "char_358_lisa",
	"swire_alter": "char_1033_swire2",
	"exusiai": "char_103_angel",
}


func _initialize() -> void:
	var selected: Array = OPERATORS.keys()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if Array(args).any(func(id: String)->bool:return not OPERATORS.has(id)):
			push_error("Expected registered operator IDs")
			quit(1)
			return
		selected = Array(args)
	for operator_id: String in selected:
		var stem: String = OPERATORS[operator_id]
		for side: String in (["single"] if operator_id in ["medical_drone","curse_doll"] else ["front", "back"]):
			var base := "res://assets/operators/%s/%s/%s" % [operator_id, side, stem]
			var atlas := SpineAtlasResource.new()
			var file := SpineSkeletonFileResource.new()
			if atlas.load_from_atlas_file(base + ".atlas") != OK or file.load_from_file(base + ".skel") != OK:
				push_error("Spine source load failed: %s %s" % [operator_id, side])
				quit(1)
				return
			var data := SpineSkeletonDataResource.new()
			data.atlas_res = atlas
			data.skeleton_file_res = file
			var out := "res://assets/operators/%s/%s/%s.res" % [operator_id, side, operator_id]
			if not data.ensure_loaded() or ResourceSaver.save(data, out, ResourceSaver.FLAG_COMPRESS) != OK:
				push_error("Spine resource generation failed: %s %s :: %s" % [operator_id, side, data.get_last_error()])
				quit(1)
				return
			print("OPERATOR_RESOURCE_OK ", operator_id, " ", side, " pages=", data.get_page_count())
	quit(0)
