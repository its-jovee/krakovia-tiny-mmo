class_name InstanceClient
extends Node


const LOCAL_PLAYER: PackedScene = preload("res://source/client/local_player/local_player.tscn")
const DUMMY_PLAYER: PackedScene = preload("res://source/common/gameplay/characters/player/player.tscn")

static var current: InstanceClient
static var local_player: LocalPlayer
static var local_harvest_node: String = ""

var players_by_peer_id: Dictionary[int, Player]

var synchronizer_manager: StateSynchronizerManagerClient
var instance_map: Map

static var _next_data_request_id: int
static var _pending_data_requests: Dictionary[int, Callable]
static var _data_subscriptions: Dictionary[StringName, Array]


func _ready() -> void:
	current = self
	
	subscribe(&"item.equip", func(data: Dictionary) -> void:
		if data.is_empty() or not data.has_all(["p", "i"]):
			return
		var player: Player = players_by_peer_id.get(data["p"], null)
		if not player:
			return
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", data["i"])
		if item:
			if item is WeaponItem:
				player.equipment_component.equip(item.slot.key, item)
			elif item is ConsumableItem:
				item.on_use(player)
	)
	
	subscribe(&"action.perform", func(data: Dictionary) -> void:
		if data.is_empty() or not data.has_all(["p", "d", "i"]):
			return
		var player: Player = players_by_peer_id.get(data["p"])
		if not player:
			return
			
		player.equipped_weapon_right.perform_action(data["i"], data["d"])
	)

	# Harvesting debug prints (iteration 0)
	subscribe(&"harvest.event", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.event:", data)
		# Track local harvesting membership
		if data.get("peer", -1) == multiplayer.get_unique_id():
			if data.get("type", StringName("")) == &"joined":
				local_harvest_node = String(data.get("node", ""))
				var ui_hud: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
				if ui_hud and ui_hud is Control:
					(ui_hud as Control).visible = true
			elif data.get("type", StringName("")) == &"left":
				local_harvest_node = ""
				var ui_hud2: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
				if ui_hud2:
					if ui_hud2.has_method("reset"):
						ui_hud2.reset()
					elif ui_hud2 is Control:
						(ui_hud2 as Control).visible = false
	)

	# Harvesting status logs (iteration 0)
	subscribe(&"harvest.status", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.status:", data)
		# Safety: if we no longer track a local node, ensure panel is hidden/reset
		if local_harvest_node == "":
			var pnl: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
			if pnl and pnl.has_method("reset"):
				pnl.reset()
		var ui_hud: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if ui_hud and ui_hud.has_method("on_status"):
			ui_hud.on_status(data)
	)

	# Harvesting distribution logs (iteration 0)
	subscribe(&"harvest.distribution", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.distribution:", data)
		# Refresh inventory UI if open (Inventory node root)
		var ui: Node = get_tree().get_root().find_child("HUD", true, false)
		if ui:
			var inv_menu: Control = ui.find_child("Inventory", true, false)
			if inv_menu and inv_menu.is_visible_in_tree():
				InstanceClient.current.request_data(&"inventory.get", inv_menu.fill_inventory)
	)

	# Encourage start and bonus
	subscribe(&"harvest.encourage.session", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.encourage.session:", data)
		var ui_hud: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if ui_hud and ui_hud.has_method("on_session"):
			ui_hud.on_session(data)
	)

	subscribe(&"harvest.encourage.hit", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.encourage.hit:", data)
		var ui_hud: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if ui_hud and ui_hud.has_method("on_hit"):
			ui_hud.on_hit(data)
	)

	subscribe(&"harvest.encourage.end", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.encourage.end:", data)
		var ui_hud: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if ui_hud and ui_hud.has_method("on_end"):
			ui_hud.on_end(data)
	)
	
	synchronizer_manager = StateSynchronizerManagerClient.new()
	synchronizer_manager.name = "StateSynchronizerManager"

	if instance_map.replicated_props_container:
		synchronizer_manager.add_container(1_000_000, instance_map.replicated_props_container)

	add_child(synchronizer_manager, true)


@rpc("any_peer", "call_remote", "reliable", 0)
func ready_to_enter_instance() -> void:
	pass


#region spawn/despawn
@rpc("authority", "call_remote", "reliable", 0)
func spawn_player(player_id: int) -> void:
	var new_player: Player
	
	if player_id == multiplayer.get_unique_id():
		# Reuse local player if already exists.
		if local_player and is_instance_valid(local_player):
			new_player = local_player
		else:
			new_player = LOCAL_PLAYER.instantiate() as LocalPlayer
			local_player = new_player

		# Always update instance and sync manager references.
		local_player.synchronizer_manager = synchronizer_manager
	else:
		new_player = DUMMY_PLAYER.instantiate()
	
	new_player.name = str(player_id)
	
	players_by_peer_id[player_id] = new_player
	
	if not new_player.is_inside_tree():
		instance_map.add_child(new_player)
		#instance_map.add_child(new_player)
	
	var sync: StateSynchronizer = new_player.state_synchronizer
	synchronizer_manager.add_entity(player_id, sync) 


@rpc("authority", "call_remote", "reliable", 0)
func despawn_player(player_id: int) -> void:
	synchronizer_manager.remove_entity(player_id)
	
	var player: Player = players_by_peer_id.get(player_id, null)
	if player and player != local_player:
		player.queue_free()
	players_by_peer_id.erase(player_id)
	# Safety: if this is the local player, reset harvesting panel
	if player_id == multiplayer.get_unique_id():
		local_harvest_node = ""
		var pnl: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if pnl and pnl.has_method("reset"):
			pnl.reset()
#endregion


static func subscribe(type: StringName, handler: Callable) -> void:
	if _data_subscriptions.has(type):
		_data_subscriptions[type].append(handler)
	else:
		_data_subscriptions[type] = [handler]


static func unsubscribe(type: StringName, handler: Callable) -> void:
	if not _data_subscriptions.has(type):
		return
	_data_subscriptions[type].erase(handler)

static func _clear_subscriptions() -> void:
	for type in _data_subscriptions:
		_data_subscriptions[type].clear()
	_data_subscriptions.clear()
	
func _exit_tree() -> void:
	_clear_subscriptions()


func request_data(type: StringName, handler: Callable, args: Dictionary = {}) -> int:
	var request_id: int = _next_data_request_id
	_next_data_request_id += 1
	_pending_data_requests[request_id] = handler
	data_request.rpc_id(1, request_id, type, args)
	# Return request_id in case you may want to keep track of it for cancelation.
	return request_id


func cancel_request_data(request_id: int) -> bool:
	# Dictionary.erase eturns true if the given key existed in the dictionary, otherwise false.
	return _pending_data_requests.erase(request_id)


@rpc("any_peer", "call_remote", "reliable", 1)
func data_request(request_id: int, type: StringName, args: Dictionary) -> void:
	# Only implemented in the server.
	pass


@rpc("authority", "call_remote", "reliable", 1)
func data_response(request_id: int, type: StringName, data: Dictionary) -> void:
	var callable: Callable = _pending_data_requests.get(request_id, Callable())
	_pending_data_requests.erase(request_id)
	if callable.is_valid():
		callable.call(data)
	data_push(type, data)


@rpc("authority", "call_remote", "reliable", 1)
func data_push(type: StringName, data: Dictionary) -> void:
	for handler: Callable in _data_subscriptions.get(type, []):
		if handler.is_valid():
			handler.call(data)
			
