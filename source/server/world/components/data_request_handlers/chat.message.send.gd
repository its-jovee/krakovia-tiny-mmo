extends DataRequestHandler

# Maximum message length to prevent spam
const MAX_MESSAGE_LENGTH: int = 500


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id)
	if not player:
		return {"error": "Player not found"}
	
	var account_name: String = player.player_resource.account_name
	
	# Check if player is muted
	if instance.world_server.database.player_data.is_muted(account_name):
		var mute_info: Dictionary = instance.world_server.database.player_data.muted_players.get(account_name, {})
		var reason: String = mute_info.get("reason", "No reason provided")
		instance.data_push.rpc_id(
			peer_id,
			&"chat.message",
			{"text": "You are muted. Reason: " + reason, "name": "Server", "id": 1}
		)
		return {"error": "muted"}
	
	# Get and sanitize message text
	var text: String = args.get("text", "").strip_edges()
	
	# Validate message is not empty
	if text.is_empty():
		return {"error": "empty_message"}
	
	# Enforce length limit
	if text.length() > MAX_MESSAGE_LENGTH:
		text = text.substr(0, MAX_MESSAGE_LENGTH)
	
	# SANITIZE BBCode tags to prevent injection attacks
	text = _sanitize_bbcode(text)
	
	# Validate and sanitize channel
	var channel: int = args.get("channel", 0)
	if channel < 0 or channel > 1:  # Only 0 (Global) and 1 (Trade) are valid
		channel = 0
	
	var message: Dictionary = {
		"text": text,
		"channel": channel,
		"name": player.player_resource.display_name,
		"id": peer_id
		#"time": Time.get_
	}
	instance.propagate_rpc(instance.data_push.bind(&"chat.message", message))
	return {} # ACK later #{"error": 0}


# Sanitize BBCode to prevent malicious tag injection
# Replaces brackets with fullwidth variants that look similar but won't be parsed as BBCode
func _sanitize_bbcode(text: String) -> String:
	# Replace brackets with fullwidth variants (U+FF3B and U+FF3D)
	# These look almost identical but won't be interpreted as BBCode
	text = text.replace("[", "［")  # Fullwidth left bracket
	text = text.replace("]", "］")  # Fullwidth right bracket
	return text
