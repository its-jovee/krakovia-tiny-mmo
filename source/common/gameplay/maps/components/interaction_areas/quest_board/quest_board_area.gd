@icon("res://assets/node_icons/blue/icon_grid.png")
class_name QuestBoardArea
extends InteractionArea
## Quest board interaction area where players can view and complete quests

@export var board_name: String = "Quest Board"

# Track players currently at quest board
var players_at_board: Array[Player] = []


func _ready() -> void:
	# Connect to parent's signals for quest board-specific logic
	# Parent already handles the player_entered/exited_interaction_area signal emission
	player_entered_interaction_area.connect(_on_player_entered_quest_board)
	player_exited_interaction_area.connect(_on_player_exited_quest_board)


func _on_player_entered_quest_board(player: Player, _area: InteractionArea) -> void:
	"""Called when player enters quest board - add quest board-specific logic"""
	players_at_board.append(player)


func _on_player_exited_quest_board(player: Player, _area: InteractionArea) -> void:
	"""Called when player exits quest board - remove from tracking"""
	players_at_board.erase(player)


func is_player_at_board(player: Player) -> bool:
	return player in players_at_board
