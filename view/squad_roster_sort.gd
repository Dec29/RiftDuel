extends RefCounted

# UI-only star metadata from Kengxxiao/ArknightsGameData, commit
# 17759cc8cdf37388414145d16262a3a06f3ab25e, character_table SHA256
# e523c7c83c36e2d76697121079e17d0282da1a94d59a55e1cc55616edf0b41c4.
# Every selectable operator is explicit; new operators must add their source rarity.
const RARITY_BY_ID := {
	"wildmane":5,
	"gavial_alter":6,
	"eunectes":6,
	"chen_alter":6,
	"goldenglow":6,
	"mon3tr_operator":6,
	"stainless":6,
	"gladiia":6,
	"muelsyse":6,
	"mlynar":6,
	"jessica_alter":6,
	"fiammetta":6,
	"dusk":6,
	"titi":6,
	"ling":6,
	"shaw":4,

	"aak": 6,
	"amiya": 5,
	"angelina": 6,
	"archetto": 6,
	"bagpipe": 6,
	"blaze": 6,
	"blemishine": 6,
	"blue_poison": 5,
	"carnelian": 6,
	"ceobe": 6,
	"chen": 6,
	"cliffheart": 5,
	"cuora": 4,
	"elysium": 5,
	"exusiai": 6,
	"eyjafjalla": 6,
	"eyjafjalla_alter": 6,
	"feater": 5,
	"flametail": 6,
	"gitano": 4,
	"gnosis": 6,
	"gravel": 4,
	"gummy": 4,
	"haze": 4,
	"hellagur": 6,
	"horn": 6,
	"hoshiguma": 6,
	"ifrit": 6,
	"ines": 6,
	"istina": 5,
	"jessica": 4,
	"kaltsit": 6,
	"lappland": 5,
	"lee": 6,
	"lin": 6,
	"liskarm": 5,
	"lumen": 6,
	"magallan": 6,
	"meteorite": 5,
	"mizuki": 6,
	"mostima": 6,
	"mountain": 6,
	"mudrock": 6,
	"myrtle": 4,
	"nearl": 5,
	"nian": 6,
	"nightingale": 6,
	"pallas": 6,
	"passenger": 6,
	"penance": 6,
	"perfumer": 4,
	"phantom": 6,
	"platinum": 5,
	"podenco": 4,
	"pozyomka": 6,
	"pramanix": 5,
	"projekt_red": 5,
	"ptilopsis": 5,
	"reed_alter": 6,
	"rosa": 6,
	"saga": 6,
	"saileach": 6,
	"saria": 6,
	"schwarz": 6,
	"shamare": 5,
	"shining": 6,
	"siege": 6,
	"silence": 5,
	"silence_alter": 6,
	"silverash": 6,
	"skadi": 6,
	"skadi_alter": 6,
	"skyfire": 5,
	"sora": 5,
	"specter": 5,
	"surtr": 6,
	"sussurro": 4,
	"suzuran": 6,
	"swire_alter": 6,
	"texas": 5,
	"texas_alter": 6,
	"thorns": 6,
	"typhon": 6,
	"vigil": 6,
	"w": 6,
	"warfarin": 5,
	"weedy": 6,
	"zima": 5,
}
const LABELS := {"rarity":"稀有度", "max_health":"生命上限", "attack":"攻击", "defense":"防御", "magic_resist":"法术抗性", "redeploy_time":"再部署", "deploy_cost":"部署费用", "block_count":"阻挡数", "attack_frequency":"攻击速度"}
const ICONS := {
	"rarity": preload("res://assets/icons/squad_sort/rarity.svg"),
	"max_health": preload("res://assets/icons/squad_sort/max_health.svg"),
	"attack": preload("res://assets/icons/squad_sort/attack.svg"),
	"defense": preload("res://assets/icons/squad_sort/defense.svg"),
	"magic_resist": preload("res://assets/icons/squad_sort/magic_resist.svg"),
	"redeploy_time": preload("res://assets/icons/squad_sort/redeploy_time.svg"),
	"deploy_cost": preload("res://assets/icons/squad_sort/deploy_cost.svg"),
	"block_count": preload("res://assets/icons/squad_sort/block_count.svg"),
	"attack_frequency": preload("res://assets/icons/squad_sort/attack_frequency.svg"),
}


static func value(operator: OperatorData, key: String) -> float:
	match key:
		"rarity": return RARITY_BY_ID[operator.operator_id]
		"attack_frequency": return 1.0 / operator.attack_interval
		"deploy_cost": return DeployRules.base_cost(operator)
	return operator.get(key)


static func ordered_ids(ids: PackedStringArray, key: String, descending: bool, get_operator: Callable) -> PackedStringArray:
	var ordered: Array[String] = []
	ordered.assign(ids)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var first := value(get_operator.call(a), key)
		var second := value(get_operator.call(b), key)
		if first == second: return a < b
		return first > second if descending else first < second
	)
	return PackedStringArray(ordered)


static func value_text(operator: OperatorData, key: String) -> String:
	var number := value(operator, key)
	match key:
		"rarity": return "%d星" % int(number)
		"attack_frequency": return "%.2f 次/秒" % number
		"redeploy_time": return "%.1f 秒" % number
		"magic_resist": return "%d%%" % int(number)
	return str(int(number))
