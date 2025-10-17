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
				
				# Close any active shops for this peer
				if has_node("ShopManager"):
					var shop_mgr: ShopManager = get_node("ShopManager")
					if shop_mgr.has_shop(peer_id):
						shop_mgr.close_shop(peer_id)
				
				despawn_player(peer_id)
	)
	
	synchronizer_manager = StateSynchronizerManagerServer.new()
	synchronizer_manager.name = "StateSynchronizerManager"
	
	add_child(synchronizer_manager, true)
	
	# Add TradeManager
	var trade_mgr = TradeManager.new()
	trade_mgr.name = "TradeManager"
	add_child(trade_mgr, true)
	
	# Add ShopManager
	var shop_mgr = ShopManager.new()
	shop_mgr.name = "ShopManager"
	add_child(shop_mgr, true)
	
	# Add HarvestManager
	harvest_manager = HarvestManager.new()
	harvest_manager.name = "HarvestManager"
	add_child(harvest_manager, true)
	
	# Add QuestManager
	var quest_mgr = QuestManager.new()
	quest_mgr.name = "QuestManager"
	add_child(quest_mgr, true)


func load_map(map_path: String) -> void:
	if instance_map:
		instance_map.queue_free()
	instance_map = load(map_path).instantiate()
	add_child(instance_map)
	#add_child(CameraProbe.new())
	
	ready.connect(func():
		if instance_map.replicated_props_container:
			synchronizer_manager.add_container(1_000_000, instance_map.replicated_props_container)
		for child in instance_map.get_children():
			if child is InteractionArea:
				child.player_entered_interaction_area.connect(self._on_player_entered_interaction_area)
				if child.has_signal("player_exited_interaction_area"):
					child.player_exited_interaction_area.connect(self._on_player_exited_interaction_area)
		
		# Reindex harvest nodes after map loads
		if harvest_manager:
			harvest_manager.reindex_existing()
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
	if interaction_area is QuestBoardArea:
		# Notify client about quest board status
		var peer_id = _get_peer_id_for_player(player)
		if peer_id != 0:  # Only notify actual connected clients
			data_push.rpc_id(peer_id, &"quest_board.status", {"in_quest_board": true})

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

@rpc("any_peer", "call_remote", "reliable", 0)
func ready_to_enter_instance() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	spawn_player(peer_id)


#region spawn/despawn
@rpc("authority", "call_remote", "reliable", 0)
func spawn_player(peer_id: int) -> void:
	var player: Player
	var spawn_index: int = 0
	
	if awaiting_peers.has(peer_id):
		player = awaiting_peers[peer_id]["player"]
		spawn_index = awaiting_peers[peer_id]["target_id"]
		awaiting_peers.erase(peer_id)
	else:
		player = instantiate_player(peer_id)
		data_push.rpc_id(peer_id, &"chat.message", {"text": get_motd(), "id": 1, "name": "Server"})
	
	player.just_teleported = true
	
	instance_map.add_child(player, true)
	
	players_by_peer_id[peer_id] = player
	
	#NEW
	var syn: StateSynchronizer = player.syn
	player.state_synchronizer.set_by_path(^":position", instance_map.get_spawn_position(spawn_index))

	print_debug("baseline server pairs:", syn.capture_baseline())
	
	# Register in sync manager AFTER we seeded states.
	synchronizer_manager.add_entity(peer_id, syn)
	synchronizer_manager.register_peer(peer_id)

	connected_peers.append(peer_id)
	_propagate_spawn(peer_id)
	
	# Sync existing shops to the newly connected player
	if has_node("ShopManager"):
		var shop_mgr: ShopManager = get_node("ShopManager")
		shop_mgr.sync_shops_to_player(peer_id, self)


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
	
	new_player.ready.connect(func():
		var syn: StateSynchronizer = new_player.state_synchronizer
		syn.set_by_path(^":character_class", new_player.player_resource.character_class)
		syn.set_by_path(^":display_name", new_player.player_resource.display_name)
		syn.set_by_path(^":handle_name", new_player.player_resource.account_name)

		var asc: AbilitySystemComponent = new_player.ability_system_component
		
		var player_stats: Dictionary[StringName, float] = player_resource.BASE_STATS.duplicate()
		
		var new_energy_max: float = player_resource.get_energy_max()
		player_stats[&"energy_max"] = new_energy_max
		player_stats[&"energy"] = new_energy_max
		
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


@rpc("authority", "call_remote", "reliable", 0)
func despawn_player(peer_id: int, delete: bool = false) -> void:
	connected_peers.remove_at(connected_peers.find(peer_id))
	
	synchronizer_manager.remove_entity(peer_id)
	synchronizer_manager.unregister_peer(peer_id)
	
	var player: Player = players_by_peer_id[peer_id]
	if player:
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
