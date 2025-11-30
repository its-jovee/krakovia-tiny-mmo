extends Control
## HarvestingPanel - Displays harvest game UI for all class types
## Supports: rhythm (miner), precision (collector), steady_aim (trapper)


# Node state
var node_path: String = ""
var count: int = 0
var multiplier: float = 1.0
var state: StringName = &""
var pool: float = 0.0
var earned_total: float = 0.0
var harvesting_total: int = 0
var next_progress: float = 0.0

# Node info
var tier: int = 1
var node_type: StringName = &""
var required_class: StringName = &""
var required_level: int = 1
var last_error: String = ""

# Node health (for health bar display)
var node_remaining: float = 100.0
var node_max_amount: float = 100.0

# Harvesting state
var is_harvesting: bool = false
var harvest_start_time: float = 0.0
var harvest_last_tick_time: float = 0.0
var harvest_tick_duration: float = 1.0

# ============================================================================
# HARVEST GAME STATE
# ============================================================================

var current_game_type: StringName = &"none"  # "rhythm", "precision", "steady_aim", "none"
var game_beat_interval: float = 1.5
var game_config: Dictionary = {}

# Beat/window timing
var next_beat_time: float = 0.0
var beat_active: bool = false
var last_beat_timestamp_ms: int = 0
var last_beat_received_at_ms: int = 0  # Client local time when beat was received

# Performance tracking
var current_streak: int = 0
var last_performance: StringName = &"passive"

# Sync state
var sync_active: bool = false
var sync_count: int = 0
var sync_bonus: float = 1.0
var sync_display_time: float = 0.0

# Precision game specific (collector)
var precision_meter_value: float = 0.0
var precision_meter_direction: int = 1
var precision_window_active: bool = false
var precision_window_start_time: float = 0.0
var precision_is_holding: bool = false

# Steady aim game specific (trapper)
var aim_circle_size: float = 1.0
var aim_window_active: bool = false
var aim_window_start_time: float = 0.0

# Visual feedback
var feedback_text: String = ""
var feedback_color: Color = Color.WHITE
var feedback_display_time: float = 0.0
const FEEDBACK_DURATION: float = 0.8

# Damage popup system (using DamagePopup nodes now)
const DamagePopupScene = preload("res://source/client/ui/hud/harvesting/DamagePopup.tscn")

# Audio
var _audio_beat: AudioStreamPlayer
var _audio_perfect: AudioStreamPlayer
var _audio_good: AudioStreamPlayer
var _audio_miss: AudioStreamPlayer
var _audio_sync: AudioStreamPlayer

# UI references
@onready var tier_label: Label = $Panel/MarginContainer/VBoxContainer/TierLabel
@onready var node_health_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/NodeHealthBar
@onready var progress_bar: ProgressBar = $Panel/MarginContainer/VBoxContainer/ProgressBar
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/InfoLabel
@onready var game_container: Control = $Panel/MarginContainer/VBoxContainer/GameContainer
@onready var feedback_label: Label = $Panel/MarginContainer/VBoxContainer/FeedbackLabel
@onready var streak_label: Label = $Panel/MarginContainer/VBoxContainer/StreakLabel



func _ready() -> void:
	visible = false
	_setup_audio_players()
	_setup_game_ui()


func _setup_audio_players() -> void:
	"""Setup audio players for feedback sounds"""
	_audio_beat = AudioStreamPlayer.new()
	_audio_beat.bus = "SFX"
	add_child(_audio_beat)
	
	_audio_perfect = AudioStreamPlayer.new()
	_audio_perfect.bus = "SFX"
	add_child(_audio_perfect)
	
	_audio_good = AudioStreamPlayer.new()
	_audio_good.bus = "SFX"
	add_child(_audio_good)
	
	_audio_miss = AudioStreamPlayer.new()
	_audio_miss.bus = "SFX"
	add_child(_audio_miss)
	
	_audio_sync = AudioStreamPlayer.new()
	_audio_sync.bus = "SFX"
	add_child(_audio_sync)
	
	# Try to load audio files (silently fail if not found)
	_try_load_audio(_audio_beat, "res://assets/audio/sfx/beat_tick.wav")
	_try_load_audio(_audio_perfect, "res://assets/audio/sfx/hit_perfect.wav")
	_try_load_audio(_audio_good, "res://assets/audio/sfx/hit_good.wav")
	_try_load_audio(_audio_miss, "res://assets/audio/sfx/hit_miss.wav")
	_try_load_audio(_audio_sync, "res://assets/audio/sfx/sync_bonus.wav")


