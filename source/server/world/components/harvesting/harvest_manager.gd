class_name HarvestManager
extends Node

## Manages all harvest nodes in an instance for efficient lookup
## Eliminates expensive get_tree().get_nodes_in_group() calls

var nodes_by_id: Dictionary[int, HarvestNode] = {}
var active_harvesters: Dictionary[int, HarvestNode] = {} # peer_id -> node


func register_node(node: HarvestNode) -> void:
	var id: int = node.get_instance_id()
	nodes_by_id[id] = node


func unregister_node(node: HarvestNode) -> void:
	var id: int = node.get_instance_id()
	nodes_by_id.erase(id)
	# Clean up any active harvesters on this node
	for peer_id in active_harvesters.keys():
		if active_harvesters[peer_id] == node:
			active_harvesters.erase(peer_id)


func find_nearest_in_range(player: Player) -> HarvestNode:
	var best: HarvestNode = null
	var best_d2: float = INF
	
	for node in nodes_by_id.values():
		if node.player_in_range(player):
			var d2: float = player.global_position.distance_squared_to(node.global_position)
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
