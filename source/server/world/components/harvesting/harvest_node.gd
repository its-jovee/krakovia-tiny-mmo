class_name HarvestNode
extends Node2D


@export var node_type: StringName = &"ore"
@export var radius: float = 64.0
@export var base_yield_per_sec: float = 1.0
@export var max_amount: float = 100.0
@export var cooldown_seconds: float = 300.0
@export var max_move_during_tick: float = 1.0
@export var energy_cost_per_sec: float = 5.0 / 30.0
@export var encourage_session_window: float = 10.0
@export var encourage_cooldown: float = 10.0
@export var encourage_bonus_pct: float = 0.25
@export var encourage_max_stacks: int = 5
@export var encourage_max_total_bonus_pct: float = 1.0


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
var _enc_session_active: bool = false
var _enc_session_expires_at: float = 0.0
var _enc_session_contributors: Dictionary[int, bool] = {}
var _enc_session_stack_count: int = 0
var _enc_session_cum_bonus_pct: float = 0.0
var _encourage_cd_until: Dictionary[int, float] = {}

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
	
	# Register with HarvestManager
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance and instance.harvest_manager:
		instance.harvest_manager.register_node(self)
	
	# Start with _process disabled since no one is harvesting yet
	set_process(false)


func _exit_tree() -> void:
	# Unregister from HarvestManager
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance and instance.harvest_manager:
		instance.harvest_manager.unregister_node(self)


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
		# Expire encourage session
		if _enc_session_active and _clock >= _enc_session_expires_at:
			# Broadcast session end
			var instance_end: ServerInstance = get_viewport() as ServerInstance
			if instance_end != null:
				for pid_end: int in harvesters.keys():
					instance_end.data_push.rpc_id(pid_end, &"harvest.encourage.end", {
						"node": String(get_path()),
						"stacks": _enc_session_stack_count,
						"total_bonus_pct": _enc_session_cum_bonus_pct,
					})
			_enc_session_active = false
			_enc_session_contributors.clear()
			_enc_session_stack_count = 0
			_enc_session_cum_bonus_pct = 0.0
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
	harvesters[peer_id] = {"joined_at": _clock, "accum_time": 0.0, "last_pos": player.global_position, "earned_total": 0.0}
	
	# Enable processing when first harvester joins
	if harvesters.size() == 1:
		set_process(true)
	
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
	# Include the leaver in distribution if there is something to distribute
	if pool_amount > 0.0:
		_distribute(&"leave")
	# Notify the leaver as well so their client can update HUD
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance != null:
		instance.data_push.rpc_id(peer_id, &"harvest.event", {
			"type": &"left",
			"node": String(get_path()),
			"peer": peer_id,
			"count": max(0, get_count() - 1),
			"multiplier": compute_multiplier(max(0, get_count() - 1)),
		})
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
	_encourage_cd_until.erase(peer_id)
	if _enc_session_active:
		_enc_session_contributors.erase(peer_id)


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
	# Send per-peer payloads
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
		}
		instance.data_push.rpc_id(pid, &"harvest.status", payload)

func _get_player(peer_id: int) -> Player:
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return null
	return instance.get_player(peer_id)

func _on_depleted() -> void:
	# Transition to cooldown, stop all harvesters, and notify
	if pool_amount > 0.0:
		_distribute(&"depleted")
	state = &"cooldown"
	_cooldown_clock = 0.0
	
	# Keep processing enabled for cooldown countdown
	set_process(true)
	
	var ids: Array = harvesters.keys().duplicate()
	for pid_any in ids:
		# notify leaving after distribution
		player_leave(int(pid_any))
		_encourage_cd_until.erase(int(pid_any))
		if _enc_session_active:
			_enc_session_contributors.erase(int(pid_any))
	_broadcast_status()

