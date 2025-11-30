extends Button
class_name GearSlotButton


@export var gear_slot: ItemSlot

var equipped_item_id: int = -1
var equipped_item: Item = null


func _ready() -> void:
	if not gear_slot:
		disabled = true
		return
	
	tooltip_text = gear_slot.display_name
	icon = gear_slot.icon
	if gear_slot.unlock_rule.kind == SlotUnlockRule.Kind.PLAYER_LEVEL:
		text = str(gear_slot.unlock_rule.level)
	
	# Connect click to unequip
	pressed.connect(_on_slot_pressed)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""Check if the dragged item can be dropped on this equipment slot"""
	print("[GearSlotButton] _can_drop_data called on slot: %s" % gear_slot.display_name if gear_slot else "NO SLOT")
	
	if not data or not data is Dictionary:
		print("  ✗ No data or not Dictionary")
		return false
	
	if not data.has("item_data"):
		print("  ✗ Data has no 'item_data' key")
		return false
	
	var item_data: Dictionary = data.item_data
	if not item_data.has("item"):
		print("  ✗ item_data has no 'item' key")
		return false
	
	var item: Item = item_data.item
	print("  → Dragging item: %s (type: %s)" % [item.item_name, item.get_class()])
	
	# Check if it's an equipment item for this slot
	if item is EquipmentItem:
		var equipment_item := item as EquipmentItem
		print("  → EquipmentItem detected! Item slot: %s, This slot: %s" % [equipment_item.slot.key if equipment_item.slot else "NULL", gear_slot.key if gear_slot else "NULL"])
		
		# Check if the slot matches (compare by key since resources don't compare well with ==)
		if not equipment_item.slot or not gear_slot or equipment_item.slot.key != gear_slot.key:
			print("  ✗ Slot mismatch! Item slot: %s, This slot: %s" % [equipment_item.slot.key if equipment_item.slot else "NULL", gear_slot.key if gear_slot else "NULL"])
			return false
		
		# Check if player can equip it
		var local_player = Events.local_player
		if local_player == null:
			local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
		if not local_player:
			print("  ✗ No local player found!")
			return false
		
		var can_equip = equipment_item.can_equip(local_player)
		print("  → Can equip: %s" % can_equip)
		return can_equip
	
	# Check if it's a gear item for this slot
	if item is GearItem:
		var gear_item := item as GearItem
		var matches = gear_item.slot and gear_slot and gear_item.slot.key == gear_slot.key
		print("  → GearItem slot match: %s" % matches)
		return matches
	
	print("  ✗ Item is not EquipmentItem or GearItem")
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	"""Handle dropping an item on this equipment slot"""
	print("[GearSlotButton] _drop_data called!")
	
	if not data is Dictionary or not data.has("item_data"):
		print("  ✗ Invalid data in drop")
		return
	
	var item_data: Dictionary = data.item_data
	var item: Item = item_data.item
	var item_id: int = item_data.item_id
	
	print("  → Dropping item: %s (ID: %d)" % [item.item_name, item_id])
	
	if item is EquipmentItem:
		# Equip the cosmetic item
		var equipment_item := item as EquipmentItem
		var local_player = Events.local_player
		if local_player == null:
			local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
		
		if local_player and equipment_item.can_equip(local_player):
			equipment_item.on_equip(local_player)
			
			# Update slot visuals
			icon = item.item_icon
			text = ""
			equipped_item_id = item_id
			equipped_item = item
			
			print("Equipped %s to %s slot" % [item.item_name, gear_slot.display_name])
	
	elif item is GearItem:
		# Handle stat-based gear items via server request
		InstanceClient.current.request_data(
			&"item.equip",
			Callable(),
			{"id": item_id}
		)


func _on_slot_pressed() -> void:
	"""Handle clicking on the equipment slot to unequip"""
	if equipped_item_id != -1:
		clear_slot()


func clear_slot() -> void:
	"""Clear the equipment slot"""
	if equipped_item and equipped_item is EquipmentItem:
		var local_player = Events.local_player
		if local_player == null:
			local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
		if local_player:
			equipped_item.on_unequip(local_player)
			print("Unequipped %s" % equipped_item.item_name)
	
	equipped_item_id = -1
	equipped_item = null
	icon = gear_slot.icon if gear_slot else null
	text = ""
