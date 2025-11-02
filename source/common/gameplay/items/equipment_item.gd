class_name EquipmentItem
extends Item
## Cosmetic equipment item that can be equipped for appearance customization
## Links inventory Item with EquipmentResource for visual rendering


## The equipment resource containing visual data and requirements
@export var equipment: EquipmentResource

## Equipment slot (accessory, etc.)
@export var slot: ItemSlot

## Level requirement (duplicated here for UI convenience)
@export_range(0, 99, 1.0, "suffix:lvl") var required_level: int = 1

## Class restrictions (empty = all classes)
@export var required_classes: Array[String] = []


func _init() -> void:
	# Equipment items should be tradeable by default
	can_trade = true
	stack_limit = 1  # Equipment doesn't stack
	# Note: can_sell is controlled per-item in the .tres file (defaults to false from Item class)


func can_equip(player: Player) -> bool:
	"""Check if player can equip this cosmetic item"""
	print("[EquipmentItem] Checking can_equip for '%s'" % item_name)
	
	if not equipment:
		print("  ✗ No equipment resource!")
		push_error("EquipmentItem '%s' has no EquipmentResource assigned!" % item_name)
		return false
	
	if not player:
		print("  ✗ No player!")
		return false
	
	if not player.player_resource:
		print("  ✗ No player_resource!")
		return false
	
	print("  → Player level: %d, Required: %d" % [player.player_resource.level, required_level])
	print("  → Player class: %s, Required: %s" % [player.player_resource.character_class, required_classes])
	print("  → Slot: %s" % (slot.key if slot else "NULL"))
	
	# Check slot unlock
	if slot and not slot.is_unlocked_for(player.player_resource):
		print("  ✗ Slot is locked!")
		return false
	
	# Check level requirement
	if player.player_resource.level < required_level:
		print("  ✗ Level too low!")
		return false
	
	# Check class requirement (empty = all classes)
	if not required_classes.is_empty():
		if not player.player_resource.character_class in required_classes:
			print("  ✗ Class requirement not met!")
			return false
	
	print("  ✅ Can equip!")
	return true


func on_equip(character: Character) -> void:
	"""Equip the cosmetic item (visual only)"""
	if not equipment:
		push_error("EquipmentItem '%s' has no EquipmentResource!" % item_name)
		return
	
	# Get composite sprite
	var composite_sprite: Node = character.get_node_or_null("CompositeSprite")
	if not composite_sprite:
		push_error("Character has no CompositeSprite node!")
		return
	
	# Equip based on slot
	match equipment.slot:
		EquipmentResource.Slot.ACCESSORY:
			if composite_sprite.has_method("equip_accessory"):
				composite_sprite.equip_accessory(equipment)
			else:
				push_error("CompositeSprite missing equip_accessory method!")
		_:
			push_warning("Unhandled equipment slot: %d" % equipment.slot)


func on_unequip(character: Character) -> void:
	"""Unequip the cosmetic item"""
	if not equipment:
		return
	
	var composite_sprite: Node = character.get_node_or_null("CompositeSprite")
	if not composite_sprite:
		return
	
	# Unequip based on slot
	match equipment.slot:
		EquipmentResource.Slot.ACCESSORY:
			if composite_sprite.has_method("unequip_accessory"):
				composite_sprite.unequip_accessory()
		_:
			pass
