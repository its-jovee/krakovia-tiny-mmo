class_name PlayerResource
extends Resource

const XP_AT_L1   := 1000   # cost to go 1 -> 2
const XP_AT_LMAX := 500000 # cost to go (MAX_LEVEL-1) -> MAX_LEVEL
const POWER_P    := 2.2    # 2.0..2.6 = nice back-loaded
const ATTRIBUTE_POINTS_PER_LEVEL: int = 3
const MAX_LEVEL: int = 30
const BASE_ENERGY_MAX: float = 100.0
const ENERGY_PER_LEVEL: float = 50.0

const BASE_STATS: Dictionary[StringName, float] = {
	StatsCatalog.HEALTH_MAX: 100.0,
	StatsCatalog.HEALTH: 100.0,
	StatsCatalog.AD: 20.0,
	StatsCatalog.ARMOR: 15.0,
	StatsCatalog.MR: 15.0,
	StatsCatalog.MOVE_SPEED: 200.0,
	StatsCatalog.ATTACK_SPEED: 0.8,   
}

func get_energy_max() -> float:
	return BASE_ENERGY_MAX + ENERGY_PER_LEVEL * (level - 1)

@export var player_id: int
@export var account_name: String

@export var display_name: String = "Player"
@export var character_class: String = "miner"

@export var golds: int
@export var inventory: Dictionary

@export var attributes: Dictionary
@export var available_attributes_points: int

@export var level: int = 1
@export var experience: int = 0

@export var guild: Guild
##
@export var server_roles: Dictionary

## Quest completion statistics
@export var quest_stats: Dictionary = {}

## Current Network ID
var current_peer_id: int


func init(
	_player_id: int,
	_account_name: String,
	_display_name: String = display_name,
	_character_class: String = character_class
) -> void:
	player_id = _player_id
	account_name = _account_name
	display_name = _display_name
	character_class = _character_class



func get_stats_from_attributes() -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = {}
	# To Replace by constants
	if attributes == null:
		return stats
	for attr_name: StringName in attributes.keys():
		match attr_name:
			&"vitality":
				stats[StatsCatalog.HEALTH_MAX] = stats.get(StatsCatalog.HEALTH_MAX, 0.0) + 5.0
			&"strength":
				stats[StatsCatalog.AD] = stats.get(StatsCatalog.AD, 0.0) + 2.0
			&"agility":
				stats[StatsCatalog.MOVE_SPEED] = stats.get(StatsCatalog.MOVE_SPEED, 0.0) + 3.0
	return stats


static func get_exp_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	var L    := float(target_level)
	var Lmax := float(MAX_LEVEL)
	var t    := pow(L / Lmax, POWER_P)              # 0..1 (nonlinear)
	var t1   := pow(1.0 / Lmax, POWER_P)            # value at level 1
	# affine map t ∈ [t1,1] -> [XP_AT_L1, XP_AT_LMAX]
	var alpha := (XP_AT_LMAX - XP_AT_L1) / (1.0 - t1)
	var beta  := XP_AT_L1 - alpha * t1
	return int(max(1.0, round(alpha * t + beta)))


func get_exp_required() -> int:
	return get_exp_for_level(level + 1)


func get_exp_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var required = get_exp_required()
	return float(experience) / float(required) if required > 0 else 0.0


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	if level >= MAX_LEVEL:
		return  # ignore or store "prestige XP" if you want

	experience += amount
	# Consume overflow and allow multi-level ups
	while level < MAX_LEVEL:
		var required := get_exp_required()
		if experience < required:
			break
		experience -= required
		_level_up_single_step()

func _level_up_single_step() -> void:
	# Single step up (used by add_experience loop)
	level += 1
	available_attributes_points += ATTRIBUTE_POINTS_PER_LEVEL
	if level >= MAX_LEVEL:
		experience = 0  # clear at cap (or keep as "post-cap XP")

func can_level_up() -> bool:
	return level < MAX_LEVEL and experience >= get_exp_required()

# convenience if we call level_up() from UI
func level_up() -> void:
	if can_level_up():
		# Respect overflow instead of nuking XP
		var required := get_exp_required()
		experience -= required
		_level_up_single_step()
	if level >= MAX_LEVEL:
		return
