class_name MinigameZone
extends Area2D

## Tracks which players are inside this minigame zone
## Used to determine who gets the popup vs just the announcement

@export var zone_name: String = "Game Arena"
@export var minigame_manager_path: NodePath

var players_in_zone: Dictionary = {}  # peer_id -> Player
var minigame_manager: MinigameManager


func _ready() -> void:
	# Check if we're on the server side
	var is_server = multiplayer.is_server()
	var parent_is_server_instance = _is_in_server_instance()
	
	print("[MinigameZone:%s] ======================================" % zone_name)
	print("[MinigameZone:%s] _ready called" % zone_name)
	print("[MinigameZone:%s] - multiplayer.is_server: %s" % [zone_name, is_server])
	print("[MinigameZone:%s] - in ServerInstance: %s" % [zone_name, parent_is_server_instance])
	print("[MinigameZone:%s] - Scene path: %s" % [zone_name, get_path()])
	print("[MinigameZone:%s] ======================================" % zone_name)
	
	# Only run on server - check if we're inside a ServerInstance
	if not parent_is_server_instance:
		print("[MinigameZone:%s] ❌ Skipping - running on client" % zone_name)
		return
	
	print("[MinigameZone:%s] ✅ Activating server-side zone detection" % zone_name)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Register with minigame manager
	await get_tree().process_frame  # Wait for tree to be ready
	
	if minigame_manager_path:
		minigame_manager = get_node_or_null(minigame_manager_path)
	
	if not minigame_manager:
		# Try to find it automatically
		var instance_manager = get_tree().get_root().find_child("InstanceManager", true, false)
		if instance_manager:
			minigame_manager = instance_manager.get_node_or_null("MinigameManager")
	
	if minigame_manager:
		minigame_manager.register_minigame_zone(self)
		print("[MinigameZone:%s] ✅ Successfully registered with MinigameManager!" % zone_name)
	else:
		push_warning("[MinigameZone:%s] ⚠️ Could not find MinigameManager!" % zone_name)
		print("[MinigameZone:%s] Scene tree path: %s" % [zone_name, get_path()])
		# Debug: print the tree structure
		_debug_print_tree()


func _exit_tree() -> void:
	if minigame_manager:
		minigame_manager.unregister_minigame_zone(self)


func _on_body_entered(body: Node2D) -> void:
	print("[MinigameZone:%s] body_entered signal fired! Body: %s, Type: %s, is Player: %s" % [zone_name, body.name, body.get_class(), body is Player])
	
	if body is Player:
		var peer_id = body.name.to_int()
		players_in_zone[peer_id] = body
		print("[MinigameZone:%s] ✅ Player %s entered (total: %d)" % [zone_name, body.player_resource.display_name, players_in_zone.size()])
		
		# Notify manager - they might get an invitation if a game is in waiting phase
		if minigame_manager:
			minigame_manager.notify_player_entered_zone(peer_id)
	else:
		print("[MinigameZone:%s] ⚠️ Body is not a Player, ignoring" % zone_name)


func _on_body_exited(body: Node2D) -> void:
	print("[MinigameZone:%s] body_exited signal fired! Body: %s" % [zone_name, body.name])
	
	if body is Player:
		var peer_id = body.name.to_int()
		players_in_zone.erase(peer_id)
		print("[MinigameZone:%s] Player %s left (total: %d)" % [zone_name, body.player_resource.display_name, players_in_zone.size()])


func get_players_in_zone() -> Array:
	return players_in_zone.keys()


func is_player_in_zone(peer_id: int) -> bool:
	return players_in_zone.has(peer_id)


func _is_in_server_instance() -> bool:
	"""Check if this zone is inside a ServerInstance (server-side)"""
	var node = self
	while node:
		if node.get_script():
			var script_path = node.get_script().resource_path
			# Specifically check for instance_server.gd (not instance_client.gd)
			if "instance_server.gd" in script_path:
				return true
		node = node.get_parent()
	return false


func _debug_print_tree() -> void:
	"""Debug helper to understand tree structure"""
	print("[MinigameZone:%s] === Tree Debug ===" % zone_name)
	print("[MinigameZone:%s] My path: %s" % [zone_name, get_path()])
	
	# Print parent chain
	var node = self
	var depth = 0
	while node and depth < 10:
		var script_info = ""
		if node.get_script():
			script_info = " (script: %s)" % node.get_script().resource_path
		print("[MinigameZone:%s]   Parent %d: %s%s" % [zone_name, depth, node.name, script_info])
		node = node.get_parent()
		depth += 1
	
	var root = get_tree().get_root()
	print("[MinigameZone:%s] Root: %s" % [zone_name, root.name])
	
	for child in root.get_children():
		print("[MinigameZone:%s]   - %s" % [zone_name, child.name])
		if child.name == "InstanceManager" or "Instance" in child.name:
			for subchild in child.get_children():
				print("[MinigameZone:%s]     - %s" % [zone_name, subchild.name])
