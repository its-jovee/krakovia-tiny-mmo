class_name VendorData
extends Resource
## Per-vendor data including inventory catalog and local supply/demand levels.
## Each vendor has their own economy - prices vary based on local transactions.

## Unique identifier for this vendor (e.g., "town_blacksmith")
@export var vendor_id: String = ""

## Display name shown to players
@export var vendor_name: String = "Merchant"

## Icon/emoji for UI display
@export var vendor_icon: String = "🏪"

## Items this vendor deals in (item IDs)
## If empty, vendor deals in ALL sellable items (legacy behavior)
@export var item_catalog: Array[int] = []

## Local supply levels for items at THIS vendor
## {item_id: {"level": float, "last_transaction": int}}
@export var local_supply: Dictionary = {}

## Price multipliers for this vendor's personality
@export var buy_multiplier: float = 0.7   # What vendor pays when BUYING from player
@export var sell_multiplier: float = 1.3  # What vendor charges when SELLING to player

## Price swing factor (how much supply affects prices)
@export var price_swing_factor: float = 10.0  # 0.1x to 10x range

## Decay rate - how fast prices return to normal
@export var decay_rate_per_hour: float = 0.1

## === STOCK SYSTEM ===
## Current stock of items vendor can sell
## {item_id: stock_count}
@export var stock: Dictionary = {}

## Maximum stock per item type
@export var max_stock_per_item: int = 50

## Starting stock for each item (replenishes slowly)
@export var base_stock_per_item: int = 10

## Stock replenishment rate per hour (toward base_stock)
@export var stock_replenish_rate: float = 2.0


## Check if this vendor deals in a specific item
func has_item(item_id: int) -> bool:
	if item_catalog.is_empty():
		return true  # Empty catalog = deals in everything
	return item_id in item_catalog


## Get the current supply level for an item at this vendor (0.0 = equilibrium)
func get_supply_level(item_id: int) -> float:
	if not local_supply.has(item_id):
		return 0.0
	return local_supply[item_id].get("level", 0.0)


## Set the supply level for an item
func set_supply_level(item_id: int, level: float) -> void:
	level = clampf(level, -1.0, 1.0)
	
	if not local_supply.has(item_id):
		local_supply[item_id] = {}
	
	local_supply[item_id]["level"] = level
	local_supply[item_id]["last_transaction"] = int(Time.get_unix_time_from_system())


## Adjust supply level after a transaction
## delta > 0 = more supply (player sold to vendor, price goes down)
## delta < 0 = less supply (player bought from vendor, price goes up)
func adjust_supply(item_id: int, delta: float) -> void:
	var current = get_supply_level(item_id)
	set_supply_level(item_id, current + delta)


## Get the price multiplier based on local supply level
## Returns value between 0.1 (very scarce) and 10.0 (very surplus)
func get_price_multiplier(item_id: int) -> float:
	var supply = get_supply_level(item_id)
	# Formula: multiplier = swing_factor ^ (-supply)
	# When supply = -1 (scarce): 10^1 = 10 (expensive)
	# When supply = 0 (normal): 10^0 = 1 (base price)
	# When supply = 1 (surplus): 10^-1 = 0.1 (cheap)
	return pow(price_swing_factor, -supply)


## Calculate the BUY price (what player pays to buy FROM vendor)
func get_buy_price(item: Item, item_id: int, event_multiplier: float = 1.0) -> int:
	var base_price = item.minimum_price if item.minimum_price > 0 else 1
	var supply_mult = get_price_multiplier(item_id)
	return int(ceil(base_price * sell_multiplier * supply_mult * event_multiplier))


## Calculate the SELL price (what vendor pays to buy FROM player)
func get_sell_price(item: Item, item_id: int, event_multiplier: float = 1.0) -> int:
	var base_price = item.minimum_price if item.minimum_price > 0 else 1
	var supply_mult = get_price_multiplier(item_id)
	# Invert supply multiplier for sell price (surplus = vendor pays less)
	return int(floor(base_price * buy_multiplier * supply_mult * event_multiplier))


