@icon("res://assets/node_icons/blue/icon_grid.png")
class_name LeaderboardArea
extends InteractionArea
## Leaderboard interaction area where players can view rankings

@export var board_name: String = "Leaderboard"

# Track players currently at leaderboard
var players_at_board: Array[Player] = []


func _ready() -> void:
	# Connect to parent's signals for leaderboard-specific logic
	# Parent already handles the player_entered/exited_interaction_area signal emission
	player_entered_interaction_area.connect(_on_player_entered_leaderboard)
	player_exited_interaction_area.connect(_on_player_exited_leaderboard)


func _on_player_entered_leaderboard(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters leaderboard - add leaderboard-specific logic"""
	players_at_board.append(player)


func _on_player_exited_leaderboard(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits leaderboard - remove from tracking"""
	players_at_board.erase(player)


func is_player_at_board(player: Player) -> bool:
	return player in players_at_board


