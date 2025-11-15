class_name TitleResource
extends Resource

## Title rarity levels - determines visual effects
enum Rarity {
	COMMON = 0,
	RARE = 1,
	EPIC = 2,
	LEGENDARY = 3
}

## Unlock condition types
enum ConditionType {
	CRAFT_COUNT,           # Total crafts or crafts by class
	LEVEL_CLASS,          # Reach level X as a specific class
	LEVEL_ALL_CLASSES,    # Reach level X on all classes
	HARVEST_COUNT,        # Harvest X items of a type
	GOLD_EARNED,          # Earn X gold total (cumulative)
	TRADES_COMPLETE,      # Complete X trades
	EVENT_FLAG,           # Special event participation
	PARTY_COUNT          # Join X harvest parties
}

## Basic identification
@export var slug: StringName
@export var title_name: String = "Untitled"
@export_multiline var description: String = ""

## Rarity and visual properties
@export var rarity: Rarity = Rarity.COMMON
@export var rarity_color: Color = Color.WHITE

## Unlock conditions
@export var condition_type: ConditionType = ConditionType.CRAFT_COUNT
@export var target_value: int = 10
@export var required_class: String = ""  # For class-specific conditions (e.g., "miner")
@export var item_category: String = ""  # For harvest conditions (e.g., "wood", "ore")


## Get the rarity color based on rarity level
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.RARE:
			return Color("#4A90E2")  # Blue
		Rarity.EPIC:
			return Color("#9B59B6")  # Purple
		Rarity.LEGENDARY:
			return Color("#FFD700")  # Gold
		_:
			return Color.WHITE


## Check if this rarity should have glow effect
func has_glow() -> bool:
	return rarity >= Rarity.EPIC


## Check if this rarity should have particle effects
func has_particles() -> bool:
	return rarity == Rarity.LEGENDARY


## Get progress key for tracking in account_titles.progress
func get_progress_key() -> String:
	match condition_type:
		ConditionType.CRAFT_COUNT:
			if required_class.is_empty():
				return "crafts_total"
			else:
				return "crafts_%s" % required_class
		ConditionType.LEVEL_CLASS:
			return "max_level_%s" % required_class
		ConditionType.LEVEL_ALL_CLASSES:
			return "all_classes_max_level"
		ConditionType.HARVEST_COUNT:
			return "harvests_%s" % item_category
		ConditionType.GOLD_EARNED:
			return "gold_earned"
		ConditionType.TRADES_COMPLETE:
			return "trades_count"
		ConditionType.EVENT_FLAG:
			return "event_%s" % slug  # Use title slug as event identifier
		ConditionType.PARTY_COUNT:
			return "parties_joined"
		_:
			return "unknown"


## Check if the current progress meets the unlock requirement
func check_unlock_condition(progress_value: int) -> bool:
	return progress_value >= target_value