## Apply time-based decay to all supply levels at this vendor
func apply_decay() -> void:
	var now = int(Time.get_unix_time_from_system())
	
	for item_id in local_supply.keys():
		var info = local_supply[item_id]
		var last_time: int = info.get("last_transaction", now)
		var hours_elapsed: float = float(now - last_time) / 3600.0
		
		if hours_elapsed <= 0:
			continue
		
		var current_level: float = info.get("level", 0.0)
		if absf(current_level) < 0.001:
			# Already at equilibrium, clean up entry
			local_supply.erase(item_id)
			continue
		
		# Decay toward 0
		var decay_amount = decay_rate_per_hour * hours_elapsed
		if current_level > 0:
			current_level = maxf(0.0, current_level - decay_amount)
		else:
			current_level = minf(0.0, current_level + decay_amount)
		
		info["level"] = current_level


## Calculate supply delta for a transaction
func calculate_supply_delta(quantity: int, item_tier: int = 1, is_player_buying: bool = true) -> float:
	# Base impact per item (scaled down for higher tiers)
	var base_impact = 0.02 / float(maxi(1, item_tier))  # Doubled impact for more noticeable changes
	var total_delta = base_impact * float(quantity)
	
	# Player buying = vendor supply decreases (negative)
	# Player selling = vendor supply increases (positive)
	if is_player_buying:
		return -total_delta
	else:
		return total_delta


## Get catalog for client display (items with current prices)
func get_catalog_for_client(event_multiplier: float = 1.0) -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	
	for item_id in item_catalog:
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item and item.can_sell:
			catalog.append({
				"id": item_id,
				"buy_price": get_buy_price(item, item_id, event_multiplier),
				"sell_price": get_sell_price(item, item_id, event_multiplier),
				"supply": get_supply_level(item_id)
			})
	
	return catalog


## Get all items with non-zero supply levels (for syncing)
func get_active_supply_levels() -> Dictionary:
	var result = {}
	for item_id in local_supply.keys():
		var level = local_supply[item_id].get("level", 0.0)
		if absf(level) > 0.001:
			result[item_id] = level
	return result


## === STOCK MANAGEMENT ===

## Get current stock of an item
func get_stock(item_id: int) -> int:
	if not stock.has(item_id):
		# Initialize with base stock
		stock[item_id] = base_stock_per_item
	return stock[item_id]


## Set stock for an item
func set_stock(item_id: int, amount: int) -> void:
	stock[item_id] = clampi(amount, 0, max_stock_per_item)


## Add stock (when player sells raw materials that convert to finished goods)
func add_stock(item_id: int, amount: int) -> void:
	var current = get_stock(item_id)
	set_stock(item_id, current + amount)


## Remove stock (when player buys)
## Returns actual amount removed (may be less if not enough stock)
func remove_stock(item_id: int, amount: int) -> int:
	var current = get_stock(item_id)
	var actual_removed = mini(current, amount)
	set_stock(item_id, current - actual_removed)
	return actual_removed


## Check if item is in stock
func has_stock(item_id: int) -> bool:
	return get_stock(item_id) > 0


## Apply stock replenishment over time (called during decay)
func apply_stock_replenishment(hours_elapsed: float) -> void:
	for item_id in stock.keys():
		var current = stock[item_id]
		if current < base_stock_per_item:
			# Replenish toward base stock
			var replenish_amount = int(stock_replenish_rate * hours_elapsed)
			stock[item_id] = mini(current + replenish_amount, base_stock_per_item)


## Initialize stock for all items in a catalog
func initialize_stock(sell_catalog: Array[int]) -> void:
	for item_id in sell_catalog:
		if not stock.has(item_id):
			stock[item_id] = base_stock_per_item

