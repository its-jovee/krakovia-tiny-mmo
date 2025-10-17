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
	
	# Get optional text color (for special messages like "Buying X")
	var text_color: String = args.get("color", "")
	# Sanitize color to prevent injection
	if not text_color.is_empty():
		# Only allow valid hex colors
		if not text_color.begins_with("#") or text_color.length() not in [4, 7]:
			text_color = ""
	
	# Check if this is a system-generated message (not manually typed by user)
	var is_system_generated: bool = args.get("system_generated", false)
	
	# SANITIZE BBCode tags to prevent injection attacks
	# Only preserve [img] tags for system-generated messages (like buying requests)
	if is_system_generated and not text_color.is_empty():
		# System message with color - preserve [img] tags but sanitize other BBCode
		text = _sanitize_bbcode_preserve_img(text)
	else:
		# User-typed message - sanitize ALL BBCode for security
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
	
	# Add color if provided
	if not text_color.is_empty():
		message["color"] = text_color
	
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


# Sanitize BBCode but preserve [img] tags for special messages
func _sanitize_bbcode_preserve_img(text: String) -> String:
	# First, extract and protect [img] tags
	var protected_text = text
	var img_pattern = RegEx.new()
	img_pattern.compile("\\[img(?:=\\d+)?\\][^\\[]+\\[\\/img\\]")
	
	var matches = img_pattern.search_all(protected_text)
	var placeholders = {}
	var placeholder_index = 0
	
	# Replace [img] tags with placeholders
	for match in matches:
		var placeholder = "<<<IMG_PLACEHOLDER_%d>>>" % placeholder_index
		placeholders[placeholder] = match.get_string()
		protected_text = protected_text.replace(match.get_string(), placeholder)
		placeholder_index += 1
	
	# Sanitize the rest (replace [ and ] to prevent BBCode injection)
	protected_text = protected_text.replace("[", "［")
	protected_text = protected_text.replace("]", "］")
	
	# Restore [img] tags
	for placeholder in placeholders:
		protected_text = protected_text.replace(placeholder, placeholders[placeholder])
	
	return protected_text
