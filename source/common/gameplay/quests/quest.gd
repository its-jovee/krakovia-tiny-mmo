class_name Quest
extends Resource
## Represents a crafting quest from an adventurer NPC


@export var quest_id: int = 0
@export var adventurer_type: String = ""
@export var required_items: Dictionary = {}  # {item_id: quantity}
@export var gold_reward: int = 0
@export var xp_reward: int = 0
@export var is_pinned: bool = false
@export var generated_at: float = 0.0  # Unix timestamp


func _init(
	_quest_id: int = 0,
	_adventurer_type: String = "",
	_required_items: Dictionary = {},
	_gold_reward: int = 0,
	_xp_reward: int = 0
) -> void:
	quest_id = _quest_id
	adventurer_type = _adventurer_type
	required_items = _required_items
	gold_reward = _gold_reward
	xp_reward = _xp_reward
	generated_at = Time.get_unix_time_from_system()


func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"adventurer_type": adventurer_type,
		"required_items": required_items,
		"gold_reward": gold_reward,
		"xp_reward": xp_reward,
		"is_pinned": is_pinned,
		"generated_at": generated_at
	}


static func from_dict(data: Dictionary) -> Quest:
	var quest = Quest.new()
	quest.quest_id = data.get("quest_id", 0)
	quest.adventurer_type = data.get("adventurer_type", "")
	quest.required_items = data.get("required_items", {})
	quest.gold_reward = data.get("gold_reward", 0)
	quest.xp_reward = data.get("xp_reward", 0)
	quest.is_pinned = data.get("is_pinned", false)
	quest.generated_at = data.get("generated_at", 0.0)
	return quest

