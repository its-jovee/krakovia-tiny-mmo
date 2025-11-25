extends Control
## Leaderboard UI for viewing player rankings


var in_leaderboard: bool = false
var leaderboards: Dictionary = {}
var current_category: String = "global"

@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var tab_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var global_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/GlobalButton
@onready var miner_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/MinerButton
@onready var forager_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/ForagerButton
@onready var trapper_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/TrapperButton
@onready var leaderboard_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/LeaderboardContainer


func _ready() -> void:
	print("Leaderboard menu _ready() called")
	hide()  # Start hidden
	
	# Set mouse filter to consume scroll events
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	close_button.pressed.connect(_on_close_button_pressed)
	global_button.pressed.connect(func(): _switch_category("global"))
	miner_button.pressed.connect(func(): _switch_category("miner"))
	forager_button.pressed.connect(func(): _switch_category("forager"))
	trapper_button.pressed.connect(func(): _switch_category("trapper"))
	
	# Subscribe to leaderboard status updates
	InstanceClient.subscribe(&"leaderboard.status", _on_leaderboard_status_update)
	
	_update_ui_text()


func _on_leaderboard_status_update(data: Dictionary) -> void:
	in_leaderboard = data.get("in_leaderboard", false)
	print("Leaderboard status update: ", in_leaderboard)
	
	if in_leaderboard:
		# Fetch leaderboards from server
		InstanceClient.current.request_data(&"leaderboard.fetch", _on_leaderboards_received, {})
		show()
	else:
		hide()


func _on_leaderboards_received(response: Dictionary) -> void:
	if response.has("error"):
		print("Error fetching leaderboards: ", response["error"])
		return
	
	leaderboards = response.get("leaderboards", {})
	print("Received leaderboards with %d categories" % leaderboards.size())
	_refresh_leaderboard_display()


func _switch_category(category: String) -> void:
	current_category = category
	_update_tab_buttons()
	_refresh_leaderboard_display()


func _update_tab_buttons() -> void:
	# Reset all buttons
	global_button.disabled = false
	miner_button.disabled = false
	forager_button.disabled = false
	trapper_button.disabled = false
	
	# Disable current category button
	match current_category:
		"global":
			global_button.disabled = true
		"miner":
			miner_button.disabled = true
		"forager":
			forager_button.disabled = true
		"trapper":
			trapper_button.disabled = true


func _refresh_leaderboard_display() -> void:
	# Clear existing entries
	for child in leaderboard_container.get_children():
		child.queue_free()
	
	# Add header
	var header = _create_header()
	leaderboard_container.add_child(header)
	
	# Get current category entries
	var entries: Array = leaderboards.get(current_category, [])
	
	if entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No entries yet. Be the first!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaderboard_container.add_child(empty_label)
		return
	
	# Display entries
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var entry_panel = _create_entry_panel(i + 1, entry)
		leaderboard_container.add_child(entry_panel)


func _create_header() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 40)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Rank
	var rank_label = Label.new()
	rank_label.text = "Rank"
	rank_label.custom_minimum_size = Vector2(50, 0)
	rank_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(rank_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	# Class (only show on global)
	if current_category == "global":
		var class_label = Label.new()
		class_label.text = "Class"
		class_label.custom_minimum_size = Vector2(70, 0)
		class_label.add_theme_font_size_override("font_size", 14)
		hbox.add_child(class_label)
	
	# Krak
	var krak_label = Label.new()
	krak_label.text = "Krak"
	krak_label.custom_minimum_size = Vector2(50, 0)
	krak_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(krak_label)
	
	# Level
	var level_label = Label.new()
	level_label.text = "Lvl"
	level_label.custom_minimum_size = Vector2(40, 0)
	level_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(level_label)
	
	# Gold
	var gold_label = Label.new()
	gold_label.text = "Gold"
	gold_label.custom_minimum_size = Vector2(80, 0)
	gold_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(gold_label)
	
	# Score
	var score_label = Label.new()
	score_label.text = "Score"
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(score_label)
	
	return panel


func _create_entry_panel(rank: int, entry: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 35)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Rank with special coloring for top 3
	var rank_label = Label.new()
	rank_label.text = str(rank)
	rank_label.custom_minimum_size = Vector2(50, 0)
	if rank == 1:
		rank_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	elif rank == 2:
		rank_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))  # Silver
	elif rank == 3:
		rank_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))  # Bronze
	hbox.add_child(rank_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = entry.get("name", "Unknown")
	name_label.custom_minimum_size = Vector2(120, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(name_label)
	
	# Class (only show on global)
	if current_category == "global":
		var class_label = Label.new()
		class_label.text = entry.get("class", "?")
		class_label.custom_minimum_size = Vector2(70, 0)
		hbox.add_child(class_label)
	
	# Krak
	var krak_label = Label.new()
	krak_label.text = str(entry.get("krak", 0))
	krak_label.custom_minimum_size = Vector2(50, 0)
	krak_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	hbox.add_child(krak_label)
	
	# Level
	var level_label = Label.new()
	level_label.text = str(entry.get("level", 1))
	level_label.custom_minimum_size = Vector2(40, 0)
	hbox.add_child(level_label)
	
	# Gold
	var gold_label = Label.new()
	gold_label.text = str(entry.get("gold", 0))
	gold_label.custom_minimum_size = Vector2(80, 0)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	hbox.add_child(gold_label)
	
	# Score
	var score_label = Label.new()
	var score: float = entry.get("score", 0.0)
	score_label.text = "%.1f" % score
	score_label.custom_minimum_size = Vector2(100, 0)
	score_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	hbox.add_child(score_label)
	
	return panel


func _update_ui_text() -> void:
	# Update static labels
	if title_label:
		title_label.text = "Leaderboard"
	if close_button:
		close_button.text = "Close"


func _on_close_button_pressed() -> void:
	hide()

