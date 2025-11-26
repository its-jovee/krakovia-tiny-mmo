class_name WorldServer
extends BaseServer
## Server autoload. Keep it clean and minimal.
## Should only care about connection and authentication stuff.

@export var database: WorldDatabase
@export var world_manager: WorldManagerClient

## Market price decay interval in seconds (default: 5 minutes)
@export var market_decay_interval: float = 300.0

## Market event interval in minutes
@export var event_interval_minutes: int = 30

var token_list: Dictionary[String, PlayerResource]

var connected_players: Dictionary[int, PlayerResource]

var _decay_timer: Timer
var _event_manager: MarketEventManager


func start_world_server() -> void:
	# Set up market price decay timer
	_setup_market_decay_timer()
	
	# Set up market event manager
	_setup_event_manager()
	
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


func _setup_market_decay_timer() -> void:
	_decay_timer = Timer.new()
	_decay_timer.wait_time = market_decay_interval
	_decay_timer.autostart = true
	_decay_timer.timeout.connect(_on_market_decay_tick)
	add_child(_decay_timer)
	print("[WorldServer] Market decay timer started (interval: %.0fs)" % market_decay_interval)


func _on_market_decay_tick() -> void:
	if database and database.market_data:
		database.market_data.apply_decay()
		# Save after decay to persist the changes
		database.save_world_database()
		print("[WorldServer] Market prices decayed toward equilibrium")


func _setup_event_manager() -> void:
	"""Initialize the market event manager"""
	_event_manager = MarketEventManager.new()
	_event_manager.name = "MarketEventManager"
	_event_manager.world_server = self
	_event_manager.event_interval_minutes = event_interval_minutes
	
	# Load event definitions from resources
	_load_event_pool()
	
	add_child(_event_manager)
	print("[WorldServer] Market event manager started (interval: %d min)" % event_interval_minutes)


func _load_event_pool() -> void:
	"""Load all market event resources from the events folder"""
	var events_path = "res://source/server/world/events/definitions/"
	
	var dir = DirAccess.open(events_path)
	if not dir:
		print("[WorldServer] No events folder found at %s, creating empty pool" % events_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var event_path = events_path + file_name
			var event = ResourceLoader.load(event_path) as MarketEvent
			if event:
				_event_manager.event_pool.append(event)
				print("[WorldServer] Loaded event: %s %s" % [event.icon, event.title])
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("[WorldServer] Loaded %d market events" % _event_manager.event_pool.size())


func get_event_manager() -> MarketEventManager:
	"""Get the market event manager"""
	return _event_manager