func _try_load_audio(player: AudioStreamPlayer, path: String) -> void:
	"""Try to load an audio file, silently fail if not found"""
	if ResourceLoader.exists(path):
		player.stream = load(path)


func _setup_game_ui() -> void:
	"""Setup game-specific UI containers"""
	if not game_container:
		return
	
	# Connect to game_container's draw signal for custom rendering
	game_container.draw.connect(_on_game_container_draw)


# ============================================================================
# STATUS AND EVENT HANDLERS
# ============================================================================

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
	
	# Get game type from status
	var new_game_type: StringName = data.get("harvest_game_type", &"none")
	if new_game_type != current_game_type:
		current_game_type = new_game_type
		_switch_game_ui()
	
	current_streak = int(data.get("streak", current_streak))
	last_performance = data.get("last_performance", last_performance)
	
	# Update node health for health bar
	node_remaining = float(data.get("remaining", node_remaining))
	# Get max_amount from first join or estimate from remaining
	if node_max_amount < node_remaining:
		node_max_amount = node_remaining
	
	# Start harvesting or restart progress if node changed
	if node_path != "" and (not was_harvesting or old_node_path != node_path):
		is_harvesting = true
		harvest_start_time = Time.get_ticks_msec() / 1000.0
		harvest_last_tick_time = 0.0
		harvest_tick_duration = 1.0
	
	_refresh()


func on_harvest_join(data: Dictionary) -> void:
	"""Called when player joins a harvest node - sets up game type"""
	if data.is_empty():
		return
	
	current_game_type = data.get("harvest_game_type", &"none")
	game_beat_interval = float(data.get("game_beat_interval", 1.5))
	game_config = data.get("game_config", {})
	
	# Get node health info from join response
	node_remaining = float(data.get("remaining", 100.0))
	node_max_amount = float(data.get("remaining", 100.0))  # Start with remaining as max (full node)
	
	_switch_game_ui()
	_refresh()


func on_harvest_tick() -> void:
	"""Called when harvest.tick fires - reset progress bar for new harvest attempt"""
	if is_harvesting:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if harvest_last_tick_time > 0.0:
			var measured_duration = current_time - harvest_last_tick_time
			harvest_tick_duration = lerp(harvest_tick_duration, measured_duration, 0.3)
		
		harvest_start_time = current_time
		harvest_last_tick_time = current_time
		
		if progress_bar:
			progress_bar.value = 0.0
		_refresh()


# ============================================================================
# GAME EVENT HANDLERS
# ============================================================================

func on_rhythm_beat(data: Dictionary) -> void:
	"""Handle rhythm beat event from server"""
	if current_game_type != &"rhythm":
		return
	
	last_beat_timestamp_ms = int(data.get("timestamp_ms", 0))
	last_beat_received_at_ms = Time.get_ticks_msec()  # Store when we received it locally
	game_beat_interval = float(data.get("next_beat_in", 0.7))
	next_beat_time = Time.get_ticks_msec() / 1000.0 + game_beat_interval
	beat_active = true
	
	# Store timing windows for visual display
	game_config["perfect_window_ms"] = data.get("perfect_window_ms", 150)
	game_config["good_window_ms"] = data.get("good_window_ms", 350)
	
	# Play beat sound
	if _audio_beat and _audio_beat.stream:
		_audio_beat.play()
	
	# Visual pulse effect
	_pulse_rhythm_indicator()


func on_precision_window(data: Dictionary) -> void:
	"""Handle precision window event from server"""
	if current_game_type != &"precision":
		return
	
	precision_window_active = true
	precision_window_start_time = Time.get_ticks_msec() / 1000.0
	precision_meter_value = 0.0
	precision_meter_direction = 1
	game_config = {
		"window_duration": data.get("window_duration", 3.0),
		"optimal_zone_start": data.get("optimal_zone_start", 0.45),
		"optimal_zone_end": data.get("optimal_zone_end", 0.55),
		"good_zone_start": data.get("good_zone_start", 0.35),
		"good_zone_end": data.get("good_zone_end", 0.65),
	}
	
	if _audio_beat and _audio_beat.stream:
		_audio_beat.play()


