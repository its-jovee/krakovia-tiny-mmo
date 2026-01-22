@tool
@icon("res://assets/node_icons/blue/icon_grid.png")
extends InteractionArea
class_name WorkerArea
## Hired Worker NPC that players can pay to gather resources over time.
## Each worker type (miner, forager, trapper) uses existing tier-based loot tables.

## Worker type determines which loot tables to use
@export_enum("miner", "forager", "trapper") var worker_type: String = "miner":
	set(value):
		worker_type = value
		_update_label()
		if Engine.is_editor_hint():
			update_configuration_warnings()

## Unique identifier for this worker (used by BotManager)
@export var worker_id: String = "":
	set(value):
		worker_id = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

## Display name shown to players
@export var worker_name: String = "Hired Worker":
	set(value):
		worker_name = value
		_update_label()

## Icon/emoji for UI display
@export var worker_icon: String = "⛏️"

## Description/personality blurb for the UI
@export_multiline var worker_description: String = "A skilled worker ready to gather resources for you."

# Bot entity ID when the worker is spawned as a walking bot
var _bot_entity_id: int = 0

# Tier configuration - base costs before burnout multiplier
const TIER_BASE_COSTS: Array[int] = [200, 500, 1000, 2000, 4000, 8000]

# Tier durations in seconds
const TIER_DURATIONS: Array[int] = [600, 1200, 1800, 2700, 3600, 5400]  # 10, 20, 30, 45, 60, 90 minutes

# Number of loot rolls per tier
const TIER_LOOT_ROLLS: Array[int] = [10, 15, 20, 30, 40, 60]

# Cached loot tables per tier
var _loot_tables: Dictionary = {}  # tier -> HarvestLootTable

# Track players currently at this worker
var players_at_worker: Array[Player] = []

# Client-side visual indicator state
var _current_job_remaining: float = 0.0  # Seconds remaining for active job
var _has_completed_job: bool = false
var _timer_label: Label = null
var _exclamation_mark: Label = null
var _last_timer_update: int = -1  # Track last displayed second to avoid flickering


func _ready() -> void:
	# Connect to parent's signals
	player_entered_interaction_area.connect(_on_player_entered_worker)
	player_exited_interaction_area.connect(_on_player_exited_worker)
	
	# Update label with worker name and icon
	_update_label()
	
	# Preload loot tables (server only)
	if not Engine.is_editor_hint():
		_load_loot_tables()
	
	# Get visual indicator references
	_exclamation_mark = get_node_or_null("ExclamationMark")
	_timer_label = get_node_or_null("TimerLabel")
	
	# Create timer label if it doesn't exist
	if not _timer_label and not Engine.is_editor_hint():
		_timer_label = Label.new()
		_timer_label.name = "TimerLabel"
		_timer_label.visible = false
		_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_timer_label.position = Vector2(-30, -75)
		_timer_label.size = Vector2(60, 20)
		_timer_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
		_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_timer_label.add_theme_constant_override("outline_size", 3)
		_timer_label.add_theme_font_size_override("font_size", 11)
		add_child(_timer_label)
	
	# Subscribe to worker status updates on client
	if not Engine.is_editor_hint() and _is_client():
		InstanceClient.subscribe(&"worker.status", _on_worker_status_update)
		# Request initial status after a short delay (wait for connection)
		get_tree().create_timer(1.0).timeout.connect(_request_initial_status)
	
	if not Engine.is_editor_hint():
		print("[WorkerArea] %s (%s) ready" % [worker_name, worker_type])


func _request_initial_status() -> void:
	"""Request initial worker status from server"""
	if _is_client() and InstanceClient.current:
		InstanceClient.current.request_data(&"worker.status", _on_status_response, {"worker_type": worker_type})


func _on_status_response(data: Dictionary) -> void:
	"""Handle response from worker.status request"""
	if data.has("status"):
		var status = data.get("status", {})
		status["worker_type"] = worker_type
		_on_worker_status_update(status)


var _anim_time: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_anim_time += delta
	
	# Update timer display on client
	if _is_client() and _current_job_remaining > 0:
		_current_job_remaining -= delta
		if _current_job_remaining <= 0:
			_current_job_remaining = 0.0
			# Job might be complete, but wait for server confirmation
		
		# Only update display when second changes
		var current_second = int(_current_job_remaining)
		if current_second != _last_timer_update:
			_last_timer_update = current_second
			_update_timer_display()
	
	# Animate exclamation mark (bounce effect)
	if _exclamation_mark and _exclamation_mark.visible:
		var bounce = sin(_anim_time * 4.0) * 3.0
		_exclamation_mark.position.y = -85.0 + bounce


