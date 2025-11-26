class_name MarketEventManager
extends Node
## Manages periodic market events that affect item prices globally.
## Events are scheduled to occur every X minutes and broadcast to all players.

signal event_started(event: MarketEvent)
signal event_ended(event: MarketEvent)

## Time between events (in minutes)
@export var event_interval_minutes: int = 30

## Pool of possible events to choose from
@export var event_pool: Array[MarketEvent] = []

## Currently active event (null if none)
var current_event: MarketEvent = null

## Timestamps for scheduling
var event_end_time: int = 0
var next_event_time: int = 0

## Reference to WorldServer for broadcasting
var world_server: WorldServer = null

## Timer for checking event state
var _check_timer: Timer


func _ready() -> void:
	# Schedule first event after a short delay
	next_event_time = int(Time.get_unix_time_from_system()) + 60  # 1 minute after server starts
	
	# Create timer to check event state every second
	_check_timer = Timer.new()
	_check_timer.wait_time = 1.0
	_check_timer.autostart = true
	_check_timer.timeout.connect(_check_event_state)
	add_child(_check_timer)
	
	print("[MarketEventManager] Ready - events every %d minutes" % event_interval_minutes)


func _check_event_state() -> void:
	var now = int(Time.get_unix_time_from_system())
	
	# Check if current event ended
	if current_event and now >= event_end_time:
		_end_current_event()
	
	# Check if time for new event
	if not current_event and now >= next_event_time:
		_start_random_event()


func _start_random_event() -> void:
	if event_pool.is_empty():
		# No events configured, reschedule
		next_event_time = int(Time.get_unix_time_from_system()) + (event_interval_minutes * 60)
		return
	
	# Pick a random event (weighted selection)
	current_event = _pick_weighted_event()
	
	if not current_event:
		next_event_time = int(Time.get_unix_time_from_system()) + (event_interval_minutes * 60)
		return
	
	# Set timing
	event_end_time = int(Time.get_unix_time_from_system()) + (current_event.duration_minutes * 60)
	next_event_time = event_end_time + (event_interval_minutes * 60)
	
	print("[MarketEventManager] 📢 Event Started: %s %s (duration: %d min)" % [
		current_event.icon,
		current_event.title,
		current_event.duration_minutes
	])
	
	event_started.emit(current_event)
	_broadcast_event_to_all_players(true)


func _end_current_event() -> void:
	if not current_event:
		return
	
	print("[MarketEventManager] 📢 Event Ended: %s %s" % [current_event.icon, current_event.title])
	
	var ended_event = current_event
	current_event = null
	
	event_ended.emit(ended_event)
	_broadcast_event_to_all_players(false)


func _pick_weighted_event() -> MarketEvent:
	"""Pick a random event using selection weights"""
	var total_weight: float = 0.0
	for event in event_pool:
		total_weight += event.selection_weight
	
	if total_weight <= 0:
		return event_pool.pick_random()
	
	var roll = randf() * total_weight
	var cumulative: float = 0.0
	
	for event in event_pool:
		cumulative += event.selection_weight
		if roll <= cumulative:
			return event
	
	return event_pool.back()


func _broadcast_event_to_all_players(active: bool) -> void:
	"""Broadcast event status to all connected players"""
	if not world_server:
		return
	
	var event_data: Dictionary
	if active and current_event:
		event_data = {
			"active": true,
			"id": current_event.event_id,
			"title": current_event.title,
			"description": current_event.description,
			"icon": current_event.icon,
			"ends_at": event_end_time,
			"affected_items": current_event.affected_items.keys()
		}
	else:
		event_data = {"active": false}
	
	# Broadcast to all instances
	var instance_manager = world_server.get_node_or_null("InstanceManager")
	if instance_manager:
		for instance in instance_manager.get_children():
			if instance is ServerInstance:
				# Push event data to market UI
				instance.propagate_rpc(instance.data_push.bind(&"market.event", event_data))
				
				# Also send a chat announcement so everyone knows
				if active and current_event:
					var price_changes = _format_price_changes(current_event)
					var chat_message = {
						"id": 0,
						"display_name": "📢 Market News",
						"text": "%s %s\n%s\n%s" % [
							current_event.icon,
							current_event.title,
							current_event.description,
							price_changes
						],
						"color": "#FFD700",
						"is_system": true
					}
					instance.propagate_rpc(instance.data_push.bind(&"chat.message", chat_message))
				elif not active:
					var chat_message = {
						"id": 0,
						"display_name": "📢 Market News",
						"text": "The market event has ended. Prices returning to normal.",
						"color": "#AAAAAA",
						"is_system": true
					}
					instance.propagate_rpc(instance.data_push.bind(&"chat.message", chat_message))


## Format price changes for chat display
func _format_price_changes(event: MarketEvent) -> String:
	if event.affected_items.is_empty():
		return ""
	
	var changes: Array[String] = []
	
	for item_id in event.affected_items.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		
		var demand_mod: float = event.affected_items[item_id]
		var percent: int
		var arrow: String
		
		if demand_mod >= 0:
			# High demand = prices UP
			percent = int(demand_mod * 100)
			arrow = "📈"
		else:
			# Low demand = prices DOWN
			percent = int(abs(demand_mod) * 100)
			arrow = "📉"
		
		changes.append("%s %s %s%d%%" % [arrow, item.item_name, "+" if demand_mod >= 0 else "-", percent])
	
	return " | ".join(changes)


## Get the price multiplier for an item (accounts for current event)
func get_price_multiplier(item_id: int, vendor_type: String = "general") -> float:
	if not current_event:
		return 1.0
	return current_event.get_combined_multiplier(item_id, vendor_type)


## Get vendor type multiplier from current event
func get_vendor_type_multiplier(vendor_type: String) -> float:
	if not current_event:
		return 1.0
	return current_event.get_vendor_type_multiplier(vendor_type)


## Get event info for client display
func get_event_info_for_client() -> Variant:
	if not current_event:
		return null
	
	return {
		"id": current_event.event_id,
		"title": current_event.title,
		"description": current_event.description,
		"icon": current_event.icon,
		"ends_at": event_end_time
	}


## Get time remaining for current event (in seconds)
func get_time_remaining() -> int:
	if not current_event:
		return 0
	return maxi(0, event_end_time - int(Time.get_unix_time_from_system()))


## Manually trigger a specific event (for testing or special occasions)
func trigger_event(event_id: String) -> bool:
	for event in event_pool:
		if event.event_id == event_id:
			# End current event if any
			if current_event:
				_end_current_event()
			
			current_event = event
			event_end_time = int(Time.get_unix_time_from_system()) + (event.duration_minutes * 60)
			next_event_time = event_end_time + (event_interval_minutes * 60)
			
			event_started.emit(current_event)
			_broadcast_event_to_all_players(true)
			return true
	
	return false


## Force end the current event immediately
func end_current_event() -> void:
	if current_event:
		_end_current_event()

