class_name HarvestNode
extends Node2D


@export var node_type: StringName = &"ore"
@export var radius: float = 64.0
@export var base_yield_per_sec: float = 1.0
@export var max_amount: float = 100.0
@export var cooldown_seconds: float = 300.0
@export var max_move_during_tick: float = 1.0
@export var energy_cost_per_sec: float = 5.0 / 30.0

## Class/Level restriction fields
@export var required_class: StringName = &"" ## Empty = any class, or &"miner"/&"forager"/&"trapper"
@export var required_level: int = 1 ## Minimum level required to harvest
@export var tier: int = 1 ## Tier for display (1-6)

## Loot table for drops (if null, uses legacy ITEM_BY_NODE_TYPE)
@export var loot_table: HarvestLootTable = null

# ============================================================================
# HARVEST GAME CONFIGURATION CONSTANTS
# ============================================================================

# Yield multipliers based on performance
const PASSIVE_YIELD_MULT: float = 0.25
const PERFECT_YIELD_MULT: float = 2.0
const GOOD_YIELD_MULT: float = 1.3
const MISS_YIELD_MULT: float = 0.5

# Energy cost multipliers
const PASSIVE_ENERGY_MULT: float = 0.5
const ACTIVE_NORMAL_ENERGY_MULT: float = 1.0
const MISS_ENERGY_PENALTY_MULT: float = 2.5

# Sync bonuses when multiple players hit together
const SYNC_BONUS_2_PLAYERS: float = 1.2
const SYNC_BONUS_3_PLUS: float = 1.5
const SYNC_WINDOW_MS: int = 300  # ±300ms for synchronized hits

# Game timing configurations per class
const GAME_CONFIGS: Dictionary = {
	&"rhythm": {  # Miner - fast beats with clear zones
		"beat_interval": 0.7,  # Fast! Every 0.7 seconds
		"perfect_window_ms": 150,  # Tight perfect zone
		"good_window_ms": 350,  # Generous good zone
	},
	&"precision": {  # Collector/Forager
		"window_duration": 2.5,  # Slightly faster
		"optimal_zone_start": 0.42,
		"optimal_zone_end": 0.58,
		"good_zone_start": 0.30,
		"good_zone_end": 0.70,
	},
	&"steady_aim": {  # Trapper - faster shrinking
		"window_duration": 1.8,  # Faster! (was 2.5)
		"perfect_radius": 0.18,  # Slightly bigger (was 0.15)
		"good_radius": 0.40,  # Slightly bigger (was 0.35)
	}
}

# ============================================================================
# NODE STATE
# ============================================================================

var harvesters: Dictionary[int, Dictionary] = {}
var multiplier: float = 1.0
var _clock: float = 0.0
var _tick_interval: float = 1.0
var _tick_accum: float = 0.0
var _status_interval: float = 1.0
var _status_accum: float = 0.0

var remaining_amount: float = 0.0
var pool_amount: float = 0.0
var state: StringName = &"full" # full | partial | depleted | cooldown
var _cooldown_clock: float = 0.0

# ============================================================================
# HARVEST GAME STATE
# ============================================================================

var harvest_game_type: StringName = &"none"  # "rhythm", "precision", "steady_aim", "none"
var game_beat_interval: float = 1.5
var game_clock: float = 0.0
var game_last_event_time: float = 0.0
var game_current_beat_id: int = 0  # Unique ID for each beat/window

# Track synchronized hits within current beat window
var sync_window_hits: Array[Dictionary] = []  # [{peer_id: int, timestamp_ms: int, performance: StringName}]
var last_sync_bonus_applied: float = 1.0

const ITEM_BY_NODE_TYPE := {
	&"ore": &"ore",
	&"plant": &"plant_fiber",
	&"hunting": &"hide",
	# NEW: Add all harvestable items
	&"copper_ore": &"copper_ore",
	&"iron_ore": &"iron_ore",
	&"coal": &"coal",
	&"stone": &"stone",
	&"clay": &"clay",
	&"wood": &"wood",
	&"berries": &"berries",
	&"mushrooms": &"mushrooms",
	&"herbs": &"herbs",
	&"olives": &"olives",
	&"apples": &"apples",
	&"wheat": &"wheat",
	&"animal_feces": &"animal_feces",
	&"quality_honey": &"quality_honey",
	&"raw_meat": &"raw_meat",
	&"bone": &"bone",
	&"feathers": &"feathers",
	&"sinew": &"sinew",
}


func _ready() -> void:
	add_to_group(&"harvest_nodes")
	remaining_amount = max(remaining_amount, max_amount)
	_update_state()
	_determine_game_type()
	
	# Register with HarvestManager (server only)
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance and instance.harvest_manager:
		instance.harvest_manager.register_node(self)
	
	# Setup floating shader and health bar on client side
	_setup_floating_shader()
	
	# Enable processing on client for health bar timer
	if not multiplayer.is_server():
		set_process(true)


