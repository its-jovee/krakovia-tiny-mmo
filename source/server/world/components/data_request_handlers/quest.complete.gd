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
	
	# Check if player is at a quest board
	if not _is_player_at_quest_board(player, instance):
		return {"error": "Must be at a quest board to complete quests"}
	
	# Get quest manager
	var quest_manager: QuestManager = instance.get_node_or_null("QuestManager")
	if not quest_manager:
		return {"error": "Quest system not available"}
	
	# Complete the quest
	var result: Dictionary = quest_manager.complete_quest(peer_id, quest_id, instance)
	
	if result.has("success") and result["success"]:
		# Send updated quest list
		var updated_quests: Array = quest_manager.get_quests_for_player(peer_id)
		instance.data_push.rpc_id(peer_id, &"quest.update", {"quests": updated_quests})
	
	return result


func _is_player_at_quest_board(player: Player, instance: ServerInstance) -> bool:
	# Check if player is at any quest board
	for child in instance.instance_map.get_children():
		if child is QuestBoardArea:
			var board = child as QuestBoardArea
			if board.is_player_at_board(player):
				return true
	return false

