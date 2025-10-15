extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	# Get quest manager
	var quest_manager: QuestManager = instance.get_node_or_null("QuestManager")
	if not quest_manager:
		return {"error": "Quest system not available"}
	
	# Get quests for player (generates if needed)
	var quests: Array = quest_manager.get_quests_for_player(peer_id)
	
	return {
		"success": true,
		"quests": quests
	}

