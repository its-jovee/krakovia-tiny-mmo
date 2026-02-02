@tool
@icon("res://assets/node_icons/blue/icon_grid.png")
extends InteractionArea
class_name VendorArea
## Vendor interaction area where players can buy AND sell items.
## Each vendor has their own inventory catalog and local supply/demand pricing.

## Unique identifier for this vendor (persists across sessions)
@export var vendor_id: String = "":
	set(value):
		vendor_id = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

## Display name shown to players
@export var vendor_name: String = "Merchant":
	set(value):
		vendor_name = value
		_update_label()

## Icon/emoji for UI display
@export var vendor_icon: String = "🏪"

## Items this vendor SELLS to players (item IDs)
@export var item_catalog: Array[int] = []

## Items this vendor BUYS from players (raw materials they need)
## If empty, uses item_catalog (buys same items they sell)
@export var buy_catalog: Array[int] = []

## Stock conversion recipes: raw materials → finished goods
## Format: {output_item_id: {input_item_id: amount_needed, ...}, ...}
## Example: {25: {8: 3}} means 3 iron ore (8) → 1 iron ingot (25)
## If empty, selling any buy_catalog item adds 1 stock to a random sell item
@export var stock_recipes: Dictionary = {}

## Base multipliers for this vendor's personality
@export_range(0.1, 1.0) var buy_multiplier: float = 0.7   # What vendor pays when BUYING from player
@export_range(1.0, 3.0) var sell_multiplier: float = 1.3  # What vendor charges when SELLING to player

## Vendor specialization (for events that affect certain vendor types)
@export_enum("general", "blacksmith", "herbalist", "fisher", "luxury", "food") var vendor_type: String = "general"

## Bonus multiplier when buying items vendor specializes in (items in buy_catalog)
## E.g., 1.3 means vendor pays 30% MORE for their specialty items
@export_range(1.0, 2.0) var specialty_bonus: float = 1.2

## Bonus for crafted items (vendors value processed goods more)
@export_range(1.0, 2.0) var crafted_bonus: float = 1.15

## Description/personality blurb for the Info tab
@export_multiline var vendor_description: String = "A friendly merchant ready to trade."

## How fast this vendor produces stock from raw materials (seconds per batch)
@export var production_time_seconds: float = 60.0

## How often this vendor restocks naturally (minutes)
@export var natural_restock_minutes: float = 30.0

# Track players currently at vendor
var players_at_vendor: Array[Player] = []

# Cached reference to VendorData (populated on server)
var _vendor_data: VendorData = null


func _ready() -> void:
	# Connect to parent's signals for vendor-specific logic
	player_entered_interaction_area.connect(_on_player_entered_vendor)
	player_exited_interaction_area.connect(_on_player_exited_vendor)
	
	# Update label with vendor name and icon
	_update_label()
	
	if not Engine.is_editor_hint():
		print("[VendorArea] %s (%s) ready - %d items in catalog" % [vendor_name, vendor_id, item_catalog.size()])


func _update_label() -> void:
	# Update the label to show vendor name with icon (using RichTextLabel for BBCode)
	var label = get_node_or_null("Label")
	if not label:
		return
	
	# Use icon texture if UIIcons autoload is available
	if Engine.has_singleton("UIIcons"):
		var icon_key := _get_vendor_icon_key()
		var icon_bbcode := UIIcons.bbcode(icon_key, 16, 16)
		
		if label is RichTextLabel:
			if not icon_bbcode.is_empty():
				label.text = "%s %s" % [icon_bbcode, vendor_name]
			else:
				label.text = vendor_name
		else:
			# Fallback for regular Label
			label.text = vendor_name
	else:
		# No icon system - just show name (no emoji)
		label.text = vendor_name