func _determine_game_type() -> void:
	"""Determine harvest game type based on required_class"""
	match required_class:
		&"miner":
			harvest_game_type = &"rhythm"
			game_beat_interval = GAME_CONFIGS[&"rhythm"]["beat_interval"]
		&"forager", &"collector":
			harvest_game_type = &"precision"
			game_beat_interval = GAME_CONFIGS[&"precision"]["window_duration"]
		&"trapper":
			harvest_game_type = &"steady_aim"
			game_beat_interval = GAME_CONFIGS[&"steady_aim"]["window_duration"]
		_:
			harvest_game_type = &"none"
			game_beat_interval = 1.5


func _setup_floating_shader() -> void:
	"""Setup floating animation shader for Class_Signal sprite on client side only"""
	if multiplayer.is_server():
		return  # Only setup on client
	
	var signal_sprite: Sprite2D = get_node_or_null("Class_Signal")
	if not signal_sprite:
		return  # Class_Signal node doesn't exist
	
	var shader: Shader = load("res://source/client/shaders/floating_signal.gdshader")
	if not shader:
		return
	
	var shader_material: ShaderMaterial = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set shader parameters
	shader_material.set_shader_parameter("float_speed", 1.5)
	shader_material.set_shader_parameter("float_amplitude", 8.0)
	shader_material.set_shader_parameter("time_offset", randf() * TAU)  # Randomize timing
	
	# Apply shader to sprite
	signal_sprite.material = shader_material
	
	# Setup health bar for client
	_setup_client_health_bar()



func _setup_client_health_bar() -> void:
	"""Client-side health bar is now handled by HarvestingPanel"""
	pass




func _broadcast_harvest_event(event_name: StringName, data: Dictionary, to_harvesters_only: bool = false) -> void:
	"""Send harvest event only to nearby players (AOI filtering) or just harvesters"""
	var instance_server: ServerInstance = _get_instance()
	if instance_server == null:
		return
	
	# If to_harvesters_only, just send to current harvesters (for node-specific events)
	if to_harvesters_only:
		for peer_id in harvesters.keys():
			instance_server.data_push.rpc_id(peer_id, event_name, data)
		return
	
	# Otherwise, use spatial filtering for all nearby players
	var my_pos: Vector2 = global_position
	const HARVEST_VIEW_DISTANCE: float = 1500.0  # Match AOI distance
	
	for peer_id in instance_server.connected_peers:
		var player: Player = instance_server.players_by_peer_id.get(peer_id)
		if player == null:
			continue
		
		# Only send to nearby players
		if my_pos.distance_squared_to(player.global_position) <= HARVEST_VIEW_DISTANCE * HARVEST_VIEW_DISTANCE:
			instance_server.data_push.rpc_id(peer_id, event_name, data)


func _get_instance() -> ServerInstance:
	"""Helper to get the ServerInstance"""
	return get_viewport() as ServerInstance


func _exit_tree() -> void:
	# Unregister from HarvestManager (server)
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance and instance.harvest_manager:
		instance.harvest_manager.unregister_node(self)


