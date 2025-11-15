class_name Player
extends Character


var player_resource: PlayerResource

var display_name: String = "Unknown":
	set = _set_display_name

var handle_name: String = " ":
	set = _set_handle_name

var title_text: String = "":
	set = _set_title_text

var title_rarity: int = 0:
	set = _set_title_rarity

var is_in_pvp_zone: bool = false
var just_teleported: bool = false:
	set(value):
		just_teleported = value
		if not is_inside_tree():
			await tree_entered
		if just_teleported:
			await get_tree().create_timer(0.5).timeout
			just_teleported = false

var has_shop_open: bool = false:
	set(value):
		has_shop_open = value
		_update_shop_indicator()

var shop_name: String = "":
	set(value):
		shop_name = value
		_update_shop_indicator()

var peer_id: int = -1
var is_remote_player: bool = false  # True for remote players on client

@onready var syn: StateSynchronizer = $StateSynchronizer
@onready var title_label: RichTextLabel = $TitleLabel
@onready var display_name_label: Label = $DisplayNameLabel
@onready var handle_name_label: Label = $HandleNameLabel
@onready var speech_bubble: Control = $SpeechBubble

var shop_indicator: Control = null

# Hover detection for remote players (client-side only)
var hover_detector: Control = null
var is_hovered: bool = false


func _init() -> void:
	pass

func _physics_process(_delta: float) -> void:
	# Remote players on client: always keep velocity zero (positions are synced from server)
	# But still call move_and_slide() so they act as solid obstacles for collision
	if is_remote_player:
		velocity = Vector2.ZERO
		move_and_slide()  # Participate in physics collision without moving

