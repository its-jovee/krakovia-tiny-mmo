extends Control


## ALl items of the player inventory.
var inventory: Dictionary
var selected_item_id: int = -1
## Filtered inventory showing equipment only.
var equipment_inventory: Dictionary
## Filtered inventory showing equipment only.
var materials_inventory: Dictionary

var latest_items: Dictionary
var gear_slots_cache: Dictionary[Panel, Item]
var selected_item: Item

@onready var inventory_grid: GridContainer = $EquipmentView/HBoxContainer/VBoxContainer/InventoryGrid
@onready var equipment_slots: GridContainer = $EquipmentView/HBoxContainer/VBoxContainer2/EquipmentSlots
@onready var rich_text_label: RichTextLabel = $EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/RichTextLabel


func _ready() -> void:
	InstanceClient.current.request_data(&"inventory.get", fill_inventory)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)


func fill_inventory(inv_data: Dictionary) -> void:
	inventory = inv_data
	var slot_index: int = 0
	
	# Clear all slots first
	_clear_all_inventory_slots()
	
	# Fill slots with items
	for item_id: int in inv_data.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry: Dictionary = inv_data[item_id]
			var stack: int = int(entry.get("stack", 1))
			
			# Find the next available Panel slot (skip Button nodes)
			var item_slot_panel: Panel = _get_next_panel_slot(slot_index)
			if item_slot_panel and item_slot_panel.has_method("set_item_data"):
				item_slot_panel.set_item_data(item_id, item, stack)
				gear_slots_cache.set(item_slot_panel, item)
				slot_index += 1
	
	# Update equipment slots
	for equipment_slot: GearSlotButton in equipment_slots.get_children():
		if equipment_slot.gear_slot:
			if equipment_slot.gear_slot == null:
				equipment_slot.text = "Empty"
		else:
			equipment_slot.icon = null
			equipment_slot.text = "Lock"


func add_item() -> void:
	pass


func _on_close_button_pressed() -> void:
	hide()


func _on_item_slot_clicked(item_slot_panel: Panel) -> void:
	var item_data = item_slot_panel.item_data
	if item_data.has("item") and item_data.item:
		selected_item = item_data.item
		selected_item_id = item_data.get("item_id", -1)
		rich_text_label.text = item_data.item.description


func _on_equip_button_pressed() -> void:
	if selected_item is GearItem or selected_item is WeaponItem:
		if selected_item_id != -1:
			InstanceClient.current.request_data(
				&"item.equip",
				Callable(),
				{"id": selected_item_id}
			)


func _clear_all_inventory_slots() -> void:
	# Clear all Panel slots in the inventory grid
	for i in range(inventory_grid.get_child_count()):
		var child = inventory_grid.get_child(i)
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
			gear_slots_cache.erase(child)


func _get_next_panel_slot(slot_index: int) -> Panel:
	# Find the next Panel node (skip Button nodes) starting from slot_index
	var panel_count: int = 0
	for i in range(inventory_grid.get_child_count()):
		var child = inventory_grid.get_child(i)
		if child is Panel:
			if panel_count == slot_index:
				return child as Panel
			panel_count += 1
	return null