func _process(delta: float) -> void:
	# Client-side: nothing to do
	if not multiplayer.is_server():
		return
	
	_clock += delta
	game_clock += delta
	
	# Handle cooldown lifecycle
	if state == &"cooldown":
		_cooldown_clock += delta
		if _cooldown_clock >= cooldown_seconds:
			remaining_amount = max_amount
			pool_amount = 0.0
			_cooldown_clock = 0.0
			_update_state()
			_broadcast_status()
		return

	# Tick harvesting when active and has harvesters
	if harvesters.size() > 0 and (state == &"full" or state == &"partial"):
		_tick_accum += delta
		_status_accum += delta
		
		# Generate game events (beats/windows) for active harvest games
		_generate_game_events()
		
		while _tick_accum >= _tick_interval:
			_tick_accum -= _tick_interval
			var count: int = get_count()
			multiplier = compute_multiplier(count)
			var base_rate: float = base_yield_per_sec * multiplier
			var ids: Array = harvesters.keys().duplicate()
			
			for pid_any in ids:
				var pid: int = int(pid_any)
				var h: Dictionary = harvesters.get(pid, {})
				var player: Player = _get_player(pid)
				if player == null:
					continue
				
				# Stop if the player moved since last tick (must stand still)
				var last_pos: Vector2 = h.get("last_pos", player.global_position)
				if player.global_position.distance_to(last_pos) > max_move_during_tick:
					player_leave(pid)
					continue
				
				# Calculate performance-based multipliers
				var performance: StringName = h.get("last_performance", &"passive")
				var yield_mult: float = _get_yield_multiplier(performance)
				var energy_mult: float = _get_energy_multiplier(performance)
				
				# Apply sync bonus if player participated in sync
				var sync_bonus: float = h.get("sync_bonus", 1.0)
				yield_mult *= sync_bonus
				
				# Pay energy cost (modified by performance)
				var asc: AbilitySystemComponent = player.get_node_or_null(^"AbilitySystemComponent")
				if asc != null:
					var energy_cost: float = energy_cost_per_sec * energy_mult
					var paid: bool = asc.try_pay_costs({&"energy": energy_cost}, {&"reason": &"harvest"})
					if not paid:
						player_leave(pid)
						continue
				
				# Calculate produce with performance multiplier
				var produce: float = base_rate * yield_mult
				if remaining_amount <= 0.0:
					produce = 0.0
				else:
					produce = min(produce, remaining_amount)
				remaining_amount -= produce
				
				# Reset performance for next tick (player must actively participate each tick)
				h["last_performance"] = &"passive"
				h["sync_bonus"] = 1.0
				
				# Immediate distribution with fractional accumulation
				var harvest_pool: float = float(h.get("harvest_pool", 0.0)) + produce
				h["harvest_pool"] = harvest_pool
				
				# When we have at least 1 full harvest, distribute immediately
				if harvest_pool >= 1.0:
					var harvest_count: int = int(floor(harvest_pool))
					harvest_pool -= float(harvest_count)
					h["harvest_pool"] = harvest_pool
					
					# Roll loot for this player's harvests
					var total_items: Dictionary = {}
					var instance_tick: ServerInstance = get_viewport() as ServerInstance
					
					for _i in range(harvest_count):
						# Send harvest.tick for EACH individual roll attempt to the harvester
						if instance_tick != null:
							instance_tick.data_push.rpc_id(pid, &"harvest.tick", {
								"node": String(get_path()),
							})
						
						var rolled_loot: Dictionary
						if loot_table != null:
							rolled_loot = loot_table.roll_loot()
						else:
							# Legacy behavior
							var slug: StringName = ITEM_BY_NODE_TYPE.get(node_type, &"ore")
							rolled_loot = {slug: 1}
						
						# Accumulate rolled items
						for item_slug in rolled_loot.keys():
							var qty: int = int(rolled_loot[item_slug])
							total_items[item_slug] = int(total_items.get(item_slug, 0)) + qty
					
					# Give items immediately
					if total_items.size() > 0:
						var instance: ServerInstance = get_viewport() as ServerInstance
						if instance == null:
							continue
							
						var items_array: Array = []
						var total_item_count: int = 0  # Count all items for EXP
						for item_slug in total_items.keys():
							var qty: int = int(total_items[item_slug])
							if qty > 0:
								if instance.give_item(pid, item_slug, qty):
									items_array.append({"slug": item_slug, "amount": qty})
									total_item_count += qty  # Add to total
						
						# Calculate and award EXP based on items received
						var exp_gained: int = 0
						if total_item_count > 0:
							exp_gained = _award_exp_for_items(pid, total_item_count, instance)
						
						# Send immediate notification with EXP info
						if items_array.size() > 0:
							instance.data_push.rpc_id(pid, &"harvest.item_received", {
								"node": String(get_path()),
								"items": items_array,
								"exp_gained": exp_gained
							})
							
							# Track title progress for harvesting
							if TitleProgressTracker.instance:
								var player_node: Player = instance.get_player(pid)
								if player_node and player_node.player_resource:
									var player_data: WorldPlayerData = instance.world_server.database.player_data
									var account_name: String = player_node.player_resource.account_name
									
									# Track harvest by node class
									var node_class: String = String(required_class)
									if not node_class.is_empty():
										# Convert forager to collector for title display
										if node_class == "forager":
											node_class = "collector"
										
										# Count total items harvested from this node
										var total_qty: int = 0
										for item_slug in total_items.keys():
											total_qty += int(total_items[item_slug])
										
										if total_qty > 0:
											TitleProgressTracker.instance.increment_progress(account_name, "harvests_%s" % node_class, total_qty, player_data, pid, instance)
									
									# Track party participation (if 2+ players)
									if harvesters.size() >= 2:
										TitleProgressTracker.instance.increment_progress(account_name, "parties_joined", 1, player_data, pid, instance)
									
									# Check for harvest-related title unlocks
									TitleProgressTracker.instance.check_and_unlock(account_name, TitleResource.ConditionType.HARVEST_COUNT, pid, instance)
									TitleProgressTracker.instance.check_and_unlock(account_name, TitleResource.ConditionType.PARTY_COUNT, pid, instance)
							
							# Update earned total for UI display
							h["earned_total"] = float(h.get("earned_total", 0.0)) + float(harvest_count)
				
				h["accum_time"] = float(h.get("accum_time", 0.0)) + 1.0
				h["joined_at"] = float(h.get("joined_at", _clock))
				h["last_pos"] = player.global_position
				harvesters[pid] = h
				
				# If node is depleted, stop everyone and enter cooldown
				if remaining_amount <= 0.0:
					_on_depleted()
					break
			_update_state()
			if state == &"cooldown":
				break
		if _status_accum >= _status_interval:
			_status_accum = 0.0
			_broadcast_status()


