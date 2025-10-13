class_name LocalPlayer
extends Player


var speed: float = 125.0
var hand_pivot_speed: float = 17.5

var input_direction: Vector2 = Vector2.ZERO
var last_input_direction: Vector2 = Vector2.ZERO
var action_input: bool = false
var interact_input: bool = false
var is_sitting_local: bool = false

var state: String = "idle"

var synchronizer_manager: StateSynchronizerManagerClient

# Zoom settings
var zoom_speed: float = 0.1  # How much to zoom per wheel step
var min_zoom: float = 1.0    # Minimum zoom level (same as slider)
var max_zoom: float = 4.0    # Maximum zoom level (same as slider)
var target_zoom: float = 1.0 # Target zoom for smooth transitions
var zoom_transition_speed: float = 10.0 # Speed of zoom transitions

@onready var mouse: Node2D = $MouseComponent

func _ready() -> void:
	Events.local_player = self
	Events.local_player_ready.emit(self)
	super()
	# mirror sit flag to local state
	var asc: AbilitySystemComponent = get_node_or_null(^"AbilitySystemComponent")
	if asc:
		asc.mirror.attribute_local_changed.connect(
			func(attr: StringName, value: float, _max_value: float) -> void:
				if attr == &"is_sitting":
					is_sitting_local = (value > 0.5)
		)
	fid_position = PathRegistry.id_of(":position")
	fid_flipped = PathRegistry.id_of(":flipped")
	fid_anim = PathRegistry.id_of(":anim")
#	fid_pivot = PathRegistry.id_of(":pivot")
		
	
	# Initialize zoom from settings
	if Events.settings.has("zoom"):
		target_zoom = Events.settings["zoom"]
		$Camera2D.zoom = Vector2.ONE * target_zoom
	else:
		target_zoom = 1.0
		$Camera2D.zoom = Vector2.ONE * target_zoom


func _physics_process(delta: float) -> void:
	check_inputs()
	move()
	update_animation(delta)
	update_zoom(delta)
	define_sync_state()

func move() -> void:
	if is_sitting_local:
		velocity = Vector2.ZERO
	else:
		velocity = input_direction * speed
	move_and_slide()


func check_inputs() -> void:
	if _is_typing_in_ui():
		input_direction = Vector2.ZERO
		action_input = false
		interact_input = false
		return
	
	# Market detection is handled by server notifications
	input_direction = Input.get_vector("left", "right", "up", "down")
	match input_direction:
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN:
			last_input_direction = input_direction
	if Input.is_action_just_pressed("action"):
		# If harvesting locally, use Encourage instead of combat action
		if InstanceClient.local_harvest_node != "":
			InstanceClient.current.request_data(&"harvest.encourage", Callable())
		else:
			pass
	interact_input = Input.is_action_just_pressed("interact")
	if interact_input:
		# Toggle join/leave harvesting (iteration 0 test)
		InstanceClient.current.request_data(&"harvest.leave", Callable(), {})
		# Optimistically hide/reset HUD; it will re-show on joined event if join succeeds
		InstanceClient.local_harvest_node = ""
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("reset"):
			panel.reset()
		InstanceClient.current.request_data(&"harvest.join", _on_harvest_join_response, {})


	# Enter (ui_accept) should open chat; remove temporary energy consume

	# Sit toggle on X
	if Input.is_action_just_pressed("sit"):
		is_sitting_local = not is_sitting_local
		InstanceClient.current.request_data(&"state.sit", Callable(), {"on": is_sitting_local})


func _on_harvest_join_response(data: Dictionary) -> void:
	"""Handle response from harvest.join request"""
	if not data.get("ok", false):
		# Show error message in HarvestingPanel
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("show_error"):
			panel.show_error(data)


func _input(event: InputEvent) -> void:
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				# Zoom in
				adjust_zoom(zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				# Zoom out
				adjust_zoom(-zoom_speed)


func adjust_zoom(zoom_delta: float) -> void:
	# Don't zoom if user is typing in UI
	if _is_typing_in_ui():
		return
	if _is_crafting_view_open():
		return
	
	# Update target zoom
	target_zoom = clampf(target_zoom + zoom_delta, min_zoom, max_zoom)
	
	# Update settings for persistence
	Events.settings["zoom"] = target_zoom


func update_zoom(delta: float) -> void:
	# Smoothly transition to target zoom
	var current_zoom = $Camera2D.zoom.x
	var new_zoom = move_toward(current_zoom, target_zoom, delta * zoom_transition_speed)
	$Camera2D.zoom = Vector2.ONE * new_zoom


func update_animation(delta: float) -> void:
	# Determine animation based on current state
	if is_sitting_local:
		anim = Animations.SIT
	elif InstanceClient.local_harvest_node != "":
		anim = Animations.HARVEST
	elif input_direction:
		anim = Animations.RUN
	else:
		anim = Animations.IDLE
	
	# Handle character flipping
	if input_direction.x != 0:
		flipped = (input_direction.x < 0)
		last_input_direction = input_direction  # Store the last direction
	elif last_input_direction.x != 0:
		# Keep facing the last direction when not moving horizontally
		flipped = (last_input_direction.x < 0)
		
var fid_position: int = PathRegistry.id_of(":position")
var fid_flipped: int = PathRegistry.id_of(":flipped")
var fid_anim: int = PathRegistry.id_of(":anim")
#var fid_pivot: int = PathRegistry.id_of(":pivot")

func define_sync_state() -> void:
	var pairs: Array[Array] = [
		[fid_position, global_position],
		[fid_flipped, flipped],
		[fid_anim, anim],
		#[fid_pivot, snappedf(hand_pivot.rotation, 0.05)],
	]
	syn.mark_many_by_id(pairs, true)
	synchronizer_manager.send_my_delta(
		multiplayer.get_unique_id(), syn.collect_dirty_pairs()
	)


func _is_typing_in_ui() -> bool:
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	var owner: Control = vp.gui_get_focus_owner()
	if owner == null:
		return false
	# Freeze movement if user is typing in a text field
	return owner is LineEdit or owner is TextEdit

func _is_crafting_view_open() -> bool:
	# Check if the inventory menu's crafting view is open
	var inventory_menu = get_tree().get_root().find_child("InventoryMenu", true, false)
	if inventory_menu == null:
		return false
	
	# Check if inventory menu is visible AND crafting view is visible
	if not inventory_menu.is_visible_in_tree():
		return false
	else:
		return true
	
	var crafting_view = inventory_menu.get_node_or_null("CraftingView")
	if crafting_view == null:
		return false
	
	return crafting_view.is_visible_in_tree()

func _set_character_class(new_class: String):
	character_resource = ResourceLoader.load(
		"res://source/common/gameplay/characters/classes/character_collection/" +
		new_class + ".tres"
	)
	animated_sprite.sprite_frames = character_resource.character_sprite
	character_class = new_class

func _on_entered_market(market_area: MarketArea) -> void:
	print("Entered market: ", market_area.market_name)

func _on_exited_market(market_area: MarketArea) -> void:
	print("Exited market: ", market_area.market_name)