func _is_client() -> bool:
	"""Check if we're running on client (not dedicated server)"""
	return ClassDB.class_exists(&"InstanceClient") and InstanceClient.current != null


func _on_worker_status_update(data: Dictionary) -> void:
	"""Handle worker status updates from server"""
	if data.get("worker_type", "") != worker_type:
		return
	
	var active_jobs = data.get("active_jobs", [])
	var completed_jobs = data.get("completed_jobs", [])
	
	# Update visual state
	_has_completed_job = completed_jobs.size() > 0
	
	# Get remaining time from first active job
	if active_jobs.size() > 0:
		_current_job_remaining = float(active_jobs[0].get("remaining", 0))
		_last_timer_update = -1  # Force display update
	else:
		_current_job_remaining = 0.0
	
	_update_visual_indicators()


func _update_visual_indicators() -> void:
	"""Update the exclamation mark and timer visibility"""
	# Show exclamation mark if job is complete
	if _exclamation_mark:
		_exclamation_mark.visible = _has_completed_job
	
	# Show timer if job is in progress
	if _timer_label:
		_timer_label.visible = _current_job_remaining > 0 and not _has_completed_job
		if _timer_label.visible:
			_update_timer_display()


func _update_timer_display() -> void:
	"""Update the timer label text"""
	if not _timer_label:
		return
	
	var total_seconds = int(_current_job_remaining)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	_timer_label.text = "⏱️ %d:%02d" % [minutes, seconds]


func _update_label() -> void:
	var label = get_node_or_null("Label")
	if label and label is Label:
		label.text = "%s %s" % [worker_icon, worker_name]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if worker_type.is_empty():
		warnings.append("worker_type must be set (miner, forager, or trapper)")
	if worker_id.is_empty():
		warnings.append("worker_id should be set for BotManager integration (e.g., 'town_miner')")
	return warnings


func _load_loot_tables() -> void:
	"""Load all tier loot tables for this worker type"""
	for tier in range(1, 7):
		var path = "res://source/server/world/components/harvesting/loot_tables/%s_t%d_loot_table.tres" % [worker_type, tier]
		var table = load(path)
		if table:
			_loot_tables[tier] = table
		else:
			push_warning("[WorkerArea] Could not load loot table: %s" % path)