# ============================================================================
# HARVEST GAME EVENT GENERATION
# ============================================================================

func _generate_game_events() -> void:
	"""Generate game events (beats/windows) for active harvest games"""
	if harvest_game_type == &"none":
		return
	
	if harvesters.size() == 0:
		return
	
	# Check if it's time for a new game event
	if game_clock - game_last_event_time >= game_beat_interval:
		game_last_event_time = game_clock
		game_current_beat_id += 1
		
		# Clear previous sync window hits
		sync_window_hits.clear()
		
		match harvest_game_type:
			&"rhythm":
				_broadcast_rhythm_beat()
			&"precision":
				_broadcast_precision_window()
			&"steady_aim":
				_broadcast_aim_window()


func _broadcast_rhythm_beat() -> void:
	"""Send rhythm beat event to all harvesters"""
	var config: Dictionary = GAME_CONFIGS[&"rhythm"]
	_broadcast_harvest_event(&"harvest.rhythm.beat", {
		"node": String(get_path()),
		"beat_id": game_current_beat_id,
		"timestamp_ms": int(game_clock * 1000),
		"perfect_window_ms": config["perfect_window_ms"],
		"good_window_ms": config["good_window_ms"],
		"next_beat_in": game_beat_interval,
	}, true)


func _broadcast_precision_window() -> void:
	"""Send precision window event to all harvesters"""
	var config: Dictionary = GAME_CONFIGS[&"precision"]
	_broadcast_harvest_event(&"harvest.precision.window", {
		"node": String(get_path()),
		"beat_id": game_current_beat_id,
		"timestamp_ms": int(game_clock * 1000),
		"window_duration": config["window_duration"],
		"optimal_zone_start": config["optimal_zone_start"],
		"optimal_zone_end": config["optimal_zone_end"],
		"good_zone_start": config["good_zone_start"],
		"good_zone_end": config["good_zone_end"],
	}, true)


func _broadcast_aim_window() -> void:
	"""Send steady aim window event to all harvesters"""
	var config: Dictionary = GAME_CONFIGS[&"steady_aim"]
	_broadcast_harvest_event(&"harvest.aim.window", {
		"node": String(get_path()),
		"beat_id": game_current_beat_id,
		"timestamp_ms": int(game_clock * 1000),
		"window_duration": config["window_duration"],
		"perfect_radius": config["perfect_radius"],
		"good_radius": config["good_radius"],
	}, true)


# ============================================================================
# HARVEST GAME INPUT HANDLING
# ============================================================================

