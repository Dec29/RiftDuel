extends SceneTree
# Focused local QA pack. Never builds or replaces the default client.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:push_error("Expected review.json and explicit QA output directory");quit(1);return
	var profile_path:=args[0]
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var base:=args[1].trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var config:="config_version=5\n[application]\nconfig/name=\"Original VFX resource check\"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method=\"forward_plus\"\n"
	FileAccess.open(base+"project.godot",FileAccess.WRITE).store_string(config)
	var pack:=PCKPacker.new()
	if pack.pck_start(ProjectSettings.globalize_path(base+String(profile.id)+"-check.pck"))!=OK:push_error("PCK start");quit(1);return
	var files: Array[String]=["res://view/original_vfx_clip.gd","res://view/original_vfx_frame.gd","res://view/original_vfx_player.gd","res://tools/test_original_vfx.gd","res://assets/battle/vfx/native_add.gdshader","res://assets/battle/vfx/native_mix.gdshader",profile_path]
	for id in profile.clip_ids:files.append(String(profile.asset_root)+String(id)+".res")
	var textures:=String(profile.asset_root)+"textures/"
	for file in DirAccess.get_files_at(textures):
		var path:=textures+file
		files.append(path)
		if file.ends_with(".import"):
			var remap:=ConfigFile.new()
			if remap.load(path)!=OK:push_error("Import remap "+path);quit(1);return
			files.append(remap.get_value("remap","path"))
	for file in files:
		var rc:=pack.add_file(file,ProjectSettings.globalize_path(file))
		if rc!=OK:push_error("PCK add "+file+" "+str(rc));quit(1);return
	if pack.add_file("res://project.godot",ProjectSettings.globalize_path(base+"project.godot"))!=OK or pack.flush()!=OK:
		push_error("PCK finish");quit(1);return
	print("VFX_PCK_OK ",profile.id," ",files.size()," files")
	quit(0)
