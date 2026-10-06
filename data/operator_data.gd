class_name OperatorData
extends Resource

const PROFESSION_IDS := ["vanguard", "guard", "defender", "sniper", "caster", "medic", "supporter", "specialist"]

@export var operator_id: String
@export var display_name: String
@export var profession: String
@export var profession_id: String
@export var branch: String
@export var max_health: int
@export var attack: int
@export var defense: int
@export var magic_resist: int
@export var damage_type: String
@export var attack_interval: float
@export var block_count: int
@export var deploy_cost: int
@export var redeploy_time: float
@export var dodge_physical: int
@export var dodge_magical: int
@export var attack_range: Array[Vector2i]
@export var terrain_requirement: String
@export var ignore_deploy_line: bool
@export var branch_trait: TraitResource
@export var talent_1: TalentResource
@export var talent_2: TalentResource
@export var skills: Array[SkillResource]
@export var equipped_skill_index: int
@export var initial_sp: int
