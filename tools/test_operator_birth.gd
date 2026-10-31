extends SceneTree
# Authored transparent birth frames are valid; idle must become visible again.
# Includes undeployable internal actors without fabricating OperatorData entries.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var db=root.get_node("OperatorDB");var content: Dictionary={}
	for id in db.all_ids():content[id]=db.get_data(id)
	var state:=MatchState.new(136,content);var cases:=0;var failures:=0
	var failures_by_id: Dictionary={}
	for id in OperatorSpineMap.ENTRIES:
		if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args():continue
		var entry:=OperatorSpineMap.entry_for(id)
		if not entry.has("deploy_seconds"):continue
		var model:=OperatorSpineVisual.new()
		if not model.initialize(id):push_error(model.last_error);quit(1);return
		for facing in 4:
			for phase in [0,7,12]:
				var actor:=UnitState.new(phase,0,id,Vector2i(11,5),10000,0,10000,facing)
				actor.deployed_tick=100;state.units=[actor];state.tick=100
				for frame in [0.0,.5,1.0,2.0,5.0,6.0,15.0,29.0,float(ceili(float(entry.deploy_seconds)*30)+2)]:
					var before:=state.state_hash();var ok:=model.prepare(actor,100.0+frame,10000)
					if not ok:
						failures+=1
						if not failures_by_id.has(id):failures_by_id[id]=model.last_error
					if before!=state.state_hash():push_error("Birth renderer mutated simulation "+id);quit(1);return
					if ok and frame>float(entry.deploy_seconds)*30 and model.mesh.get_surface_count()==0:push_error("Birth never becomes visible "+id);quit(1);return
					cases+=1
		await process_frame
	print("OPERATOR_BIRTH cases=",cases," failures=",failures," first_failures=",JSON.stringify(failures_by_id))
	if failures>0:push_error("Declared native birth frames were rejected")
	quit(0 if failures==0 else 1)