func handle_harvest_game_input(peer_id: int, input_data: Dictionary) -> Dictionary:
	"""Handle player input for harvest game - returns performance feedback"""
	if not multiplayer.is_server():
		return {"ok": false, "err": &"not_server"}
	
	if not harvesters.has(peer_id):
		return {"ok": false, "err": &"not_harvesting"}
	
	var h: Dictionary = harvesters.get(peer_id, {})
	var client_timestamp_ms: int = int(input_data.get("timestamp_ms", 0))
	var input_game_type: StringName = input_data.get("game_type", &"")
	
	# Validate game type matches
	if input_game_type != harvest_game_type:
		return {"ok": false, "err": &"wrong_game_type"}
	
	# Calculate performance based on game type
	var performance: StringName = &"miss"
	var timing_offset_ms: int = 0
	
	match harvest_game_type:
		&"rhythm":
			var offset_from_beat: int = int(input_data.get("offset_from_beat_ms", 9999))
			var result: Dictionary = _evaluate_rhythm_input(offset_from_beat)
			performance = result["performance"]
			timing_offset_ms = result["offset_ms"]
		&"precision":
			var release_position: float = float(input_data.get("release_position", 0.5))
			performance = _evaluate_precision_input(release_position)
		&"steady_aim":
			var aim_radius: float = float(input_data.get("aim_radius", 1.0))
			performance = _evaluate_aim_input(aim_radius)
	
	# Update harvester state with performance
	h["last_performance"] = performance
	
	# Update streak
	var current_streak: int = int(h.get("rhythm_streak", 0))
	if performance == &"miss":
		current_streak = 0
	else:
		current_streak += 1
	h["rhythm_streak"] = current_streak
	
	# Track hit for synchronization detection
	if performance != &"miss":
		sync_window_hits.append({
			"peer_id": peer_id,
			"timestamp_ms": client_timestamp_ms,
			"performance": performance,
		})
		
		# Check for synchronized hits and apply bonus
		_check_and_apply_sync_bonus()
	
	harvesters[peer_id] = h
	
	# Get instance for broadcasting
	var instance: ServerInstance = _get_instance()
	
	# Calculate damage based on performance
	var yield_mult: float = _get_yield_multiplier(performance)
	var base_damage: float = base_yield_per_sec * yield_mult * (1.0 + current_streak * 0.05)  # 5% bonus per streak
	var damage_dealt: float = minf(base_damage, remaining_amount)
	
	# Apply damage to node
	var old_remaining: float = remaining_amount
	remaining_amount = maxf(0.0, remaining_amount - damage_dealt)
	var actual_damage: float = old_remaining - remaining_amount
	
	# Roll for loot - every successful roll = guaranteed loot
	var items_given: Array[Dictionary] = []
	var exp_gained: int = 0
	var roll_chance: float = 0.0  # The chance % shown to player
	var roll_value: float = 0.0   # The actual dice roll (lower = better)
	var roll_hit: bool = false    # Did the roll succeed?
	
	if actual_damage > 0 and instance != null:
		var player: Player = instance.get_player(peer_id)
		if player:
			# Calculate loot chance based on performance
			match performance:
				&"perfect":
					roll_chance = 1.0  # 100% - always hits
				&"good":
					roll_chance = 0.65  # 65% chance
				&"miss":
					roll_chance = 0.15  # 15% chance (low but possible)
				_:
					roll_chance = 0.25  # Passive: 25%
			
			# Roll the dice!
			roll_value = randf()
			roll_hit = roll_value <= roll_chance
			
			# Every hit = guaranteed loot
			if roll_hit:
				var items_to_give: int = 1
				
				# Perfect can give bonus items
				if performance == &"perfect" and randf() < 0.3:
					items_to_give += 1
				
				# Get and give loot
				var loot_items: Dictionary = _get_loot_items(items_to_give)
				for item_slug: StringName in loot_items:
					var qty: int = int(loot_items[item_slug])
					if qty > 0 and instance.give_item(peer_id, item_slug, qty):
						items_given.append({"slug": item_slug, "amount": qty})
				
				# Award EXP for items received
				if items_given.size() > 0:
					exp_gained = _award_exp_for_items(peer_id, items_to_give, instance)
					
					# Send item notification popup (same as passive harvesting)
					instance.data_push.rpc_id(peer_id, &"harvest.item_received", {
						"node": String(get_path()),
						"items": items_given,
						"exp_gained": exp_gained
					})
	
	# Check for depletion
	if remaining_amount <= 0:
		_on_depleted()
	
	# Send feedback to player with damage info
	var feedback_data: Dictionary = {
		"node": String(get_path()),
		"performance": performance,
		"streak": current_streak,
		"timing_offset_ms": timing_offset_ms,
		"yield_mult": yield_mult,
		"damage": actual_damage,
		"remaining": remaining_amount,
		"max_amount": max_amount,
		"items": items_given,
		"exp": exp_gained,
		# Roll info for visual feedback
		"roll_chance": roll_chance,
		"roll_value": roll_value,
		"roll_hit": roll_hit,
	}
	
	if instance != null:
		instance.data_push.rpc_id(peer_id, &"harvest.game.feedback", feedback_data)
		
		# Broadcast damage to all nearby players for visual feedback
		var damage_data: Dictionary = {
			"node": String(get_path()),
			"damage": actual_damage,
			"performance": performance,
			"remaining": remaining_amount,
			"max_amount": max_amount,
			"peer_id": peer_id,
		}
		_broadcast_harvest_event(&"harvest.damage", damage_data, false)
	
	return {
		"ok": true,
		"performance": performance,
		"streak": current_streak,
	}


func _evaluate_rhythm_input(offset_from_beat_ms: int) -> Dictionary:
	"""Evaluate rhythm input timing and return performance"""
	var config: Dictionary = GAME_CONFIGS[&"rhythm"]
	var perfect_window: int = int(config["perfect_window_ms"])
	var good_window: int = int(config["good_window_ms"])
	
	# The offset is how many ms after the beat the player pressed
	# Ideal timing is right when beat happens (offset ~0)
	# But we also allow hitting slightly early (negative offset not possible with current impl)
	var offset_ms: int = abs(offset_from_beat_ms)
	
	var performance: StringName = &"miss"
	if offset_ms <= perfect_window:
		performance = &"perfect"
	elif offset_ms <= good_window:
		performance = &"good"
	
	return {
		"performance": performance,
		"offset_ms": offset_from_beat_ms,
	}


