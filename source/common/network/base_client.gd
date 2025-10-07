class_name BaseClient
extends Node


# Client Default Configuration / Set with load_client_configuration()
var address: String = "127.0.0.1"
var port: int = 8043
var certificate_path: String = "res://data/config/tls/certificate.crt"

# Client Components
var client: WebSocketMultiplayerPeer
var multiplayer_api: MultiplayerAPI
var authentication_callback := Callable()


func _process(_delta: float) -> void:
	if multiplayer_api and multiplayer_api.has_multiplayer_peer():
		multiplayer_api.poll()


func init_multiplayer_api(use_default: bool = false) -> void:
	multiplayer_api = (
		MultiplayerAPI.create_default_interface()
		if not use_default else multiplayer
	)
	
	multiplayer_api.connected_to_server.connect(_on_connection_succeeded)
	multiplayer_api.connection_failed.connect(_on_connection_failed)
	multiplayer_api.server_disconnected.connect(_on_server_disconnected)
	
	if authentication_callback:
		multiplayer_api.peer_authenticating.connect(_on_peer_authenticating)
		multiplayer_api.peer_authentication_failed.connect(_on_peer_authentication_failed)
		multiplayer_api.set_auth_callback(authentication_callback)
	
	get_tree().set_multiplayer(
		multiplayer_api,
		NodePath("") if use_default else get_path()
	)


func load_client_configuration(section_key: String, default_config_path: String = "") -> bool:
	var parsed_arguments := CmdlineUtils.get_parsed_args()
	
	var config_path := default_config_path
	var config_file := ConfigFile.new()
	if parsed_arguments.has("config"):
		config_path = parsed_arguments["config"]
	var error := config_file.load(config_path)
	if error != OK:
		printerr("Failed to load config at %s, error: %s" % [config_path, error_string(error)])
	else:
		address = config_file.get_value(section_key, "address", address)
		port = config_file.get_value(section_key, "port", port)
		certificate_path = config_file.get_value(section_key, "certificate_path", certificate_path)
	return true


func start_client() -> void:
	if not multiplayer_api:
		init_multiplayer_api()
	
	client = WebSocketMultiplayerPeer.new()
	
	var url: String
	var tls_options: TLSOptions
	
	# Only use WSS for external connections (not localhost)
	if address == "127.0.0.1" or address == "localhost":
		# Internal server connection - use WS without TLS
		url = "ws://" + address + ":" + str(port)
		tls_options = null
	else:
		# External/player connection - use WSS with TLS
		tls_options = TLSOptionsUtils.create_client_tls_options(certificate_path)
		if port == 443:
			url = "wss://" + address
		else:
			url = "wss://" + address + ":" + str(port)
	
	var error: Error = client.create_client(url, tls_options)
	if error != OK:
		printerr("Error while creating client: %s" % error_string(error))
	
	multiplayer_api.multiplayer_peer = client
	
	
func _on_connection_succeeded() -> void:
	print("Successfully connected as %d!" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	print("Failed to connect to the server.")


func _on_server_disconnected() -> void:
	print("Server disconnected.")


func _on_peer_authenticating(_peer_id: int) -> void:
	print("Trying to authenticate.")


func _on_peer_authentication_failed(_peer_id: int) -> void:
	print("Authentification failed.")
