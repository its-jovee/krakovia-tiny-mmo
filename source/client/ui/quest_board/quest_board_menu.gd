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
	panel.custom_minimum_size = Vector2(0, 120)
	
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
	
	var required_items: Dictionary = quest_data.get("required_items", {})
	for item_id in required_items.keys():
		var quantity_required: int = required_items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var item_row = HBoxContainer.new()
			vbox.add_child(item_row)
			
			var item_text = Label.new()
			var player_quantity: int = 0
			if inventory.has(item_id):
				player_quantity = inventory[item_id].get("stack", 0)
			
			item_text.text = "  • %s: %d/%d" % [item.item_name, player_quantity, quantity_required]
			
			# Color code based on availability
			if player_quantity >= quantity_required:
				item_text.add_theme_color_override("font_color", Color(0, 1, 0))  # Green
			else:
				item_text.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red
			
			item_row.add_child(item_text)
	
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

