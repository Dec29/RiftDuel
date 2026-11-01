extends SceneTree
var failures := 0
func _initialize() -> void:
	var script := GDScript.new()
	script.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	if script.reload()!=OK:quit(1);return
	var importer: RefCounted=script.new();var file := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := file.get_csv_line();var columns := {};var operators := {}
	for i in header.size():columns[header[i]]=i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size()==1 and row[0].is_empty():continue
		if not importer._validate_row(row,columns):quit(1);return
		var op: OperatorData=importer._build_operator(row,columns);operators[op.operator_id]=op
	if not importer._append_skills(operators):quit(1);return
	for id in OS.get_cmdline_user_args():
		var actual: OperatorData=operators[id];var expected := load("res://resources/operators/"+id+".tres") as OperatorData
		for property in ["operator_id","display_name","profession_id","branch","max_health","attack","defense","magic_resist","damage_type","attack_interval","block_count","deploy_cost","initial_deploy_cost","redeploy_time","attack_range","terrain_requirement"]:check(actual.get(property)==expected.get(property),id+" CSV/runtime "+property)
		for slot in ["branch_trait","talent_1","talent_2"]:check(actual.get(slot).effect_type==expected.get(slot).effect_type and actual.get(slot).effect_params==expected.get(slot).effect_params,id+" CSV/runtime "+slot)
		check(actual.skills.size()==3 and expected.skills.size()==3,id+" actual3skills")
		for index in 3:
			for property in ["skill_name","initial_sp","sp_required","sp_recharge_type","trigger_type","duration","effect_type","effect_params","attack_range_override","burst_range_override"]:check(actual.skills[index].get(property)==expected.skills[index].get(property),"%s.S%d.%s CSV/runtime"%[id,index+1,property])
	print("SIX_STAR_IMPORT_OK failures=",failures);quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
