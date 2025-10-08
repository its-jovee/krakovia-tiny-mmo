class_name WorldManagerClient
extends BaseClient


signal token_received(auth_token: String, username: String, character_id: int)

@export var database: WorldDatabase
@export var world_server: WorldServer

var world_info: Dictionary


func start_client_to_master_server(_world_info: Dictionary) -> void:
	world_info = _world_info
	load_client_configuration("world-manager-client", "res://data/config/world_config.cfg")
	start_client()


func _on_connection_succeeded() -> void:
	print("Successfully connected to the Gateway as %d!" % multiplayer.get_unique_id())
	
	# Auto-detect environment
	var address = "kraftovia.com/ws" if OS.has_feature("template") else "127.0.0.1"
	var port = 443 if OS.has_feature("template") else 8087
	
	fetch_server_info.rpc_id(
		1,
		{
			"port": port,
			"address": address,
			"info": world_info,
			"population": world_server.connected_players.size()
		}
	)


func _on_connection_failed() -> void:
	print("Failed to connect to the MasterServer as WorldServer.")


func _on_server_disconnected() -> void:
	print("Game Server disconnected.")


@rpc("any_peer")
func fetch_server_info(_info: Dictionary) -> void:
	pass


@rpc("authority")
func fetch_token(auth_token: String, username: String, character_id: int) -> void:
	token_received.emit(auth_token, username, character_id)


@rpc("any_peer")
func player_disconnected(_username: String) -> void:
	pass


@rpc("authority")
func create_player_character_request(gateway_id: int, peer_id: int, handle: String, character_data: Dictionary) -> void:
	player_character_creation_result.rpc_id(
		1,
		gateway_id,
		peer_id,
		handle,
		database.player_data.create_player_character(handle, character_data)
	)


@rpc("any_peer")
func player_character_creation_result(_gateway_id: int, _peer_id: int, _handle: String, _result_code: int) -> void:
	pass


@rpc("authority")
func request_player_characters(gateway_id: int, peer_id: int, handle: String) -> void:
	receive_player_characters.rpc_id(
		1,
		database.player_data.get_account_characters(handle),
		gateway_id,
		peer_id
	)


@rpc("any_peer")
func receive_player_characters(_gateway_id: int, _peer_id: int, _player_characters: Dictionary) -> void:
	pass


@rpc("authority")
func request_login(
	gateway_id: int,
	peer_id: int,
	handle: String,
	character_id: int
) -> void:
	if (
		database.player_data.players.has(character_id)
		and database.player_data.players[character_id].account_name == handle
	):
		result_login.rpc_id(
			1,
			OK,
			gateway_id,
			peer_id,
			handle,
			character_id,
		)


@rpc("any_peer")
func result_login(
	_result_code: int,
	_gateway_id: int,
	_peer_id: int,
	_handle: String,
	_character_id: int
) -> void:
	pass
