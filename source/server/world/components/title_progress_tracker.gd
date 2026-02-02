extends Node
class_name TitleProgressTracker

## Singleton instance for easy access across the server
static var instance: TitleProgressTracker


func _ready() -> void:
	instance = self


## Initialize account titles data if not present
func ensure_account_data(account_name: String, player_data: WorldPlayerData) -> void:
	if not player_data.account_titles.has(account_name):
		player_data.account_titles[account_name] = {
			"unlocked": [],
			"progress": {}
		}


## Increment a progress stat for an account
func increment_progress(account_name: String, stat_key: String, amount: int, player_data: WorldPlayerData, peer_id: int = -1, instance: ServerInstance = null) -> void:
	ensure_account_data(account_name, player_data)
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	if not account_data["progress"].has(stat_key):
		account_data["progress"][stat_key] = 0
	
	account_data["progress"][stat_key] += amount
	
	# Debug print
	print("[TitleProgressTracker] %s: %s = %d (+%d)" % [account_name, stat_key, account_data["progress"][stat_key], amount])
	
	# Send progress update to client if they're online
	if peer_id > 0 and instance:
		instance.data_push.rpc_id(peer_id, &"title.progress", {
			"stat_key": stat_key,
			"value": account_data["progress"][stat_key]
		})


## Set a progress value (for things like max level that don't increment)
func set_progress(account_name: String, stat_key: String, value: int, player_data: WorldPlayerData, peer_id: int = -1, instance: ServerInstance = null) -> void:
	ensure_account_data(account_name, player_data)
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	var old_value = account_data["progress"].get(stat_key, 0)
	
	# Only update if new value is higher (for max level tracking)
	if value > old_value:
		account_data["progress"][stat_key] = value
		print("[TitleProgressTracker] %s: %s = %d (was %d)" % [account_name, stat_key, value, old_value])
		
		# Send progress update to client if they're online
		if peer_id > 0 and instance:
			instance.data_push.rpc_id(peer_id, &"title.progress", {
				"stat_key": stat_key,
				"value": value
			})


## Get current progress value
func get_progress(account_name: String, stat_key: String, player_data: WorldPlayerData) -> int:
	if not player_data.account_titles.has(account_name):
		return 0
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	return account_data["progress"].get(stat_key, 0)


## Check and unlock titles of a specific type
func check_and_unlock(account_name: String, condition_type: int, peer_id: int, instance: ServerInstance) -> void:
	var player_data: WorldPlayerData = instance.world_server.database.player_data
	ensure_account_data(account_name, player_data)
	
	# Get all titles from registry
	var registry: ContentRegistry = ContentRegistryHub.registry_of(&"titles")
	if not registry:
		print("[TitleProgressTracker] ERROR: Titles registry not found!")
		return
	
	# Load the titles index directly
	var titles_index: ContentIndex = load("res://source/common/registry/indexes/titles_index.tres")
	if not titles_index:
		print("[TitleProgressTracker] ERROR: Titles index not found!")
		return
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	var unlocked_list: Array = account_data["unlocked"]
	var progress_data: Dictionary = account_data["progress"]
	
	# Iterate through all titles
	for entry in titles_index.entries:
		var title_slug: StringName = entry["slug"]
		
		# Skip if already unlocked
		if title_slug in unlocked_list:
			continue
		
		# Load title resource
		var title: TitleResource = ContentRegistryHub.load_by_slug(&"titles", title_slug)
		if not title:
			continue
		
		# Only check titles of the specified condition type
		if title.condition_type != condition_type:
			continue
		
		# Get current progress for this title
		var progress_key: String = title.get_progress_key()
		var current_progress: int = progress_data.get(progress_key, 0)
		
		# Check if unlocked
		if title.check_unlock_condition(current_progress):
			unlock_title(account_name, title_slug, peer_id, instance)


## Check for level-based title unlocks (handles "all classes" check)
func check_level_titles(account_name: String, peer_id: int, instance: ServerInstance) -> void:
	# Check regular level class titles
	check_and_unlock(account_name, TitleResource.ConditionType.LEVEL_CLASS, peer_id, instance)
	
	# Check "all classes at level X" titles
	var player_data: WorldPlayerData = instance.world_server.database.player_data
	ensure_account_data(account_name, player_data)
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	var progress_data: Dictionary = account_data["progress"]
	
	# Calculate minimum level across all classes
	var miner_level = progress_data.get("max_level_miner", 1)
	var collector_level = progress_data.get("max_level_collector", 1)
	var trapper_level = progress_data.get("max_level_trapper", 1)
	
	var min_level = mini(miner_level, mini(collector_level, trapper_level))
	
	# Update the special "all classes" progress
	set_progress(account_name, "all_classes_max_level", min_level, player_data, peer_id, instance)
	
	# Check all-classes titles
	check_and_unlock(account_name, TitleResource.ConditionType.LEVEL_ALL_CLASSES, peer_id, instance)


## Unlock a specific title and notify the player
func unlock_title(account_name: String, title_slug: StringName, peer_id: int, instance: ServerInstance) -> void:
	var player_data: WorldPlayerData = instance.world_server.database.player_data
	ensure_account_data(account_name, player_data)
	
	var account_data: Dictionary = player_data.account_titles[account_name]
	var unlocked_list: Array = account_data["unlocked"]
	
	# Check if already unlocked
	if title_slug in unlocked_list:
		return
	
	# Add to unlocked list
	unlocked_list.append(title_slug)
	
	# Load title for notification
	var title: TitleResource = ContentRegistryHub.load_by_slug(&"titles", title_slug)
	if not title:
		return
	
	print("[TitleProgressTracker] 🏆 %s unlocked title: %s" % [account_name, title.get_translated_name()])
	
	# Send notification to player
	instance.data_push.rpc_id(peer_id, &"title.unlocked", {
		"slug": String(title_slug),
		"name": title.title_name,
		"description": title.description,
		"rarity": title.rarity
	})
	
	# Save database
	instance.world_server.database.save_world_database()


## Get all progress data for an account
func get_all_progress(account_name: String, player_data: WorldPlayerData) -> Dictionary:
	ensure_account_data(account_name, player_data)
	return player_data.account_titles[account_name]
