extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var db=root.get_node("OperatorDB");var data: Dictionary={}
 for id in db.all_ids():data[id]=db.get_data(id)
 var state:=MatchState.new(5,data)
 for id in AttackTimeline.IDS+AttackTimeline.ADAPTED_IDS:
  var op: OperatorData=state._operator_data[id]
  for index in op.skills.size():
   var unit:=UnitState.new(0,0,id,Vector2i.ZERO,1000,0,0,0,index);unit.skill_ticks_left=1000
   var profile:=AttackActionData.profile(unit,true)
   if profile.has("events") and profile.events.size()>1:print(id," S",index+1," ",profile.clip," events",profile.events," declared_shots",op.skills[index].effect_params.get("shot_count",-1))
 quit(0)
