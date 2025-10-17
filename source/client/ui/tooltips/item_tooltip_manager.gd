extends Node

## Singleton that manages item tooltip display
## Loads item metadata from JSON and displays tooltips on hover

var item_metadata: Dictionary = {}
var tooltip_scene: PackedScene
var current_tooltip: Control = null
var tooltip_layer: CanvasLayer = null
var current_tween: Tween = null
var current_item: Item = null
var current_hovering_control: Control = null  # Track which control is being hovered
var cached_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	print("========================================")
	print("ItemTooltipManager _ready() CALLED")
	print("========================================")
	
	# Load item metadata
	_load_item_metadata()
	
	# Preload tooltip scene
	tooltip_scene = preload("res://source/client/ui/tooltips/item_tooltip.tscn")
	print("Tooltip scene preloaded")
	
	# Create dedicated tooltip layer with high layer number
	tooltip_layer = CanvasLayer.new()
	tooltip_layer.layer = 100  # Render on top of everything
	tooltip_layer.name = "TooltipLayer"
	get_tree().root.call_deferred("add_child", tooltip_layer)
	print("Tooltip layer created on layer 100")
	print("ItemTooltipManager initialization COMPLETE")
	print("========================================")


func _load_item_metadata() -> void:
	var file_path = "res://source/common/gameplay/items/item_metadata.json"
	
	if not FileAccess.file_exists(file_path):
		push_error("Item metadata file not found: " + file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open item metadata file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse item metadata JSON: " + json.get_error_message())
		return
	
	item_metadata = json.data
	print("Loaded metadata for ", item_metadata.size(), " items")


func show_item_tooltip(item: Item, mouse_position: Vector2, source_control: Control = null) -> void:
	print("=== TOOLTIP SHOW ===")
	if item:
		print("Item: ", item.item_name)
	else:
		print("Item: NULL")
	print("Mouse pos: ", mouse_position)
	
	if not item:
		print("No item!")
		return
	
	# If we're showing tooltip for the same control, keep cached position and just update content
	if current_hovering_control == source_control and current_tooltip and is_instance_valid(current_tooltip) and current_tooltip.visible:
		print("Same control - updating content only, keeping position")
		_update_tooltip_content(item)
		return
	
	print("Different control or first show - full update")
	# Different control or first time showing - update everything
	current_item = item
	current_hovering_control = source_control
	cached_position = mouse_position
	
	# Hide existing tooltip immediately (no animation when switching between items)
	_hide_tooltip_immediate()
	
	# Create new tooltip
	if not tooltip_scene:
		print("No tooltip scene!")
		return
	
	current_tooltip = tooltip_scene.instantiate()
	print("Tooltip created")
	
	# Add to dedicated tooltip layer FIRST
	tooltip_layer.add_child(current_tooltip)
	print("Tooltip added to TooltipLayer (layer 100)")
	
	# Set tooltip content AFTER adding to tree
	var content = _create_tooltip_content(item)
	print("@@@ Content created, length: ", content.length())
	print("@@@ Content preview: ", content.substr(0, 100))
	if current_tooltip.has_method("set_content"):
		print("@@@ Calling set_content()")
		current_tooltip.set_content(content)
		print("@@@ set_content() returned")
	
	# Configure the RichTextLabel to display properly
	var rtl = current_tooltip.get_node_or_null("RichTextLabel")
	if rtl:
		# Set text color and size
		rtl.add_theme_color_override("default_color", Color.WHITE)
		rtl.add_theme_font_size_override("normal_font_size", 14)
		
		# Ensure it's visible and has proper size
		rtl.custom_minimum_size = Vector2(280, 100)
		rtl.size = Vector2(280, 100)
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.bbcode_enabled = true
		rtl.visible = true
		
		# Set the text DIRECTLY (bypass set_content)
		rtl.clear()
		rtl.text = content  # Set as plain text
		
		# Force update
		rtl.queue_redraw()
		print("DEBUG: RichTextLabel configured and visible")
		print("DEBUG: RichTextLabel.text length: ", rtl.text.length())
		print("DEBUG: RichTextLabel.text first 100 chars: ", rtl.text.substr(0, 100))
	
	# Style the panel with a dark semi-transparent background
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.8, 0.8, 0.8, 1.0)
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	current_tooltip.add_theme_stylebox_override("panel", stylebox)
	
	# Force tooltip to render in front
	current_tooltip.z_index = 1000
	current_tooltip.z_as_relative = false
	
	# Position tooltip relative to source control if provided, otherwise use mouse
	if source_control:
		# Position to the right of the item panel
		var panel_rect = source_control.get_global_rect()
		current_tooltip.position = Vector2(panel_rect.position.x + panel_rect.size.x + 10, panel_rect.position.y)
		print("Tooltip positioned relative to panel: ", current_tooltip.position)
	else:
		# Fallback to mouse position
		current_tooltip.position = mouse_position + Vector2(15, 15)
		print("Tooltip positioned at mouse: ", current_tooltip.position)
	
	# Make tooltip visible with animation
	current_tooltip.visible = true
	current_tooltip.modulate.a = 0.0  # Start transparent
	current_tooltip.show()
	
	# Fade in animation
	current_tween = create_tween()
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_property(current_tooltip, "modulate:a", 1.0, 0.15)
	
	# Make sure tooltip stays on screen
	await get_tree().process_frame
	
	_adjust_tooltip_position(current_tooltip, source_control if source_control else mouse_position)
	

