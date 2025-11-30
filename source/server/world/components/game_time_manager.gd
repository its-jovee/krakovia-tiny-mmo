class_name GameTimeManager
extends Node
## Manages the game world's day/night cycle.
## Time is represented as a float from 0.0 to 1.0 where:
## - 0.0 to 0.5 = Day phase
## - 0.5 to 1.0 = Night phase

signal time_changed(time_of_day: float)
signal day_started()
signal night_started()

## Duration of a full day cycle in seconds (45 minutes)
const DAY_DURATION: int = 45 * 60  # 2700 seconds

## How often to broadcast time to clients (in seconds)
const BROADCAST_INTERVAL: float = 30.0

## Current time of day (0.0 to 1.0)
var time_of_day: float = 0.0

## Whether it's currently day (true) or night (false)
var _was_day: bool = true

## Reference to WorldServer for broadcasting
var world_server: WorldServer = null

## Timer for periodic broadcasts
var _broadcast_timer: Timer

## Server start time for calculating world time
var _server_start_time: int = 0


func _ready() -> void:
	_server_start_time = int(Time.get_unix_time_from_system())
	
	# Calculate initial time of day
	_update_time_of_day()
	
	# Set up broadcast timer
	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = BROADCAST_INTERVAL
	_broadcast_timer.autostart = true
	_broadcast_timer.timeout.connect(_on_broadcast_timer)
	add_child(_broadcast_timer)
	
	print("[GameTimeManager] Ready - Day duration: %d seconds (%.1f minutes)" % [DAY_DURATION, DAY_DURATION / 60.0])
	print("[GameTimeManager] Initial time: %.3f (%s)" % [time_of_day, "Day" if is_day() else "Night"])


func _process(_delta: float) -> void:
	_update_time_of_day()
	
	# Check for day/night transitions
	var is_now_day = is_day()
	if is_now_day != _was_day:
		if is_now_day:
			day_started.emit()
			print("[GameTimeManager] 🌅 Day has begun!")
		else:
			night_started.emit()
			print("[GameTimeManager] 🌙 Night has fallen!")
		_was_day = is_now_day


func _update_time_of_day() -> void:
	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - _server_start_time
	
	# Calculate time within the current day cycle
	var time_in_cycle = elapsed % DAY_DURATION
	time_of_day = float(time_in_cycle) / float(DAY_DURATION)
	
	time_changed.emit(time_of_day)


## Returns true if it's currently daytime (0.0 to 0.5)
func is_day() -> bool:
	return time_of_day < 0.5


## Returns true if it's currently nighttime (0.5 to 1.0)
func is_night() -> bool:
	return time_of_day >= 0.5


## Get the current time of day as a float (0.0 to 1.0)
func get_time_of_day() -> float:
	return time_of_day


## Get the current phase name for display
func get_phase_name() -> String:
	if time_of_day < 0.1:
		return "Dawn"
	elif time_of_day < 0.4:
		return "Day"
	elif time_of_day < 0.5:
		return "Dusk"
	elif time_of_day < 0.6:
		return "Evening"
	elif time_of_day < 0.9:
		return "Night"
	else:
		return "Late Night"


## Get time remaining until the next phase change (in seconds)
func get_time_until_phase_change() -> int:
	var target: float
	if is_day():
		target = 0.5  # Time until night
	else:
		target = 1.0  # Time until day (wraps around)
	
	var remaining_fraction = target - time_of_day
	return int(remaining_fraction * DAY_DURATION)


## Broadcast current time to all clients
func broadcast_time() -> void:
	if not world_server:
		return
	
	var time_data = {
		"time": time_of_day,
		"is_day": is_day(),
		"phase": get_phase_name(),
		"day_duration": DAY_DURATION
	}
	
	var instance_manager = world_server.get_node_or_null("InstanceManager")
	if instance_manager:
		for instance in instance_manager.get_children():
			if instance is ServerInstance:
				instance.propagate_rpc(instance.data_push.bind(&"game.time", time_data))


## Send current time to a specific peer (used when player joins)
func send_time_to_peer(instance: ServerInstance, peer_id: int) -> void:
	var time_data = {
		"time": time_of_day,
		"is_day": is_day(),
		"phase": get_phase_name(),
		"day_duration": DAY_DURATION
	}
	
	instance.data_push.rpc_id(peer_id, &"game.time", time_data)


func _on_broadcast_timer() -> void:
	broadcast_time()

