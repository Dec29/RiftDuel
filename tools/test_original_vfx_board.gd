extends SceneTree
const Player=preload("res://view/original_vfx_player.gd")
const ProfileSource=preload("res://tools/test_original_vfx.gd")
var profile: Dictionary=ProfileSource.DEFAULT_PROFILE
var asset_root: String
var output_path: String
class Board extends MatchView:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("1a1e24"))
		renderer.draw_arena(self)
class Actor extends Node2D:
	var model: OperatorSpineVisual
	var scale_value:=1.0
	var flipped:=false
	func _draw() -> void:
		draw_set_transform(model.anchor_offset(scale_value),0,Vector2(-scale_value if flipped else scale_value,scale_value))
		draw_mesh(model.mesh,model.texture)
var board: Board
var state: MatchState
var units: Array[UnitState]=[]
var actors: Array[Actor]=[]
var clips: Array[Resource]=[]
var players: Array=[]
var label: Label
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():profile=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	asset_root=profile.asset_root;output_path=profile.output
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	var op: OperatorData=load("res://resources/operators/"+String(profile.operator_id)+".tres")
	var ids:=PackedStringArray([profile.operator_id])
	state=MatchState.new(400,{profile.operator_id:op},MatchState.DEFAULT_BALL_DATA,MatchState.DEFAULT_ARENA,[ids,ids],[PackedInt32Array([2]),PackedInt32Array([2])])
	board=Board.new();board.bind(state,LocalInput.new(0),{profile.operator_id:op});root.add_child(board);board.set_process(false)
	for i in 3:
		var unit:=UnitState.new(i,0 if i==0 else 1,String(profile.operator_id),Vector2i(13,5),10000,0,0,0,2)
		if i==0:
			unit.nitrogen_shot_tick=0
			unit.last_attack_tick=0
		units.append(unit);state.units.append(unit)
		var actor:=Actor.new();actor.model=OperatorSpineVisual.new()
		if not check(actor.model.initialize(String(profile.operator_id)),"Native skeleton "+actor.model.last_error):return
		if i==0 and not String(profile.actor_attack_clip).is_empty():
			# QA source-pose override only. No change to production animation mappings.
			for side in 2:
				if not check(profile.actor_attack_clip in actor.model._source(side).get_animation_names(),"Actual source clip exists"):return
			actor.model._entry=actor.model._entry.duplicate(true)
			actor.model._entry["attack_clip"]=profile.actor_attack_clip
		board.add_child(actor);actors.append(actor)
	for id in profile.clip_ids:
		clips.append(load(asset_root+id+".res"))
		var player=Player.new();player.attach(board);players.append(player)
	label=Label.new();label.position=Vector2(28,20);label.z_index=1000;board.add_child(label)
	var cases:=0
	for mirrored in [false,true]:
		board.mirror_board=mirrored;board.projection.mirrored=mirrored
		for facing in 4:
			var offset:=AttackRange.rotate_offset(Vector2i.RIGHT*3,facing)
			units[0].cell=Vector2i(13,5);units[0].facing=facing
			units[1].cell=units[0].cell+offset+Vector2i(0,-1)
			units[2].cell=units[0].cell+offset+Vector2i(0,1)
			units[1].facing=(facing+2)%4;units[2].facing=(facing+2)%4
			var before:=state.state_hash()
			for at in profile.board_times:
				sample(at,facing,mirrored,units[0].cell+offset)
				await process_frame
				await RenderingServer.frame_post_draw
				if not check(state.state_hash()==before,"Projection / actor / VFX are read-only"):return
				var rc:=root.get_texture().get_image().save_png(output_path+"board-f%d-m%d-t%.2f.png" % [facing,int(mirrored),at])
				if not check(rc==OK,"Board capture"):return
				cases+=1
	if not check(players[2].instance.z_index>actors[1].z_index and players[2].instance.z_index<actors[2].z_index,"VFX depth between rear and front actor anchors"):return
	FileAccess.open(output_path+"board-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"cases":cases,"real_resources":"BoardProjection + BattleRenderer.draw_arena + OperatorSpineVisual source pose","scope":"QA fixture composes separate actor items to test depth API; does not replace MatchView draw ordering or wire battle events."},"\t"))
	print("VFX_BOARD_OK: 24 actor/board/facing/mirror captures; state hash unchanged; depth brackets")
	quit(0)
func sample(at: float, facing: int, mirrored: bool, target_cell: Vector2i) -> void:
	var origin:=board.projection.cell_rect(units[0].cell).get_center()
	var target:=board.projection.cell_rect(target_cell).get_center()
	var polygon:=board.projection.cell_polygon(units[0].cell)
	var width:=polygon[0].distance_to(polygon[1])
	for i in 3:
		actors[i].position=board.projection.cell_rect(units[i].cell).get_center()
		actors[i].z_index=roundi(actors[i].position.y)
		actors[i].scale_value=actors[i].model.scale_for_row(width)
		actors[i].flipped=(units[i].facing==2)!=mirrored
		if not actors[i].model.prepare(units[i],at*30.0,90):push_error(actors[i].model.last_error);quit(1);return
		actors[i].queue_redraw()
	var release: float=profile.start_times[1]
	var head:=origin.lerp(target,clampf((at-release)/float(profile.projectile_seconds),0,1))
	var locations: Array[Vector2]=[]
	for anchor in profile.anchors:locations.append({"source":origin,"projectile":head,"target":target}[anchor])
	var starts: Array=profile.start_times
	for i in 4:
		players[i].sample(clips[i],at-starts[i],facing,locations[i],width,mirrored,roundi(locations[i].y))
	label.text=String(profile.title)+" · 原生角色 / 实际棋盘投影 · f=%d mirror=%s t=%.2f\n展示时钟仅读取；后排角色在效果之后，前排角色遮挡效果；正式结算锚点未接入" % [facing,mirrored,at]
	board.queue_redraw()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
