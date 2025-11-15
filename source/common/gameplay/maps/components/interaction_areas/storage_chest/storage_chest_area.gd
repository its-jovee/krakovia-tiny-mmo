@tool
@icon("res://assets/node_icons/blue/icon_grid.png")
extends InteractionArea
class_name StorageChestArea
## Family Crest storage area where players can access account-wide storage

@export var storage_name: String = "Family Crest"

# Track players currently at storage chest
var players_in_storage: Array[Player] = []

func _ready() -> void:
	# Connect to our own handlers for storage-specific logic
	# Parent already handles the player_entered_interaction_area signal emission
	player_entered_interaction_area.connect(_on_player_entered_storage_area)
	player_exited_interaction_area.connect(_on_player_exited_storage_area)

func _on_player_entered_storage_area(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters storage area"""
	# Defensive check: Ensure player_resource is initialized
	if not player.player_resource:
		print("[StorageChestArea] ⚠️ Player resource not yet initialized for %s, skipping" % player.name)
		return
	
	players_in_storage.append(player)
	print("[StorageChestArea] Player %s entered storage area" % player.player_resource.display_name)

func _on_player_exited_storage_area(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits storage area"""
	players_in_storage.erase(player)
	if player.player_resource:
		print("[StorageChestArea] Player %s exited storage area" % player.player_resource.display_name)
	else:
		print("[StorageChestArea] Player exited storage area")

func is_player_in_storage(player: Player) -> bool:
	return player in players_in_storage