func on_aim_window(data: Dictionary) -> void:
	"""Handle aim window event from server"""
	if current_game_type != &"steady_aim":
		return
	
	aim_window_active = true
	aim_window_start_time = Time.get_ticks_msec() / 1000.0
	aim_circle_size = 1.0
	game_config = {
		"window_duration": data.get("window_duration", 2.5),
		"perfect_radius": data.get("perfect_radius", 0.15),
		"good_radius": data.get("good_radius", 0.35),
	}
	
	if _audio_beat and _audio_beat.stream:
		_audio_beat.play()


func on_game_feedback(data: Dictionary) -> void:
	"""Handle game feedback from server"""
	var performance: StringName = data.get("performance", &"miss")
	current_streak = int(data.get("streak", 0))
	
	# Update node health from feedback
	node_remaining = float(data.get("remaining", node_remaining))
	var new_max: float = float(data.get("max_amount", node_max_amount))
	if new_max > 0:
		node_max_amount = new_max
	
	# Get roll info
	var roll_chance: float = float(data.get("roll_chance", 0.0))
	var roll_value: float = float(data.get("roll_value", 0.0))
	var roll_hit: bool = data.get("roll_hit", false)
	var damage: float = float(data.get("damage", 0.0))
	
	# Get items received (if any)
	var items: Array = data.get("items", [])
	var exp: int = int(data.get("exp", 0))
	
	# Set feedback text and color
	match performance:
		&"perfect":
			if items.size() > 0:
				feedback_text = "PERFECT!"
			else:
				feedback_text = "PERFECT!"
			feedback_color = Color(0.2, 1.0, 0.4)  # Green
			if _audio_perfect and _audio_perfect.stream:
				_audio_perfect.play()
		&"good":
			if items.size() > 0:
				feedback_text = "Good! +Items"
			else:
				feedback_text = "Good"
			feedback_color = Color(1.0, 0.9, 0.2)  # Yellow
			if _audio_good and _audio_good.stream:
				_audio_good.play()
		&"miss":
			feedback_text = "Miss..."
			feedback_color = Color(1.0, 0.3, 0.3)  # Red
			if _audio_miss and _audio_miss.stream:
				_audio_miss.play()
	
	feedback_display_time = FEEDBACK_DURATION
	last_performance = performance
	
	# Spawn damage popup with roll info
	if damage > 0:
		_spawn_damage_popup(damage, performance, roll_chance, roll_value, roll_hit, items)
	
	_refresh()


func on_sync_bonus(data: Dictionary) -> void:
	"""Handle sync bonus notification"""
	sync_active = true
	sync_count = int(data.get("sync_count", 2))
	sync_bonus = float(data.get("sync_bonus", 1.2))
	sync_display_time = 2.0  # Show for 2 seconds
	
	if _audio_sync and _audio_sync.stream:
		_audio_sync.play()
	
	_refresh()


func on_node_health(data: Dictionary) -> void:
	"""Handle node health updates from server"""
	if not is_harvesting:
		return
	
	# Only update if this is for our current node
	var incoming_node: String = data.get("node", "")
	if incoming_node != "" and incoming_node != node_path:
		return
	
	node_remaining = float(data.get("remaining", node_remaining))
	var new_max: float = float(data.get("max_amount", node_max_amount))
	if new_max > 0:
		node_max_amount = new_max
	
	# Update state if depleted
	var new_state: StringName = data.get("state", state)
	if new_state == &"depleted" or new_state == &"cooldown":
		state = new_state
	
	_refresh()


func on_damage(data: Dictionary) -> void:
	"""Handle damage popup from active harvest hits"""
	var incoming_node: String = data.get("node", "")
	
	# Only show popups for our current node
	if not is_harvesting or (incoming_node != "" and incoming_node != node_path):
		return
	
	var damage: float = float(data.get("damage", 0.0))
	var performance: StringName = data.get("performance", &"passive")
	
	if damage <= 0:
		return
	
	# Update node health immediately
	node_remaining = float(data.get("remaining", node_remaining))
	var new_max: float = float(data.get("max_amount", node_max_amount))
	if new_max > 0:
		node_max_amount = new_max
	
	_refresh()


