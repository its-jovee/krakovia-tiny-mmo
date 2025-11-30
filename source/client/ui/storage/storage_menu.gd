extends Control
## Family Crest Storage UI - Account-wide item storage

const MAX_STORAGE_SLOTS: int = 48
const INVENTORY_SLOTS: int = 30  # Adjust based on actual inventory size

# Storage and inventory data
var storage_data: Dictionary = {}
var inventory_data: Dictionary = {}

# UI references
@onready var storage_grid: GridContainer = $Panel/HBoxContainer/RightPanel/ScrollContainer/StorageGrid
@onready var inventory_grid: GridContainer = $Panel/HBoxContainer/LeftPanel/ScrollContainer/InventoryGrid
@onready var storage_count_label: Label = $Panel/HBoxContainer/RightPanel/StorageHeader/CountLabel
@onready var close_button: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Initialize storage and inventory slots
	_initialize_slots()
	
	# Subscribe to data updates
	InstanceClient.subscribe(&"storage.update", _on_storage_update)
	InstanceClient.subscribe(&"inventory.update", _on_inventory_update)

func _initialize_slots() -> void:
	# Create storage slots (48 slots)
	for i in range(MAX_STORAGE_SLOTS):
		var slot = _create_item_slot()
		storage_grid.add_child(slot)
	
	# Create inventory slots
	for i in range(INVENTORY_SLOTS):
		var slot = _create_item_slot()
		inventory_grid.add_child(slot)

func _create_item_slot() -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(48, 48)
	
	# Add icon texture rect
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.anchor_left = 0
	icon.anchor_top = 0
	icon.anchor_right = 1
	icon.anchor_bottom = 1
	slot.add_child(icon)
	
	# Add amount label
	var amount = Label.new()
	amount.name = "ItemAmount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	amount.anchor_left = 1
	amount.anchor_top = 1
	amount.anchor_right = 1
	amount.anchor_bottom = 1
	amount.offset_left = -20
	amount.offset_top = -16
	amount.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	amount.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot.add_child(amount)
	
	# Enable drag and drop
	slot.set_script(load("res://source/client/ui/inventory/item_slot.gd"))
	
	# Connect click event
	slot.gui_input.connect(_on_slot_clicked.bind(slot))
	
	return slot

func show_menu() -> void:
	# Play open sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_open()
	
	# Animate menu open
	if has_node("/root/UIAnimations"):
		get_node("/root/UIAnimations").animate_panel_open(self)
	else:
		visible = true
	
	# Request fresh data from server
	InstanceClient.current.request_data(&"storage.get", _on_storage_received, {})
	InstanceClient.current.request_data(&"inventory.get", _on_inventory_received, {})

func _on_close_button_pressed() -> void:
	# Play close sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_close()
	
	# Animate menu close
	if has_node("/root/UIAnimations"):
		get_node("/root/UIAnimations").animate_panel_close(self)
	else:
		visible = false

func _on_storage_received(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to get storage: " + data.error)
		return
	
	storage_data = data
	_refresh_storage_grid()

func _on_inventory_received(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to get inventory: " + data.error)
		return
	
	inventory_data = data
	_refresh_inventory_grid()

func _refresh_storage_grid() -> void:
	# Clear all slots
	for child in storage_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill with storage items
	var slot_index = 0
	for item_id in storage_data.keys():
		if slot_index >= MAX_STORAGE_SLOTS:
			break
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry = storage_data[item_id]
			var stack = entry.get("stack", 1)
			
			var slot = storage_grid.get_child(slot_index)
			if slot and slot.has_method("set_item_data"):
				slot.set_item_data(item_id, item, stack)
				slot.set_meta("is_storage_slot", true)
			slot_index += 1
	
	# Update slot count
	if storage_count_label:
		storage_count_label.text = "%d/%d" % [storage_data.size(), MAX_STORAGE_SLOTS]

func _refresh_inventory_grid() -> void:
	# Clear all slots
	for child in inventory_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill with inventory items
	var slot_index = 0
	for item_id in inventory_data.keys():
		if slot_index >= INVENTORY_SLOTS:
			break
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry = inventory_data[item_id]
			var stack = entry.get("stack", 1)
			
			var slot = inventory_grid.get_child(slot_index)
			if slot and slot.has_method("set_item_data"):
				slot.set_item_data(item_id, item, stack)
				slot.set_meta("is_storage_slot", false)
			slot_index += 1

func _on_storage_update(data: Dictionary) -> void:
	storage_data = data
	_refresh_storage_grid()

func _on_inventory_update(data: Dictionary) -> void:
	inventory_data = data
	_refresh_inventory_grid()

func _on_slot_clicked(event: InputEvent, slot: Panel) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# Get item data from slot
	if not "item_data" in slot or slot.item_data.is_empty():
		return
	
	var item_id = slot.item_data.get("item_id", -1)
	if item_id == -1:
		return
	
	var is_storage = slot.get_meta("is_storage_slot", false)
	
	# Show quantity dialog
	_show_transfer_dialog(item_id, slot.item_data.get("stack", 1), is_storage)

func _show_transfer_dialog(item_id: int, max_quantity: int, from_storage: bool) -> void:
	# For now, transfer 1 item at a time with simple confirmation
	# TODO: Add proper quantity dialog
	if from_storage:
		# Withdraw from storage
		InstanceClient.current.request_data(&"storage.withdraw", func(result):
			if result.has("error"):
				print("Failed to withdraw: ", result.error)
		, {"item_id": item_id, "quantity": 1})
	else:
		# Deposit to storage
		InstanceClient.current.request_data(&"storage.deposit", func(result):
			if result.has("error"):
				print("Failed to deposit: ", result.error)
		, {"item_id": item_id, "quantity": 1})