func _evaluate_precision_input(release_position: float) -> StringName:
	"""Evaluate precision release position and return performance"""
	var config: Dictionary = GAME_CONFIGS[&"precision"]
	var optimal_start: float = config["optimal_zone_start"]
	var optimal_end: float = config["optimal_zone_end"]
	var good_start: float = config["good_zone_start"]
	var good_end: float = config["good_zone_end"]
	
	if release_position >= optimal_start and release_position <= optimal_end:
		return &"perfect"
	elif release_position >= good_start and release_position <= good_end:
		return &"good"
	return &"miss"


func _evaluate_aim_input(aim_radius: float) -> StringName:
	"""Evaluate steady aim radius and return performance"""
	var config: Dictionary = GAME_CONFIGS[&"steady_aim"]
	var perfect_radius: float = config["perfect_radius"]
	var good_radius: float = config["good_radius"]
	
	if aim_radius <= perfect_radius:
		return &"perfect"
	elif aim_radius <= good_radius:
		return &"good"
	return &"miss"


func _check_and_apply_sync_bonus() -> void:
	"""Check if multiple players hit within sync window and apply bonus"""
	if sync_window_hits.size() < 2:
		return
	
	# Group hits by timestamp proximity
	var synced_peers: Array[int] = []
	for i in range(sync_window_hits.size()):
		var hit_i: Dictionary = sync_window_hits[i]
		var peer_i: int = int(hit_i["peer_id"])
		if peer_i in synced_peers:
			continue
		
		var sync_group: Array[int] = [peer_i]
		for j in range(i + 1, sync_window_hits.size()):
			var hit_j: Dictionary = sync_window_hits[j]
			var peer_j: int = int(hit_j["peer_id"])
			if peer_j in synced_peers:
				continue
			
			var time_diff: int = abs(int(hit_i["timestamp_ms"]) - int(hit_j["timestamp_ms"]))
			if time_diff <= SYNC_WINDOW_MS:
				sync_group.append(peer_j)
		
		# Apply sync bonus if 2+ players in sync
		if sync_group.size() >= 2:
			var sync_bonus: float = SYNC_BONUS_2_PLAYERS if sync_group.size() == 2 else SYNC_BONUS_3_PLUS
			
			for pid in sync_group:
				if harvesters.has(pid):
					var h: Dictionary = harvesters[pid]
					h["sync_bonus"] = sync_bonus
					harvesters[pid] = h
				synced_peers.append(pid)
			
			# Broadcast sync event to all participants
			var instance: ServerInstance = _get_instance()
			if instance != null:
				for pid in sync_group:
					instance.data_push.rpc_id(pid, &"harvest.game.sync", {
						"node": String(get_path()),
						"sync_count": sync_group.size(),
						"sync_bonus": sync_bonus,
						"synced_peers": sync_group,
					})


func _get_loot_items(count: int) -> Dictionary:
	"""Get items from loot table (or legacy fallback)"""
	var result: Dictionary = {}
	for _i in range(count):
		var rolled: Dictionary
		if loot_table != null:
			rolled = loot_table.roll_loot()
		else:
			# Legacy behavior
			var slug: StringName = ITEM_BY_NODE_TYPE.get(node_type, &"ore")
			rolled = {slug: 1}
		
		for item_slug in rolled.keys():
			var qty: int = int(rolled[item_slug])
			result[item_slug] = int(result.get(item_slug, 0)) + qty
	
	return result


func _get_yield_multiplier(performance: StringName) -> float:
	"""Get yield multiplier based on performance"""
	match performance:
		&"perfect":
			return PERFECT_YIELD_MULT
		&"good":
			return GOOD_YIELD_MULT
		&"miss":
			return MISS_YIELD_MULT
		_:  # passive
			return PASSIVE_YIELD_MULT


func _get_energy_multiplier(performance: StringName) -> float:
	"""Get energy cost multiplier based on performance"""
	match performance:
		&"perfect", &"good":
			return ACTIVE_NORMAL_ENERGY_MULT
		&"miss":
			return MISS_ENERGY_PENALTY_MULT
		_:  # passive
			return PASSIVE_ENERGY_MULT


# ============================================================================
# PLAYER JOIN/LEAVE
# ============================================================================

func player_in_range(player: Player) -> bool:
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= radius


func get_count() -> int:
	return harvesters.size()


