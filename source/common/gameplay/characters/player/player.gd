class_name Player
extends Character


var player_resource: PlayerResource

var display_name: String = "Unknown":
	set = _set_display_name

var handle_name: String = " ":
	set = _set_handle_name

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

@onready var syn: StateSynchronizer = $StateSynchronizer
@onready var display_name_label: Label = $DisplayNameLabel
@onready var handle_name_label: Label = $HandleNameLabel
@onready var speech_bubble: Control = $SpeechBubble

var shop_indicator: Control = null

# Hover detection for remote players (client-side only)
var hover_detector: Control = null
var is_hovered: bool = false
var outline_material: ShaderMaterial = null


func _init() -> void:
	pass

func _ready() -> void:
	super._ready()
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
	
	# Prepare outline shader material
	var outline_shader = preload("res://source/client/shaders/player_outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = outline_shader
	outline_material.set_shader_parameter("line_color", Color(1.0, 1.0, 1.0, 1.0))  # White
	outline_material.set_shader_parameter("line_thickness", 1.5)
	print("Shader material prepared for: ", display_name)

func _on_mouse_entered() -> void:
	"""Called when mouse enters player area"""
	print("Mouse entered player: ", display_name)
	is_hovered = true
	# Apply outline shader to sprite
	if animated_sprite:
		animated_sprite.material = outline_material
		print("Applied outline material to sprite")
	else:
		print("WARNING: animated_sprite is null!")

func _on_mouse_exited() -> void:
	"""Called when mouse exits player area"""
	print("Mouse exited player: ", display_name)
	is_hovered = false
	# Remove outline shader
	if animated_sprite:
		animated_sprite.material = null
		print("Removed outline material from sprite")

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
	display_name_label.text = new_name
	display_name = new_name


func show_speech_bubble(text: String) -> void:
	if not is_node_ready():
		await ready
	if speech_bubble and speech_bubble.has_method("show_message"):
		speech_bubble.show_message(text)


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
