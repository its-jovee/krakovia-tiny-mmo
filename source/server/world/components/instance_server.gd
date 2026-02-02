class_name ServerInstance
extends SubViewport


signal player_entered_warper(player: Player, current_instance: ServerInstance, warper: Warper)

const PLAYER: PackedScene = preload("res://source/common/gameplay/characters/player/player.tscn")

static var world_server: WorldServer

static var global_chat_commands: Dictionary[String, ChatCommand]
static var global_role_definitions: Dictionary[String, Dictionary]

var local_chat_commands: Dictionary[String, ChatCommand]
var local_role_definitions: Dictionary[String, Dictionary]
var local_role_assignments: Dictionary[int, PackedStringArray]

var players_by_peer_id: Dictionary[int, Player]
## Current connected peers to the instance.
var connected_peers: PackedInt64Array = PackedInt64Array()
## Peers coming from another instance.
var awaiting_peers: Dictionary = {}#[int, Player]

var last_accessed_time: float

var instance_map: Map
var instance_resource: InstanceResource

var synchronizer_manager: StateSynchronizerManagerServer

var request_handlers: Dictionary[StringName, DataRequestHandler]

var harvest_manager: HarvestManager


func _ready() -> void:
	world_server.multiplayer_api.peer_disconnected.connect(
		func(peer_id: int):
			if connected_peers.has(peer_id):
				# Cancel any active trades for this peer
				if has_node("TradeManager"):
					var trade_mgr: TradeManager = get_node("TradeManager")
					for session_id in trade_mgr.active_trades.keys():
						var session = trade_mgr.active_trades[session_id]
						if session.peer_a == peer_id or session.peer_b == peer_id:
							trade_mgr.cancel_trade(session_id, peer_id)
							break
				
				# Close any open shops for this peer
				if has_node("ShopManager"):
					var shop_mgr: ShopManager = get_node("ShopManager")
					if shop_mgr.has_shop(peer_id):
						shop_mgr.close_shop(peer_id)
				
				despawn_player(peer_id)
				# Ensure database captures persisted energy immediately on disconnect
				if world_server and world_server.database:
					world_server.database.save_world_database()
	)
	
	synchronizer_manager = StateSynchronizerManagerServer.new()
	synchronizer_manager.name = "StateSynchronizerManager"
	
	add_child(synchronizer_manager, true)
	
	# Add TradeManager
	var trade_mgr = TradeManager.new()
	trade_mgr.name = "TradeManager"
	add_child(trade_mgr, true)
	
	# Add HarvestManager
	harvest_manager = HarvestManager.new()
	harvest_manager.name = "HarvestManager"
	add_child(harvest_manager, true)
	
	# Add QuestManager
	var quest_mgr = QuestManager.new()
	quest_mgr.name = "QuestManager"
	add_child(quest_mgr, true)
	
	# Add ShopManager
	var shop_mgr = ShopManager.new()
	shop_mgr.name = "ShopManager"
	add_child(shop_mgr, true)
	
	# Add TitleProgressTracker
	var title_tracker = TitleProgressTracker.new()
	title_tracker.name = "TitleProgressTracker"
	add_child(title_tracker, true)
	
	# Add LeaderboardManager
	var LeaderboardManagerClass = load("res://source/server/world/components/leaderboard_manager.gd")
	if LeaderboardManagerClass:
		var leaderboard_mgr = LeaderboardManagerClass.new()
		leaderboard_mgr.name = "LeaderboardManager"
		leaderboard_mgr.world_server = world_server
		add_child(leaderboard_mgr, true)

	# Add BotManager
	var bot_mgr = BotManager.new()
	bot_mgr.name = "BotManager"
	bot_mgr.server_instance = self
	add_child(bot_mgr, true)


