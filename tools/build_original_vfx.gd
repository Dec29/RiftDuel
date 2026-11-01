extends SceneTree
const Sampler=preload("res://tools/original_vfx_sampler.gd")
const Frame=preload("res://view/original_vfx_frame.gd")
const Clip=preload("res://view/original_vfx_clip.gd")

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:
		push_error("Expected one explicit effect build.json path");quit(1);return
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if int(config.frames_per_second)<1 or int(config.frames_per_second)>60 or config.clips.is_empty():
		push_error("Invalid frame rate or empty clip list");quit(1);return
	for spec in config.clips:
		if spec.role not in ["start","projectile","hit","attached"] or spec.emission_seconds<=0 or spec.duration_seconds<spec.emission_seconds or spec.attachment_offset.size()!=3:
			push_error("Invalid effect duration / attachment for "+str(spec.id));quit(1);return
	var pack: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(config.source_pack))
	for requirement in pack.get("required_component_adapters",[]):
		if requirement.feature not in ["particle_trails","birth_sub_emitters"]:
			push_error("Source component requires an explicit adapter: "+JSON.stringify(requirement));quit(1);return
	var output: String=config.output
	var rows: Array=[]
	for spec in config.clips:
		if float(spec.get("loop_from_seconds",-1.0))>=float(spec.duration_seconds):
			push_error("Invalid explicit effect loop");quit(1);return
		var sampler=Sampler.new()
		sampler.discard_invisible=bool(config.get("discard_invisible",false))
		sampler.pack=pack
		sampler.asset_root=String(config.source_pack).get_base_dir()
		sampler.restore_prewarm=bool(config.get("restore_prewarm",false))
		sampler.ground_plane=bool(spec.get("ground_plane",false))
		sampler.phase=int(spec.prefab)
		sampler.role=String(spec.role)
		sampler.emission_seconds=float(spec.emission_seconds)
		sampler.sample_horizon=float(spec.duration_seconds)
		sampler.travel_units=float(spec.travel_units)
		sampler.attachment_offset=Vector3(spec.attachment_offset[0],spec.attachment_offset[1],spec.attachment_offset[2])
		sampler.init_particles()
		var clip=Clip.new()
		clip.effect_id=spec.id
		clip.source_prefab=pack.prefabs[int(spec.prefab)].name
		clip.frames_per_second=int(config.frames_per_second)
		clip.duration_seconds=float(spec.duration_seconds)
		clip.emission_seconds=float(spec.emission_seconds)
		clip.loop_from_seconds=float(spec.get("loop_from_seconds",-1.0))
		clip.canonical_travel_units=float(spec.travel_units)
		clip.frames_per_facing=int(ceil(clip.duration_seconds*clip.frames_per_second))
		var begin:=Time.get_ticks_msec()
		for facing in 4:
			for frame in clip.frames_per_facing:
				var entry=Frame.new()
				entry.capture(sampler.sample_mesh(int(spec.prefab),float(frame)/clip.frames_per_second,facing))
				clip.frames.append(entry)
			print("VFX_BAKE_FACING ",spec.id," ",facing)
			await process_frame
		var path:=output+"/"+String(spec.id)+".res"
		var rc:=ResourceSaver.save(clip,path,ResourceSaver.FLAG_COMPRESS)
		if rc!=OK:push_error("Save failed "+path+" "+str(rc));quit(1);return
		rows.append({"id":spec.id,"file":path,"frames":clip.frames.size(),"duration_seconds":clip.duration_seconds,"bake_ms":Time.get_ticks_msec()-begin})
		print("VFX_CLIP_SAVED ",JSON.stringify(rows[-1]))
	FileAccess.open(output+"/build_report.json",FileAccess.WRITE).store_string(JSON.stringify({"fps":config.frames_per_second,"facing_count":4,"clips":rows},"\t"))
	print("VFX_BUILD_OK")
	quit(0)
