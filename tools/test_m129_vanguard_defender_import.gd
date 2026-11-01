extends SceneTree
var failures := 0
func check(ok: bool,label: String)->void:
	if not ok:failures+=1;push_error(label)
func _initialize()->void:
	var script := GDScript.new()
	script.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	if script.reload()!=OK:quit(1);return
	var importer: RefCounted=script.new()
	var rows: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://import/source_data/m129/vanguard_defender_rows.json"))
	var file := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := file.get_csv_line();var columns := {}
	for i in header.size():columns[header[i]]=i
	for source in rows.operators:
		var row := PackedStringArray()
		for key in header:row.append(csv_text(source.get(key,"")))
		check(importer._validate_row(row,columns),"Operator row schema "+str(source.operator_name))
		var actual: OperatorData=importer._build_operator(row,columns)
		for extra in rows.skills:
			if extra.operator_id!=actual.operator_id:continue
			var sr := PackedStringArray()
			for key in header:sr.append(csv_text(extra.get(key,"")))
			actual.skills.append(importer._build_skill(sr,columns))
		check(actual.validation_error().is_empty(),actual.operator_id+" generated resource "+actual.validation_error())
		var expected := load("res://resources/operators/"+actual.operator_id+".tres") as OperatorData
		for property in ["operator_id","display_name","profession_id","branch","max_health","attack","defense","magic_resist","block_count","attack_interval","attack_range","deploy_cost","initial_deploy_cost","redeploy_time","group_id"]:check(actual.get(property)==expected.get(property),actual.operator_id+"."+property)
		for slot in ["branch_trait","talent_1","talent_2"]:check(actual.get(slot).effect_type==expected.get(slot).effect_type and actual.get(slot).effect_params==expected.get(slot).effect_params,actual.operator_id+"."+slot)
		check(actual.skills.size()==expected.skills.size(),actual.operator_id+" skill count")
		for i in actual.skills.size():
			for field in ["skill_name","initial_sp","sp_required","sp_recharge_type","trigger_type","effect_type","effect_params","duration","attack_range_override"]:check(actual.skills[i].get(field)==expected.skills[i].get(field),"%s S%d %s"%[actual.operator_id,i+1,field])
	print("M129_VANGUARD_DEFENDER_IMPORT_OK failures=",failures);quit(0 if failures==0 else 1)

func csv_text(value:Variant)->String:
	return str(int(value)) if value is float and value==floor(value) else str(value)
