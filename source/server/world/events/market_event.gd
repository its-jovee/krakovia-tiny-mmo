class_name MarketEvent
extends Resource
## Defines a market event that affects item prices globally.
## Events are triggered periodically and broadcast to all players.

## Unique identifier for this event
@export var event_id: String = ""

## Display title shown to players
@export var title: String = ""

## Description explaining the event's effect
@export var description: String = ""

## Icon/emoji for UI display
@export var icon: String = "📢"

## Which items are affected and how much
## {item_id: demand_modifier}
## demand_modifier > 0 = high demand, prices UP (good for sellers)
## demand_modifier < 0 = surplus/low demand, prices DOWN (good for buyers)
@export var affected_items: Dictionary = {}

## Multiplier for specific vendor types (optional)
## {"blacksmith": 1.5, "general": 1.0}
## Vendors of that type get extra/reduced effect
@export var vendor_type_multipliers: Dictionary = {}

## How long this event lasts (in minutes)
@export var duration_minutes: int = 30

## Minimum/maximum rarity weight for random selection
## Higher weight = more likely to be picked
@export var selection_weight: float = 1.0


## Get the price multiplier for an item during this event
func get_item_multiplier(item_id: int) -> float:
	if not affected_items.has(item_id):
		return 1.0
	
	var demand_mod: float = affected_items[item_id]
	# Convert demand modifier to price multiplier
	# +0.5 demand = 1.5x price
	# -0.5 demand = 0.67x price (1 / 1.5)
	if demand_mod >= 0:
		return 1.0 + demand_mod
	else:
		return 1.0 / (1.0 - demand_mod)


## Get vendor type multiplier
func get_vendor_type_multiplier(vendor_type: String) -> float:
	return vendor_type_multipliers.get(vendor_type, 1.0)


## Get the final price multiplier for an item at a specific vendor type
func get_combined_multiplier(item_id: int, vendor_type: String) -> float:
	var item_mult = get_item_multiplier(item_id)
	var vendor_mult = get_vendor_type_multiplier(vendor_type)
	
	# Vendor type amplifies or dampens the event effect
	# If item_mult > 1 (price up) and vendor_mult > 1, prices go up more
	# If item_mult < 1 (price down) and vendor_mult > 1, prices go down more
	if item_mult > 1.0:
		return 1.0 + (item_mult - 1.0) * vendor_mult
	elif item_mult < 1.0:
		return 1.0 - (1.0 - item_mult) * vendor_mult
	return 1.0


## Get info dictionary for client display
func get_client_info() -> Dictionary:
	return {
		"id": event_id,
		"title": title,
		"description": description,
		"icon": icon,
		"duration_minutes": duration_minutes,
		"affected_item_count": affected_items.size()
	}

