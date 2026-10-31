extends SceneTree
const Player=preload("res://view/original_vfx_player.gd")
const DEFAULT_PROFILE={"actor_attack_clip":"","board_times":[0.35,0.7,1.35],"performance_cycle_seconds":11.1,"id":"weedy_s3","title":"温蒂默认S3","operator_id":"weedy","asset_root":"res://assets/battle/vfx/weedy_s3/","output":"res://.ai/weedy-s3-original-20261021/usable-evidence/","clip_ids":["start","flight","hit","buff"],"start_times":[0.0,0.4,1.05,1.05],"anchors":["source","projectile","target","target"],"target_distance_units":2.8,"projectile_seconds":0.65,"loop_seconds":11.5,"verify_times":[0.35,0.7,1.35,2.1,8.9,9.7,11.1],"hit_verify_time":1.35,"capture_ranges":[[0.0,11.1]]}
var profile: Dictionary=DEFAULT_PROFILE
var asset_root: String
var output_path: String
class Stage extends Node2D:
	var background:=0
	var label: Label
	func _ready() -> void:
		label=Label.new();label.position=Vector2(28,20)
		label.add_theme_font_size_override("font_size",20)
		add_child(label)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),[Color("161d26"),Color("d3d7db"),Color("565e65")][background])
		if background==2:
			for y in 18:
				for x in 32:
					if (x+y)%2==0:draw_rect(Rect2(x*40,y*40,40,40),Color("899197"))
		for x in range(150,1150,80):draw_line(Vector2(x,180),Vector2(x,600),Color(0.4,0.6,0.7,0.2))
		draw_line(Vector2(150,420),Vector2(1150,420),Color(0.4,0.6,0.7,0.3))
var stage: Stage
var clips: Array[Resource]=[]
var players: Array=[]
var age:=0.0
var playing:=true
var rate:=1.0
var facing:=0
var mirrored:=false
var mode: String
var frames:=0
var elapsed:=0.0
var cpu_ms:=PackedFloat64Array()
var delta_ms:=PackedFloat64Array()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	if args.size()>1:profile=JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	asset_root=profile.asset_root;output_path=profile.output
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	mode=args[0] if not args.is_empty() else "interactive"
	stage=Stage.new();root.add_child(stage)
	for id in profile.clip_ids:
		var clip: Resource=load(asset_root+id+".res")
		if not check(clip.frames.size()==4*clip.frames_per_facing,"Four facings "+id):return
		for frame in clip.frames:
			for index in frame.layer_count():
				var material: ShaderMaterial=frame.material_at(index)
				if not check(material.get_shader_parameter("main_texture") is Texture2D,"Saved source texture "+id):return
		clips.append(clip)
	for i in ((6 if mode=="performance" else 1)*clips.size()):
		var player=Player.new();player.attach(stage);players.append(player)
	if mode in ["interactive","controls"]:root.window_input.connect(_input)
	if mode=="controls":await verify_controls();return
	if mode=="verify":await verify();return
	if mode=="capture":await capture();return
	process_frame.connect(tick)
	root.title=String(profile.title)+" · 可用效果 / Space暂停 · ←→逐帧 · B背景 · F朝向 · M镜像 · S慢放 · R重播"

func sample(at: float) -> int:
	var count:=0
	var release: float=profile.start_times[1] if profile.start_times.size()>1 else profile.start_times[0]
	var direction:=Vector2(cos(facing*PI/2),sin(facing*PI/2)*0.5)
	if mirrored:direction.x=-direction.x
	for group in players.size()/clips.size():
		var origin:=Vector2(470+(group%3)*150,420+(group/3)*120) if players.size()>clips.size() else Vector2(500,420)
		var target: Vector2=origin+direction*float(profile.target_distance_units)*80
		var head:=origin.lerp(target,clampf((at-release)/float(profile.projectile_seconds),0,1))
		var locations: Array[Vector2]=[]
		for anchor in profile.anchors:locations.append({"source":origin,"projectile":head,"target":target}[anchor])
		var starts: Array=profile.start_times
		for i in clips.size():
			if players[group*clips.size()+i].sample(clips[i],at-starts[i],facing,locations[i],80.0,mirrored,20+i):
				count+=1
				if mode=="verify":
					var sampled=players[group*clips.size()+i]
					for layer_index in sampled._layers.size():
						var layer: MeshInstance2D=sampled._layers[layer_index]
						if layer.visible and not check(layer.material==sampled.frame.material_at(layer_index),"Canvas source material binding"):return -1
	stage.label.text=String(profile.title)+" · 原素材分层网格动画  t=%.3fs  %s  %.2f×\nSpace暂停  ←→逐帧  R重播  S慢放  B背景  F朝向  M镜像；组合时点为只读展示配置，未改结算" % [at,"播放" if playing else "暂停",rate]
	stage.queue_redraw()
	return count

