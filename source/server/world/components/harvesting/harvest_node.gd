class_name HarvestNode
extends Node2D


@export var node_type: StringName = &"ore"
@export var radius: float = 64.0
@export var base_yield_per_sec: float = 1.0
@export var max_amount: float = 100.0
@export var cooldown_seconds: float = 300.0
@export var max_move_during_tick: float = 1.0
@export var energy_cost_per_sec: float = 5.0 / 30.0


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


func _ready() -> void:
	add_to_group(&"harvest_nodes")
	remaining_amount = max(remaining_amount, max_amount)
	_update_state()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_clock += delta
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
				var asc: AbilitySystemComponent = player.get_node_or_null(^"AbilitySystemComponent")
				if asc != null:
					# Use resource system so regen pauses during harvesting
					var paid: bool = asc.try_pay_costs({&"energy": energy_cost_per_sec}, {&"reason": &"harvest"})
					if not paid:
						player_leave(pid)
						continue
				var produce: float = base_rate
				if remaining_amount <= 0.0:
					produce = 0.0
				else:
					produce = min(produce, remaining_amount)
				remaining_amount -= produce
				pool_amount += produce
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


func player_join(peer_id: int, player: Player) -> bool:
	if not multiplayer.is_server():
		return false
	if not (state == &"full" or state == &"partial"):
		return false
	if not player_in_range(player):
		return false
	if harvesters.has(peer_id):
		return true
	harvesters[peer_id] = {"joined_at": _clock, "accum_time": 0.0, "last_pos": player.global_position}
	multiplier = compute_multiplier(get_count())
	_broadcast({
		"type": &"joined",
		"node": String(get_path()),
		"peer": peer_id,
		"count": get_count(),
		"multiplier": multiplier,
	})
	_broadcast_status()
	return true


func player_leave(peer_id: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not harvesters.has(peer_id):
		return false
	var h: Dictionary = harvesters[peer_id]
	var joined_at: float = float(h.get("joined_at", _clock))
	h["accum_time"] = float(h.get("accum_time", 0.0)) + (_clock - joined_at)
	harvesters.erase(peer_id)
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
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return
	for pid: int in harvesters.keys():
		instance.data_push.rpc_id(pid, &"harvest.event", payload)

func _broadcast_status() -> void:
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return
	var payload: Dictionary = {
		"node": String(get_path()),
		"count": get_count(),
		"multiplier": multiplier,
		"state": state,
		"remaining": remaining_amount,
		"pool": pool_amount,
	}
	for pid: int in harvesters.keys():
		instance.data_push.rpc_id(pid, &"harvest.status", payload)

func _get_player(peer_id: int) -> Player:
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return null
	return instance.get_player(peer_id)

func _on_depleted() -> void:
	# Transition to cooldown, stop all harvesters, and notify
	state = &"cooldown"
	_cooldown_clock = 0.0
	var ids: Array = harvesters.keys().duplicate()
	for pid_any in ids:
		player_leave(int(pid_any))
	_broadcast_status()
