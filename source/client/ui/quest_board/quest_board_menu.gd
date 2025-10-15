extends Control
## Quest Board UI for viewing and completing quests


var available_quests: Array = []
var pinned_quest_id: int = -1
var in_quest_board: bool = false
var inventory: Dictionary = {}

@onready var quest_list_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/QuestListContainer
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel


func _ready() -> void:
	print("Quest Board menu _ready() called")
	hide()  # Start hidden
	
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Subscribe to quest board status updates
	InstanceClient.subscribe(&"quest_board.status", _on_quest_board_status_update)
	InstanceClient.subscribe(&"quest.update", _on_quest_update)
	InstanceClient.subscribe(&"inventory.update", _on_inventory_update)


func _on_quest_board_status_update(data: Dictionary) -> void:
	in_quest_board = data.get("in_quest_board", false)
	print("Quest board status update: ", in_quest_board)
	
	if in_quest_board:
		# Fetch quests from server
		InstanceClient.current.request_data(&"quest.fetch", _on_quests_received, {})
		show()
	else:
		hide()


func _on_quests_received(response: Dictionary) -> void:
	if response.has("error"):
		print("Error fetching quests: ", response["error"])
		return
	
	available_quests = response.get("quests", [])
	print("Received %d quests" % available_quests.size())
	_refresh_quest_display()


func _on_quest_update(data: Dictionary) -> void:
	available_quests = data.get("quests", [])
	print("Quest list updated: %d quests" % available_quests.size())
	_refresh_quest_display()


func _on_inventory_update(inv_data: Dictionary) -> void:
	inventory = inv_data
	_refresh_quest_display()


func _refresh_quest_display() -> void:
	# Clear existing quest panels
	for child in quest_list_container.get_children():
		child.queue_free()
	
	# Sort quests by gold reward (ascending - smallest to biggest)
	var sorted_quests = available_quests.duplicate()
	sorted_quests.sort_custom(func(a, b): return a.get("gold_reward", 0) < b.get("gold_reward", 0))
	
	# Separate pinned and unpinned quests
	var pinned_quests: Array = []
	var unpinned_quests: Array = []
	
	for quest_data in sorted_quests:
		if quest_data.get("is_pinned", false):
			pinned_quests.append(quest_data)
		else:
			unpinned_quests.append(quest_data)
	
	# Display pinned quests first, then unpinned quests
	for quest_data in pinned_quests:
		var quest_panel = _create_quest_panel(quest_data)
		quest_list_container.add_child(quest_panel)
	
	for quest_data in unpinned_quests:
		var quest_panel = _create_quest_panel(quest_data)
		quest_list_container.add_child(quest_panel)


func _create_quest_panel(quest_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 180)  # Increased for item slots
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Header with adventurer type and pin indicator
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var adventurer_label = Label.new()
	adventurer_label.text = "[%s]" % quest_data.get("adventurer_type", "Unknown")
	adventurer_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(adventurer_label)
	
	if quest_data.get("is_pinned", false):
		var pin_indicator = Label.new()
		pin_indicator.text = " ⭐ PINNED"
		pin_indicator.add_theme_color_override("font_color", Color(1, 0.8, 0))
		header_hbox.add_child(pin_indicator)
	
	# Required items
	var items_label = Label.new()
	items_label.text = "Required Items:"
	vbox.add_child(items_label)
	
	# Create grid for item slots
	var items_grid = GridContainer.new()
	items_grid.columns = 3  # 3 items per row
	items_grid.add_theme_constant_override("h_separation", 8)
	items_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(items_grid)
	
	var required_items: Dictionary = quest_data.get("required_items", {})
	for item_id in required_items.keys():
		var quantity_required: int = required_items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var player_quantity: int = 0
			if inventory.has(item_id):
				player_quantity = inventory[item_id].get("stack", 0)
			
			var item_slot = _create_quest_item_slot(item, quantity_required, player_quantity)
			items_grid.add_child(item_slot)
	
	# Rewards
	var rewards_label = Label.new()
	var gold_reward: int = quest_data.get("gold_reward", 0)
	var xp_reward: int = quest_data.get("xp_reward", 0)
	rewards_label.text = "Rewards: %d Gold, %d XP" % [gold_reward, xp_reward]
	rewards_label.add_theme_color_override("font_color", Color(1, 0.9, 0))
	vbox.add_child(rewards_label)
	
	# Buttons
	var button_hbox = HBoxContainer.new()
	vbox.add_child(button_hbox)
	
	# Pin button
	var pin_button = Button.new()
	pin_button.text = "Unpin" if quest_data.get("is_pinned", false) else "Pin"
	pin_button.custom_minimum_size = Vector2(80, 0)
	pin_button.pressed.connect(_on_pin_quest_pressed.bind(quest_data.get("quest_id", -1)))
	button_hbox.add_child(pin_button)
	
	# Complete button
	var complete_button = Button.new()
	complete_button.text = "Complete"
	complete_button.custom_minimum_size = Vector2(100, 0)
	complete_button.pressed.connect(_on_complete_quest_pressed.bind(quest_data.get("quest_id", -1)))
	
	# Check if player can complete
	var can_complete: bool = _can_complete_quest(quest_data)
	complete_button.disabled = not can_complete
	
	button_hbox.add_child(complete_button)
	
	return panel