func load_map(map_path: String) -> void:
	if instance_map:
		instance_map.queue_free()
	instance_map = load(map_path).instantiate()
	add_child(instance_map)
	#add_child(CameraProbe.new())
	
	ready.connect(func():
		if instance_map.replicated_props_container:
			synchronizer_manager.add_container(1_000_000, instance_map.replicated_props_container)
		
		# FIX: Search recursively for all InteractionAreas, not just direct children
		# This ensures nested areas (like MarketArea under Components) are connected
		var interaction_areas = instance_map.find_children("*", "InteractionArea", true, false)
		print("[ServerInstance] Found %d InteractionArea(s) in map" % interaction_areas.size())
		
		for child in interaction_areas:
			if child is InteractionArea:
				child.player_entered_interaction_area.connect(self._on_player_entered_interaction_area)
				if child.has_signal("player_exited_interaction_area"):
					child.player_exited_interaction_area.connect(self._on_player_exited_interaction_area)
				print("[ServerInstance] ✅ Connected InteractionArea: %s at path: %s" % [child.name, child.get_path()])
		
		# Reindex harvest nodes after map loads
		if harvest_manager:
			harvest_manager.reindex_existing()
		
		# Initialize vendor data for all vendors in the map
		_initialize_vendors()
		
		# Initialize Halloween Monster if present
		_initialize_halloween_monster()

		# Spawn worker bots (Rocky, Fern, Jack walking near their stations)
		_initialize_worker_bots()

		# Spawn ambient bots from BotSpawnPoint markers in the map
		if has_node("BotManager"):
			var bot_mgr: BotManager = get_node("BotManager")
			bot_mgr.spawn_bots_from_map()
		)


func _on_player_entered_interaction_area(player: Player, interaction_area: InteractionArea) -> void:
	if player.just_teleported:
		return
	if interaction_area is Warper:
		player_entered_warper.emit.call_deferred(player, self, interaction_area)
	if interaction_area is Teleporter:
		if not player.just_teleported:
			player.just_teleported = true
			player.syn.set_by_path(^":position", interaction_area.target.global_position)
	if interaction_area is MarketArea:
		# Notify client about market status
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"market.status", {"in_market": true})
			# Also push current market prices for dynamic pricing display
			_push_market_prices(peer_id, interaction_area as MarketArea)
	if interaction_area is QuestBoardArea:
		# Notify client about quest board status
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"quest_board.status", {"in_quest_board": true})
	if interaction_area is StorageChestArea:
		# Notify client about storage chest status
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"storage_chest.status", {"in_storage_area": true})
	# Check for LeaderboardArea by name since runtime type checking is tricky
	if interaction_area.name == "LeaderboardArea":
		# Notify client about leaderboard status
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"leaderboard.status", {"in_leaderboard": true})
	if interaction_area is VendorArea:
		# Notify client about vendor - this auto-opens the vendor UI
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:
			var vendor = interaction_area as VendorArea
			print("[ServerInstance] Player %d entered VendorArea: %s (%s)" % [peer_id, vendor.vendor_name, vendor.vendor_id])
			data_push.rpc_id(peer_id, &"vendor.status", {
				"in_vendor": true,
				"vendor": vendor.get_vendor_info()
			})
	if interaction_area is WorkerArea:
		# Notify client about worker area - this auto-opens the worker hire UI
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:
			var worker = interaction_area as WorkerArea
			print("[ServerInstance] Player %d entered WorkerArea: %s (%s)" % [peer_id, worker.worker_name, worker.worker_type])
			
			# Check if player has completed jobs for this worker
			var has_completed = false
			if player.player_resource:
				var completed = player.player_resource.get_completed_jobs(worker.worker_type)
				has_completed = completed.size() > 0
			
			data_push.rpc_id(peer_id, &"worker.area.status", {
				"in_worker_area": true,
				"worker_type": worker.worker_type,
				"worker_id": worker.worker_id,
				"worker_name": worker.worker_name,
				"worker_icon": worker.worker_icon,
				"has_completed_jobs": has_completed
			})