# ============================================================================
# INPUT HANDLING
# ============================================================================

func handle_game_input() -> Dictionary:
	"""Called by local_player when Space is pressed during harvesting"""
	if current_game_type == &"none":
		return {}
	
	var now_ms: int = Time.get_ticks_msec()
	
	var input_data: Dictionary = {
		"timestamp_ms": now_ms,
		"game_type": current_game_type,
	}
	
	match current_game_type:
		&"rhythm":
			# Send offset from beat (how many ms after receiving the beat we pressed)
			var offset_from_beat_ms: int = now_ms - last_beat_received_at_ms
			input_data["offset_from_beat_ms"] = offset_from_beat_ms
		&"precision":
			input_data["release_position"] = precision_meter_value
			precision_is_holding = false
		&"steady_aim":
			input_data["aim_radius"] = aim_circle_size
	
	return input_data


func start_precision_hold() -> void:
	"""Start holding for precision game"""
	if current_game_type == &"precision" and precision_window_active:
		precision_is_holding = true


func release_precision_hold() -> Dictionary:
	"""Release hold for precision game, returns input data"""
	if current_game_type == &"precision" and precision_is_holding:
		precision_is_holding = false
		return {
			"timestamp_ms": Time.get_ticks_msec(),
			"game_type": &"precision",
			"release_position": precision_meter_value,
		}
	return {}


# ============================================================================
# PROCESS AND RENDERING
# ============================================================================

func _process(delta: float) -> void:
	# Update feedback display timer
	if feedback_display_time > 0:
		feedback_display_time -= delta
		if feedback_display_time <= 0:
			feedback_text = ""
	
	# Update sync display timer
	if sync_display_time > 0:
		sync_display_time -= delta
		if sync_display_time <= 0:
			sync_active = false
	
	# Update progress bar smoothly
	if is_harvesting and visible and progress_bar:
		var elapsed = Time.get_ticks_msec() / 1000.0 - harvest_start_time
		var progress = clampf(elapsed / harvest_tick_duration, 0.0, 1.0)
		progress_bar.value = progress * 100.0
	
	# Update game-specific elements
	_update_game_visuals(delta)
	
	# Trigger visual updates for game container
	if game_container and game_container.visible:
		game_container.queue_redraw()
	
	# Always update position when visible
	if visible:
		_update_position()


func _update_game_visuals(delta: float) -> void:
	"""Update game-specific visual elements"""
	match current_game_type:
		&"rhythm":
			_update_rhythm_visual(delta)
		&"precision":
			_update_precision_visual(delta)
		&"steady_aim":
			_update_aim_visual(delta)


func _update_rhythm_visual(_delta: float) -> void:
	"""Update rhythm game visual (beat indicator pulse)"""
	pass  # Drawing is handled by _on_game_container_draw


func _update_precision_visual(delta: float) -> void:
	"""Update precision game visual (oscillating meter)"""
	if not precision_window_active:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var window_duration = float(game_config.get("window_duration", 3.0))
	var elapsed = current_time - precision_window_start_time
	
	# Window expired
	if elapsed >= window_duration:
		precision_window_active = false
		return
	
	# Oscillate meter value (0 to 1 and back)
	var oscillation_speed = 2.0  # Full cycle per second
	precision_meter_value += delta * oscillation_speed * precision_meter_direction
	
	if precision_meter_value >= 1.0:
		precision_meter_value = 1.0
		precision_meter_direction = -1
	elif precision_meter_value <= 0.0:
		precision_meter_value = 0.0
		precision_meter_direction = 1


func _update_aim_visual(_delta: float) -> void:
	"""Update steady aim visual (shrinking circle)"""
	if not aim_window_active:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var window_duration = float(game_config.get("window_duration", 2.5))
	var elapsed = current_time - aim_window_start_time
	
	# Window expired
	if elapsed >= window_duration:
		aim_window_active = false
		return
	
	# Shrink circle from 1.0 to 0.0
	aim_circle_size = 1.0 - (elapsed / window_duration)


