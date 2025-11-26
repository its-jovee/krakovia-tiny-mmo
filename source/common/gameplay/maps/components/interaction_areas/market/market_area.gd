@tool
@icon("res://assets/node_icons/blue/icon_grid.png")
extends InteractionArea
class_name MarketArea
## Market area where players can buy/sell items with NPC vendors
## Prices are dynamic based on supply/demand (see MarketData)

@export var market_name: String = "Market"
@export var sell_multiplier: float = 1.0  # Base multiplier for sell prices
@export var buy_multiplier: float = 1.5   # Base multiplier for buy prices (higher than sell)

# Track players currently in market
var players_in_market: Array[Player] = []

# Cache for buyable items catalog (lazy loaded)
var _buyable_items_cache: Array[Dictionary] = []
var _cache_valid: bool = false

func _ready() -> void:
	# Connect to our own handlers for market-specific logic
	# Parent already handles the player_entered_interaction_area signal emission
	player_entered_interaction_area.connect(_on_player_entered_market_area)
	player_exited_interaction_area.connect(_on_player_exited_market_area)
	
	# Debug: Confirm MarketArea is initialized
	print("[MarketArea] Ready! Position: %s, Scale: %s, Monitoring: %s" % [global_position, scale, monitoring])

func _on_player_entered_market_area(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters market - add market-specific logic"""
	print("[MarketArea] 🟢 Player %s ENTERED market!" % player.name)
	
	# Defensive check: Ensure player_resource is initialized
	# With the baseline sync fix, this should always be true, but we check anyway
	if not player.player_resource:
		print("[MarketArea] ⚠️ Player resource not yet initialized for %s, skipping" % player.name)
		return
	
	players_in_market.append(player)
	print("[MarketArea] Players in market: %d" % players_in_market.size())
	
	# Notify client that player entered market (for client-side effects)
	if player.has_method("_on_entered_market"):
		player._on_entered_market(self)

func _on_player_exited_market_area(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits market - remove from tracking"""
	players_in_market.erase(player)
	# Notify client that player left market (for client-side effects)
	if player.has_method("_on_exited_market"):
		player._on_exited_market(self)

func is_player_in_market(player: Player) -> bool:
	return player in players_in_market

func get_sell_price(item: Item, item_id: int = -1) -> int:
	if not item.can_sell:
		return 0
	
	# Calculate base price (could be enhanced with item rarity, level, etc.)
	var base_price = item.minimum_price
	if base_price <= 0:
		# Default pricing based on item type
		base_price = _get_default_item_price(item)
	
	# Apply dynamic pricing multiplier if available
	var dynamic_multiplier = _get_dynamic_price_multiplier(item_id)
	
	return int(base_price * sell_multiplier * dynamic_multiplier)

func _get_default_item_price(item: Item) -> int:
	# Default pricing logic based on item tags or type
	if "material" in item.tags:
		return 5  # Basic materials
	elif "ore" in item.tags:
		return 10  # Ores are more valuable
	elif "weapon" in item.tags:
		return 50  # Weapons are valuable
	elif "armor" in item.tags:
		return 40  # Armor is valuable
	else:
		return 1  # Default minimal price


## Get the buy price for an item (what player pays to buy from NPC)
func get_buy_price(item: Item, item_id: int = -1) -> int:
	if not item.can_sell:
		return 0
	
	var base_price = item.minimum_price
	if base_price <= 0:
		base_price = _get_default_item_price(item)
	
	# Apply dynamic pricing multiplier if available
	var dynamic_multiplier = _get_dynamic_price_multiplier(item_id)
	
	# Buy price is higher than sell price (NPC markup)
	return int(base_price * buy_multiplier * dynamic_multiplier)


## Get dynamic price multiplier from market data (server only)
## Returns 1.0 if market data not available (client-side or no data)
func _get_dynamic_price_multiplier(item_id: int) -> float:
	if item_id <= 0:
		return 1.0
	
	# Only works on server - try to get market data from WorldDatabase
	var market_data = _get_market_data()
	if market_data == null:
		return 1.0
	
	return market_data.get_price_multiplier(item_id)


## Get MarketData from the WorldDatabase (server only)
## Returns null on client or if database not accessible
func _get_market_data() -> MarketData:
	# Navigate up the tree to find WorldDatabase
	# MarketArea -> InstanceMap -> ServerInstance -> InstanceManager -> WorldMain -> WorldDatabase
	var node = get_parent()
	while node != null:
		# Look for world_server property or WorldDatabase child
		if node.has_node("WorldDatabase"):
			var db = node.get_node("WorldDatabase")
			if db and "market_data" in db:
				return db.market_data
		if node.has_node("WorldServer"):
			var ws = node.get_node("WorldServer")
			if ws and "database" in ws and ws.database:
				return ws.database.market_data
		node = node.get_parent()
	
	return null


## Get catalog of all items available for purchase
## Returns array of {item_id, item_name, buy_price, tags, description}
func get_buyable_items_catalog() -> Array[Dictionary]:
	if _cache_valid:
		return _buyable_items_cache
	
	_buyable_items_cache.clear()
	
	# Load items index to iterate all items
	var index_path := "res://source/common/registry/indexes/items_index.tres"
	var content_index = ResourceLoader.load(index_path)
	if content_index == null:
		push_error("[MarketArea] Could not load items index")
		return _buyable_items_cache
	
	for entry in content_index.entries:
		var item_id: int = entry.get(&"id", 0)
		if item_id == 0:
			continue
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item == null:
			continue
		
		# Only include items that can be sold (and thus bought from NPCs)
		if not item.can_sell:
			continue
		
		_buyable_items_cache.append({
			"item_id": item_id,
			"item_name": item.item_name,
			"buy_price": get_buy_price(item, item_id),
			"sell_price": get_sell_price(item, item_id),
			"tags": Array(item.tags),
			"description": item.description
		})
	
	_cache_valid = true
	print("[MarketArea] Built catalog with %d buyable items" % _buyable_items_cache.size())
	return _buyable_items_cache


## Invalidate catalog cache (call when prices change)
func invalidate_catalog_cache() -> void:
	_cache_valid = false
	_buyable_items_cache.clear()