func _on_player_exited_interaction_area(player: Player, interaction_area: InteractionArea) -> void:
	if interaction_area is MarketArea:
		# Notify client that they left market
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"market.status", {"in_market": false})
	if interaction_area is QuestBoardArea:
		# Notify client that they left quest board
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"quest_board.status", {"in_quest_board": false})
	if interaction_area is StorageChestArea:
		# Notify client that they left storage chest
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"storage_chest.status", {"in_storage_area": false})
	# Check for LeaderboardArea by name since runtime type checking is tricky
	if interaction_area.name == "LeaderboardArea":
		# Notify client that they left leaderboard
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"leaderboard.status", {"in_leaderboard": false})
	if interaction_area is VendorArea:
		# Notify client that they left vendor area
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:
			data_push.rpc_id(peer_id, &"vendor.status", {"in_vendor": false})
	if interaction_area is WorkerArea:
		# Notify client that they left worker area
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:
			data_push.rpc_id(peer_id, &"worker.area.status", {"in_worker_area": false})


func _push_market_prices(peer_id: int, market: MarketArea) -> void:
	"""Push current market prices and supply levels to client for display"""
	var market_data = _get_market_data()
	if market_data == null:
		return
	
	# Get active supply levels (items with non-equilibrium prices)
	var supply_levels = market_data.get_active_supply_levels()
	
	# Build price multipliers dictionary for client
	var price_multipliers = {}
	for item_id in supply_levels.keys():
		price_multipliers[item_id] = market_data.get_price_multiplier(item_id)
	
	data_push.rpc_id(peer_id, &"market.prices", {
		"market_name": market.market_name,
		"supply_levels": supply_levels,
		"price_multipliers": price_multipliers
	})


func _push_market_prices_global(peer_id: int) -> void:
	"""Push current market prices without a specific market reference (for vendors)"""
	var market_data = _get_market_data()
	if market_data == null:
		return
	
	var supply_levels = market_data.get_active_supply_levels()
	var price_multipliers = {}
	for item_id in supply_levels.keys():
		price_multipliers[item_id] = market_data.get_price_multiplier(item_id)
	
	data_push.rpc_id(peer_id, &"market.prices", {
		"market_name": "Market",
		"supply_levels": supply_levels,
		"price_multipliers": price_multipliers
	})


func _get_market_data() -> MarketData:
	"""Get MarketData from WorldDatabase"""
	if world_server and world_server.database:
		return world_server.database.market_data
	return null


@rpc("any_peer", "call_remote", "reliable", 0)
func ready_to_enter_instance() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	spawn_player(peer_id)