func _pulse_rhythm_indicator() -> void:
	"""Trigger visual pulse on rhythm beat"""
	# The pulse is now handled in the draw function based on beat_active state
	if game_container:
		game_container.queue_redraw()


func _switch_game_ui() -> void:
	"""Switch visible game UI based on current game type"""
	if game_container:
		game_container.queue_redraw()


func _update_position() -> void:
	"""Position the panel below the player (in world space)"""
	var camera_zoom: float = 1.0
	var viewport: Viewport = get_viewport()
	if viewport:
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			camera_zoom = camera.zoom.x
	
	scale = Vector2.ONE / camera_zoom
	
	if get_parent():
		var parent_pos: Vector2 = get_parent().global_position
		var panel_node = get_node_or_null("Panel")
		var actual_width: float = panel_node.size.x if panel_node else 0
		var scaled_half_width: float = (actual_width / 2.0) * scale.x
		
		# Position below player (positive y is down)
		var y_offset: float = 40  # Below the player sprite
		
		global_position = parent_pos + Vector2(-scaled_half_width, y_offset)


func _spawn_damage_popup(
	damage: float,
	performance: StringName,
	roll_chance: float,
	roll_value: float,
	roll_hit: bool,
	items: Array
) -> void:
	"""Spawn separate damage and roll popups with stacking"""
	var panel_node = get_node_or_null("Panel")
	var panel_width: float = panel_node.size.x if panel_node else 200.0
	var center_x: float = panel_width / 2.0
	
	# =========================================================================
	# POPUP 1: DAMAGE (left side)
	# =========================================================================
	var dmg_text: String = "-%.1f" % damage
	var dmg_color: Color
	var dmg_scale: float
	var dmg_effect: StringName
	
	match performance:
		&"perfect":
			dmg_color = Color(0.4, 1.0, 0.6)  # Bright green
			dmg_scale = 1.4
			dmg_effect = &"wave"
		&"good":
			dmg_color = Color(1.0, 0.95, 0.3)  # Yellow
			dmg_scale = 1.15
			dmg_effect = &"wave"
		&"miss":
			dmg_color = Color(1.0, 0.5, 0.5)  # Red
			dmg_scale = 0.9
			dmg_effect = &"shake"
		_:
			dmg_color = Color(0.6, 0.6, 0.6)  # Gray
			dmg_scale = 0.7
			dmg_effect = &"none"
	
	# Spawn damage popup (left side) - CHAOTIC!
	var dmg_popup = DamagePopupScene.instantiate()
	dmg_popup.text = dmg_text
	dmg_popup.popup_color = dmg_color
	dmg_popup.position = Vector2(center_x + randf_range(-70, -20), randf_range(-35, -15))
	dmg_popup.start_scale = dmg_scale
	dmg_popup.effect_type = dmg_effect
	dmg_popup.rise_speed = randf_range(30.0, 50.0)  # Random rise speed
	dmg_popup.lifetime = randf_range(0.9, 1.3)
	dmg_popup.drift_direction = randf_range(-1.5, -0.5)  # Drift left
	add_child(dmg_popup)
	
	# =========================================================================
	# POPUP 2: ROLL RESULT (right side, rises faster)
	# =========================================================================
	var chance_pct: int = int(roll_chance * 100)
	var roll_text: String
	var roll_color: Color
	var roll_scale: float
	var roll_effect: StringName
	
	if performance == &"perfect":
		# Perfect is always a crit
		roll_text = "CRIT!"
		roll_color = Color(1.0, 0.85, 0.2)  # Gold
		roll_scale = 1.6
		roll_effect = &"rainbow"
	elif roll_hit:
		# Successful roll
		roll_text = "%d%% → Hit!" % chance_pct
		roll_color = Color(0.3, 1.0, 0.5)  # Green
		roll_scale = 1.3
		roll_effect = &"wave"
	else:
		# Failed roll
		roll_text = "%d%% → Miss" % chance_pct
		roll_color = Color(0.8, 0.4, 0.4)  # Dim red
		roll_scale = 1.0
		roll_effect = &"shake"
	
	# Spawn roll popup (right side) - CHAOTIC!
	var roll_popup = DamagePopupScene.instantiate()
	roll_popup.text = roll_text
	roll_popup.popup_color = roll_color
	roll_popup.position = Vector2(center_x + randf_range(20, 70), randf_range(-40, -10))
	roll_popup.start_scale = roll_scale
	roll_popup.effect_type = roll_effect
	roll_popup.rise_speed = randf_range(40.0, 65.0)  # Faster rise
	roll_popup.lifetime = randf_range(1.0, 1.4)
	roll_popup.drift_direction = randf_range(0.5, 1.5)  # Drift right
	add_child(roll_popup)




