extends SceneTree
const IDS := ["ines","vigil"]
var failures := 0
func _initialize() -> void:
	var script := GDScript.new()
	script.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	if script.reload()!=OK:push_error("Importer compile failed");quit(1);return
	var importer: RefCounted=script.new()
	var file := FileAccess.open("res://import/operators.csv",FileAccess.READ)
	var header := file.get_csv_line();var columns := {}
	for i in header.size():columns[header[i]]=i
	var operators := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size()==1 and row[0].is_empty():continue
		if not check(row.size()==header.size(),"CSV column count"):continue
		if not check(importer._validate_row(row,columns),"CSV source row invalid: "+row[columns.operator_name]):continue
		var op: OperatorData=importer._build_operator(row,columns)
		check(not operators.has(op.operator_id),"CSV duplicate "+op.operator_id);operators[op.operator_id]=op
	if not check(operators.size()==importer.OPERATOR_IDS.size(),"Every registered CSV row valid; actual%d expected%d"%[operators.size(),importer.OPERATOR_IDS.size()]):quit(1);return
	if not check(importer._append_skills(operators),"Full catalog additional-skill rows import"):quit(1);return
	for id in IDS:
		var actual: OperatorData=operators[id];var expected := load("res://resources/operators/"+id+".tres") as OperatorData
		for property in ["operator_id","display_name","profession_id","branch","max_health","attack","defense","magic_resist","damage_type","attack_interval","block_count","deploy_cost","redeploy_time","attack_range","terrain_requirement","dodge_physical","dodge_magical"]:
			check(actual.get(property)==expected.get(property),"%s.%s actual=%s expected=%s"%[id,property,str(actual.get(property)),str(expected.get(property))])
		for slot in ["branch_trait","talent_1","talent_2"]:
			check(actual.get(slot).effect_type==expected.get(slot).effect_type and actual.get(slot).effect_params==expected.get(slot).effect_params,id+"."+slot+" effect contract")
		check(actual.skills.size()==expected.skills.size(),id+" original skill count")
		for index in mini(actual.skills.size(),expected.skills.size()):
			for property in ["skill_name","initial_sp","sp_required","sp_recharge_type","trigger_type","duration","effect_type","effect_params","attack_range_override","burst_range_override"]:
				check(actual.skills[index].get(property)==expected.skills[index].get(property),"%s.S%d.%s actual=%s expected=%s"%[id,index+1,property,str(actual.skills[index].get(property)),str(expected.skills[index].get(property))])
	print("Next eight CSV/runtime roundtrip, dynamic full-catalog validation and exact base/skill contracts; failures=%d"%failures);quit(0 if failures==0 else 1)
func check(ok: bool,message: String) -> bool:
	if not ok:failures+=1;push_error(message)
	return ok