func compute_multiplier(count: int) -> float:
	if count <= 1:
		return 1.0
	elif count == 2:
		return 1.1
	elif count == 3:
		return 1.2
	elif count == 4:
		return 1.3
	else:
		return 1.5


func _update_state() -> void:
	if remaining_amount <= 0.0:
		if state != &"cooldown":
			state = &"depleted"
		return
	var ratio: float = remaining_amount / max(1.0, max_amount)
	if ratio > 0.66:
		state = &"full"
	elif ratio > 0.0:
		state = &"partial"
	else:
		state = &"depleted"


func player_join(peer_id: int, player: Player) -> Dictionary:
	if not multiplayer.is_server():
		return {"ok": false, "err": &"not_server"}
	
	# Check class restriction
	if not required_class.is_empty():
		var player_class: String = player.player_resource.character_class if player.player_resource else ""
		if player_class != required_class:
			return {"ok": false, "err": &"wrong_class", "required_class": required_class}
	
	# Check level restriction
	var player_level: int = player.player_resource.level if player.player_resource else 1
	if player_level < required_level:
		return {"ok": false, "err": &"level_too_low", "required_level": required_level, "player_level": player_level}
	
	if not (state == &"full" or state == &"partial"):
		return {"ok": false, "err": &"node_depleted"}
	if not player_in_range(player):
		return {"ok": false, "err": &"out_of_range"}
	if harvesters.has(peer_id):
		return {"ok": true, "already_joined": true}
	
	# Initialize harvester with game state
	harvesters[peer_id] = {
		"joined_at": _clock,
		"accum_time": 0.0,
		"last_pos": player.global_position,
		"earned_total": 0.0,
		"harvest_pool": 0.0,
		"last_performance": &"passive",
		"rhythm_streak": 0,
		"sync_bonus": 1.0,
	}
	
	# Enable processing when first harvester joins
	if harvesters.size() == 1:
		set_process(true)
		# Reset game clock so first beat comes after interval
		game_last_event_time = game_clock
	
	multiplier = compute_multiplier(get_count())
	_broadcast({
		"type": &"joined",
		"node": String(get_path()),
		"peer": peer_id,
		"count": get_count(),
		"multiplier": multiplier,
	})
	_broadcast_status()
	return {"ok": true}


