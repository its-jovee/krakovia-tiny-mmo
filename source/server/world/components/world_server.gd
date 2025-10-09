class_name WorldServer
extends BaseServer
## Server autoload. Keep it clean and minimal.
## Should only care about connection and authentication stuff.

@export var database: WorldDatabase
@export var world_manager: WorldManagerClient

var token_list: Dictionary[String, PlayerResource]

var connected_players: Dictionary[int, PlayerResource]


func start_world_server() -> void:
	world_manager.token_received.connect(
		func(auth_token: String, _username: String, character_id: int):
			var player: PlayerResource = database.player_data.get_player_resource(character_id)
			token_list[auth_token] = player
	)
	
	authentication_callback = _authentication_callback
	load_server_configuration("world-server", "res://data/config/world_config.cfg")
	start_server()
	
	$InstanceManager.start_instance_manager()


func _on_peer_connected(peer_id: int) -> void:
	print("Peer: %d is connected." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer: %d is disconnected." % peer_id)
	
	# Save player data immediately on disconnect to prevent data loss
	if connected_players.has(peer_id):
		database.save_world_database()
		world_manager.player_disconnected.rpc_id(
			1,
			connected_players[peer_id].account_name
		)
		connected_players.erase(peer_id)


func _on_peer_authenticating(peer_id: int) -> void:
	print("Peer: %d is trying to authenticate." % peer_id)
	multiplayer.send_auth(peer_id, "data_from_server".to_ascii_buffer())


func _on_peer_authentication_failed(peer_id: int) -> void:
	print("Peer: %d failed to authenticate." % peer_id)


func _authentication_callback(peer_id: int, data: PackedByteArray) -> void:
	var auth_token := bytes_to_var(data) as String
	print("Peer: %d is trying to connect with data: \"%s\"." % [peer_id, auth_token])
	if is_valid_authentication_token(auth_token):
		var player_resource: PlayerResource = token_list[auth_token]
		# Check if player is banned
		if database.player_data.is_banned(player_resource.account_name):
			print("Peer: %d (%s) is banned. Connection rejected." % [peer_id, player_resource.account_name])
			server.disconnect_peer(peer_id)
			token_list.erase(auth_token)
			return
		multiplayer.complete_auth(peer_id)
		connected_players[peer_id] = player_resource
		token_list.erase(auth_token)
	else:
		server.disconnect_peer(peer_id)


func is_valid_authentication_token(auth_token: String) -> bool:
	if token_list.has(auth_token):
		return true
	return false