func _on_player_entered_worker(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters worker area"""
	print("[WorkerArea] Player %s entered %s" % [player.name, worker_name])
	if player not in players_at_worker:
		players_at_worker.append(player)
	# Pause bot wandering when a player enters
	_notify_bot_interaction(true, player.global_position)


func _on_player_exited_worker(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits worker area"""
	print("[WorkerArea] Player %s exited %s" % [player.name, worker_name])
	players_at_worker.erase(player)
	# Resume bot wandering if no players left
	if players_at_worker.is_empty():
		_notify_bot_interaction(false, Vector2.ZERO)


func _notify_bot_interaction(interacting: bool, player_pos: Vector2) -> void:
	"""Tell the worker bot to pause or resume wandering"""
	if worker_id.is_empty():
		return
	var bot_mgr = _get_bot_manager()
	if not bot_mgr:
		return
	if interacting:
		if bot_mgr.has_method("pause_worker_for_interaction"):
			bot_mgr.pause_worker_for_interaction(worker_id, player_pos)
	else:
		if bot_mgr.has_method("resume_worker_wandering"):
			bot_mgr.resume_worker_wandering(worker_id)


## Get base cost for a tier (before burnout)
func get_base_cost(tier: int) -> int:
	if tier < 1 or tier > 6:
		return 0
	return TIER_BASE_COSTS[tier - 1]


## Get duration for a tier in seconds
func get_duration(tier: int) -> int:
	if tier < 1 or tier > 6:
		return 0
	return TIER_DURATIONS[tier - 1]


## Get number of loot rolls for a tier
func get_loot_rolls(tier: int) -> int:
	if tier < 1 or tier > 6:
		return 0
	return TIER_LOOT_ROLLS[tier - 1]


## Roll loot for a completed job
## Returns dictionary of {item_slug: quantity}
func roll_loot(tier: int) -> Dictionary:
	var result: Dictionary = {}
	
	if not _loot_tables.has(tier):
		push_error("[WorkerArea] No loot table for tier %d" % tier)
		return result
	
	var table: HarvestLootTable = _loot_tables[tier]
	var rolls = get_loot_rolls(tier)
	
	# Roll the loot table multiple times
	for i in range(rolls):
		var roll_result = table.roll_loot()
		for item_slug in roll_result.keys():
			result[item_slug] = result.get(item_slug, 0) + roll_result[item_slug]
	
	return result


## Get worker info for client UI
func get_worker_info() -> Dictionary:
	var tiers: Array[Dictionary] = []
	for tier in range(1, 7):
		tiers.append({
			"tier": tier,
			"base_cost": get_base_cost(tier),
			"duration": get_duration(tier),
			"rolls": get_loot_rolls(tier)
		})
	
	return {
		"type": worker_type,
		"name": worker_name,
		"icon": worker_icon,
		"description": worker_description,
		"tiers": tiers
	}


## Get worker status for a specific player
func get_player_status(player_resource: PlayerResource) -> Dictionary:
	var now = int(Time.get_unix_time_from_system())
	
	# Get active jobs for this worker
	var active_jobs: Array[Dictionary] = []
	var completed_jobs: Array[Dictionary] = []
	
	for job in player_resource.worker_jobs:
		if job.get("worker_type") != worker_type:
			continue
		
		var end_time = job.get("start_time", 0) + job.get("duration_seconds", 0)
		var remaining = maxi(0, end_time - now)
		
		var job_info = {
			"tier": job.get("tier", 1),
			"start_time": job.get("start_time", 0),
			"duration": job.get("duration_seconds", 0),
			"remaining": remaining,
			"completed": remaining == 0
		}
		
		if remaining == 0:
			completed_jobs.append(job_info)
		else:
			active_jobs.append(job_info)
	
	# Get burnout info
	var burnout_info = player_resource.get_worker_burnout(worker_type)
	var burnout_reset = player_resource.get_burnout_reset_time(worker_type)
	
	# Calculate current costs for each tier
	var tier_costs: Array[int] = []
	for tier in range(1, 7):
		var cost = player_resource.calculate_worker_cost(worker_type, get_base_cost(tier))
		tier_costs.append(cost)
	
	return {
		"active_jobs": active_jobs,
		"completed_jobs": completed_jobs,
		"hire_count": burnout_info.get("hire_count", 0),
		"burnout_reset_seconds": burnout_reset,
		"current_costs": tier_costs
	}


# === BOT MANAGER INTEGRATION ===


## Called by instance_server to spawn the worker bot
func spawn_worker_bot() -> void:
	if worker_id.is_empty():
		# Generate an ID if not set
		worker_id = "%s_%s" % [worker_type, name.to_lower().replace(" ", "_")]

	var bot_mgr: Node = _get_bot_manager()
	if bot_mgr and bot_mgr.has_method("spawn_worker_bot"):
		_bot_entity_id = bot_mgr.spawn_worker_bot(self)
		print("[WorkerArea] Spawned worker bot for %s (entity %d)" % [worker_name, _bot_entity_id])

		# Hide the static visual since the bot is now the visual representation
		if _bot_entity_id != 0:
			_hide_static_visual()


## Hide the static worker visual and label (the bot replaces them)
func _hide_static_visual() -> void:
	var worker_visual = get_node_or_null("WorkerVisual")
	if worker_visual:
		worker_visual.visible = false

	var label = get_node_or_null("Label")
	if label:
		label.visible = false


## Notify BotManager that this worker has been hired (should leave)
func notify_worker_hired() -> void:
	if worker_id.is_empty():
		return

	var bot_mgr: Node = _get_bot_manager()
	if bot_mgr and bot_mgr.has_method("set_worker_busy"):
		bot_mgr.set_worker_busy(worker_id, true)
		print("[WorkerArea] Worker %s is now busy (hired)" % worker_name)


## Notify BotManager that this worker's job is complete (should return)
func notify_worker_job_complete() -> void:
	if worker_id.is_empty():
		return

	var bot_mgr: Node = _get_bot_manager()
	if bot_mgr and bot_mgr.has_method("set_worker_busy"):
		bot_mgr.set_worker_busy(worker_id, false)
		print("[WorkerArea] Worker %s job complete (returning)" % worker_name)


## Get reference to BotManager (only works on server)
func _get_bot_manager() -> Node:
	# Walk up to find ServerInstance
	var node: Node = self
	while node:
		if node is SubViewport and node.has_node("BotManager"):
			return node.get_node("BotManager")
		node = node.get_parent()
	return null
