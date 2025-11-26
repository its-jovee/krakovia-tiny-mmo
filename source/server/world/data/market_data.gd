class_name MarketData
extends Resource
## Persistent storage for market supply/demand state
## Used for dynamic pricing across all items in the economy

## Supply level per item: {item_id: supply_info}
## supply_info = {
##   "level": float (-1.0 to 1.0, negative=scarce, positive=surplus),
##   "last_transaction": int (unix timestamp for decay calculation)
## }
@export var item_supply: Dictionary = {}

## Price configuration
@export var price_swing_factor: float = 10.0  # Base for exponential pricing (10 = 0.1x to 10x range)
@export var decay_rate_per_hour: float = 0.1  # How fast prices return to normal (supply_level decay per hour)

## Transaction history for analytics (optional, limited size)
@export var transaction_log: Array = []
@export var max_log_entries: int = 1000


## Get the current supply level for an item (0.0 = equilibrium)
func get_supply_level(item_id: int) -> float:
	if not item_supply.has(item_id):
		return 0.0
	return item_supply[item_id].get("level", 0.0)


## Set the supply level for an item
func set_supply_level(item_id: int, level: float) -> void:
	level = clampf(level, -1.0, 1.0)
	
	if not item_supply.has(item_id):
		item_supply[item_id] = {}
	
	item_supply[item_id]["level"] = level
	item_supply[item_id]["last_transaction"] = int(Time.get_unix_time_from_system())


## Adjust supply level after a transaction
## delta > 0 = more supply (selling to NPC, price goes down)
## delta < 0 = less supply (buying from NPC, price goes up)
func adjust_supply(item_id: int, delta: float) -> void:
	var current = get_supply_level(item_id)
	set_supply_level(item_id, current + delta)


## Get the price multiplier for an item based on its supply level
## Returns value between 0.1 (very scarce) and 10.0 (very surplus)
func get_price_multiplier(item_id: int) -> float:
	var supply = get_supply_level(item_id)
	# Formula: multiplier = swing_factor ^ (-supply)
	# When supply = -1 (scarce): 10^1 = 10 (expensive)
	# When supply = 0 (normal): 10^0 = 1 (base price)
	# When supply = 1 (surplus): 10^-1 = 0.1 (cheap)
	return pow(price_swing_factor, -supply)


## Apply time-based decay to all supply levels
## Call this periodically (e.g., every save cycle or hourly)
func apply_decay() -> void:
	var now = int(Time.get_unix_time_from_system())
	
	for item_id in item_supply.keys():
		var info = item_supply[item_id]
		var last_time: int = info.get("last_transaction", now)
		var hours_elapsed: float = float(now - last_time) / 3600.0
		
		if hours_elapsed <= 0:
			continue
		
		var current_level: float = info.get("level", 0.0)
		if absf(current_level) < 0.001:
			# Already at equilibrium
			continue
		
		# Decay toward 0
		var decay_amount = decay_rate_per_hour * hours_elapsed
		if current_level > 0:
			current_level = maxf(0.0, current_level - decay_amount)
		else:
			current_level = minf(0.0, current_level + decay_amount)
		
		info["level"] = current_level
		# Don't update last_transaction - only transactions update that


## Log a transaction for analytics
func log_transaction(item_id: int, quantity: int, is_buy: bool, price_per_unit: int) -> void:
	var entry = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"item_id": item_id,
		"quantity": quantity,
		"is_buy": is_buy,
		"price": price_per_unit
	}
	
	transaction_log.append(entry)
	
	# Keep log size bounded
	while transaction_log.size() > max_log_entries:
		transaction_log.pop_front()


## Get all items with non-zero supply levels (for syncing to clients)
func get_active_supply_levels() -> Dictionary:
	var result = {}
	for item_id in item_supply.keys():
		var level = item_supply[item_id].get("level", 0.0)
		if absf(level) > 0.001:  # Only include non-equilibrium items
			result[item_id] = level
	return result


## Calculate supply delta for a transaction based on quantity and item tier
## Higher tier items have less impact per unit (they're rarer)
func calculate_supply_delta(quantity: int, item_tier: int = 1, is_buy: bool = true) -> float:
	# Base impact per item (scaled down for higher tiers)
	var base_impact = 0.01 / float(maxi(1, item_tier))
	var total_delta = base_impact * float(quantity)
	
	# Buying decreases supply (negative), selling increases supply (positive)
	if is_buy:
		return -total_delta
	else:
		return total_delta


