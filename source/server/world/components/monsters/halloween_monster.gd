class_name HalloweenMonster
extends Node2D
## Server-authoritative Halloween Monster - static hazard that teleports touching players to spawn


var touch_distance: float = 48.0  # Distance to detect player touch
var sprite_offset: Vector2 = Vector2(0, -36)  # Match the sprite's position offset

var server_instance: ServerInstance


func _ready() -> void:
	print("[HalloweenMonster] _ready() called! Is server: ", multiplayer.is_server())


func initialize(instance: ServerInstance) -> void:
	server_instance = instance
	print("[HalloweenMonster] Initialized at position: ", global_position)


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	if not server_instance:
		return
	
	# Monster's visual center (where the sprite actually is)
	var monster_center := global_position + sprite_offset
	
	# Check all players for touch
	for peer_id: int in server_instance.players_by_peer_id:
		var player: Player = server_instance.players_by_peer_id[peer_id]
		if not player or not is_instance_valid(player):
			continue
		
		# Check distance from monster's visual center to player's center (slightly above feet)
		var player_center := player.global_position + Vector2(0, -16)
		var distance_to_player := monster_center.distance_to(player_center)
		if distance_to_player <= touch_distance:
			_on_touch_player(player)


func _on_touch_player(player: Player) -> void:
	print("[HalloweenMonster] Touched player: ", player.name, " - sending to spawn!")
	
	# Send player back to spawn
	player.just_teleported = true
	player.syn.set_by_path(^":position", server_instance.instance_map.get_spawn_position(0))

