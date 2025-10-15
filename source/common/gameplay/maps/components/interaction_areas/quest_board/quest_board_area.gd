@icon("res://assets/node_icons/blue/icon_grid.png")
class_name QuestBoardArea
extends InteractionArea
## Quest board interaction area where players can view and complete quests


signal player_exited_interaction_area(player: Player, interaction_area: InteractionArea)

@export var board_name: String = "Quest Board"

# Track players currently at quest board
var players_at_board: Array[Player] = []


func _ready() -> void:
	# Connect to player enter/exit events
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var player = body as Player
		if not player.just_teleported:
			players_at_board.append(player)
			# Emit signal for server
			player_entered_interaction_area.emit(player, self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		var player = body as Player
		players_at_board.erase(player)
		# Emit signal for server
		player_exited_interaction_area.emit(player, self)


func is_player_at_board(player: Player) -> bool:
	return player in players_at_board
