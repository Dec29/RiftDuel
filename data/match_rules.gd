class_name MatchRules
extends RefCounted

const CONFIG = preload("res://data/config.gd")
const MINUTE_TICKS := CONFIG.PHYSICS_TICK_RATE * 60 / CONFIG.PHYSICS_TICKS_PER_SIMULATION_TICK
const MAX_MINUTES := 30
const MAX_ROUNDS := 9
var mode: String
var minutes: int
var rounds: int
var draft_enabled: bool

func _init(win_mode: String = "single", duration_minutes: int = 5, total_rounds: int = 1, use_draft: bool = false) -> void:
	assert(win_mode in ["single","score"] and duration_minutes>=1 and duration_minutes<=MAX_MINUTES and total_rounds>=1 and total_rounds<=MAX_ROUNDS)
	mode = win_mode
	minutes = duration_minutes
	rounds = total_rounds
	draft_enabled = use_draft

static func pvp_default() -> MatchRules:
	return MatchRules.new("score",5,1,true)

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=4 or not value.get("draft_enabled") is bool or not value.get("mode") is String or value.mode not in ["single","score"]:
		return "判胜模式或规则字段无效"
	for key in ["minutes","rounds"]:
		var number: Variant = value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)) or number<1 or number>(MAX_MINUTES if key=="minutes" else MAX_ROUNDS):
			return "时长须为1至30分钟，局数须为1至9的整数"
	return ""

static func from_wire(value: Dictionary) -> MatchRules:
	return MatchRules.new(value.mode,int(value.minutes),int(value.rounds),value.draft_enabled)

func to_wire() -> Dictionary:
	return {"mode":mode,"minutes":minutes,"rounds":rounds,"draft_enabled":draft_enabled}

func copy() -> MatchRules:
	return MatchRules.new(mode,minutes,rounds,draft_enabled)

func duration_ticks() -> int:
	return minutes * MINUTE_TICKS

func max_ticks() -> int:
	return duration_ticks() + (CONFIG.OVERTIME_TICKS if mode=="single" else 0)

func max_input_ticks() -> int:
	# At most one recovery per completed battle tick; relay validates format only.
	return max_ticks() if mode == "single" else duration_ticks() * (CONFIG.GOAL_RECOVERY_INPUT_TICKS + 1)

func summary() -> String:
	return "%s · 每局%d分钟 · 共%d局" % ["限时积分" if mode=="score" else "单球决胜",minutes,rounds]
