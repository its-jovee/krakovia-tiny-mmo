class_name BotManager
extends Node
## Manages all bot NPCs within a ServerInstance.
## Bots are Player instances with negative entity IDs that are server-controlled.

signal bot_spawned(bot: Player, entity_id: int)
signal bot_despawned(entity_id: int)

const PLAYER_SCENE: PackedScene = preload("res://source/common/gameplay/characters/player/player.tscn")

var server_instance: ServerInstance
var bots_by_entity_id: Dictionary[int, Player] = {}
var controllers_by_entity_id: Dictionary[int, BotController] = {}

var _next_entity_id: int = -1000
var _update_accumulator: float = 0.0
var _update_interval: float = 0.1  # 10 Hz bot updates

enum ActivityMode {
	ACTIVE,      ## Full activity rate (1.0x)
	REDUCED,     ## Reduced rate for offline characters (0.25x)
	DECORATIVE   ## Minimal activity for background NPCs (0.1x)
}


func _ready() -> void:
	set_process(true)
	print("[BotManager] Initialized for instance")


func _process(delta: float) -> void:
	_update_accumulator += delta
	if _update_accumulator >= _update_interval:
		var tick_delta: float = _update_accumulator
		_update_accumulator = 0.0
		_tick_all_bots(tick_delta)


func _tick_all_bots(delta: float) -> void:
	for entity_id: int in controllers_by_entity_id:
		var controller: BotController = controllers_by_entity_id[entity_id]
		controller.tick(delta)


## Scan the instance map for BotSpawnPoint markers and spawn bots at each location.
func spawn_bots_from_map() -> void:
	if not server_instance or not server_instance.instance_map:
		push_warning("[BotManager] Cannot spawn bots - no instance map available")
		return

	# Use find_children to search recursively - more reliable than manual recursion
	# Search by class name string as fallback if class_name isn't registered
	var spawn_points: Array[Node] = server_instance.instance_map.find_children("*", "BotSpawnPoint", true, false)

	# Debug: Also try finding by script if class search fails
	if spawn_points.is_empty():
		print("[BotManager] No BotSpawnPoint class found, trying script-based search...")
		spawn_points = _find_spawn_points_by_script(server_instance.instance_map)

	print("[BotManager] Found %d bot spawn points" % spawn_points.size())

	for spawn_point in spawn_points:
		# Check if it has the expected properties (duck typing)
		if spawn_point.has_method("get_dialogue_array") and "bot_name" in spawn_point:
			spawn_bot(
				spawn_point.bot_name,
				spawn_point.bot_class,
				spawn_point.global_position,
				ActivityMode.ACTIVE,  # Changed from DECORATIVE for testing
				{
					"head_id": spawn_point.appearance_head_id,
					"wander_radius": spawn_point.wander_radius,
					"dialogue": spawn_point.get_dialogue_array()
				}
			)
		else:
			push_warning("[BotManager] Found spawn point but missing expected properties: %s" % spawn_point.name)


## Fallback: Find spawn points by checking if they have the BotSpawnPoint script attached
func _find_spawn_points_by_script(node: Node) -> Array[Node]:
	var results: Array[Node] = []
	var script = node.get_script()
	if script:
		var script_path: String = script.resource_path if script.resource_path else ""
		if "bot_spawn_point" in script_path.to_lower():
			results.append(node)
			print("[BotManager] Found spawn point by script: %s at %s" % [node.name, node.get_path()])
	for child in node.get_children():
		results.append_array(_find_spawn_points_by_script(child))
	return results


## Spawn a new bot and return its entity ID.
func spawn_bot(
	display_name: String,
	character_class: String,
	position: Vector2,
	activity_mode: ActivityMode = ActivityMode.DECORATIVE,
	options: Dictionary = {}
) -> int:
	var entity_id: int = _allocate_entity_id()
	print("[BotManager] Spawning bot '%s' (class: %s) at %s with ID %d" % [display_name, character_class, position, entity_id])

	# Load character resource
	var character_resource_path: String = (
		"res://source/common/gameplay/characters/classes/character_collection/" +
		character_class + ".tres"
	)
	var character_resource: CharacterResource = ResourceLoader.load(character_resource_path)
	if not character_resource:
		push_error("[BotManager] Failed to load character resource: %s" % character_resource_path)
		return 0

	# Create Player instance (same as real players)
	var bot: Player = PLAYER_SCENE.instantiate() as Player
	if not bot:
		push_error("[BotManager] Failed to instantiate player scene!")
		return 0

	bot.name = "Bot_%d" % entity_id
	bot.peer_id = entity_id

	# Create a minimal PlayerResource for the bot
	var bot_resource: PlayerResource = PlayerResource.new()
	bot_resource.display_name = display_name
	bot_resource.character_class = character_class
	bot_resource.appearance_head_id = options.get("head_id", "head_a")
	bot_resource.account_name = "_bot_%d" % entity_id
	bot_resource.player_id = entity_id
	bot.player_resource = bot_resource

	# Set character resource BEFORE adding to tree (like instantiate_player does)
	bot.character_resource = character_resource
	bot.character_class = character_class
	bot.appearance_head_id = bot_resource.appearance_head_id

	# Store references early so they're available in the ready callback
	bots_by_entity_id[entity_id] = bot

	# Create controller early
	var controller: BotController = BotController.new()
	controller.bot = bot
	controller.entity_id = entity_id
	controller.activity_mode = activity_mode
	controller.home_position = position
	controller.wander_radius = options.get("wander_radius", 150.0)
	controller.dialogue_pool = options.get("dialogue", [])
	controller.server_instance = server_instance
	controllers_by_entity_id[entity_id] = controller

	# Setup synchronizer in ready callback (like instantiate_player does)
	bot.ready.connect(func():
		var syn: StateSynchronizer = bot.syn
		if not syn:
			push_error("[BotManager] Bot has no StateSynchronizer!")
			return

		syn.set_by_path(^":position", position)
		syn.set_by_path(^":character_class", character_class)
		syn.set_by_path(^":display_name", display_name)
		syn.set_by_path(^":handle_name", "")  # Bots have no handle
		syn.set_by_path(^":appearance_head_id", bot_resource.appearance_head_id)
		syn.set_by_path(^":anim", Character.Animations.IDLE)
		syn.set_by_path(^":flipped", false)
		syn.set_by_path(^":title_text", "")
		syn.set_by_path(^":title_rarity", 0)

		# Register with sync manager
		server_instance.synchronizer_manager.add_entity(entity_id, syn)

		# Setup controller
		controller.setup()

		# Notify existing clients
		_spawn_bot_to_clients(entity_id)

		print("[BotManager] Bot '%s' (ID: %d) ready and synced" % [display_name, entity_id])
		bot_spawned.emit(bot, entity_id)
	)

	# Add to map (triggers _ready)
	server_instance.instance_map.add_child(bot, true)

	# Position bot
	bot.global_position = position

	return entity_id