# ============================================================================
# REFRESH AND DISPLAY
# ============================================================================

func reset() -> void:
	node_path = ""
	count = 0
	multiplier = 1.0
	state = &""
	pool = 0.0
	earned_total = 0.0
	harvesting_total = 0
	next_progress = 0.0
	tier = 1
	node_type = &""
	required_class = &""
	required_level = 1
	last_error = ""
	is_harvesting = false
	harvest_start_time = 0.0
	
	# Reset node health
	node_remaining = 100.0
	node_max_amount = 100.0
	
	# Reset game state
	current_game_type = &"none"
	current_streak = 0
	last_performance = &"passive"
	beat_active = false
	last_beat_received_at_ms = 0
	precision_window_active = false
	aim_window_active = false
	sync_active = false
	feedback_text = ""
	
	visible = false
	_switch_game_ui()
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
		if node_health_bar:
			node_health_bar.visible = false
		if info_label:
			info_label.visible = false
		if progress_bar:
			progress_bar.visible = false
		if game_container:
			game_container.visible = false
		if feedback_label:
			feedback_label.visible = false
		if streak_label:
			streak_label.visible = false
	elif node_path != "" and is_harvesting:
		visible = true
		
		var node_display = _get_node_display_name(node_type)
		
		if tier_label:
			tier_label.text = "Tier %d %s" % [tier, node_display]
		
		# Update node health bar
		if node_health_bar:
			node_health_bar.visible = true
			node_health_bar.max_value = node_max_amount
			# Animate progress bar value change
			if has_node("/root/UIAnimations"):
				get_node("/root/UIAnimations").animate_bar_fill(node_health_bar, node_remaining)
			else:
				node_health_bar.value = node_remaining
			# Color based on health percentage
			var health_pct: float = node_remaining / max(node_max_amount, 1.0)
			var bar_style = StyleBoxFlat.new()
			if health_pct > 0.66:
				bar_style.bg_color = Color(0.3, 0.85, 0.4)  # Green
			elif health_pct > 0.33:
				bar_style.bg_color = Color(0.95, 0.8, 0.2)  # Yellow
			else:
				bar_style.bg_color = Color(0.95, 0.3, 0.3)  # Red
			bar_style.corner_radius_top_left = 2
			bar_style.corner_radius_top_right = 2
			bar_style.corner_radius_bottom_left = 2
			bar_style.corner_radius_bottom_right = 2
			node_health_bar.add_theme_stylebox_override("fill", bar_style)
			# Background style
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
			bg_style.corner_radius_top_left = 2
			bg_style.corner_radius_top_right = 2
			bg_style.corner_radius_bottom_left = 2
			bg_style.corner_radius_bottom_right = 2
			node_health_bar.add_theme_stylebox_override("background", bg_style)
		
		if progress_bar:
			progress_bar.visible = false  # Hide old progress bar, we use node health bar now
		
		# Update info label with player count and game prompt
		if info_label:
			info_label.visible = true
			var game_prompt: String = _get_game_prompt()
			if game_prompt != "":
				info_label.text = "%d Player%s • %s" % [
					count,
					"s" if count != 1 else "",
					game_prompt
				]
			else:
				info_label.text = "%d Player%s • Passive Mode" % [
					count,
					"s" if count != 1 else "",
				]
		
		# Show game container for active games
		if game_container:
			game_container.visible = (current_game_type != &"none")
		
		# Update feedback label
		if feedback_label:
			if feedback_text != "":
				feedback_label.visible = true
				feedback_label.text = feedback_text
				feedback_label.add_theme_color_override("font_color", feedback_color)
			elif sync_active:
				feedback_label.visible = true
				feedback_label.text = "SYNC x%d! (%.1fx)" % [sync_count, sync_bonus]
				feedback_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			else:
				feedback_label.visible = false
		
		# Update streak label
		if streak_label:
			if current_streak > 0 and current_game_type != &"none":
				streak_label.visible = true
				streak_label.text = "Streak: %d" % current_streak
			else:
				streak_label.visible = false
	else:
		visible = false