func _distribute(reason: StringName) -> void:
	if pool_amount <= 0.0:
		return
	if harvesters.size() == 0:
		return
	var instance: ServerInstance = get_viewport() as ServerInstance
	if instance == null:
		return
	# Sum of times
	var total_time: float = 0.0
	for pid_any in harvesters.keys():
		var pid: int = int(pid_any)
		var h: Dictionary = harvesters.get(pid, {})
		total_time += float(h.get("accum_time", 0.0))
	if total_time <= 0.0:
		return
	# Integer shares by largest remainder method; carry fractional remainder forward
	var slug: StringName = ITEM_BY_NODE_TYPE.get(node_type, &"ore")
	var pool_int: int = int(floor(pool_amount))
	var pool_frac: float = pool_amount - float(pool_int)
	if pool_int <= 0:
		return # keep fractional pool for next session
	# Build quotas
	var allocations: Array = [] # [{pid, base:int, rem:float}]
	var sum_base: int = 0
	for pid_any2 in harvesters.keys():
		var pid2: int = int(pid_any2)
		var h2: Dictionary = harvesters.get(pid2, {})
		var t: float = float(h2.get("accum_time", 0.0))
		if t <= 0.0:
			continue
		var quota: float = float(pool_int) * (t / total_time)
		var base_share: int = int(floor(quota))
		var remainder: float = quota - float(base_share)
		sum_base += base_share
		allocations.append({"pid": pid2, "base": base_share, "rem": remainder})
	var leftover: int = pool_int - sum_base
	if leftover > 0 and allocations.size() > 0:
		allocations.sort_custom(func(a, b): return a["rem"] > b["rem"]) # descending by remainder
		for i in range(min(leftover, allocations.size())):
			allocations[i]["base"] = int(allocations[i]["base"]) + 1
	# Award
	for alloc in allocations:
		var final_share: int = int(alloc["base"])
		if final_share <= 0:
			continue
		var pid_award: int = int(alloc["pid"])
		if instance.give_item(pid_award, slug, final_share):
			# Accumulate per-harvester earned_total for stable expected_total
			var h_aw: Dictionary = harvesters.get(pid_award, {})
			h_aw["earned_total"] = float(h_aw.get("earned_total", 0.0)) + float(final_share)
			harvesters[pid_award] = h_aw
			instance.data_push.rpc_id(pid_award, &"harvest.distribution", {
				"node": String(get_path()),
				"items": [{"slug": slug, "amount": final_share}],
				"reason": reason,
			})
	# Reset pool to fractional remainder and zero accum_time for continuing harvesters
	pool_amount = pool_frac
	for pid_any3 in harvesters.keys():
		var pid3: int = int(pid_any3)
		var h3: Dictionary = harvesters.get(pid3, {})
		h3["accum_time"] = 0.0
		harvesters[pid3] = h3


func request_encourage(peer_id: int) -> Dictionary:
	if not multiplayer.is_server():
		return {"ok": false, "err": &"not_server"}
	if not harvesters.has(peer_id):
		return {"ok": false, "err": &"not_harvesting"}
	var cd_until: float = float(_encourage_cd_until.get(peer_id, 0.0))
	if cd_until > _clock:
		return {"ok": false, "err": &"cooldown", "cd_remaining": cd_until - _clock}
	var instance: ServerInstance = get_viewport() as ServerInstance
	# If no session active, start it with this contributor
	if not _enc_session_active:
		_enc_session_active = true
		_enc_session_expires_at = _clock + encourage_session_window
		_enc_session_contributors.clear()
		_enc_session_stack_count = 0
		_enc_session_cum_bonus_pct = 0.0
		_enc_session_contributors[peer_id] = true
		_enc_session_stack_count = 1
		_encourage_cd_until[peer_id] = _clock + encourage_cooldown
		if instance != null:
			for pid_s: int in harvesters.keys():
				instance.data_push.rpc_id(pid_s, &"harvest.encourage.session", {
					"node": String(get_path()),
					"started_by": peer_id,
					"window": encourage_session_window,
				})
		return {
			"ok": true, "session_started": true, "hit": false,
			"stack_index": 1, "time_left": encourage_session_window,
			"cd_remaining": encourage_cooldown
		}
	# Session active: check caps and uniqueness
	if _enc_session_contributors.has(peer_id):
		return {"ok": false, "err": &"already_contributed", "time_left": _enc_session_expires_at - _clock}
	if _enc_session_stack_count >= encourage_max_stacks or _enc_session_cum_bonus_pct >= encourage_max_total_bonus_pct:
		return {"ok": false, "err": &"cap_reached", "time_left": _enc_session_expires_at - _clock}
	# Apply stack
	var remaining_pct: float = encourage_max_total_bonus_pct - _enc_session_cum_bonus_pct
	var apply_pct: float = min(encourage_bonus_pct, remaining_pct)
	_enc_session_contributors[peer_id] = true
	_enc_session_stack_count += 1
	_enc_session_cum_bonus_pct += apply_pct
	pool_amount += pool_amount * apply_pct
	_encourage_cd_until[peer_id] = _clock + encourage_cooldown
	if instance != null:
		for pid_h: int in harvesters.keys():
			instance.data_push.rpc_id(pid_h, &"harvest.encourage.hit", {
				"node": String(get_path()),
				"peer": peer_id,
				"stack_index": _enc_session_stack_count,
				"bonus_pct_applied": apply_pct,
				"total_bonus_pct": _enc_session_cum_bonus_pct,
				"time_left": max(0.0, _enc_session_expires_at - _clock),
			})
	return {
		"ok": true, "session_started": false, "hit": true,
		"stack_index": _enc_session_stack_count,
		"cd_remaining": encourage_cooldown,
		"time_left": max(0.0, _enc_session_expires_at - _clock)
	}