#region spawn/despawn
@rpc("authority", "call_remote", "reliable", 0)
func spawn_player(peer_id: int) -> void:
	var player: Player
	var spawn_index: int = 0
	var saved_position: Vector2 = Vector2.ZERO
	
	if awaiting_peers.has(peer_id):
		player = awaiting_peers[peer_id]["player"]
		spawn_index = awaiting_peers[peer_id]["target_id"]
		saved_position = awaiting_peers[peer_id].get("saved_position", Vector2.ZERO)
		awaiting_peers.erase(peer_id)
	else:
		player = instantiate_player(peer_id)
		data_push.rpc_id(peer_id, &"chat.message", {"text": get_motd(), "id": 1, "name": "Server"})
	
	player.just_teleported = true
	
	instance_map.add_child(player, true)
	
	players_by_peer_id[peer_id] = player
	
	#NEW
	var syn: StateSynchronizer = player.syn
	
	# Use saved position if available, otherwise use spawn point
	var spawn_position: Vector2
	if saved_position != Vector2.ZERO:
		spawn_position = saved_position
	else:
		spawn_position = instance_map.get_spawn_position(spawn_index)
	
	player.state_synchronizer.set_by_path(^":position", spawn_position)

	print_debug("baseline server pairs:", syn.capture_baseline())
	
	# Register in sync manager AFTER we seeded states.
	synchronizer_manager.add_entity(peer_id, syn)
	synchronizer_manager.register_peer(peer_id)

	# FIX: Send baseline to existing peers BEFORE they receive spawn command
	# This prevents race conditions where area detection fires before player data arrives
	_send_baseline_to_existing_peers(peer_id, syn)

	connected_peers.append(peer_id)
	_propagate_spawn(peer_id)
	
	# Send current game time to new player
	if world_server and world_server.get_game_time_manager():
		world_server.get_game_time_manager().send_time_to_peer(self, peer_id)
	
	# Automatically grant Alpha Tester title to all players
	if TitleProgressTracker.instance and player.player_resource:
		var account_name: String = player.player_resource.account_name
		var player_data: WorldPlayerData = world_server.database.player_data
		
		# Set the event flag for Alpha Tester
		TitleProgressTracker.instance.set_progress(account_name, "event_founder", 1, player_data, peer_id, self)
		
		# Check if they should unlock the Alpha Tester title
		TitleProgressTracker.instance.check_and_unlock(account_name, TitleResource.ConditionType.EVENT_FLAG, peer_id, self)
	
	# Sync all active shops to the new player
	if has_node("ShopManager"):
		var shop_mgr: ShopManager = get_node("ShopManager")
		shop_mgr.sync_shops_to_player(peer_id, self)

	# Sync all bots to the new player
	if has_node("BotManager"):
		var bot_mgr: BotManager = get_node("BotManager")
		bot_mgr.send_bots_to_peer(peer_id)


func instantiate_player(peer_id: int) -> Player:
	var player_resource: PlayerResource = world_server.connected_players[peer_id]
	var character_resource: CharacterResource = ResourceLoader.load(
		"res://source/common/gameplay/characters/classes/character_collection/" +
		player_resource.character_class + ".tres"
	)
	
	var new_player: Player = PLAYER.instantiate() as Player
	new_player.name = str(peer_id)
	new_player.player_resource = player_resource
	new_player.character_resource = character_resource
	
	# Set appearance properties BEFORE adding to tree so CompositeSprite can initialize correctly
	new_player.character_class = player_resource.character_class
	new_player.appearance_head_id = player_resource.appearance_head_id
	
	new_player.ready.connect(func():
		var syn: StateSynchronizer = new_player.state_synchronizer
		syn.set_by_path(^":character_class", new_player.player_resource.character_class)
		syn.set_by_path(^":display_name", new_player.player_resource.display_name)
		syn.set_by_path(^":handle_name", new_player.player_resource.account_name)
		syn.set_by_path(^":appearance_head_id", new_player.player_resource.appearance_head_id)
		syn.set_by_path(^":equipped_accessory_id", new_player.player_resource.equipped_accessory_id)
		
		# Sync title information
		var title_slug: String = player_resource.selected_title_slug
		if not title_slug.is_empty():
			var title: TitleResource = ContentRegistryHub.load_by_slug(&"titles", StringName(title_slug))
			if title:
				syn.set_by_path(^":title_text", title.title_name)
				syn.set_by_path(^":title_slug", player_resource.selected_title_slug)
				syn.set_by_path(^":title_rarity", title.rarity)
			else:
				syn.set_by_path(^":title_text", "")
				syn.set_by_path(^":title_rarity", 0)
		else:
			syn.set_by_path(^":title_text", "")
			syn.set_by_path(^":title_rarity", 0)

		var asc: AbilitySystemComponent = new_player.ability_system_component
		
		var player_stats: Dictionary[StringName, float] = player_resource.BASE_STATS.duplicate()
		
		var new_energy_max: float = player_resource.get_energy_max()
		player_stats[&"energy_max"] = new_energy_max
		# Restore energy from persisted value if available; otherwise start full
		var start_energy: float = player_resource.current_energy if player_resource.current_energy >= 0.0 else new_energy_max
		player_stats[&"energy"] = clamp(start_energy, 0.0, new_energy_max)
		
		var stats_from_attributes: Dictionary[StringName, float] = player_resource.get_stats_from_attributes()
		for stat_name: StringName in stats_from_attributes:
			var inc: float = stats_from_attributes[stat_name]
			player_stats[stat_name] = player_stats.get(stat_name, 0.0) + inc
		for stat_name: StringName in player_stats:
			var value: float = player_stats[stat_name]
			print(stat_name, " : ", value)
			if stat_name.ends_with("_max"):
				var base_attr: StringName = stat_name.trim_suffix(&"_max")
				asc.ensure_attr(base_attr, value, value)
				asc.set_max_server(base_attr, value, true)
				asc.set_value_server(base_attr, value)
			else:
				asc.ensure_attr(stat_name, value, value)
				asc.set_value_server(stat_name, value)
		

		#var base_stats: Dictionary = new_player.character_resource.build_base_stats(new_player.player_resource.level)
		#
		#for stat_name: StringName in base_stats:
			#var value: float = base_stats[stat_name]
			#if stat_name.ends_with("_max"):
				#var base_attr: StringName = stat_name.trim_suffix(&"_max")
				#asc.ensure_attr(base_attr, value, value)
				#asc.set_max_server(base_attr, value, true)
				#asc.set_value_server(base_attr, value)
			#else:
				#asc.ensure_attr(stat_name, value, value)
				#asc.set_value_server(stat_name, value)
		# Install pluggable resource modules so costs/regen work
		var resources := new_player.character_resource.power_resources.duplicate()
		var has_hp_cost := false
		var has_energy := false
		for r in resources:
			if r is HealthCostResource:
				has_hp_cost = true
			elif r is EnergyResource:
				has_energy = true
		if not has_hp_cost:
			resources.append(HealthCostResource.new())
		if not has_energy:
			resources.append(EnergyResource.new())
		asc.install_resources(resources, player_stats)
	,
	CONNECT_ONE_SHOT)
	
	return new_player