func _get_game_prompt() -> String:
	"""Get the input prompt for current game type"""
	match current_game_type:
		&"rhythm":
			return "Press SPACE on beat!"
		&"precision":
			if precision_window_active:
				return "HOLD & RELEASE in zone!"
			return "Wait for window..."
		&"steady_aim":
			if aim_window_active:
				return "Press SPACE when small!"
			return "Wait for target..."
		_:
			return ""


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


# ============================================================================
# CUSTOM DRAWING FOR GAME UI
# ============================================================================

func _on_game_container_draw() -> void:
	"""Draw game-specific visuals in the game container"""
	if not game_container or current_game_type == &"none":
		return
	
	match current_game_type:
		&"rhythm":
			_draw_rhythm_game()
		&"precision":
			_draw_precision_game()
		&"steady_aim":
			_draw_aim_game()


func _draw_rhythm_game() -> void:
	"""Draw rhythm beat indicator - pulse expands outward from center when you should hit"""
	var rect = game_container.get_rect()
	var center_y = rect.size.y / 2
	var width = rect.size.x
	var center_x = width / 2
	
	# Get timing windows from config
	var perfect_ms: float = float(game_config.get("perfect_window_ms", 150))
	var good_ms: float = float(game_config.get("good_window_ms", 350))
	
	# Fixed zone widths for visual clarity
	var perfect_half_width: float = 25.0
	var good_half_width: float = 55.0
	
	# Draw timeline bar
	game_container.draw_rect(Rect2(0, center_y - 2, width, 4), Color(0.3, 0.3, 0.3))
	
	# Draw GOOD zone (yellow) - outer zone
	game_container.draw_rect(
		Rect2(center_x - good_half_width, center_y - 18, good_half_width * 2, 36),
		Color(0.85, 0.75, 0.2, 0.4)
	)
	
	# Draw PERFECT zone (green) - inner zone  
	game_container.draw_rect(
		Rect2(center_x - perfect_half_width, center_y - 18, perfect_half_width * 2, 36),
		Color(0.3, 0.8, 0.4, 0.5)
	)
	
	# Draw expanding ring when beat is active (hit NOW!)
	if beat_active:
		# Time since beat was received
		var time_since_beat_ms: float = float(Time.get_ticks_msec() - last_beat_received_at_ms)
		
		# Ring expands outward over the good window time
		var expand_progress: float = clampf(time_since_beat_ms / good_ms, 0.0, 1.0)
		
		# Determine what zone we're in based on time
		var in_perfect: bool = time_since_beat_ms <= perfect_ms
		var in_good: bool = time_since_beat_ms <= good_ms
		
		if in_good:
			# Draw expanding ring
			var ring_radius: float = 8.0 + expand_progress * 50.0
			var ring_alpha: float = 1.0 - expand_progress * 0.7
			
			var ring_color: Color
			if in_perfect:
				ring_color = Color(0.3, 1.0, 0.5, ring_alpha)  # Green - PERFECT zone!
			else:
				ring_color = Color(1.0, 0.9, 0.3, ring_alpha)  # Yellow - GOOD zone
			
			# Draw ring
			game_container.draw_arc(Vector2(center_x, center_y), ring_radius, 0, TAU, 32, ring_color, 4.0)
			
			# Draw solid center circle
			var center_color: Color
			if in_perfect:
				center_color = Color(0.4, 1.0, 0.6, 0.9)
			else:
				center_color = Color(1.0, 0.85, 0.3, 0.7)
			game_container.draw_circle(Vector2(center_x, center_y), 12.0, center_color)
		else:
			# Window expired - beat missed
			beat_active = false
	else:
		# No active beat - draw dim center target
		game_container.draw_circle(Vector2(center_x, center_y), 8.0, Color(0.5, 0.5, 0.5, 0.5))
	
	# Draw center crosshair
	game_container.draw_line(
		Vector2(center_x, center_y - 22),
		Vector2(center_x, center_y + 22),
		Color(1.0, 1.0, 1.0, 0.6),
		1.0
	)


