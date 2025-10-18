extends Control


var node_path: String = ""
var count: int = 0
var multiplier: float = 1.0
var state: StringName = &""
var pool: float = 0.0
var earned_total: float = 0.0 # kept for potential future use, not displayed
var harvesting_total: int = 0
var next_progress: float = 0.0

var session_active: bool = false
var session_expires_at: float = 0.0
var session_stacks: int = 0
var session_total_bonus: float = 0.0

# New fields for class/level requirements
var tier: int = 1
var node_type: StringName = &""
var required_class: StringName = &""
var required_level: int = 1
var last_error: String = ""

# Smooth progress bar tracking
var harvest_start_time: float = 0.0
var harvest_last_tick_time: float = 0.0
var harvest_tick_duration: float = 1.0  # Duration between ticks (learned from server)
var is_harvesting: bool = false

# UI references
@onready var tier_label: Label = $Panel/MarginContainer/VBoxContainer/TierLabel
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/ProgressBar
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/InfoLabel


func _ready() -> void:
	visible = false


func on_status(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	var was_harvesting = is_harvesting
	var old_node_path = node_path
	
	node_path = String(data.get("node", node_path))
	count = int(data.get("count", count))
	multiplier = float(data.get("multiplier", multiplier))
	state = data.get("state", state)
	pool = float(data.get("pool", pool))
	earned_total = float(data.get("earned_total", earned_total))
	harvesting_total = int(data.get("projected_total_int", harvesting_total))
	next_progress = float(data.get("next_progress", next_progress))
	tier = int(data.get("tier", tier))
	node_type = data.get("node_type", node_type)
	required_class = data.get("required_class", required_class)
	required_level = int(data.get("required_level", required_level))
	
	# Start harvesting or restart progress if node changed
	if node_path != "" and (not was_harvesting or old_node_path != node_path):
		is_harvesting = true
		harvest_start_time = Time.get_ticks_msec() / 1000.0
		harvest_last_tick_time = 0.0  # Reset tick timing when starting new node
		harvest_tick_duration = 1.0  # Start with default 1 second estimate
	
	_refresh()


func on_session(data: Dictionary) -> void:
	if data.is_empty():
		return
	visible = true
	session_active = true
	session_stacks = 1
	session_total_bonus = 0.0
	var window: float = float(data.get("window", 10.0))
	session_expires_at = Time.get_ticks_msec() / 1000.0 + window
	_refresh()


func on_harvest_tick() -> void:
	"""Called when harvest.tick fires - reset progress bar for new harvest attempt"""
	print_debug("[HarvestingPanel] on_harvest_tick called. is_harvesting=%s, visible=%s" % [is_harvesting, visible])
	if is_harvesting:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Learn the tick duration from the time between ticks
		if harvest_last_tick_time > 0.0:
			var measured_duration = current_time - harvest_last_tick_time
			# Use a moving average to smooth out network jitter
			harvest_tick_duration = lerp(harvest_tick_duration, measured_duration, 0.3)
			print_debug("[HarvestingPanel] Measured tick duration: %f, smoothed: %f" % [measured_duration, harvest_tick_duration])
		
		harvest_start_time = current_time
		harvest_last_tick_time = current_time
		
		if progress_bar:
			progress_bar.value = 0.0  # Force reset to 0 immediately
		_refresh()
		print_debug("[HarvestingPanel] Progress bar reset. harvest_start_time=%f" % harvest_start_time)


func on_hit(data: Dictionary) -> void:
	if data.is_empty():
		return
	session_active = true
	session_stacks = int(data.get("stack_index", session_stacks))
	session_total_bonus = float(data.get("total_bonus_pct", session_total_bonus))
	var time_left: float = float(data.get("time_left", 0.0))
	if time_left > 0.0:
		session_expires_at = Time.get_ticks_msec() / 1000.0 + time_left
	_refresh()


func on_end(data: Dictionary) -> void:
	session_active = false
	session_stacks = 0
	session_total_bonus = 0.0
	session_expires_at = 0.0
	_refresh()


func _process(_delta: float) -> void:
	# Update session expiry
	if session_active and session_expires_at > 0.0:
		if (Time.get_ticks_msec() / 1000.0) >= session_expires_at:
			session_active = false
			session_stacks = 0
			session_total_bonus = 0.0
			session_expires_at = 0.0
			_refresh()
	
	# Update progress bar smoothly
	if is_harvesting and visible and progress_bar:
		var elapsed = Time.get_ticks_msec() / 1000.0 - harvest_start_time
		# Use the learned tick duration from server timing
		var progress = clampf(elapsed / harvest_tick_duration, 0.0, 1.0)
		progress_bar.value = progress * 100.0
	
	# Always update position when visible (follow player)
	if visible:
		_update_position()


func _update_progress_bar(progress: float) -> void:
	"""Update the progress bar visual"""
	if progress_bar:
		progress_bar.value = progress * 100.0


func _update_position() -> void:
	"""Position the panel above the player, like speech bubble (in world space)"""
	# Scale inversely with zoom to maintain consistent size
	var camera_zoom: float = 1.0
	var viewport: Viewport = get_viewport()
	if viewport:
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			camera_zoom = camera.zoom.x
	
	# Scale inversely with zoom to maintain consistent size
	scale = Vector2.ONE / camera_zoom
	
	# Position the bubble above the player
	if get_parent():
		var parent_pos: Vector2 = get_parent().global_position
		# Center horizontally on the player, accounting for scale and actual width
		# Use the actual panel size which changes based on message length
		var panel_node = get_node_or_null("Panel")
		var actual_width: float = panel_node.size.x if panel_node else 0
		var scaled_half_width: float = (actual_width / 2.0) * scale.x
		
		# Adjust Y offset based on bubble height so tall bubbles don't cover the character
		var actual_height: float = panel_node.size.y if panel_node else 0
		var scaled_height: float = actual_height * scale.y
		var y_offset: float = -scaled_height + 80  # 50px padding above the player
		
		global_position = parent_pos + Vector2(-scaled_half_width, y_offset)


func reset() -> void:
	node_path = ""
	count = 0
	multiplier = 1.0
	state = &""
	pool = 0.0
	earned_total = 0.0
	harvesting_total = 0
	next_progress = 0.0
	session_active = false
	session_stacks = 0
	session_total_bonus = 0.0
	session_expires_at = 0.0
	tier = 1
	node_type = &""
	required_class = &""
	required_level = 1
	last_error = ""
	is_harvesting = false
	harvest_start_time = 0.0
	visible = false
	_refresh()


func show_error(error_data: Dictionary) -> void:
	"""Display error message for failed harvest attempt"""
	var err: StringName = error_data.get("err", &"")
	match err:
		&"wrong_class":
			var req_class: String = String(error_data.get("required_class", ""))
			last_error = "Requires %s class" % req_class.capitalize()
		&"level_too_low":
			var req_level: int = int(error_data.get("required_level", 1))
			last_error = "Requires level %d" % req_level
		&"node_depleted":
			last_error = "Node is depleted"
		&"out_of_range":
			last_error = "Out of range"
		_:
			last_error = "Cannot harvest"
	visible = true
	_refresh()
	# Auto-hide error after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if last_error != "":
		last_error = ""
		visible = false
		_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	
	# Show error message if present
	if last_error != "":
		visible = true
		if tier_label:
			tier_label.text = "[color=red]%s[/color]" % last_error
		if info_label:
			info_label.visible = false
		if progress_bar:
			progress_bar.visible = false
	# Only show when we have a node and are harvesting
	elif node_path != "" and is_harvesting:
		visible = true
		
		# Get node display name from node_type
		var node_display = _get_node_display_name(node_type)
		
		# Update tier label
		if tier_label:
			tier_label.text = "Tier %d %s" % [tier, node_display]
		
		# Show progress bar
		if progress_bar:
			progress_bar.visible = true
			progress_bar.max_value = 100.0
		
		# Update info label (player count and multiplier)
		if info_label:
			info_label.visible = true
			info_label.text = "%d Player%s • %.2fx Multiplier" % [
				count,
				"s" if count != 1 else "",
				multiplier
			]
	else:
		visible = false


func _get_node_display_name(type: StringName) -> String:
	"""Convert node_type to a friendly display name"""
	match type:
		&"ore":
			return "Miner Node"
		&"plant":
			return "Forager Node"
		&"hunting":
			return "Trapper Node"
		_:
			return "%s Node" % String(type).capitalize()
