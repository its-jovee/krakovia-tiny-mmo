extends Panel
class_name EquipmentSlot
## Drag-and-drop capable equipment slot for cosmetic items


@export var gear_slot: ItemSlot

var equipped_item_id: int = -1
var equipped_item: Item = null

@onready var icon: TextureRect = $Icon
@onready var slot_label: Label = $SlotLabel


func _ready() -> void:
	if not gear_slot:
		push_error("EquipmentSlot has no gear_slot assigned!")
		return
	
	# Set label to slot name
	if slot_label:
		slot_label.text = gear_slot.display_name
	
	# Set default icon if available
	if icon and gear_slot.icon:
		icon.texture = gear_slot.icon
		icon.modulate = Color(1, 1, 1, 0.3)  # Dim when empty


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""Check if the dragged item can be dropped on this equipment slot"""
	print("[EquipmentSlot] _can_drop_data called on slot: %s" % (gear_slot.display_name if gear_slot else "NO SLOT"))
	
	if not gear_slot:
		print("  ✗ No gear_slot configured")
		return false
	
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
		print("  ✅ Can equip: %s" % can_equip)
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
	print("[EquipmentSlot] _drop_data called! 🎉")
	
	if not data is Dictionary or not data.has("item_data"):
		print("  ✗ Invalid data in drop")
		return
	
	var item_data: Dictionary = data.item_data
	var item: Item = item_data.item
	var item_id: int = item_data.item_id
	
	print("  → Dropping item: %s (ID: %d)" % [item.item_name, item_id])
	
	if item is EquipmentItem:
		# Equip the cosmetic item via server (SERVER AUTHORITATIVE)
		var equipment_item := item as EquipmentItem
		var slot_type: String = "accessory"
		if equipment_item.slot:
			slot_type = equipment_item.slot.key
		
		print("  → Sending server request: item.equip_cosmetic")
		print("  → Item ID: %d, Slot: %s" % [item_id, slot_type])
		
		# Send request to server
		InstanceClient.current.request_data(
			&"item.equip_cosmetic",
			func(response: Dictionary):
				print("[EquipmentSlot] Equip response: %s" % response)
				if response.get("ok", false):
					print("  ✅ Successfully equipped %s via drag-and-drop!" % response.get("item_name", "item"))
					# Server will sync, which will trigger visual update
				else:
					print("  ✗ Failed to equip: %s" % response.get("error", "Unknown error")),
			{
				"item_id": item_id,
				"slot": slot_type
			}
		)
	
	elif item is GearItem:
		# Handle stat-based gear items via server request
		InstanceClient.current.request_data(
			&"item.equip",
			Callable(),
			{"id": item_id}
		)


func _gui_input(event: InputEvent) -> void:
	"""Handle clicking on the slot to unequip"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if equipped_item_id != -1:
				print("[EquipmentSlot] Clicked to unequip")
				
				# Unequip via server (SERVER AUTHORITATIVE)
				var slot_type: String = "accessory"
				if gear_slot:
					slot_type = gear_slot.key
				
				print("  → Sending server request: item.unequip_cosmetic")
				InstanceClient.current.request_data(
					&"item.unequip_cosmetic",
					func(response: Dictionary):
						print("[EquipmentSlot] Unequip response: %s" % response)
						if response.get("ok", false):
							print("  ✅ Successfully unequipped via click!")
						else:
							print("  ✗ Failed to unequip: %s" % response.get("error", "Unknown error")),
					{
						"slot": slot_type
					}
				)


func set_equipped_item(item_id: int, item: Item) -> void:
	"""Set an equipped item (called from equip button)"""
	if equipped_item_id != -1:
		clear_slot()
	
	equipped_item_id = item_id
	equipped_item = item
	
	if icon:
		icon.texture = item.item_icon
		icon.modulate = Color.WHITE
	
	print("[EquipmentSlot] Set equipped item: %s" % item.item_name)


func clear_slot() -> void:
	"""Clear the equipment slot (visual only - server handles the actual unequip)"""
	print("[EquipmentSlot] Clearing slot visual")
	
	equipped_item_id = -1
	equipped_item = null
	
	# Reset visuals
	if icon:
		if gear_slot and gear_slot.icon:
			icon.texture = gear_slot.icon
			icon.modulate = Color(1, 1, 1, 0.3)  # Dim when empty
		else:
			icon.texture = null
	
	print("  → Slot cleared")
