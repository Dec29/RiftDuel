extends SceneTree

var failures := 0
const IDS := ["goldenglow","dusk","chen_alter","fiammetta"]


func _initialize() -> void:
	var script := GDScript.new()
	script.source_code=FileAccess.get_file_as_string("res://tools/import_operators.gd").replace("extends EditorScript","extends RefCounted")
	if script.reload()!=OK:quit(1);return
	var importer: RefCounted=script.new()
	var rows: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://import/source_data/m129/runtime_rows.json"))
	var header := FileAccess.open("res://import/operators.csv",FileAccess.READ).get_csv_line()
	var columns := {}
	for index in header.size():columns[header[index]]=index
	var loaded := {}
	for record: Dictionary in rows.operators:
		var row := PackedStringArray()
		for column in header:row.append(str(int(record[column])) if record[column] is float and record[column]==floorf(record[column]) else str(record[column]))
		check(importer._validate_row(row,columns),"CSV row validates "+record.operator_id)
		var data: OperatorData=importer._build_operator(row,columns)
		loaded[data.operator_id]=data
	var skill_header := FileAccess.open("res://import/skills.csv",FileAccess.READ).get_csv_line()
	var skill_columns := {}
	for index in skill_header.size():skill_columns[skill_header[index]]=index
	for record: Dictionary in rows.skills:
		var row := PackedStringArray()
		for column in skill_header:row.append(str(int(record[column])) if record[column] is float and record[column]==floorf(record[column]) else str(record[column]))
		var skill: SkillResource=importer._build_skill(row,skill_columns)
		loaded[record.operator_id].skills.append(skill)
	for id in IDS:
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://import/source_data/m129/"+id+".json"))
		var data := load("res://resources/operators/"+id+".tres") as OperatorData
		check(data.validation_error().is_empty(),id+" resource: "+data.validation_error())
		for entry in data.skills:check(not "<@" in entry.description and not "{" in entry.description,id+" resolved readable skill text")
		check(data.max_health==source.base.maxHp and data.attack==source.base.atk and data.defense==source.base.def and data.magic_resist==source.base.magicResistance,id+" original base")
		var parsed: OperatorData=loaded[id]
		for key in ["operator_id","profession_id","max_health","attack","defense","magic_resist","damage_type","attack_interval","block_count","deploy_cost","initial_deploy_cost","redeploy_time","attack_range","terrain_requirement"]:check(parsed.get(key)==data.get(key),id+" CSV/runtime "+key)
		for slot in ["branch_trait","talent_1","talent_2"]:check(parsed.get(slot).effect_type==data.get(slot).effect_type and parsed.get(slot).effect_params==data.get(slot).effect_params,id+" CSV/runtime "+slot)
		check(parsed.skills.size()==3 and data.skills.size()==3,id+" actual three skills")
		for index in 3:
			for key in ["skill_name","description","initial_sp","sp_required","sp_recharge_type","trigger_type","effect_type","effect_params","duration","attack_range_override"]:check(parsed.skills[index].get(key)==data.skills[index].get(key),"%s.S%d CSV/runtime %s"%[id,index+1,key])
			var invalid := data.skills[index].duplicate(true) as SkillResource
			invalid.effect_params.unexpected=1
			check(not invalid.validation_error().is_empty(),"Strict unknown key "+id)
	print("M129_RANGED_DATA_OK four operators,12skills, pinned bases, strict resources, exact CSV row roundtrip; failures=",failures)
	quit(0 if failures==0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:failures+=1;push_error(message)
