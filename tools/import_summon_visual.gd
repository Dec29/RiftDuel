extends SceneTree

const SOURCES := {
	"champagne_bottle": ["token_10031_swire2_gdtrap", ["single"]],
	"mon3tr_reconstruction": ["token_10050_monstr_prosts", ["single"]],
	"ling_soul1": ["token_10020_ling_soul1", ["single"]],
	"ling_soul2": ["token_10020_ling_soul2", ["single"]],
	"ling_soul3": ["token_10020_ling_soul3", ["single"]],
	"flowing_shape": ["token_10030_mlyss_wtrman", ["single"]],
	"jessica_shield": ["token_10032_jesca2_jckshd", ["single"]],
	"dusk_freeling": ["token_10015_dusk_drgn", ["single"]],
	"stainless_device_atk": ["token_10027_ironmn_pile1", ["single"]],
	"stainless_device_sp": ["token_10027_ironmn_pile2", ["single"]],
	"stainless_cannon": ["token_10027_ironmn_pile3", ["single"]],
	"vigil_wolf": ["token_10028_vigil_wolf", ["single"]],
	"pozyomka_typewriter": ["token_10026_bgsnow_subbow", ["single"]],
	"silence_alter_drone": ["token_10029_slent2_protrb", ["single"]],
	"seaborn": ["token_10017_skadi2_dedant", ["single"]],
	"w_mine": ["token_10008_cqbw_box", ["single"]],
	"mon3tr": ["token_10002_kalts_mon3tr", ["single"]],
	"nightingale_phantom": ["token_10003_cgbird_bird", ["single"]],
	"phantom_clone": ["token_10007_phatom_twin", ["front", "back"]],
}

func _initialize() -> void:
	var selected: Array=SOURCES.keys()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size()!=1 or not SOURCES.has(args[0]):
			push_error("Expected one registered summon ID");quit(1);return
		selected=[args[0]]
	for id: String in selected:
		for side: String in SOURCES[id][1]:
			var base := "res://assets/operators/%s/%s/%s" % [id, side, SOURCES[id][0]]
			var atlas := SpineAtlasResource.new()
			var file := SpineSkeletonFileResource.new()
			if atlas.load_from_atlas_file(base + ".atlas") != OK or file.load_from_file(base + ".skel") != OK:
				push_error("Summon source load failed: " + base)
				quit(1)
				return
			var data := SpineSkeletonDataResource.new()
			data.atlas_res = atlas
			data.skeleton_file_res = file
			var out := "res://assets/operators/%s/%s/%s.res" % [id, side, id]
			if not data.ensure_loaded() or data.get_page_count() != 1 or data.is_page_pma(0) or ResourceSaver.save(data, out, ResourceSaver.FLAG_COMPRESS) != OK:
				push_error("Summon native resource failed: %s :: %s" % [base, data.get_last_error()])
				quit(1)
				return
			print("SUMMON_RESOURCE_OK ", id, " ", side, " animations=", data.get_animation_names())
	quit(0)
