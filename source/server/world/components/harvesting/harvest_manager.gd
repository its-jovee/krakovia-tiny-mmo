class_name HarvestManager
extends Node

## Manages all harvest nodes in an instance for efficient lookup
## Eliminates expensive get_tree().get_nodes_in_group() calls

var nodes_by_id: Dictionary[int, HarvestNode] = {}
var active_harvesters: Dictionary[int, HarvestNode] = {} # peer_id -> node

# Spatial grid for O(1) lookups
const GRID_SIZE: int = 500  # Grid cell size in pixels
var _spatial_grid: Dictionary = {}  # Vector2i -> [HarvestNode]
var _grid_dirty: bool = true


func register_node(node: HarvestNode) -> void:
	var id: int = node.get_instance_id()
	nodes_by_id[id] = node
	_grid_dirty = true


func unregister_node(node: HarvestNode) -> void:
	var id: int = node.get_instance_id()
	nodes_by_id.erase(id)
	_grid_dirty = true
	# Clean up any active harvesters on this node
	for peer_id in active_harvesters.keys():
		if active_harvesters[peer_id] == node:
			active_harvesters.erase(peer_id)


func _rebuild_spatial_grid() -> void:
	"""Rebuild spatial grid when nodes change"""
	_spatial_grid.clear()
	
	for node in nodes_by_id.values():
		var grid_coord = Vector2i(
			int(node.global_position.x / GRID_SIZE),
			int(node.global_position.y / GRID_SIZE)
		)
		if not _spatial_grid.has(grid_coord):
			_spatial_grid[grid_coord] = []
		_spatial_grid[grid_coord].append(node)
	
	_grid_dirty = false
	print_debug("[HarvestManager] Rebuilt spatial grid: %d cells, %d nodes" % [_spatial_grid.size(), nodes_by_id.size()])


func find_nearest_in_range(player: Player) -> HarvestNode:
	"""Optimized lookup using spatial grid (O(1) instead of O(n))"""
	if _grid_dirty:
		_rebuild_spatial_grid()
	
	var player_pos = player.global_position
	var grid_coord = Vector2i(int(player_pos.x / GRID_SIZE), int(player_pos.y / GRID_SIZE))
	
	var best: HarvestNode = null
	var best_d2: float = INF
	
	# Check 3x3 grid around player for nearby nodes
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_grid = grid_coord + Vector2i(dx, dy)
			if not _spatial_grid.has(check_grid):
				continue
			
			for node in _spatial_grid[check_grid]:
				if node.player_in_range(player):
					var d2: float = player_pos.distance_squared_to(node.global_position)
					if d2 < best_d2:
						best = node
						best_d2 = d2
	
	return best


func leave_current_node(peer_id: int) -> void:
	var current_node: HarvestNode = active_harvesters.get(peer_id)
	if current_node:
		current_node.player_leave(peer_id)
		active_harvesters.erase(peer_id)


func ensure_single_harvest(peer_id: int, new_node: HarvestNode) -> void:
	var current_node: HarvestNode = active_harvesters.get(peer_id)
	if current_node and current_node != new_node:
		current_node.player_leave(peer_id)
	active_harvesters[peer_id] = new_node


func get_player_harvest_node(peer_id: int) -> HarvestNode:
	return active_harvesters.get(peer_id)


func cleanup_peer(peer_id: int) -> void:
	var node: HarvestNode = active_harvesters.get(peer_id)
	if node:
		node.cleanup_peer(peer_id)
	active_harvesters.erase(peer_id)


func reindex_existing() -> void:
	"""Scan for harvest nodes already in the tree (for hot reload/map load)"""
	nodes_by_id.clear()
	if get_viewport() is ServerInstance:
		var instance: ServerInstance = get_viewport() as ServerInstance
		for node in instance.get_tree().get_nodes_in_group(&"harvest_nodes"):
			if node is HarvestNode:
				register_node(node)
	print_debug("HarvestManager: Indexed %d harvest nodes" % nodes_by_id.size())
