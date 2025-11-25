extends PanelContainer


signal character_created()

var selected_class: String = "miner"
var selected_head: String = "head_a"
var head_options: Array[String] = ["head_a", "head_b", "head_c", "head_d"]  # Only valid head options
var current_head_index: int = 0

# Preview sprite
var preview_sprite: CompositeSprite = null

@onready var name_input: LineEdit = $MarginContainer/HBoxContainer/LeftPanel/NameInput
@onready var miner_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ClassButtons/MinerButton
@onready var forager_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ClassButtons/ForagerButton
@onready var trapper_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ClassButtons/TrapperButton
@onready var head_label: Label = $MarginContainer/HBoxContainer/LeftPanel/HeadSelection/HeadLabel
@onready var error_label: Label = $MarginContainer/HBoxContainer/LeftPanel/ErrorLabel
@onready var create_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ButtonsContainer/CreateButton
@onready var preview_viewport: SubViewport = $MarginContainer/HBoxContainer/RightPanel/PreviewContainer/SubViewportContainer/SubViewport


func _ready() -> void:
	# Set default class
	miner_button.button_pressed = true
	_update_head_display()
	_setup_preview_sprite()


func show_modal() -> void:
	visible = true
	name_input.text = ""
	error_label.text = ""
	selected_class = "miner"
	current_head_index = 0
	miner_button.button_pressed = true
	forager_button.button_pressed = false
	trapper_button.button_pressed = false
	_update_head_display()
	name_input.grab_focus()


func hide_modal() -> void:
	visible = false


func _setup_preview_sprite() -> void:
	"""Create a CompositeSprite in the preview viewport"""
	if not preview_viewport:
		return
	
	# Create the composite sprite
	preview_sprite = CompositeSprite.new()
	preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # Disable filtering for crisp pixels
	preview_viewport.add_child(preview_sprite)
	
	# Center it in the 128x128 viewport with appropriate scale to fit
	preview_sprite.position = Vector2(64, 74)  # Center horizontally, slightly lower to show full sprite
	preview_sprite.scale = Vector2(3.5, 3.5)  # Scale up for visibility while keeping it in bounds
	
	# Set initial appearance
	_update_preview()
	
	# After preview is set, disable filtering on all child sprites
	call_deferred("_disable_sprite_filtering")


func _disable_sprite_filtering() -> void:
	"""Disable texture filtering on all sprite children for crisp pixel art"""
	if not preview_sprite:
		return
	
	# Recursively disable filtering on all sprite children
	for child in preview_sprite.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			print("[CharacterCreation] Disabled filtering on: ", child.name)


func _update_preview() -> void:
	"""Update the preview sprite with current selections"""
	if not preview_sprite:
		return
	
	preview_sprite.set_appearance(selected_class, selected_head)
	preview_sprite.play_animation("idle")
	
	# Ensure filtering is disabled after updating appearance
	call_deferred("_disable_sprite_filtering")


func _on_class_button_pressed(char_class: String) -> void:
	selected_class = char_class
	# Update button states
	miner_button.button_pressed = (char_class == "miner")
	forager_button.button_pressed = (char_class == "forager")
	trapper_button.button_pressed = (char_class == "trapper")
	# Update preview
	_update_preview()


func _on_previous_head_pressed() -> void:
	current_head_index -= 1
	if current_head_index < 0:
		current_head_index = head_options.size() - 1
	_update_head_display()
	_update_preview()


func _on_next_head_pressed() -> void:
	current_head_index += 1
	if current_head_index >= head_options.size():
		current_head_index = 0
	_update_head_display()
	_update_preview()


func _update_head_display() -> void:
	selected_head = head_options[current_head_index]
	head_label.text = "Head " + selected_head.substr(-1, 1).to_upper()


func _on_create_button_pressed() -> void:
	var character_name: String = name_input.text.strip_edges()
	
	# Validate name
	if character_name.is_empty():
		error_label.text = "Name cannot be empty"
		return
	
	if character_name.length() < 4:
		error_label.text = "Name must be at least 4 characters"
		return
	
	if character_name.length() > 16:
		error_label.text = "Name must be 16 characters or less"
		return
	
	# Disable button to prevent double-clicks
	create_button.disabled = true
	error_label.text = "Creating character..."
	
	# Send character creation request
	InstanceClient.current.request_data(
		&"character.create",
		_on_create_response,
		{
			"name": character_name,
			"class": selected_class,
			"head": selected_head
		}
	)


func _on_create_response(data: Dictionary) -> void:
	create_button.disabled = false
	
	if data.get("ok", false):
		print("[CharacterCreation] Character created successfully!")
		error_label.text = ""
		hide_modal()
		character_created.emit()
	else:
		var err: StringName = data.get("err", &"unknown")
		match err:
			&"empty_name":
				error_label.text = "Name cannot be empty"
			&"name_too_short":
				error_label.text = "Name must be at least 4 characters"
			&"name_too_long":
				error_label.text = "Name must be 16 characters or less"
			&"invalid_class":
				error_label.text = "Invalid class selected"
			&"max_characters_reached":
				error_label.text = "Maximum characters reached for this account"
			&"banned_word":
				error_label.text = "Name contains inappropriate words"
			_:
				error_label.text = "Failed to create character: " + String(err)


func _on_cancel_button_pressed() -> void:
	hide_modal()
