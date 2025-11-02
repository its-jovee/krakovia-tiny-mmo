class_name EquipmentResource
extends Resource
## Cosmetic equipment item that can be worn in appearance slots
## Supports cross-class compatibility with class-specific sprites

enum Slot {
	ACCESSORY,  # Head accessories (pumpkin head, hats, etc.)
	# Future slots:
	# HELMET,
	# CAPE,
	# BODY_ARMOR,
	# etc.
}

## Unique identifier for this equipment (e.g., "pumpkin_head")
@export var item_id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Description/flavor text
@export var description: String = ""

## Which slot this equipment occupies
@export var slot: Slot = Slot.ACCESSORY

## Class restrictions (empty = all classes can equip)
## Examples: ["miner", "forager"] = only those classes
##           [] = any class can equip
@export var required_classes: Array[String] = []

## Minimum level requirement
@export var required_level: int = 1

## Sprite frames per class for cross-class compatibility
## Structure: {"miner": SpriteFrames, "forager": SpriteFrames, "trapper": SpriteFrames}
## For single-class items, just include one key
@export var sprite_frames_by_class: Dictionary = {}

## Whether this equipment is animated (uses SpriteFrames) or static (single frame)
@export var is_animated: bool = false

## Future: Stat modifiers, special effects, etc.
@export var stat_modifiers: Dictionary = {}
@export var special_effects: Array[Resource] = []


func get_sprite_frames_for_class(char_class: String) -> SpriteFrames:
	"""Get the appropriate sprite frames for a character class"""
	if sprite_frames_by_class.has(char_class):
		return sprite_frames_by_class[char_class]
	
	# Fallback to first available if class-specific not found
	if sprite_frames_by_class.size() > 0:
		push_warning("EquipmentResource '%s': No sprite frames for class '%s', using fallback" % [item_id, char_class])
		return sprite_frames_by_class.values()[0]
	
	push_error("EquipmentResource '%s': No sprite frames available!" % item_id)
	return null


func can_equip(char_class: String, level: int) -> bool:
	"""Check if this equipment can be equipped by a character"""
	# Check level requirement
	if level < required_level:
		return false
	
	# Check class requirement (empty array = all classes can equip)
	if required_classes.is_empty():
		return true
	
	return char_class in required_classes


func get_slot_name() -> String:
	"""Get human-readable slot name"""
	match slot:
		Slot.ACCESSORY:
			return "Accessory"
		_:
			return "Unknown"
