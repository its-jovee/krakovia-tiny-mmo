extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	var quest_id: int = args.get("quest_id", -1)
	if quest_id == -1:
		return {"error": "Invalid quest_id"}
	
	# Get quest manager
	var quest_manager: QuestManager = instance.get_node_or_null("QuestManager")
	if not quest_manager:
		return {"error": "Quest system not available"}
	
	# Pin/unpin the quest
	var result: Dictionary = quest_manager.pin_quest(peer_id, quest_id)
	
	if result.has("success") and result["success"]:
		# Send updated quest list
		var updated_quests: Array = quest_manager.get_quests_for_player(peer_id)
		instance.data_push.rpc_id(peer_id, &"quest.update", {"quests": updated_quests})
	
	return result