func _ready() -> void:
	
	super._ready()
	
	if has_node("PointLight2D"):
		var light = $PointLight2D
		light.blend_mode = PointLight2D.BLEND_MODE_MIX
		light.energy = 0.1
		print("PointLight2D configurado para BLEND_MODE_MIX no player: ", display_name)
	else:
		print("Aviso: Player sem PointLight2D!")
		
	# Only setup hover detection for remote players (not local player)
	# Check if we're on client and this is not the local player
	print("Player _ready: peer_id=", peer_id, " local_id=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server())
	if not multiplayer.is_server() and peer_id != -1 and peer_id != multiplayer.get_unique_id():
		print("Setting up hover detection for remote player: ", display_name, " (peer_id: ", peer_id, ")")
		call_deferred("_setup_hover_detection")



func _setup_hover_detection() -> void:
	"""Setup mouse hover detection for remote players"""
	print("_setup_hover_detection called for: ", display_name, " (peer_id: ", peer_id, ")")
	
	# Double-check we're not setting this up for local player
	if peer_id == multiplayer.get_unique_id():
		print("WARNING: Attempted to setup hover detection for local player, aborting!")
		return
	
	# Create a Control node for mouse detection (works better than Area2D for this)
	hover_detector = Control.new()
	hover_detector.name = "HoverDetector"
	hover_detector.mouse_filter = Control.MOUSE_FILTER_STOP
	hover_detector.position = Vector2(-24, -48)  # Top-left corner
	hover_detector.size = Vector2(48, 64)  # Cover the player sprite
	hover_detector.z_index = 50  # Above the player but below UI
	add_child(hover_detector)
	print("Created HoverDetector Control at position: ", hover_detector.position, " with size: ", hover_detector.size)
	
	# Connect mouse signals
	hover_detector.mouse_entered.connect(_on_mouse_entered)
	hover_detector.mouse_exited.connect(_on_mouse_exited)
	print("Connected mouse signals for: ", display_name)

func _on_mouse_entered() -> void:
	"""Called when mouse enters player area"""
	print("Mouse entered player: ", display_name)
	is_hovered = true
	_apply_combined_shader(true)

func _on_mouse_exited() -> void:
	"""Called when mouse exits player area"""
	print("Mouse exited player: ", display_name)
	is_hovered = false
	_apply_combined_shader(false)

func _apply_combined_shader(with_outline: bool) -> void:
	"""Switch between animation-only and animation+outline shader"""
	if not animated_sprite or not animation_shader:
		return
	
	if with_outline:
		# Switch to combined shader (animation + outline)
		var combined_shader = load("res://source/client/shaders/character_animation_outline.gdshader")
		if combined_shader:
			var new_material = ShaderMaterial.new()
			new_material.shader = combined_shader
			
			# Copy all animation parameters from current shader
			new_material.set_shader_parameter("time_offset", animation_time_offset)
			new_material.set_shader_parameter("breathing_intensity", 0.6)
			new_material.set_shader_parameter("breathing_speed", 
				animation_shader.get_shader_parameter("breathing_speed"))
			new_material.set_shader_parameter("squash_stretch_intensity", 0.08)
			new_material.set_shader_parameter("squash_stretch_speed", 
				animation_shader.get_shader_parameter("squash_stretch_speed"))
			
			# Copy current animation state
			var current_state = animation_shader.get_shader_parameter("animation_state")
			new_material.set_shader_parameter("animation_state", current_state)
			
			# Add outline parameters
			new_material.set_shader_parameter("line_color", Color.WHITE)
			new_material.set_shader_parameter("line_thickness", 1.5)
			
			# Apply combined shader
			animated_sprite.material = new_material
			animation_shader = new_material  # Update reference so future updates work
			print("Applied combined shader (animation + outline)")
	else:
		# Restore animation-only shader
		var anim_shader = load("res://source/client/shaders/character_animation.gdshader")
		if anim_shader:
			var new_material = ShaderMaterial.new()
			new_material.shader = anim_shader
			
			# Copy animation parameters
			new_material.set_shader_parameter("time_offset", animation_time_offset)
			new_material.set_shader_parameter("breathing_intensity", 0.6)
			new_material.set_shader_parameter("breathing_speed", 
				animation_shader.get_shader_parameter("breathing_speed"))
			new_material.set_shader_parameter("squash_stretch_intensity", 0.08)
			new_material.set_shader_parameter("squash_stretch_speed", 
				animation_shader.get_shader_parameter("squash_stretch_speed"))
			
			# Copy current animation state
			var current_state = animation_shader.get_shader_parameter("animation_state")
			new_material.set_shader_parameter("animation_state", current_state)
			
			# Apply animation-only shader
			animated_sprite.material = new_material
			animation_shader = new_material  # Update reference
			print("Restored animation-only shader")

func _input(event: InputEvent) -> void:
	"""Handle input events for right-click trading"""
	if not is_hovered:
		return
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			_on_right_click_player()
			# Accept the event so it doesn't propagate
			get_viewport().set_input_as_handled()

func _on_right_click_player() -> void:
	"""Send trade request when right-clicking a player"""
	if handle_name.is_empty() or handle_name == " ":
		print("Cannot trade with player: no handle name")
		return
	
	# Send trade command through the chat system
	# This is equivalent to typing "/trade @HandleName"
	InstanceClient.current.request_data(
		&"chat.command.exec",
		func(_response): pass,  # Empty callback
		{"cmd": "trade", "params": ["trade", "@" + handle_name]}
	)

func _set_handle_name(new_handle: String) -> void:
	handle_name = new_handle
	if is_node_ready():
		handle_name_label.text = "@" + new_handle

func _set_display_name(new_name: String) -> void:
	display_name = new_name
	_update_display_name_label()

func _set_title_text(new_title: String) -> void:
	title_text = new_title
	_update_display_name_label()

func _set_title_rarity(new_rarity: int) -> void:
	title_rarity = new_rarity
	_update_display_name_label()

func _update_display_name_label() -> void:
	if not is_node_ready():
		return
	
	# Update the display name (always show it normally)
	display_name_label.text = display_name
	display_name_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Handle title label
	if title_text.is_empty():
		# No title: hide the label
		title_label.visible = false
		title_label.text = ""
	else:
		# Show and update title with BBCode (bold + wave for rare titles)
		title_label.visible = true
		
		var rarity_color: Color = _get_title_rarity_color(title_rarity)
		var color_hex: String = rarity_color.to_html(false)
		var title_upper: String = title_text.to_upper()
		
		# Apply wave effect for rare+ titles (rarity >= 1)
		# Wrap in [center] tag for proper centering
		var formatted_text: String
		if title_rarity >= 1:
			# Rare, Epic, Legendary get wave effect
			formatted_text = "[center][wave][b][color=#%s]%s[/color][/b][/wave][/center]" % [color_hex, title_upper]
		else:
			# Common just gets bold and color
			formatted_text = "[center][b][color=#%s]%s[/color][/b][/center]" % [color_hex, title_upper]
		
		title_label.text = formatted_text

func _get_title_rarity_color(rarity: int) -> Color:
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


func show_speech_bubble(text: String) -> void:
	if not is_node_ready():
		await ready
	if speech_bubble and speech_bubble.has_method("show_message"):
		speech_bubble.show_message(text)


func set_player_collision_enabled(enabled: bool) -> void:
	"""Enable or disable player-to-player collision (used by minigames/PvP zones)"""
	if multiplayer.is_server():
		return  # Server-side players always have collision for physics authority
	
	# Only affects remote players on clients
	if peer_id == multiplayer.get_unique_id():
		return  # Don't modify local player collision
	
	if enabled:
		# Enable collision - remote player becomes solid obstacle
		collision_layer = 1  # On layer 1 (same as all players)
		collision_mask = 7   # Collide with players (1), objects (2), walls (4)
	else:
		# Disable collision - remote player is non-solid
		collision_layer = 0  # Not on any layer
		collision_mask = 6   # Still collide with objects (2) and walls (4), not players


func _update_shop_indicator() -> void:
	print("=== PLAYER: _update_shop_indicator called ===")
	print("Player name: ", name)
	print("peer_id: ", peer_id)
	print("has_shop_open: ", has_shop_open)
	print("shop_name: ", shop_name)
	print("is_node_ready: ", is_node_ready())
	
	if not is_node_ready():
		print("Node not ready yet, waiting...")
		return
	
	if has_shop_open and shop_name != "":
		print("Should show shop indicator!")
		# Show shop indicator
		if shop_indicator == null:
			print("Creating new shop indicator...")
			var shop_indicator_scene = preload("res://source/client/ui/shop/shop_indicator.tscn")
			shop_indicator = shop_indicator_scene.instantiate()
			add_child(shop_indicator)
			# Position is now handled by shop_indicator's _process() method (like speech bubble)
			shop_indicator.peer_id = peer_id
			print("Shop indicator created and added!")
		
		shop_indicator.shop_name = shop_name
		shop_indicator.visible = true
		print("Shop indicator should now be visible!")
	else:
		print("Should hide shop indicator")
		# Hide/remove shop indicator
		if shop_indicator != null:
			shop_indicator.visible = false
			print("Shop indicator hidden")
