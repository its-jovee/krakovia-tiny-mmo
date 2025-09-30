extends Panel

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $ItemAmount

# Store item data for drag and drop
var item_data: Dictionary = {}

func _ready() -> void:
	# Enable input events for this panel
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect click event
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Emit signal or call parent method to handle item selection
		_handle_item_click()

func _handle_item_click() -> void:
	# Find the inventory menu parent and call its item selection method
	var inventory_menu = _find_inventory_menu()
	if inventory_menu and inventory_menu.has_method("_on_item_slot_clicked"):
		inventory_menu._on_item_slot_clicked(self)

func _find_inventory_menu() -> Node:
	var current = get_parent()
	var depth = 0
	while current and depth < 10:  # Prevent infinite loops
		if current.name == "Inventory" and current.has_method("_on_item_slot_clicked"):
			return current
		current = current.get_parent()
		depth += 1
	return null

func _get_drag_data(_at_position: Vector2) -> Variant:
	if icon.texture == null:
		return null
	
	# Create drag data with all necessary information
	var drag_data = {
		"texture": icon.texture,
		"amount_text": amount_label.text,
		"item_data": item_data,
		"source_slot": self
	}
	
	var preview = duplicate()
	var c = Control.new()
	c.add_child(preview)
	preview.self_modulate = Color.TRANSPARENT
	c.modulate = Color(c.modulate, 0.5)
	
	set_drag_preview(c)
	icon.hide()
	return drag_data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data != null and data is Dictionary and data.has("texture")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	
	# Store current slot data
	var current_texture = icon.texture
	var current_amount = amount_label.text
	var current_item_data = item_data.duplicate()
	var current_source = self
	
	# Update this slot with dragged data
	icon.texture = data.texture
	amount_label.text = data.amount_text
	item_data = data.item_data.duplicate()
	
	# Update source slot with this slot's data
	if data.has("source_slot") and data.source_slot != self:
		var source_slot: Panel = data.source_slot
		source_slot.icon.texture = current_texture
		source_slot.amount_label.text = current_amount
		source_slot.item_data = current_item_data
		
		# Update metadata in both slots
		if current_texture:
			set_meta("item_id", current_item_data.get("item_id", -1))
		else:
			remove_meta("item_id")
			
		if data.texture:
			source_slot.set_meta("item_id", data.item_data.get("item_id", -1))
		else:
			source_slot.remove_meta("item_id")
	else:
		# If dropping on same slot, restore original data
		icon.texture = current_texture
		amount_label.text = current_amount
		item_data = current_item_data
	
	icon.show()

var data_bk
func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_DRAG_BEGIN:
		data_bk = get_viewport().gui_get_drag_data()
	if what == Node.NOTIFICATION_DRAG_END:
		if not is_drag_successful():
			if data_bk:
				data_bk.source_slot.icon.show()

# Method to set item data (called by inventory menu)
func set_item_data(item_id: int, item: Item, stack: int) -> void:
	item_data = {
		"item_id": item_id,
		"item": item,
		"stack": stack
	}
	
	if item:
		icon.texture = item.item_icon
		amount_label.text = str(stack)
		set_meta("item_id", item_id)
	else:
		icon.texture = null
		amount_label.text = ""
		remove_meta("item_id")

# Method to clear item data
func clear_item_data() -> void:
	item_data.clear()
	icon.texture = null
	amount_label.text = ""
	remove_meta("item_id")