func _can_complete_quest(quest_data: Dictionary) -> bool:
	var required_items: Dictionary = quest_data.get("required_items", {})
	for item_id in required_items.keys():
		var quantity_required: int = required_items[item_id]
		if not inventory.has(item_id):
			return false
		var player_quantity: int = inventory[item_id].get("stack", 0)
		if player_quantity < quantity_required:
			return false
	return true


func _on_pin_quest_pressed(quest_id: int) -> void:
	print("Pinning quest: ", quest_id)
	InstanceClient.current.request_data(&"quest.pin", func(response: Dictionary):
		if response.has("error"):
			print("Error pinning quest: ", response["error"])
		else:
			print("Quest pinned successfully")
	, {"quest_id": quest_id})


func _on_complete_quest_pressed(quest_id: int) -> void:
	print("Completing quest: ", quest_id)
	InstanceClient.current.request_data(&"quest.complete", func(response: Dictionary):
		if response.has("error"):
			print("Error completing quest: ", response["error"])
			_show_notification("Error: " + response["error"])
		elif response.has("success") and response["success"]:
			var gold_reward: int = response.get("gold_reward", 0)
			var xp_reward: int = response.get("xp_reward", 0)
			var adventurer: String = response.get("adventurer_type", "")
			_show_notification("Quest Complete! +%d Gold, +%d XP" % [gold_reward, xp_reward])
			print("Quest completed! Received %d gold and %d XP from %s" % [gold_reward, xp_reward, adventurer])
	, {"quest_id": quest_id})


func _show_notification(message: String) -> void:
	print("Notification: ", message)
	# TODO: Add proper notification UI
	# For now just print to console


func _on_close_button_pressed() -> void:
	hide()


## Create an item slot panel for quest display (similar to crafting UI)
func _create_quest_item_slot(item: Item, required_quantity: int, available_quantity: int) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(64, 0)
	
	# Create the item slot panel
	var item_slot = Panel.new()
	item_slot.custom_minimum_size = Vector2(64, 64)
	item_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect hover events for tooltip
	item_slot.mouse_entered.connect(func(): ItemTooltipManager.show_item_tooltip(item, item_slot.get_global_mouse_position(), item_slot))
	item_slot.mouse_exited.connect(func(): ItemTooltipManager.hide_tooltip())
	
	# Add icon
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = item.item_icon
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.layout_mode = 1
	icon.anchors_preset = Control.PRESET_CENTER
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -24.0
	icon.offset_top = -24.0
	icon.offset_right = 24.0
	icon.offset_bottom = 24.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	item_slot.add_child(icon)
	
	# Add quantity label to the slot
	var amount_label = Label.new()
	amount_label.name = "ItemAmount"
	amount_label.text = str(required_quantity)
	amount_label.layout_mode = 1
	amount_label.anchors_preset = Control.PRESET_TOP_RIGHT
	amount_label.anchor_left = 1.0
	amount_label.anchor_top = 0.0
	amount_label.anchor_right = 1.0
	amount_label.anchor_bottom = 0.0
	amount_label.offset_left = -25.0
	amount_label.offset_top = 2.0
	amount_label.offset_right = -2.0
	amount_label.offset_bottom = 20.0
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	item_slot.add_child(amount_label)
	
	container.add_child(item_slot)
	
	# Show availability below the slot
	var avail_label = Label.new()
	avail_label.text = "%d/%d" % [available_quantity, required_quantity]
	avail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avail_label.custom_minimum_size = Vector2(64, 0)
	if available_quantity < required_quantity:
		avail_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))  # Red
	else:
		avail_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))  # Green
	container.add_child(avail_label)
	
	return container

