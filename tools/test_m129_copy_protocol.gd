extends SceneTree
var failures := 0

class SilentLAN:
	extends NetSession
	var sent: Array[Dictionary]=[]
	func _send(message: Dictionary) -> void:sent.append(message)

func check(ok: bool,label: String)->void:
	if not ok:failures+=1;push_error(label)

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var content: Dictionary=root.get_node("OperatorDB").network_content()
	var session := NetSession.new(content);var input := LocalInput.new(0)
	check(InputCommand.Kind.COPY==4 and NetSession.PROTOCOL==6 and RelaySession.PROTOCOL_VERSION==7,"Exactenum andLAN6/relay7")
	for face in 4:
		input.select_operator("bagpipe");input.queue_copy(6,99,"bagpipe",face)
		var rows := CommandCodec.encode(input.take_commands())
		check(rows==[[6,4,"bagpipe",99,0,0,-1,face,-1]] and input.selected_operator_id.is_empty(),"LocalInput emitsnineintentfields andclearsselection")
		var decoded := CommandCodec.decode(JSON.parse_string(JSON.stringify(rows)),6,content.ids,session._copy_ids)
		check(decoded.has("commands") and CommandCodec.encode(decoded.commands)==rows,"COPY roundtrip exactfields")
	check(CommandCodec.decode([[6,4,"bagpipe",0,0,0,-1,0,-1]],6,content.ids).has("error"),"COPY requires explicit injected ordinarycatalog")
	for id in content.summon_owners:
		check(id not in session._copy_ids and CommandCodec.decode([[6,4,id,0,0,0,-1,0,-1]],6,content.ids,session._copy_ids).has("error"),"SummonCOPYrejected "+id)
	for spec in [[0,7],[1,5],[2,"unknown"],[2,""],[3,-1],[4,1],[5,1],[6,0],[7,-1],[7,4],[8,0],[3,0.5],[3,true]]:
		var row: Array=[6,4,"bagpipe",0,0,0,-1,0,-1];row[spec[0]]=spec[1]
		check(CommandCodec.decode([row],6,content.ids,session._copy_ids).has("error"),"COPY invalidfield rejected "+str(spec))
	for row in [[6,4,"bagpipe",0,0,0,-1,0],[6,4,"bagpipe",0,0,0,-1,0,-1,1]]:check(CommandCodec.decode([row],6,content.ids,session._copy_ids).has("error"),"COPY exactninefields")
	# Session accepts an ordinary ID outside remote_squad; real squad/window validation stays in sim.
	session.phase="running";session.remote_squad=PackedStringArray(["saga"])
	session._receive({"type":"frame","tick":4,"commands":[[4,4,"bagpipe",99,0,0,-1,2,-1]]})
	check(session.phase=="running" and session._remote_frames.has(4),"LAN receivesCOPY onlyintent no simulatedownership/windowdecision")
	var relay := RelaySession.new(content);relay.phase="running";relay.remote_squad=PackedStringArray(["saga"]);relay._received_through=5
	relay._receive({"v":RelaySession.PROTOCOL_VERSION,"type":"input","seq":1,"side":1,"room_id":"a".repeat(32),"match_id":"b".repeat(32),"tick":6,"commands":[[6,4,"bagpipe",99,0,0,-1,2,-1]]})
	check(relay.phase=="running" and relay._remote_frames.has(6),"Relay client receivesCOPY throughsame strictcodec")
	for old in NetSession.PROTOCOL:
		var lan := SilentLAN.new(content);lan.phase="hosting";lan.build_id="build";lan.room_code="123456"
		lan._receive({"type":"hello","protocol":old,"build":"build","code":"123456"})
		check(lan.phase=="hosting" and lan.sent.size()==1 and lan.sent[0].type=="reject","LAN rejectsoldversion%d"%old);lan.free()
	for old in RelaySession.PROTOCOL_VERSION:
		var legacy := RelaySession.new(content);legacy.phase="connecting";legacy._receive({"v":old,"type":"hello","seq":1})
		check(legacy.phase=="failed","Relayclient rejectsoldversion%d"%old);legacy.free()
	session.free();relay.free()
	print("M129_COPY_PROTOCOL_OK failures=",failures);quit(0 if failures==0 else 1)