func _draw_precision_game() -> void:
	"""Draw precision meter with zones"""
	var rect = game_container.get_rect()
	var bar_height = 24.0
	var y_offset = (rect.size.y - bar_height) / 2
	var width = rect.size.x
	
	# Draw background
	game_container.draw_rect(Rect2(0, y_offset, width, bar_height), Color(0.2, 0.2, 0.2))
	
	# Get zone config
	var optimal_start = float(game_config.get("optimal_zone_start", 0.45))
	var optimal_end = float(game_config.get("optimal_zone_end", 0.55))
	var good_start = float(game_config.get("good_zone_start", 0.35))
	var good_end = float(game_config.get("good_zone_end", 0.65))
	
	# Draw miss zones (red edges)
	game_container.draw_rect(Rect2(0, y_offset, good_start * width, bar_height), Color(0.6, 0.2, 0.2))
	game_container.draw_rect(Rect2(good_end * width, y_offset, (1.0 - good_end) * width, bar_height), Color(0.6, 0.2, 0.2))
	
	# Draw good zones (yellow)
	game_container.draw_rect(Rect2(good_start * width, y_offset, (optimal_start - good_start) * width, bar_height), Color(0.8, 0.7, 0.2))
	game_container.draw_rect(Rect2(optimal_end * width, y_offset, (good_end - optimal_end) * width, bar_height), Color(0.8, 0.7, 0.2))
	
	# Draw optimal zone (green)
	game_container.draw_rect(Rect2(optimal_start * width, y_offset, (optimal_end - optimal_start) * width, bar_height), Color(0.2, 0.8, 0.3))
	
	# Draw current position indicator
	if precision_window_active:
		var indicator_x = precision_meter_value * width
		var indicator_color = Color.WHITE if not precision_is_holding else Color(1.0, 1.0, 0.5)
		game_container.draw_rect(Rect2(indicator_x - 3, y_offset - 4, 6, bar_height + 8), indicator_color)


func _draw_aim_game() -> void:
	"""Draw shrinking aim circle with color-coded feedback"""
	var rect = game_container.get_rect()
	var center = Vector2(rect.size.x / 2, rect.size.y / 2)
	var max_radius = min(rect.size.x, rect.size.y) / 2 - 5
	
	var perfect_radius = float(game_config.get("perfect_radius", 0.15))
	var good_radius = float(game_config.get("good_radius", 0.35))
	
	# Draw target zones (static background)
	# Miss zone (outer - red tinted)
	game_container.draw_circle(center, max_radius, Color(0.5, 0.2, 0.2, 0.3))
	
	# Good zone (yellow)
	game_container.draw_circle(center, max_radius * good_radius, Color(0.8, 0.7, 0.2, 0.5))
	
	# Perfect zone (green)
	game_container.draw_circle(center, max_radius * perfect_radius, Color(0.2, 0.8, 0.3, 0.7))
	
	# Draw center dot
	game_container.draw_circle(center, 4, Color.WHITE)
	
	# Draw shrinking circle if window active - COLOR CODED based on current position
	if aim_window_active:
		var current_radius = aim_circle_size * max_radius
		
		# Determine circle color based on current size
		var circle_color: Color
		if aim_circle_size <= perfect_radius:
			# In perfect zone - bright green
			circle_color = Color(0.3, 1.0, 0.4, 1.0)
		elif aim_circle_size <= good_radius:
			# In good zone - yellow
			circle_color = Color(1.0, 0.9, 0.2, 1.0)
		else:
			# In miss zone - red
			circle_color = Color(1.0, 0.3, 0.3, 1.0)
		
		# Draw the shrinking circle with dynamic color
		game_container.draw_arc(center, current_radius, 0, TAU, 32, circle_color, 4.0)
		
		# Add a pulsing glow effect when in perfect zone
		if aim_circle_size <= perfect_radius:
			var glow_color = Color(0.3, 1.0, 0.4, 0.3)
			game_container.draw_arc(center, current_radius + 3, 0, TAU, 32, glow_color, 2.0)
