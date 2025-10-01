@tool
@icon("res://assets/node_icons/blue/icon_grid.png")
extends InteractionArea
class_name MarketArea
## Market area where players can sell items to NPCs for gold

signal player_exited_interaction_area(player: Player, interaction_area: InteractionArea)

@export var market_name: String = "Market"
@export var sell_multiplier: float = 1.0  # Multiplier for base item prices

# Track players currently in market
var players_in_market: Array[Player] = []

func _ready() -> void:
	# Connect to player enter/exit events
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var player = body as Player
		if not player.just_teleported:
			players_in_market.append(player)
			# Notify client that player entered market
			if player.has_method("_on_entered_market"):
				player._on_entered_market(self)
			# Emit signal for server (this was missing!)
			player_entered_interaction_area.emit(player, self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		var player = body as Player
		players_in_market.erase(player)
		# Notify client that player left market
		if player.has_method("_on_exited_market"):
			player._on_exited_market(self)
		# Emit signal for server
		player_exited_interaction_area.emit(player, self)

func is_player_in_market(player: Player) -> bool:
	return player in players_in_market

func get_sell_price(item: Item) -> int:
	if not item.can_sell:
		return 0
	
	# Calculate base price (could be enhanced with item rarity, level, etc.)
	var base_price = item.minimum_price
	if base_price <= 0:
		# Default pricing based on item type
		base_price = _get_default_item_price(item)
	
	return int(base_price * sell_multiplier)

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
