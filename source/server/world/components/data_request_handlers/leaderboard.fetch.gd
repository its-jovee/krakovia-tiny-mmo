extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	# Get leaderboard manager
	var leaderboard_manager = instance.get_node_or_null("LeaderboardManager")
	if not leaderboard_manager:
		return {"error": "Leaderboard system not available"}
	
	# Get all leaderboard data
	var leaderboard_data: Dictionary = leaderboard_manager.get_leaderboard_data()
	
	return {
		"success": true,
		"leaderboards": leaderboard_data
	}
