class_name GatewayManagerClient
extends BaseClient


signal account_creation_result_received(user_id: int, result_code: int, data: Dictionary)
signal login_succeeded(account_info: Dictionary, _worlds_info: Dictionary)
signal response_received(response: Dictionary)

@export var gateway: GatewayServer

var worlds_info: Dictionary


func _ready() -> void:
	load_client_configuration("gateway-manager-client", "res://data/config/gateway_config.cfg")
	start_client()


func _on_connection_succeeded() -> void:
	print("Successfully connected to the Gateway Manager as %d!" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	print("Failed to connect to the Gateway Manager as Gateway.")
	# Try to reconnect.
	get_tree().create_timer(15.0).timeout.connect(start_client)


func _on_server_disconnected() -> void:
	print("Gateway Manager disconnected.")
	# Try to reconnect.
	get_tree().create_timer(15.0).timeout.connect(start_client)


@rpc("authority")
func update_worlds_info(_worlds_info: Dictionary) -> void:
	worlds_info = _worlds_info


@rpc("authority")
func fetch_auth_token(target_peer: int, auth_token: String, _address: String, _port: int) -> void:
	response_received.emit(
		{"t-id": target_peer, "token": auth_token, "adress": _address, "port": _port}
	)
	#gateway.connected_peers[target_peer]["token_received"] = true
	#gateway.fetch_auth_token.rpc_id(target_peer, auth_token, _address, _port)


@rpc("any_peer")
func login_request(_peer_id: int, _username: String, _password: String) -> void:
	pass


@rpc("authority")
func login_result(peer_id: int, result: Dictionary) -> void:
	if result.has("error"):
		response_received.emit(
			{"t-id": peer_id, "a": result, "w": worlds_info, "error": result}
		)
		#gateway.login_result.rpc_id(peer_id, result["error"])
	else:
		#gateway.login_result.rpc_id(peer_id, 0)
		#login_succeeded.emit(peer_id, result, worlds_info)
		response_received.emit(
			{"t-id": peer_id, "a": result, "w": worlds_info}
		)


@rpc("any_peer")
func create_account_request(_peer_id: int, _username: String, _password: String, _is_guest: bool) -> void:
	pass


@rpc("authority")
func account_creation_result(peer_id: int, result_code: int, result: Dictionary) -> void:
	if result_code == OK:
		#login_succeeded.emit(peer_id, result, worlds_info)
		response_received.emit(
			{"t-id": peer_id, "a": result, "w": worlds_info}
		)
	else:
		# Handle error cases
		response_received.emit(
			{"t-id": peer_id, "error": result_code}
		)
	#gateway.account_creation_result.rpc_id(peer_id, result_code)


@rpc("any_peer")
func create_player_character_request(_peer_id: int , _username: String, _character_data: Dictionary, _world_id: int) -> void:
	pass


@rpc("authority")
func player_character_creation_result(peer_id: int, result: Dictionary) -> void:
	response_received.emit(
		{"t-id": peer_id, "data": result}
	)
	#gateway.player_character_creation_result.rpc_id(
		#peer_id, result_code
	#)


@rpc("any_peer")
func request_player_characters(_peer_id: int, _username: String, _world_id: int) -> void:
	pass


@rpc("authority")
func receive_player_characters(peer_id: int, player_characters: Dictionary) -> void:
	response_received.emit(
		{"t-id": peer_id, "data": player_characters}
	)
	#gateway.receive_player_characters.rpc_id(peer_id, player_characters)


@rpc("any_peer")
func request_login(_peer_id: int, _username: String, _world_id: int, _character_id: int) -> void:
	pass


@rpc("any_peer")
func peer_disconnected_without_joining_world(_account_name: String) -> void:
	pass


#@rpc("any_peer")
#func request_world_info() -> void:
	#pass
#
#
#@rpc("authority")
#func receive_world_info(world_info: Dictionary) -> void:
	#response_received.emit(worlds_info)