func player_leave(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not harvesters.has(peer_id):
		return false
	
	# No need to distribute pool since we're doing immediate distribution
	# Just notify and remove
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance != null:
		instance.data_push.rpc_id(peer_id, &"harvest.event", {
			"type": &"left",
			"node": String(get_path()),
			"peer": peer_id,
			"count": max(0, get_count() - 1),
			"multiplier": compute_multiplier(max(0, get_count() - 1)),
		})
		
		# Notify harvest manager to remove from active_harvesters
		if instance.harvest_manager:
			instance.harvest_manager.active_harvesters.erase(peer_id)
	
	harvesters.erase(peer_id)
	
	# Disable processing when last harvester leaves (but keep enabled during cooldown)
	if harvesters.size() == 0 and state != &"cooldown":
		set_process(false)
	
	multiplier = compute_multiplier(get_count())
	_broadcast({
		"type": &"left",
		"node": String(get_path()),
		"peer": peer_id,
		"count": get_count(),
		"multiplier": multiplier,
	})
	_broadcast_status()
	return true


func cleanup_peer(peer_id: int) -> void:
	if harvesters.has(peer_id):
		player_leave(peer_id)


func _broadcast(payload: Dictionary) -> void:
	# Use spatial filtering to broadcast events to nearby players
	_broadcast_harvest_event(&"harvest.event", payload, false)


func _broadcast_status() -> void:
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return
	var pool_int: int = int(floor(pool_amount))
	var total_time: float = 0.0
	var pid_list: Array[int] = []
	for pid_any in harvesters.keys():
		var pid_i: int = int(pid_any)
		pid_list.append(pid_i)
		var h_all: Dictionary = harvesters.get(pid_i, {})
		total_time += float(h_all.get("accum_time", 0.0))
	# Build largest-remainder integer preview shares
	var shares: Dictionary[int, int] = {}
	var remainders: Array = [] # [{pid:int, rem:float}]
	var sum_base: int = 0
	if pool_int > 0 and total_time > 0.0:
		for pid_p in pid_list:
			var h_p: Dictionary = harvesters.get(pid_p, {})
			var t_p: float = float(h_p.get("accum_time", 0.0))
			if t_p <= 0.0:
				shares[pid_p] = 0
				continue
			var quota: float = float(pool_int) * (t_p / total_time)
			var base_share: int = int(floor(quota))
			var rem: float = quota - float(base_share)
			shares[pid_p] = base_share
			sum_base += base_share
			remainders.append({"pid": pid_p, "rem": rem})
		var leftover: int = pool_int - sum_base
		if leftover > 0 and remainders.size() > 0:
			remainders.sort_custom(func(a, b): return a["rem"] > b["rem"]) # desc by remainder
			for i in range(min(leftover, remainders.size())):
				var pid_extra: int = int(remainders[i]["pid"])
				shares[pid_extra] = int(shares.get(pid_extra, 0)) + 1
	else:
		for pid_zero in pid_list:
			shares[pid_zero] = 0
	# Send per-peer payloads to harvesters
	for pid: int in pid_list:
		var h: Dictionary = harvesters.get(pid, {})
		var earned_total: int = int(h.get("earned_total", 0))
		var my_share_int: int = int(shares.get(pid, 0))
		var projected_total_int: int = earned_total + my_share_int
		# For a potential progress bar, compute own remainder (optional)
		var next_progress: float = 0.0
		if pool_int > 0 and total_time > 0.0:
			var t_self: float = float(h.get("accum_time", 0.0))
			var quota_self: float = float(pool_int) * (t_self / total_time)
			next_progress = quota_self - floor(quota_self)
		var payload: Dictionary = {
			"node": String(get_path()),
			"count": get_count(),
			"multiplier": multiplier,
			"state": state,
			"remaining": remaining_amount,
			"pool": pool_amount,
			"earned_total": earned_total,
			"projected_total_int": projected_total_int,
			"next_progress": next_progress,
			"tier": tier,
			"node_type": String(node_type),
			# Add harvest game info
			"harvest_game_type": harvest_game_type,
			"streak": int(h.get("rhythm_streak", 0)),
			"last_performance": h.get("last_performance", &"passive"),
		}
		instance.data_push.rpc_id(pid, &"harvest.status", payload)
	
	# Broadcast node health to ALL nearby players (for health bar display)
	_broadcast_node_health()


func _broadcast_node_health() -> void:
	"""Broadcast node health/remaining amount to all nearby players for health bar display"""
	var instance: ServerInstance = _get_instance()
	if instance == null:
		return
	
	var health_data: Dictionary = {
		"node": String(get_path()),
		"remaining": remaining_amount,
		"max_amount": max_amount,
		"state": state,
		"harvester_count": harvesters.size(),
	}
	
	# Send to all nearby players (not just harvesters)
	_broadcast_harvest_event(&"harvest.node_health", health_data, false)


func _get_player(peer_id: int) -> Player:
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return null
	return instance.get_player(peer_id)


func _on_depleted() -> void:
	# Transition to cooldown, stop all harvesters, and notify
	state = &"cooldown"
	_cooldown_clock = 0.0
	pool_amount = 0.0  # Reset pool
	
	# Keep processing enabled for cooldown countdown
	set_process(true)
	
	var ids: Array = harvesters.keys().duplicate()
	for pid_any in ids:
		player_leave(int(pid_any))
	_broadcast_status()


func _distribute(reason: StringName) -> void:
	# DEPRECATED: No longer used with immediate distribution system
	# Kept for backward compatibility but does nothing
	pass


func _calculate_exp_per_item() -> int:
	# Tier-based EXP per item: T1=5, T2=10, T3=15, T4=20, T5=25, T6=30
	return tier * 5


func _award_exp_for_items(player_id: int, item_count: int, instance: ServerInstance) -> int:
	var player: Player = _get_player(player_id)
	if not player or not player.player_resource:
		return 0
	
	var pr: PlayerResource = player.player_resource
	if pr.level >= PlayerResource.MAX_LEVEL:
		return 0
	
	# Calculate total EXP (exp per item * number of items)
	var exp_per_item = _calculate_exp_per_item()
	var total_exp = exp_per_item * item_count
	
	pr.experience += total_exp
	
	# Check for level-ups (can level up multiple times)
	var leveled_up = false
	while pr.can_level_up():
		var old_level = pr.level
		pr.level_up()
		leveled_up = true
		print("Player %s leveled up: %d -> %d" % [pr.display_name, old_level, pr.level])

	if leveled_up and player:
		var asc: AbilitySystemComponent = player.ability_system_component
		if asc:
			var new_energy_max: float = pr.get_energy_max()
			asc.set_max_server(&"energy", new_energy_max, true)
			asc.set_value_server(&"energy", new_energy_max)
	
	# Notify client of exp gain (separate from harvest notification)
	instance.data_push.rpc_id(player_id, &"exp.update", {
		"exp": pr.experience,
		"level": pr.level,
		"exp_required": pr.get_exp_required(),
		"leveled_up": leveled_up
	})
	
	return total_exp
