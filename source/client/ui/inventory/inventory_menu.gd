extends Control


## ALl items of the player inventory.
var inventory: Dictionary
var selected_item_id: int = -1
## Filtered inventory showing equipment only.
var equipment_inventory: Dictionary
## Filtered inventory showing equipment only.
var materials_inventory: Dictionary

var latest_items: Dictionary
var gear_slots_cache: Dictionary[Button, Item]
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
	for item_id: int in inv_data.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry: Dictionary = inv_data[item_id]
			var stack: int = int(entry.get("stack", 1))
			var button: Button = inventory_grid.get_child(slot_index) as Button
			button.icon = item.item_icon
			button.text = str(stack)
			button.set_meta(&"item_id", item_id)
			slot_index += 1
			gear_slots_cache.set(button, item)
			if not button.pressed.has_connections():
				button.pressed.connect(_on_item_slot_button_pressed.bind(button, item))
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


func _on_item_slot_button_pressed(button: Button, item: Item) -> void:
	selected_item = item
	selected_item_id = int(button.get_meta(&"item_id", -1))
	rich_text_label.text = item.description


func _on_equip_button_pressed() -> void:
	if selected_item is GearItem or selected_item is WeaponItem:
		if selected_item_id != -1:
			InstanceClient.current.request_data(
				&"item.equip",
				Callable(),
				{"id": selected_item_id}
			)