func get_motd() -> String:
	return world_server.world_manager.world_info.get("motd", "Default Welcome")


## Spawn the new player on all other client in the current instance
## and spawn all other players on the new client.
func _propagate_spawn(new_player_id: int) -> void:
	for peer_id: int in connected_peers:
		spawn_player.rpc_id(peer_id, new_player_id)
		if new_player_id != peer_id:
			spawn_player.rpc_id(new_player_id, peer_id)


## Send baseline state of a newly spawned player to all existing connected peers
## This ensures existing players receive the new player's metadata (name, class, handle)
## BEFORE the spawn command triggers, preventing race conditions with area detection
func _send_baseline_to_existing_peers(new_player_id: int, syn: StateSynchronizer) -> void:
	if connected_peers.is_empty():
		return
	
	var baseline_pairs: Array = syn.capture_baseline()
	if baseline_pairs.is_empty():
		print("[ServerInstance] Warning: No baseline data for peer ", new_player_id)
		return
	
	print("[ServerInstance] Sending baseline for new player ", new_player_id, " to ", connected_peers.size(), " existing peers")
	print("[ServerInstance] Baseline data: ", baseline_pairs)
	
	# Send baseline to each existing peer using the bootstrap protocol
	for peer_id: int in connected_peers:
		# Package as a single-entity bootstrap
		var objects: Array = [{ "eid": new_player_id, "pairs": baseline_pairs }]
		var payload: PackedByteArray = WireCodec.encode_bootstrap([], objects)
		synchronizer_manager.on_bootstrap.rpc_id(peer_id, payload)
		print("[ServerInstance] Sent baseline to peer ", peer_id)


