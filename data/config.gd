extends Node

const GRID_COLUMNS := 21
const GRID_ROWS := 11
const BALL_START_CELL := Vector2i(10, 5)

const TICK_RATE := 30
const MATCH_TICKS := 9000
const OVERTIME_TICKS := 1800

const COST_INITIAL := 10
const COST_MAX := 99
const COST_REGEN_RATE := 1
const COST_REGEN_TICKS := TICK_RATE
const RETREAT_REFUND_RATIO := 0.5

const UNIT_DAMAGE_PERCENT_BY_PROFESSION := {
	"vanguard": 25,
	"guard": 40,
	"defender": 17,
	"sniper": 25,
	"caster": 30,
	"medic": 0,
	"supporter": 20,
	"specialist": 25,
	"summon": 0,
}
const UNIT_EFFECTIVE_DEFENSE_PERCENT := 70
const UNIT_MIN_DAMAGE_PERCENT := 5
const UNIT_HEAL_PERCENT := 50
const BLOCK_BALL_MIN := 3
const BALL_MOVE_TICKS := 8