func _get_vendor_icon_key() -> String:
	"""Map vendor icon emoji or vendor_type to icon key"""
	# Map emojis to icon keys
	match vendor_icon:
		"⚒️":
			return "blacksmith"
		"🌿":
			return "herbalist"
		"🌾":
			return "grocer"
		"💎":
			return "jeweler"
		"🪵":
			return "carpenter"
		"🏪":
			return "vendor"
		_:
			# Try to map vendor_type to icon key
			match vendor_type:
				"blacksmith":
					return "blacksmith"
				"herbalist":
					return "herbalist"
				"food":
					return "grocer"
				"luxury":
					return "jeweler"
				_:
					return "vendor"  # Default


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if vendor_id.is_empty():
		warnings.append("vendor_id is empty! Set a unique ID for this vendor (e.g., 'town_blacksmith')")
	if item_catalog.is_empty():
		warnings.append("item_catalog is empty. This vendor won't have any items to trade.")
	return warnings


func _on_player_entered_vendor(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters vendor area"""
	print("[VendorArea] Player %s entered %s" % [player.name, vendor_name])
	if player not in players_at_vendor:
		players_at_vendor.append(player)


func _on_player_exited_vendor(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits vendor area"""
	print("[VendorArea] Player %s exited %s" % [player.name, vendor_name])
	players_at_vendor.erase(player)


func is_player_at_vendor(player: Player) -> bool:
	return player in players_at_vendor


## Initialize vendor data from WorldDatabase (called by server)
func initialize_vendor_data(database: Node) -> void:
	if not database or not database.has_method("get_vendor_data"):
		push_warning("[VendorArea] Cannot initialize vendor data - no database")
		return
	
	_vendor_data = database.get_vendor_data(vendor_id)
	
	# Sync configuration to VendorData
	_vendor_data.vendor_name = vendor_name
	_vendor_data.vendor_icon = vendor_icon
	_vendor_data.item_catalog = item_catalog
	_vendor_data.buy_multiplier = buy_multiplier
	_vendor_data.sell_multiplier = sell_multiplier
	
	# Initialize stock for all items vendor sells
	_vendor_data.initialize_stock(item_catalog)
	
	print("[VendorArea] Initialized vendor data for %s - %d sell items, %d buy items, stock initialized" % [
		vendor_id, 
		item_catalog.size(),
		buy_catalog.size() if not buy_catalog.is_empty() else item_catalog.size()
	])


## Get the VendorData for this vendor
func get_vendor_data() -> VendorData:
	return _vendor_data


## Check if this vendor SELLS a specific item
func sells_item(item_id: int) -> bool:
	if item_catalog.is_empty():
		return true  # Empty = sells everything sellable
	return item_id in item_catalog


## Check if this vendor BUYS a specific item from players
func buys_item(item_id: int) -> bool:
	# Always buy items that are inputs to our recipes
	if _is_recipe_input(item_id):
		return true
	
	var actual_buy_catalog = buy_catalog if not buy_catalog.is_empty() else item_catalog
	if actual_buy_catalog.is_empty():
		return true  # Empty = buys everything
	return item_id in actual_buy_catalog


func _is_recipe_input(item_id: int) -> bool:
	"""Check if an item is an input to any of our stock recipes"""
	for recipe in stock_recipes.values():
		if recipe is Dictionary and recipe.has(item_id):
			return true
	return false


func get_all_recipe_inputs() -> Array[int]:
	"""Get all unique input item IDs from all recipes"""
	var inputs: Array[int] = []
	for recipe in stock_recipes.values():
		if recipe is Dictionary:
			for input_id in recipe.keys():
				if input_id not in inputs:
					inputs.append(input_id)
	return inputs


## Get how much of an item the vendor still needs to buy
## Returns -1 if unlimited (not a recipe input), 0 if fully stocked, or the quantity needed
func get_max_buy_quantity(item_id: int) -> int:
	if not _is_recipe_input(item_id):
		return -1  # Not a recipe input, buy unlimited (or based on buy_catalog rules)
	
	if not _vendor_data:
		return 10  # Fallback
	
	var total_needed: int = 0
	
	for output_id in stock_recipes.keys():
		var recipe = stock_recipes[output_id]
		if recipe.has(item_id):
			var amount_per_craft: int = recipe[item_id]
			
			# Calculate how many more of this output we can make (up to max stock)
			var current_stock = _vendor_data.get_stock(output_id)
			var producing = _vendor_data.get_production_amount(output_id)
			var max_stock = _vendor_data.max_stock_per_item
			var can_produce_more = maxi(0, max_stock - current_stock - producing)
			
			# How much of this input we need for that
			var needed_for_output = can_produce_more * amount_per_craft
			
			# Subtract any pending materials we already have
			var pending_amount = 0
			if _vendor_data.pending_materials.has(output_id):
				pending_amount = _vendor_data.pending_materials[output_id].get(item_id, 0)
			needed_for_output = maxi(0, needed_for_output - pending_amount)
			
			total_needed += needed_for_output
	
	return total_needed


## Legacy compatibility
func has_item(item_id: int) -> bool:
	return sells_item(item_id) or buys_item(item_id)


## Get buy price (what player pays to buy FROM this vendor)
func get_buy_price(item: Item, item_id: int, event_multiplier: float = 1.0) -> int:
	if _vendor_data:
		return _vendor_data.get_buy_price(item, item_id, event_multiplier)
	
	# Fallback if no vendor data
	var base_price = item.minimum_price if item.minimum_price > 0 else 1
	return int(ceil(base_price * sell_multiplier * event_multiplier))


## Get sell price (what vendor pays to buy FROM player)
## This includes specialty bonuses, crafted item bonuses, and demand premium
func get_sell_price(item: Item, item_id: int, event_multiplier: float = 1.0) -> int:
	var base_sell_price: int
	if _vendor_data:
		base_sell_price = _vendor_data.get_sell_price(item, item_id, event_multiplier)
	else:
		# Fallback if no vendor data
		var base_price = item.minimum_price if item.minimum_price > 0 else 1
		base_sell_price = int(floor(base_price * buy_multiplier * event_multiplier))
	
	# Apply bonuses that make selling more profitable
	var bonus_mult = 1.0
	
	# Specialty bonus: vendor pays MORE for items they specifically want
	if is_specialty_item(item_id):
		bonus_mult *= specialty_bonus
	
	# Crafted bonus: processed goods are worth more
	if item.is_crafted:
		bonus_mult *= crafted_bonus
	
	# Demand premium: if this item is needed for production of out-of-stock goods, pay more
	var demand_bonus = _calculate_demand_premium(item_id)
	bonus_mult *= demand_bonus
	
	return int(floor(float(base_sell_price) * bonus_mult))


## Calculate demand premium for a material based on output stock levels
## Returns 1.0 if no premium, up to 1.5 if desperately needed
func _calculate_demand_premium(input_item_id: int) -> float:
	if stock_recipes.is_empty() or not _vendor_data:
		return 1.0
	
	var max_premium = 1.0
	
	# Check each recipe that uses this input
	for output_id in stock_recipes.keys():
		var recipe = stock_recipes[output_id]
		if recipe.has(input_item_id):
			# This input is used for this output
			var current_stock = _vendor_data.get_stock(output_id)
			var max_stock = _vendor_data.max_stock_per_item
			
			# Calculate how "desperate" we are for this output
			# At 0 stock: 50% premium, at half stock: 25% premium, at full: no premium
			var stock_ratio = float(current_stock) / float(max_stock)
			var premium = 1.0 + (0.5 * (1.0 - stock_ratio))  # 1.0 to 1.5
			
			max_premium = maxf(max_premium, premium)
	
	return max_premium


## Check if an item is a specialty for this vendor (in their buy_catalog)
func is_specialty_item(item_id: int) -> bool:
	# If buy_catalog is empty, nothing is "specialty" (general merchant)
	if buy_catalog.is_empty():
		return false
	return item_id in buy_catalog


## Get current supply level for an item
func get_supply_level(item_id: int) -> float:
	if _vendor_data:
		return _vendor_data.get_supply_level(item_id)
	return 0.0


## Adjust supply after a transaction
func adjust_supply(item_id: int, quantity: int, item_tier: int, is_player_buying: bool) -> void:
	if _vendor_data:
		var delta = _vendor_data.calculate_supply_delta(quantity, item_tier, is_player_buying)
		_vendor_data.adjust_supply(item_id, delta)


## === STOCK MANAGEMENT ===

## Get current stock of an item
func get_stock(item_id: int) -> int:
	if _vendor_data:
		return _vendor_data.get_stock(item_id)
	return 0


## Check if item is in stock
func has_stock(item_id: int, quantity: int = 1) -> bool:
	return get_stock(item_id) >= quantity


## Remove stock when player buys (returns actual amount removed)
func remove_stock(item_id: int, quantity: int) -> int:
	if _vendor_data:
		return _vendor_data.remove_stock(item_id, quantity)
	return 0


## Process raw material sale and convert to stock
## Called when player sells items to this vendor
func process_material_sale(item_id: int, quantity: int) -> void:
	if not _vendor_data:
		return
	
	# Check if we have recipes defined
	if stock_recipes.is_empty():
		# Simple mode: each raw material sold adds stock to random finished goods
		_add_stock_simple(quantity)
		return
	
	# Recipe mode: accumulate materials and convert when enough
	_process_recipe_conversion(item_id, quantity)


## Simple stock addition (no recipes)
func _add_stock_simple(quantity: int) -> void:
	if item_catalog.is_empty():
		return
	
	# Add stock evenly across all items vendor sells
	var stock_per_item = maxi(1, quantity / item_catalog.size())
	for sell_item_id in item_catalog:
		_vendor_data.add_stock(sell_item_id, stock_per_item)


## Process recipe-based conversion
func _process_recipe_conversion(input_item_id: int, quantity: int) -> void:
	# Find recipes that use this input item
	for output_id in stock_recipes.keys():
		var recipe: Dictionary = stock_recipes[output_id]
		if recipe.has(input_item_id):
			# Add materials to pending production
			var started = _vendor_data.add_materials(
				output_id, 
				input_item_id, 
				quantity, 
				recipe, 
				production_time_seconds
			)
			if started > 0:
				print("[VendorArea] %s: Started producing %d of item %d (from %d of item %d)" % [
					vendor_name, started, output_id, quantity, input_item_id
				])
			else:
				print("[VendorArea] %s: Stockpiled %d of item %d for item %d" % [
					vendor_name, quantity, input_item_id, output_id
				])


## Get catalog for client (items with prices)
## Returns both what vendor sells AND what they buy from players
func get_catalog_for_client(event_multiplier: float = 1.0) -> Dictionary:
	var sell_catalog_result: Array[Dictionary] = []  # Items player can BUY from vendor
	var buy_catalog_result: Array[Dictionary] = []  # Items vendor will BUY from player
	
	# Process any completed production first
	if _vendor_data:
		_vendor_data.process_production()
	
	# Get production status
	var production_status: Dictionary = {}
	if _vendor_data:
		production_status = _vendor_data.get_production_status(stock_recipes)
	
	# Items vendor sells to players (with stock info)
	for item_id in item_catalog:
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item and item.can_sell:
			var entry = {
				"id": item_id,
				"price": get_buy_price(item, item_id, event_multiplier),
				"supply": get_supply_level(item_id),
				"stock": get_stock(item_id)  # How many available
			}
			
			# Add production info if applicable
			if production_status.has(item_id):
				var prod = production_status[item_id]
				entry["producing"] = prod.get("producing", 0)
				entry["next_ready_in"] = prod.get("next_ready_in", 0)
				entry["stock_full"] = prod.get("stock_full", false)
				entry["pending"] = prod.get("pending", {})
				entry["needed"] = prod.get("needed", {})
			
			# Add recipe requirements if this item has a recipe
			if stock_recipes.has(item_id):
				entry["recipe"] = stock_recipes[item_id]
			
			sell_catalog_result.append(entry)
	
	# Build reverse lookup: input_id -> [output_ids it produces]
	# Also calculate max needed for each input to fill all output stocks
	var input_produces: Dictionary = {}  # {input_id: [{output_id, output_name, needs}, ...]}
	var input_max_needed: Dictionary = {}  # {input_id: max_quantity_vendor_needs}
	
	for output_id in stock_recipes.keys():
		var recipe = stock_recipes[output_id]
		var output_item: Item = ContentRegistryHub.load_by_id(&"items", output_id)
		var output_name = output_item.item_name if output_item else "Unknown"
		
		# Calculate how many more of this output we can make (up to max stock)
		var current_stock = get_stock(output_id) if _vendor_data else 0
		var producing = _vendor_data.get_production_amount(output_id) if _vendor_data else 0
		var max_stock = _vendor_data.max_stock_per_item if _vendor_data else 10
		var can_produce_more = maxi(0, max_stock - current_stock - producing)
		
		for input_id in recipe.keys():
			var amount_per_craft: int = recipe[input_id]
			
			if not input_produces.has(input_id):
				input_produces[input_id] = []
			input_produces[input_id].append({
				"id": output_id,
				"name": output_name,
				"needs": amount_per_craft
			})
			
			# Calculate how much of this input we still need
			var needed_for_output = can_produce_more * amount_per_craft
			# Subtract any pending materials we already have
			var pending_amount = 0
			if _vendor_data and _vendor_data.pending_materials.has(output_id):
				pending_amount = _vendor_data.pending_materials[output_id].get(input_id, 0)
			needed_for_output = maxi(0, needed_for_output - pending_amount)
			
			input_max_needed[input_id] = input_max_needed.get(input_id, 0) + needed_for_output
	
	# Items vendor buys from players (include all recipe inputs)
	var actual_buy_catalog = buy_catalog.duplicate() if not buy_catalog.is_empty() else item_catalog.duplicate()
	
	# Add all recipe inputs to buy catalog
	var recipe_inputs = get_all_recipe_inputs()
	for input_id in recipe_inputs:
		if input_id not in actual_buy_catalog:
			actual_buy_catalog.append(input_id)
	
	for item_id in actual_buy_catalog:
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:  # Remove can_sell check - vendor needs these materials!
			var price = get_sell_price(item, item_id, event_multiplier)
			
			# Ensure minimum price of 1g for items vendor needs
			if input_produces.has(item_id) and price < 1:
				price = maxi(1, int(ceil(float(item.minimum_price) * buy_multiplier)))
				if price < 1:
					price = 1  # Absolute floor
			
			var entry = {
				"id": item_id,
				"price": price,
				"supply": get_supply_level(item_id)
			}
			
			# Add "produces" info and max buy quantity if this is a recipe input
			if input_produces.has(item_id):
				entry["produces"] = input_produces[item_id]
				entry["is_needed"] = true  # Mark as needed for production
				entry["max_buy"] = input_max_needed.get(item_id, 0)  # Cap on how much vendor will buy
			
			buy_catalog_result.append(entry)
	
	return {
		"sells": sell_catalog_result,  # What player can buy
		"buys": buy_catalog_result  # What vendor will buy from player
	}


## Get vendor info for client UI
func get_vendor_info() -> Dictionary:
	# Get translated name if _vendor_data is available
	var display_name: String = vendor_name
	if _vendor_data and _vendor_data.has_method("get_translated_name"):
		display_name = _vendor_data.get_translated_name()
	
	return {
		"id": vendor_id,
		"name": display_name,
		"icon": vendor_icon,
		"type": vendor_type,
		"description": vendor_description,
		"buy_multiplier": buy_multiplier,
		"sell_multiplier": sell_multiplier,
		"specialty_bonus": specialty_bonus,
		"crafted_bonus": crafted_bonus,
		"production_time": production_time_seconds,
		"restock_time": natural_restock_minutes,
		"catalog_size": item_catalog.size(),
		"buy_catalog_size": buy_catalog.size(),
		"recipes": _get_recipes_info()
	}


func _get_recipes_info() -> Array[Dictionary]:
	"""Get recipe info for display in Info tab"""
	var recipes_info: Array[Dictionary] = []
	
	for output_id in stock_recipes.keys():
		var inputs = stock_recipes[output_id]
		var output_item: Item = ContentRegistryHub.load_by_id(&"items", output_id)
		if not output_item:
			continue
		
		var input_info: Array[Dictionary] = []
		for input_id in inputs.keys():
			var input_item: Item = ContentRegistryHub.load_by_id(&"items", input_id)
			if input_item:
				input_info.append({
					"id": input_id,
					"name": input_item.item_name,
					"amount": inputs[input_id]
				})
		
		recipes_info.append({
			"output_id": output_id,
			"output_name": output_item.item_name,
			"inputs": input_info
		})
	
	return recipes_info
