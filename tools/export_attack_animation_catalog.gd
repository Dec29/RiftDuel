extends SceneTree
# Run audit_attack_animation_events first; --write regenerates the pure-data catalog.
func _initialize() -> void:
 var rows: Dictionary={}
 for id in OperatorSpineMap.ENTRIES:
  var entry: Dictionary=OperatorSpineMap.ENTRIES[id];var row: Dictionary={}
  for key in ["attack_clip","down_clip","melee_clip","chain_seconds","skill_actions","skill_actions_back","front_only_skills","attack_only_active","animation_seconds"]:
   if entry.has(key):row[key]=entry[key]
  rows[id]=row
 var path:="res://.ai/attack-timing-20261023/source-events.json"
 if not FileAccess.file_exists(path):push_error("Run the native source audit before catalog export");quit(1);return
 var evidence: Array=JSON.parse_string(FileAccess.get_file_as_string(path))
 var events: Dictionary={};var frames: Dictionary={}
 for action in evidence:
  if not action.completed:push_error("Incomplete native source "+str(action));quit(1);return
  var id: String=action.id;var clip: String=action.clip;var side:=str(int(action.side))
  var duration:=roundi(float(action.completion_sample_usec)*30.0/1000000.0)
  if not frames.has(id):frames[id]={}
  if not frames[id].has(clip):frames[id][clip]={}
  frames[id][clip][side]=duration
  var attacks: Array[int]=[]
  for event in action.events:
   if event.name=="OnAttack":attacks.append(roundi(float(event.time_usec)*30.0/1000000.0))
  if attacks.is_empty():continue
  if not events.has(id):events[id]={}
  if not events[id].has(clip):events[id][clip]={}
  events[id][clip][side]=[duration,attacks]
 if "--write" in OS.get_cmdline_user_args():
  var output:=FileAccess.open("res://data/attack_animation_catalog.gd",FileAccess.WRITE)
  if output==null:push_error("Cannot write attack catalog");quit(1);return
  output.store_string("class_name AttackAnimationCatalog\nextends RefCounted\n# Generated from pinned native events and the existing verified action mapping.\nconst EVENTS := "+JSON.stringify(events)+"\nconst MAPPING := "+JSON.stringify(rows)+"\nconst FRAMES := "+JSON.stringify(frames)+"\n")
 else:
  if events!=AttackActionData.CATALOG.EVENTS or rows!=AttackActionData.CATALOG.MAPPING or frames!=AttackActionData.CATALOG.FRAMES:
   push_error("Catalog differs from native audit/mapping: events%s mapping%s frames%s"%[events==AttackActionData.CATALOG.EVENTS,rows==AttackActionData.CATALOG.MAPPING,frames==AttackActionData.CATALOG.FRAMES]);quit(1);return
 print("ATTACK_CATALOG_OK actions=",evidence.size()," mappings=",rows.size()," event_actors=",events.size());quit(0)
