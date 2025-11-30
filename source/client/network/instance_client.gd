class_name InstanceClient
extends Node


const LOCAL_PLAYER: PackedScene = preload("res://source/client/local_player/local_player.tscn")
const DUMMY_PLAYER: PackedScene = preload("res://source/common/gameplay/characters/player/player.tscn")

static var current: InstanceClient
static var local_player: LocalPlayer
static var local_harvest_node: String = ""
static var day_night_cycle: DayNightCycle = null

var players_by_peer_id: Dictionary[int, Player]

var synchronizer_manager: StateSynchronizerManagerClient
var instance_map: Map

static var _next_data_request_id: int
static var _pending_data_requests: Dictionary[int, Callable]
static var _data_subscriptions: Dictionary[StringName, Array]


func _ready() -> void:
	current = self
	
	# Subscribe to chat messages for speech bubbles
	subscribe(&"chat.message", func(message: Dictionary) -> void:
		if message.is_empty():
			return
		var text: String = message.get("text", "")
		var sender_id: int = message.get("id", 0)
		
		# Skip system messages (id = 1)
		if sender_id == 1 or text.is_empty():
			return
		
		# Find the player and show speech bubble
		var player: Player = players_by_peer_id.get(sender_id, null)
		if player and player.has_method("show_speech_bubble"):
			player.show_speech_bubble(text)
	)
	
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
	
	# Harvesting tick - fires when a harvest attempt happens (for progress bar reset)
	subscribe(&"harvest.tick", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.tick:", data)
		var harvesting_panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if harvesting_panel and harvesting_panel.has_method("on_harvest_tick"):
			harvesting_panel.on_harvest_tick()
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

	# Harvest game events - Rhythm (Miner)
	subscribe(&"harvest.rhythm.beat", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.rhythm.beat:", data)
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_rhythm_beat"):
			panel.on_rhythm_beat(data)
	)
	
	# Harvest game events - Precision (Collector)
	subscribe(&"harvest.precision.window", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.precision.window:", data)
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_precision_window"):
			panel.on_precision_window(data)
	)
	
	# Harvest game events - Steady Aim (Trapper)
	subscribe(&"harvest.aim.window", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.aim.window:", data)
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_aim_window"):
			panel.on_aim_window(data)
	)
	
	# Harvest game feedback (performance result)
	subscribe(&"harvest.game.feedback", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.game.feedback:", data)
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_game_feedback"):
			panel.on_game_feedback(data)
	)
	
	# Harvest game sync bonus (multiple players hit together)
	subscribe(&"harvest.game.sync", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("harvest.game.sync:", data)
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_sync_bonus"):
			panel.on_sync_bonus(data)
	)
	
	# Harvest node health updates
	subscribe(&"harvest.node_health", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_node_health"):
			panel.on_node_health(data)
	)
	
	# Harvest damage events (for damage popups)
	subscribe(&"harvest.damage", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		var panel: Node = get_tree().get_root().find_child("HarvestingPanel", true, false)
		if panel and panel.has_method("on_damage"):
			panel.on_damage(data)
	)
	
	# Shop system subscriptions
	subscribe(&"shop.status", _on_shop_status)
	subscribe(&"shop.update", _on_shop_update)
	subscribe(&"shop.opened", _on_shop_opened)
	subscribe(&"shop.closed", _on_shop_closed)
	subscribe(&"shop.item_sold", _on_shop_item_sold)
	subscribe(&"shop.purchase_complete", _on_shop_purchase_complete)
	
	# Title unlocked notification
	subscribe(&"title.unlocked", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("title.unlocked:", data)
		_show_title_unlocked_notification(data)
	)
	
	# Title progress update
	subscribe(&"title.progress", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		print_debug("title.progress:", data)
		# Notify titles menu if it's open
		var titles_menu = get_tree().get_root().find_child("TitlesMenu", true, false)
		if titles_menu and titles_menu.visible and titles_menu.has_method("on_progress_update"):
			titles_menu.on_progress_update(data)
	)
	
	# Day/night cycle time updates
	subscribe(&"game.time", func(data: Dictionary) -> void:
		if data.is_empty():
			return
		# Forward to DayNightCycle if it exists
		if day_night_cycle:
			day_night_cycle._on_time_update(data)
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
	print("=== CLIENT: spawn_player called for player_id: ", player_id, " ===")
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
		# Mark as remote player so it keeps velocity at zero
		new_player.is_remote_player = true
		# Remote players: no collision with other players by default (prevents griefing/dragging)
		# Positions are authority-synced from server, not physics-driven
		new_player.collision_layer = 0  # Not on any collision layer
		new_player.collision_mask = 6   # Still detect walls (2) and objects (4)
		new_player.velocity = Vector2.ZERO
		# Physics stays enabled for collision detection, but velocity is locked to zero
	
	new_player.name = str(player_id)
	# CRITICAL: Set the peer_id so shop indicators work correctly
	new_player.peer_id = player_id
	print("Set player.peer_id to: ", new_player.peer_id)
	
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


@rpc("authority", "call_remote", "reliable", 0)
func set_player_collision_mode(enabled: bool) -> void:
	"""Toggle player-to-player collision for all remote players (used by minigames)"""
	print("[InstanceClient] Setting player collision mode: ", enabled)
	for peer_id: int in players_by_peer_id:
		var player: Player = players_by_peer_id[peer_id]
		if player and is_instance_valid(player):
			player.set_player_collision_enabled(enabled)
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


# Shop system handlers
func _on_shop_status(data: Dictionary) -> void:
	"""Handle shop status updates (shop opened/closed by any player)"""
	print("=== CLIENT: Received shop.status ===")
	print("Data: ", data)
	
	if data.is_empty():
		print("ERROR: Empty data!")
		return
	
	var seller_peer_id = data.get("seller_peer_id", -1)
	var status = data.get("status", "")
	
	print("Seller peer ID: ", seller_peer_id)
	print("Status: ", status)
	print("Available players: ", players_by_peer_id.keys())
	
	# Find the player and update their shop indicator
	var player: Player = players_by_peer_id.get(seller_peer_id, null)
	print("Found player: ", player != null)
	
	if player:
		print("Player name: ", player.name)
		print("Player peer_id before: ", player.peer_id)
		
		if status == "opened":
			player.has_shop_open = true
			player.shop_name = data.get("shop_name", "Shop")
			player.peer_id = seller_peer_id  # Ensure peer_id is set
			print("Shop opened - has_shop_open: ", player.has_shop_open, ", shop_name: ", player.shop_name)
		elif status == "closed":
			player.has_shop_open = false
			player.shop_name = ""
			print("Shop closed")
	else:
		print("ERROR: Could not find player with peer_id: ", seller_peer_id)


func _on_shop_update(data: Dictionary) -> void:
	"""Handle shop inventory updates"""
	# This is primarily handled by the shop UI itself
	pass


func _on_shop_opened(data: Dictionary) -> void:
	"""Handle own shop being opened"""
	print("Your shop is now open: ", data.get("shop_name", ""))


func _on_shop_closed(data: Dictionary) -> void:
	"""Handle own shop being closed"""
	print("Your shop has closed")


func _on_shop_item_sold(data: Dictionary) -> void:
	"""Handle item being sold from your shop"""
	var item_name = data.get("item_name", "Unknown")
	var quantity = data.get("quantity", 0)
	var price = data.get("total_price", 0)
	var buyer_name = data.get("buyer_name", "Unknown")
	print("Sold %dx %s for %d gold to %s" % [quantity, item_name, price, buyer_name])


func _on_shop_purchase_complete(data: Dictionary) -> void:
	"""Handle successful purchase from another player's shop"""
	var item_name = data.get("item_name", "Unknown")
	var quantity = data.get("quantity", 0)
	var price = data.get("total_price", 0)
	var seller_name = data.get("seller_name", "Unknown")
	print("Purchased %dx %s for %d gold from %s" % [quantity, item_name, price, seller_name])


func _show_title_unlocked_notification(data: Dictionary) -> void:
	"""Show a toast notification when a title is unlocked (top right corner)"""
	var notification_scene = preload("res://source/client/ui/notifications/title_unlocked_notification.tscn")
	var notification = notification_scene.instantiate()
	
	# Set notification content
	var title_label: Label = notification.get_node("MarginContainer/VBoxContainer/TitleLabel")
	var desc_label: Label = notification.get_node("MarginContainer/VBoxContainer/DescriptionLabel")
	
	var title_name: String = data.get("name", "Unknown Title")
	var description: String = data.get("description", "")
	var rarity: int = data.get("rarity", 0)
	
	title_label.text = title_name
	desc_label.text = description
	
	# Apply rarity color
	var rarity_color: Color = _get_rarity_color(rarity)
	title_label.add_theme_color_override("font_color", rarity_color)
	
	# Find HUD and add notification to it
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud:
		hud.add_child(notification)
		# Position at top right corner (toast style)
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		notification.position = Vector2(viewport_size.x - 420.0, 20.0)
	else:
		# Fallback: add to self but it won't be positioned correctly
		add_child(notification)
	
	notification.visible = true
	
	# Play animation
	var anim_player: AnimationPlayer = notification.get_node("AnimationPlayer")
	if anim_player:
		anim_player.play("show")
		await anim_player.animation_finished
		notification.queue_free()


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		0: # COMMON
			return Color.WHITE
		1: # RARE
			return Color("#4A90E2")
		2: # EPIC
			return Color("#9B59B6")
		3: # LEGENDARY
			return Color("#FFD700")
		_:
			return Color.WHITE
