class_name PlayerResource
extends Resource


const ATTRIBUTE_POINTS_PER_LEVEL: int = 3

const BASE_STATS: Dictionary[StringName, float] = {
	StatsCatalog.HEALTH_MAX: 100.0,
	StatsCatalog.HEALTH: 100.0,
	StatsCatalog.AD: 20.0,
	StatsCatalog.ARMOR: 15.0,
	StatsCatalog.MR: 15.0,
	StatsCatalog.MOVE_SPEED: 75.0,
	StatsCatalog.ATTACK_SPEED: 0.8
}

@export var player_id: int
@export var account_name: String

@export var display_name: String = "Player"
@export var character_class: String = "knight"

@export var golds: int
@export var inventory: Dictionary

@export var attributes: Dictionary
@export var available_attributes_points: int

@export var level: int

@export var guild: Guild
##
@export var server_roles: Dictionary

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


func level_up() -> void:
	available_attributes_points += ATTRIBUTE_POINTS_PER_LEVEL
	level += 1
