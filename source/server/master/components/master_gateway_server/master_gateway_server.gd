class_name GatewayManagerServer
extends BaseServer


@export var world_manager: WorldManagerServer
@export var authentication_manager: AuthenticationManager
@export var database: MasterDatabase


func _ready() -> void:
	load_server_configuration("gateway-manager-server", "res://data/config/master_config.cfg")
	start_server()


func _on_peer_connected(peer_id: int) -> void:
	print("Gateway: %d is connected to GatewayManager." % peer_id)
	update_worlds_info.rpc_id(peer_id, world_manager.connected_worlds)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Gateway: %d is disconnected to GatewayManager." % peer_id)


@rpc("authority")
func update_worlds_info(_worlds_info: Dictionary) -> void:
	pass


# Send an authentication auth_token to the gateway for a specific peer,
# used by the peer to connect to a game server.
@rpc("authority")
func fetch_auth_token(_target_peer: int, _auth_token: String, _address: String, _port: int) -> void:
	pass


@rpc("any_peer")
func login_request(peer_id: int, handle: String, password: String) -> void:
	var gateway_id := multiplayer.get_remote_sender_id()
	var account: AccountResource = database.validate_credentials(
		handle, password
	)
	if not account:
		login_result.rpc_id(gateway_id, peer_id, {"error": 50})
	elif account.peer_id:
		login_result.rpc_id(gateway_id, peer_id, {"error": 51})
	else:
		account.peer_id = peer_id
		login_result.rpc_id(
			gateway_id, peer_id,
			{"name": account.handle, "id": account.id}
		)


@rpc("authority")
func login_result(_peer_id: int, _result: Dictionary) -> void:
	pass



@rpc("any_peer")
func create_account_request(peer_id: int, handle: String, password: String, is_guest: bool) -> void:
	var gateway_id: int = multiplayer_api.get_remote_sender_id()
	var result_code: int = 0
	var return_data: Dictionary = {}
	var result: AccountResource = authentication_manager.create_account(handle, password, is_guest)
	if result == null:
		result_code = 30
	else:
		return_data = {"name": result.handle, "id": result.id}
		result.peer_id = peer_id
	account_creation_result.rpc_id(gateway_id, peer_id, result_code, return_data)



@rpc("authority")
func account_creation_result(_peer_id: int, _result_code: int, _data: Dictionary) -> void:
	pass


# Used to create the player's character.
@rpc("any_peer")
func create_player_character_request(peer_id: int, handle: String, character_data: Dictionary, world_id: int) -> void:
	var gateway_id := multiplayer_api.get_remote_sender_id()
	if database.account_collection.collection.has(handle):
		var account := database.account_collection.collection[handle] as AccountResource
		if account.peer_id == peer_id and world_manager.connected_worlds.has(world_id):
			world_manager.create_player_character_request.rpc_id(
				world_id, gateway_id, peer_id, account.handle, character_data
			)
		#else:
			#player_character_creation_result.rpc_id(gateway_id, peer_id, 80)


@rpc("authority")
func player_character_creation_result(_peer_id: int, result: Dictionary) -> void:
	pass


@rpc("any_peer")
func request_player_characters(peer_id: int, handle: String, world_id: int) -> void:
	var gateway_id := multiplayer_api.get_remote_sender_id()
	if (
		world_manager.connected_worlds.has(world_id)
		and database.account_collection.collection.has(handle)
	):
		var account := database.account_collection.collection[handle] as AccountResource
		if account.peer_id == peer_id:
			world_manager.request_player_characters.rpc_id(
				world_id,
				gateway_id,
				peer_id,
				handle,
			)


@rpc("authority")
func receive_player_characters(_player_characters: Dictionary) -> void:
	pass


@rpc("any_peer")
func request_login(peer_id: int, username: String, world_id: int, character_id: int) -> void:
	var gateway_id := multiplayer_api.get_remote_sender_id()
	if (
		world_manager.connected_worlds.has(world_id)
		and database.account_collection.collection.has(username)
		and database.account_collection.collection[username].peer_id == peer_id
	):
		world_manager.request_login.rpc_id(
			world_id,
			gateway_id,
			peer_id,
			username,
			character_id
		)


@rpc("any_peer")
func peer_disconnected_without_joining_world(account_name: String) -> void:
	if database.account_collection.collection.has(account_name):
		database.account_collection.collection[account_name].peer_id = 0
