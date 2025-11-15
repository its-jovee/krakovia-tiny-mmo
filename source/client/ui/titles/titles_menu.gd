extends Control

@onready var scroll_container: ScrollContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer
@onready var title_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/TitleList
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var header_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/Label

var titles_data: Dictionary = {}
var selected_title_slug: String = ""


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		# Request titles data when menu opens
		InstanceClient.current.request_data(&"titles.get", _on_titles_received, {})


func _on_titles_received(data: Dictionary) -> void:
	if data.has("error"):
		print("Error loading titles: ", data["error"])
		return
	
	titles_data = data
	selected_title_slug = data.get("selected", "")
	
	# Clear existing title rows
	for child in title_list.get_children():
		child.queue_free()
	
	# Sort titles: by rarity (ascending - common first), then by completion rate (descending)
	var titles_array: Array = data.get("titles", [])
	titles_array.sort_custom(func(a, b):
		var rarity_a = a.get("rarity", 0)
		var rarity_b = b.get("rarity", 0)
		
		# First sort by rarity (lowest first - Common, Rare, Epic, Legendary)
		if rarity_a != rarity_b:
			return rarity_a < rarity_b
		
		# Then sort by completion rate (highest first)
		var progress_a = float(a.get("progress", 0))
		var target_a = float(a.get("target", 1))
		var progress_b = float(b.get("progress", 0))
		var target_b = float(b.get("target", 1))
		
		var completion_a = progress_a / target_a if target_a > 0 else 0.0
		var completion_b = progress_b / target_b if target_b > 0 else 0.0
		
		return completion_a > completion_b
	)
	
	# Create title rows
	for title_data in titles_array:
		_create_title_row(title_data)


func _create_title_row(title_data: Dictionary) -> void:
	# Create horizontal row container
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	
	var rarity: int = title_data.get("rarity", 0)
	var rarity_color: Color = _get_rarity_color(rarity)
	var is_unlocked: bool = title_data.get("unlocked", false)
	
	# Style the row with subtle border
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style_box.border_width_left = 2
	style_box.border_color = rarity_color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", style_box)
	
	# If locked, dim it
	if not is_unlocked:
		row.modulate = Color(0.7, 0.7, 0.7, 1.0)
	
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	row.add_child(hbox)
	
	# [Title Name] - fixed width, colored by rarity
	var title_label: Label = Label.new()
	title_label.text = title_data.get("name", "Unknown")
	title_label.add_theme_color_override("font_color", rarity_color)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.custom_minimum_size = Vector2(160, 0)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(title_label)
	
	# [Requirement] - description
	var desc_label: Label = Label.new()
	desc_label.text = title_data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.custom_minimum_size = Vector2(220, 0)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.clip_text = true
	hbox.add_child(desc_label)
	
	# [Progress] - shows progress or unlocked status
	if is_unlocked:
		# Show "Unlocked" badge
		var unlocked_label: Label = Label.new()
		unlocked_label.text = "✓ Unlocked"
		unlocked_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1.0))
		unlocked_label.add_theme_font_size_override("font_size", 12)
		unlocked_label.custom_minimum_size = Vector2(180, 0)
		unlocked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unlocked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(unlocked_label)
	else:
		# Show progress bar with percentage
		var progress: int = title_data.get("progress", 0)
		var target: int = title_data.get("target", 1)
		var percentage: float = (float(progress) / float(target)) * 100.0 if target > 0 else 0.0
		
		var progress_container: HBoxContainer = HBoxContainer.new()
		progress_container.custom_minimum_size = Vector2(250, 0)
		progress_container.add_theme_constant_override("separation", 10)
		
		var progress_bar: ProgressBar = ProgressBar.new()
		progress_bar.min_value = 0
		progress_bar.max_value = target
		progress_bar.value = progress
		progress_bar.show_percentage = false
		progress_bar.custom_minimum_size = Vector2(150, 20)
		progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		progress_container.add_child(progress_bar)
		
		var progress_label: Label = Label.new()
		progress_label.text = "%d / %d" % [progress, target]
		progress_label.add_theme_font_size_override("font_size", 11)
		progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress_label.custom_minimum_size = Vector2(80, 0)
		progress_container.add_child(progress_label)
		
		hbox.add_child(progress_container)
	
	# [Equip Button] - fixed width
	var equip_button: Button = Button.new()
	equip_button.custom_minimum_size = Vector2(100, 0)
	var title_slug: String = title_data.get("slug", "")
	
	if is_unlocked:
		if title_slug == selected_title_slug:
			equip_button.text = "✓ Equipped"
			equip_button.disabled = false
			equip_button.pressed.connect(func(): _unequip_title())
		else:
			equip_button.text = "Equip"
			equip_button.pressed.connect(func(): _equip_title(title_slug, title_data.get("name", "")))
	else:
		equip_button.text = "Locked"
		equip_button.disabled = true
	
	hbox.add_child(equip_button)
	
	title_list.add_child(row)


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		0: # COMMON
			return Color.WHITE
		1: # RARE
			return Color("#4A90E2")
		2: # EPIC
			return Color("#9B59B6")
		3: # LEGENDARY
			return Color("#FFD700")
		_:
			return Color.WHITE


func _equip_title(title_slug: String, title_name: String) -> void:
	InstanceClient.current.request_data(&"titles.select", func(response: Dictionary):
		if response.get("success", false):
			print("Equipped title: ", title_name)
			# Refresh the menu
			_on_titles_received(titles_data)
			# Request updated data
			InstanceClient.current.request_data(&"titles.get", _on_titles_received, {})
	, {"slug": title_slug})


func _unequip_title() -> void:
	InstanceClient.current.request_data(&"titles.select", func(response: Dictionary):
		if response.get("success", false):
			print("Unequipped title")
			# Refresh the menu
			_on_titles_received(titles_data)
			# Request updated data
			InstanceClient.current.request_data(&"titles.get", _on_titles_received, {})
	, {"slug": ""})


func _on_close_pressed() -> void:
	hide()


func on_progress_update(data: Dictionary) -> void:
	"""Update progress bars when server sends progress update"""
	if not visible:
		return
	
	# Refresh the entire menu to show updated progress
	InstanceClient.current.request_data(&"titles.get", _on_titles_received, {})