func _spawn_bot_to_clients(entity_id: int) -> void:
	if server_instance.connected_peers.is_empty():
		print("[BotManager] No connected peers to send bot %d to" % entity_id)
		return

	var bot: Player = bots_by_entity_id[entity_id]
	var syn: StateSynchronizer = bot.syn
	var baseline_pairs: Array = syn.capture_baseline()

	print("[BotManager] Bot %d baseline pairs: %s" % [entity_id, baseline_pairs])

	if baseline_pairs.is_empty():
		push_warning("[BotManager] No baseline data for bot %d" % entity_id)
		return

	# Send baseline to each connected peer
	for peer_id: int in server_instance.connected_peers:
		var objects: Array = [{ "eid": entity_id, "pairs": baseline_pairs }]
		var payload: PackedByteArray = WireCodec.encode_bootstrap([], objects)
		server_instance.synchronizer_manager.on_bootstrap.rpc_id(peer_id, payload)

	# Send spawn command to all peers
	for peer_id: int in server_instance.connected_peers:
		server_instance.spawn_player.rpc_id(peer_id, entity_id)


## Despawn a bot by entity ID.
func despawn_bot(entity_id: int) -> void:
	if not bots_by_entity_id.has(entity_id):
		return

	var bot: Player = bots_by_entity_id[entity_id]

	# Remove from sync manager
	server_instance.synchronizer_manager.remove_entity(entity_id)

	# Notify clients
	for peer_id: int in server_instance.connected_peers:
		server_instance.despawn_player.rpc_id(peer_id, entity_id)

	# Cleanup
	controllers_by_entity_id.erase(entity_id)
	bots_by_entity_id.erase(entity_id)
	bot.queue_free()

	print("[BotManager] Despawned bot ID: %d" % entity_id)
	bot_despawned.emit(entity_id)


## Despawn all bots.
func despawn_all_bots() -> void:
	var ids_to_remove: Array[int] = []
	for entity_id: int in bots_by_entity_id:
		ids_to_remove.append(entity_id)
	for entity_id: int in ids_to_remove:
		despawn_bot(entity_id)


## Called when a new player joins - send all existing bots to them.
func send_bots_to_peer(peer_id: int) -> void:
	print("[BotManager] Sending %d bots to peer %d" % [bots_by_entity_id.size(), peer_id])
	for entity_id: int in bots_by_entity_id:
		var bot: Player = bots_by_entity_id[entity_id]
		var syn: StateSynchronizer = bot.syn
		var baseline_pairs: Array = syn.capture_baseline()

		print("[BotManager] Sending bot %d to peer %d, baseline: %s" % [entity_id, peer_id, baseline_pairs])

		if not baseline_pairs.is_empty():
			var objects: Array = [{ "eid": entity_id, "pairs": baseline_pairs }]
			var payload: PackedByteArray = WireCodec.encode_bootstrap([], objects)
			server_instance.synchronizer_manager.on_bootstrap.rpc_id(peer_id, payload)

		server_instance.spawn_player.rpc_id(peer_id, entity_id)


## Broadcast a chat message from a bot.
func broadcast_bot_chat(entity_id: int, message: String) -> void:
	if not bots_by_entity_id.has(entity_id):
		return

	var bot: Player = bots_by_entity_id[entity_id]
	var chat_data: Dictionary = {
		"text": message,
		"display_name": bot.player_resource.display_name,
		"id": entity_id,
		"is_bot": true
	}

	server_instance.propagate_rpc(server_instance.data_push.bind(&"chat.message", chat_data))


func _allocate_entity_id() -> int:
	var id: int = _next_entity_id
	_next_entity_id -= 1
	return id


## Get bot count.
func get_bot_count() -> int:
	return bots_by_entity_id.size()