@rpc("authority", "call_remote", "reliable", 0)
func despawn_player(peer_id: int, delete: bool = false) -> void:
	connected_peers.remove_at(connected_peers.find(peer_id))
	
	synchronizer_manager.remove_entity(peer_id)
	synchronizer_manager.unregister_peer(peer_id)
	
	var player: Player = players_by_peer_id[peer_id]
	if player:
		# Persist current energy to PlayerResource before removing the player
		var asc: AbilitySystemComponent = player.ability_system_component
		if asc:
			var energy_max: float = asc.get_max(&"energy")
			var energy_cur: float = asc.get_value(&"energy")
			player.player_resource.current_energy = clamp(energy_cur, 0.0, energy_max)
		
		# Quick-Switch: Save position and logout time
		player.player_resource.last_position = player.global_position
		player.player_resource.last_logout_time = Time.get_unix_time_from_system()
		
		# Cleanup harvesting memberships (now uses manager)
		if harvest_manager:
			harvest_manager.cleanup_peer(peer_id)
		
		if delete:
			player.queue_free()
		else:
			instance_map.remove_child(player)
		players_by_peer_id.erase(peer_id)
	
	for id: int in connected_peers:
		despawn_player.rpc_id(id, peer_id)


func broadcast_player_collision_mode(enabled: bool) -> void:
	"""Enable or disable player-to-player collision for all clients (used by minigames)"""
	print("[ServerInstance] Broadcasting collision mode: ", enabled)
	for peer_id: int in connected_peers:
		set_player_collision_mode.rpc_id(peer_id, enabled)


@rpc("authority", "call_remote", "reliable", 0)
func set_player_collision_mode(enabled: bool) -> void:
	# Client-side handler stub (actual implementation in InstanceClient)
	pass
#endregion


@rpc("any_peer", "call_remote", "reliable", 1)
func data_request(request_id: int, type: StringName, args: Dictionary) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	print("[ServerInstance] data_request received - Type: %s, Args: %s, From peer: %d" % [type, args, peer_id])
	
	# Rate-limit
	#if not _rate_ok(
		#return
	
	if not request_handlers.has(type):
		print("[ServerInstance] Loading handler for type: %s" % type)
		var script: GDScript = ContentRegistryHub.load_by_slug(
			&"data_request_handlers",
			type
		) as GDScript
		if not script:
			print("[ServerInstance] ERROR: Could not load handler script for type: %s" % type)
			return
		var request_handler: DataRequestHandler = script.new() as DataRequestHandler
		if not request_handler:
			print("[ServerInstance] ERROR: Could not instantiate handler for type: %s" % type)
			return
		request_handlers[type] = request_handler
		print("[ServerInstance] Handler loaded successfully for type: %s" % type)
	else:
		print("[ServerInstance] Using cached handler for type: %s" % type)
	
	var response_data = request_handlers[type].data_request_handler(peer_id, self, args)
	print("[ServerInstance] Handler returned: %s" % response_data)
	
	data_response.rpc_id(
		peer_id,
		request_id,
		type,
		response_data
	)


@rpc("authority", "call_remote", "reliable", 1)
func data_response(request_id: int, type: StringName, data: Dictionary) -> void:
	# Only implemented in the client
	pass


@rpc("authority", "call_remote", "reliable", 1)
func data_push(type: StringName, data: Dictionary) -> void:
	# Only implemented in the client
	pass


func propagate_rpc(callable: Callable) -> void:
	for peer_id: int in connected_peers:
		callable.rpc_id(peer_id)


func get_player(peer_id: int) -> Player:
	var p: Player = players_by_peer_id.get(peer_id, null)
	return p


func _initialize_halloween_monster() -> void:
	# Find the monster in the map
	var monster: HalloweenMonster = instance_map.find_child("monster_halloween", true, false) as HalloweenMonster
	if not monster:
		# No monster in this map (normal for non-overworld maps)
		return
	
	# Initialize the monster (static, no movement needed)
	monster.initialize(self)
	print("[ServerInstance] ✅ Halloween Monster initialized as static hazard")


