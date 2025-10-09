class_name AdminUtils
extends RefCounted
## Shared utility functions for admin commands


## Find a player by their @handle (account_name)
## Returns peer_id or -1 if not found
static func find_player_by_handle(handle: String, instance: ServerInstance) -> int:
	# Remove @ prefix if present
	if handle.begins_with("@"):
		handle = handle.substr(1)
	
	for peer_id in instance.players_by_peer_id.keys():
		var player: Player = instance.players_by_peer_id[peer_id]
		if player and player.player_resource.account_name == handle:
			return peer_id
	
	return -1


## Parse duration string to seconds
## Examples: "30m" -> 1800, "2h" -> 7200, "7d" -> 604800, "permanent" -> 0
## Returns 0 for permanent ban/mute
static func parse_duration(duration_str: String) -> int:
	if duration_str.is_empty() or duration_str == "permanent" or duration_str == "perm":
		return 0
	
	var value: int = 0
	var unit: String = ""
	
	# Extract number and unit
	var num_str: String = ""
	for i in range(duration_str.length()):
		var c: String = duration_str[i]
		if c.is_valid_int():
			num_str += c
		else:
			unit = duration_str.substr(i)
			break
	
	if num_str.is_empty():
		return 0
	
	value = num_str.to_int()
	
	match unit.to_lower():
		"s", "sec", "second", "seconds":
			return value
		"m", "min", "minute", "minutes":
			return value * 60
		"h", "hr", "hour", "hours":
			return value * 3600
		"d", "day", "days":
			return value * 86400
		"w", "week", "weeks":
			return value * 604800
		_:
			# Default to minutes if no unit specified
			return value * 60


## Format duration in seconds to human-readable string
static func format_duration(seconds: int) -> String:
	if seconds == 0:
		return "permanent"
	
	var days: int = seconds / 86400
	var hours: int = (seconds % 86400) / 3600
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60
	
	var parts: PackedStringArray = []
	
	if days > 0:
		parts.append(str(days) + "d")
	if hours > 0:
		parts.append(str(hours) + "h")
	if minutes > 0:
		parts.append(str(minutes) + "m")
	if secs > 0 and days == 0 and hours == 0:
		parts.append(str(secs) + "s")
	
	return " ".join(parts) if not parts.is_empty() else "0s"


## Format unix timestamp to human-readable time
static func format_timestamp(timestamp: int) -> String:
	if timestamp == 0:
		return "never"
	
	var datetime: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