func tick() -> void:
	var dt:=root.get_process_delta_time()
	if mode=="performance":
		elapsed+=dt
		var begin:=Time.get_ticks_usec()
		sample(fmod(elapsed,float(profile.performance_cycle_seconds)))
		cpu_ms.append((Time.get_ticks_usec()-begin)/1000.0)
		delta_ms.append(dt*1000)
		frames+=1
		if elapsed>=23:
			cpu_ms.sort();delta_ms.sort()
			var report: Dictionary={"instances":players.size(),"concurrent_skill_sequences":players.size()/4,"seconds":elapsed,"frames":frames,"average_process_fps":frames/elapsed,"cpu_submit_ms_p95":cpu_ms[int(cpu_ms.size()*0.95)],"cpu_submit_ms_median":cpu_ms[cpu_ms.size()/2],"process_delta_ms_p95":delta_ms[int(delta_ms.size()*0.95)],"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"note":"Actual runtime of baked mesh playback; excludes full-match load. Six simultaneous four-part sequences. CPU excludes GPU present."}
			FileAccess.open(output_path+"performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
			print("VFX_PERFORMANCE_OK ",JSON.stringify(report));quit(0)
		return
	if playing:age=fmod(age+dt*rate,float(profile.loop_seconds))
	sample(age)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():return
	if event.keycode==KEY_SPACE:playing=not playing
	elif event.keycode==KEY_RIGHT:playing=false;age=minf(float(profile.loop_seconds),age+1.0/30)
	elif event.keycode==KEY_LEFT:playing=false;age=maxf(0,age-1.0/30)
	elif event.keycode==KEY_R:age=0
	elif event.keycode==KEY_B:stage.background=(stage.background+1)%3
	elif event.keycode==KEY_F:facing=(facing+1)%4
	elif event.keycode==KEY_M:mirrored=not mirrored
	elif event.keycode==KEY_S:rate=0.25 if rate==1 else 1.0

func verify() -> void:
	var results: Array=[]
	for direction in 4:
		facing=direction
		for mirror in [false,true]:
			mirrored=mirror
			for index in clips.size():
				var local_age: float=minf(.35,clips[index].duration_seconds*.5)
				sample(float(profile.start_times[index])+local_age)
				await process_frame
				await RenderingServer.frame_post_draw
				if not check(players[index].instance.visible,"Clip at expected read-only sample "+str(index)):return
				if not check(players[index].frame==clips[index].frame_at(local_age,facing),"Exact frame / facing selection "+str(index)):return
			root.get_texture().get_image().save_png(output_path+"facing%d-mirror%d.png" % [facing,int(mirrored)])
	facing=0;mirrored=false
	for bg in 3:
		stage.background=bg
		for at in profile.verify_times:
			var active:=sample(at)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_path+"bg%d-t%.2f.png" % [bg,at])
			results.append({"background":bg,"time":at,"active":active})
			if at==profile.verify_times[-1]:
				var expected:=0
				for index in clips.size():
					if clips[index].loop_from_seconds>=0 and at>=profile.start_times[index]:expected+=1
				if not check(active==expected,"Finite phases expire; explicit loops remain until caller stops them"):return
	sample(float(profile.hit_verify_time))
	await process_frame
	await RenderingServer.frame_post_draw
	var first:=hash(root.get_texture().get_image().get_region(Rect2i(400,150,650,500)).get_data())
	sample(2.1);sample(float(profile.hit_verify_time))
	await process_frame
	await RenderingServer.frame_post_draw
	var returned:=hash(root.get_texture().get_image().get_region(Rect2i(400,150,650,500)).get_data())
	if not check(first==returned,"Frame seek is repeatable"):return
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var paused:=hash(root.get_texture().get_image().get_region(Rect2i(400,150,650,500)).get_data())
	if not check(first==paused,"Unchanged supplied clock freezes pixels"):return
	for player in players:player.clear()
	if not check(stage.get_child_count()==players.size()+1,"No per-frame node growth"):return
	FileAccess.open(output_path+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"facing_mirror_cases":8,"background_lifecycle_cases":results,"seek_hash":first,"pause_hash":paused,"node_count":stage.get_child_count(),"note":"Component only; no simulation wired, no network or full-match claim."},"\t"))
	print("VFX_COMPONENT_OK: 4 facings x mirror; 3 backgrounds; full lifecycle; seek/pause; nodes reused")
	quit(0)

func capture() -> void:
	stage.background=0
	var capture_index:=0
	for segment in profile.capture_ranges:
		for i in int(ceil((segment[1]-segment[0])*15)):
			sample(float(segment[0])+i/15.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_path+"frame-%03d.png" % capture_index)
			capture_index+=1
	print("VFX_CAPTURE_OK ",capture_index)
	quit(0)

func verify_controls() -> void:
	age=1.35
	for key in [KEY_SPACE,KEY_RIGHT,KEY_LEFT,KEY_S,KEY_B,KEY_F,KEY_M]:
		var event:=InputEventKey.new()
		event.keycode=key;event.pressed=true
		root.window_input.emit(event)
		await process_frame
	if not check(not playing and is_equal_approx(age,1.35) and rate==0.25 and stage.background==1 and facing==1 and mirrored,"Window key route: pause / step / speed / background / facing / mirror"):return
	sample(age)
	await process_frame
	await RenderingServer.frame_post_draw
	var event:=InputEventKey.new();event.keycode=KEY_R;event.pressed=true
	root.window_input.emit(event)
	if not check(age==0,"Replay key"):return
	FileAccess.open(output_path+"controls.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"method":"Window.window_input signal with InputEventKey; not physical OS keyboard input","keys":["Space","Right","Left","S","B","F","M","R"]},"\t"))
	print("VFX_CONTROLS_OK: Window key route, pause, step +/-1/30, quarter speed, background, facing, mirror, replay")
	quit(0)

func check(ok: bool, message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