func _initialize_vendors() -> void:
	"""Initialize all VendorArea nodes with their persistent data"""
	if not world_server or not world_server.database:
		return
	
	var vendors = instance_map.find_children("*", "VendorArea", true, false)
	print("[ServerInstance] Initializing %d vendor(s)..." % vendors.size())
	
	for vendor_node in vendors:
		if vendor_node is VendorArea:
			var vendor = vendor_node as VendorArea
			if vendor.vendor_id.is_empty():
				push_warning("[ServerInstance] VendorArea '%s' has no vendor_id! Generating one." % vendor.name)
				vendor.vendor_id = "vendor_%s_%d" % [vendor.name.to_lower(), vendor.get_instance_id()]
			
			vendor.initialize_vendor_data(world_server.database)
			print("[ServerInstance] ✅ Vendor '%s' (%s) initialized - %d items" % [
				vendor.vendor_name, 
				vendor.vendor_id, 
				vendor.item_catalog.size()
			])


func _initialize_worker_bots() -> void:
	"""Spawn walking bots for each WorkerArea (Rocky, Fern, Jack, etc.)"""
	if not has_node("BotManager"):
		return

	var workers = instance_map.find_children("*", "WorkerArea", true, false)
	print("[ServerInstance] Spawning worker bots for %d worker(s)..." % workers.size())

	for worker_node in workers:
		if worker_node is WorkerArea:
			var worker = worker_node as WorkerArea
			# Generate worker_id if not set
			if worker.worker_id.is_empty():
				worker.worker_id = "%s_%s" % [worker.worker_type, worker.name.to_lower().replace(" ", "_")]

			worker.spawn_worker_bot()


func _get_peer_id_for_player(player: Player) -> int:
	# Find the peer_id for this player by searching through the mapping
	for peer_id in players_by_peer_id.keys():
		if players_by_peer_id[peer_id] == player:
			return peer_id
	return 0  # Return 0 if not found


func get_player_syn(peer_id: int) -> StateSynchronizer:
	var p: Player = get_player(peer_id)
	return null if p == null else p.get_node_or_null(^"StateSynchronizer")


## Fixe une propriété arbitraire relative à la racine du Player via le Synchronizer.
## Exemple: ^":scale", ^"Sprite2D:modulate", ^"AbilitySystemComponent/AttributesMirror:health"
func set_player_path_value(peer_id: int, rel_path: NodePath, value: Variant) -> bool:
	var syn: StateSynchronizer = get_player_syn(peer_id)
	if syn == null:
		return false
	syn.set_by_path(rel_path, value)  # applique local + marque dirty
	return true


# Award an item to a player's inventory by slug (server-authoritative).
func give_item(peer_id: int, item_slug: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	var p: Player = get_player(peer_id)
	if p == null:
		return false
	var item_id: int = ContentRegistryHub.id_from_slug(&"items", item_slug)
	if item_id <= 0:
		return false
	var inv: Dictionary = p.player_resource.inventory
	var slot: Dictionary = inv.get(item_id, {"stack": 0})
	slot["stack"] = int(slot.get("stack", 0)) + amount
	inv[item_id] = slot
	return true


# To translate in english
## API “propre” pour les attributs (serveur = source de vérité).
## Utilise l’ASC si présent ; sinon fallback en poussant le miroir.
func set_player_attr_current(peer_id: int, attr: StringName, value: float) -> bool:
	var p: Player = get_player(peer_id)
	if p == null:
		return false

	var asc: AbilitySystemComponent = p.get_node_or_null(^"AbilitySystemComponent")
	if asc != null and asc.has_method("set_attr_current"):
		asc.set_attr_current(attr, value)
		return true

	# Fallback (si pas encore d'API ASC dédiée) : pousser le miroir côté client.
	var np := NodePath("AbilitySystemComponent/AttributesMirror:" + String(attr))
	return set_player_path_value(peer_id, np, value)
