extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var data: OperatorData=load("res://resources/operators/swire_alter.tres")
 var state:=MatchState.new(734,{"swire_alter":data})
 var source:=UnitState.new(0,0,"swire_alter",Vector2i(13,5),data.max_health)
 var bomb:=ChampagneBomb.new(1,source,Vector2i(12,5),0,700)
 state.champagne_bombs.append(bomb)
 var original:=state.state_hash()
 for field in ["bomb_id","source_id","side","placed_tick","attack","triggered_tick"]:
  var value: int=bomb.get(field);bomb.set(field,value+1)
  if state.state_hash()==original:push_error("Bomb future field omitted from hash: "+field);quit(1);return
  bomb.set(field,value)
 bomb.cell+=Vector2i.RIGHT
 if state.state_hash()==original:push_error("Bomb cell omitted from hash");quit(1);return
 bomb.cell-=Vector2i.RIGHT
 if state.state_hash()!=original:push_error("Bomb hash not restored");quit(1);return
 print("CHAMPAGNE_BOMB_HASH_OK actual declared fields only; future fields and restoration")
 quit(0)