func hide_tooltip() -> void:
	if not current_tooltip:
		return
	
	# Clear tracking variables
	current_hovering_control = null
	current_item = null
	
	# Cancel any ongoing fade-in animation
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	# Just remove immediately, no fade-out
	current_tooltip.queue_free()
	current_tooltip = null


func _update_tooltip_content(item: Item) -> void:
	"""Update tooltip content without changing position or recreating the tooltip"""
	if not current_tooltip or not is_instance_valid(current_tooltip):
		return
	
	current_item = item
	
	# Get the RichTextLabel and update its content
	var rtl = current_tooltip.get_node_or_null("RichTextLabel")
	if rtl:
		var content = _create_tooltip_content(item)
		rtl.clear()
		rtl.text = content
		rtl.queue_redraw()


# Internal function to hide tooltip immediately without animation
func _hide_tooltip_immediate() -> void:
	# Note: Don't clear current_hovering_control here, as it's used for comparison
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	
	if current_tooltip and is_instance_valid(current_tooltip):
		current_tooltip.queue_free()
		current_tooltip = null


func _create_tooltip_content(item: Item) -> String:
	var content = ""
	
	# Item name (bold, larger)
	content += "[b][font_size=16]" + item.item_name + "[/font_size][/b]\n"
	
	# Description
	if item.description and item.description != "":
		content += "[color=#CCCCCC]" + item.description + "[/color]\n"
	
	content += "\n"
	
	# Sell price
	if item.can_sell and item.minimum_price > 0:
		content += "[color=#FFD700]Sell Price: " + str(item.minimum_price) + " gold[/color]\n"
	
	# Get item slug from registry
	var item_slug = _get_item_slug(item)
	
	if item_slug and item_metadata.has(item_slug):
		var metadata = item_metadata[item_slug]
		
		# Separator
		if metadata.harvest_sources.size() > 0 or metadata.crafted_by.size() > 0:
			content += "[color=#666666]─────────────────[/color]\n"
		
		# Harvestable sources
		if metadata.harvest_sources.size() > 0:
			content += "[color=#88FF88][b]Harvestable:[/b][/color]\n"
			for source in metadata.harvest_sources:
				# FIX: Renamed variable from class_name to harvester_class
				var harvester_class = String(source["class"]).capitalize()
				var tier_text = "Tier " + str(source["tier"])
				var rare_text = " (Rare)" if source["is_rare"] else ""
				content += "  • " + harvester_class + " " + tier_text + rare_text + "\n"
		
		# Craftable recipes
		if metadata.crafted_by.size() > 0:
			if metadata.harvest_sources.size() > 0:
				content += "\n"
			content += "[color=#88CCFF][b]Craftable:[/b][/color]\n"
			for recipe in metadata.crafted_by:
				# FIX: Renamed variable from class_name to crafter_class
				var crafter_class = String(recipe["class"]).capitalize()
				var level_text = "Lvl " + str(recipe["level"])
				content += "  • " + crafter_class + " " + level_text + " (" + recipe["recipe_name"] + ")\n"
	
	return content

func _get_item_slug(item: Item) -> StringName:
	# Get the resource path of the item
	var resource_path = item.resource_path
	if resource_path.is_empty():
		return &""
	
	# Item files are stored like "res://source/.../copper_ore.tres"
	# Extract the filename without extension
	var filename = resource_path.get_file().get_basename()
	
	# The filename IS the slug (e.g., "copper_ore.tres" → "copper_ore")
	return StringName(filename)


func _adjust_tooltip_position(tooltip: Control, source: Variant) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = tooltip.size
	var final_pos = tooltip.position  # Use current position as starting point
	
	# If tooltip goes off right edge, show it on the left side instead
	if final_pos.x + tooltip_size.x > viewport_size.x:
		if source is Control:
			var panel_rect = source.get_global_rect()
			final_pos.x = panel_rect.position.x - tooltip_size.x - 10
		else:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
	
	# If tooltip goes off bottom edge, adjust upward
	if final_pos.y + tooltip_size.y > viewport_size.y:
		final_pos.y = viewport_size.y - tooltip_size.y - 10
	
	# Clamp to screen bounds
	final_pos.x = clamp(final_pos.x, 10, viewport_size.x - tooltip_size.x - 10)
	final_pos.y = clamp(final_pos.y, 10, viewport_size.y - tooltip_size.y - 10)
	
	tooltip.position = final_pos
