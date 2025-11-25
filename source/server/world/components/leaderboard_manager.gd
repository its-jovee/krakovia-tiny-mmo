class_name LeaderboardManager
extends Node
## Manages leaderboard data caching and periodic updates

const UPDATE_INTERVAL_SECONDS: int = 60  # Update every 60 seconds
const MAX_ENTRIES_PER_LEADERBOARD: int = 50
const KRAK_ITEM_ID: int = 317

# Score formula weights
const KRAK_WEIGHT: float = 10000.0
const GOLD_WEIGHT: float = 0.1
const LEVEL_WEIGHT: float = 100.0

# Cached leaderboard data
var cached_leaderboards: Dictionary = {
	"global": [],
	"miner": [],
	"forager": [],
	"trapper": []
}

var update_timer: Timer
var world_server: WorldServer


func _ready() -> void:
	# Set up update timer
	update_timer = Timer.new()
	update_timer.wait_time = UPDATE_INTERVAL_SECONDS
	update_timer.autostart = true
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	
	print("[LeaderboardManager] Initialized. Will update every %d seconds." % UPDATE_INTERVAL_SECONDS)
	
	# Do initial update after a short delay to ensure world_server is set
	await get_tree().create_timer(1.0).timeout
	update_leaderboards()


func _on_update_timer_timeout() -> void:
	update_leaderboards()


func update_leaderboards() -> void:
	if not world_server or not world_server.database or not world_server.database.player_data:
		print("[LeaderboardManager] Cannot update leaderboards - world server or database not ready")
		return
	
	var start_time := Time.get_ticks_msec()
	var player_data: WorldPlayerData = world_server.database.player_data
	
	# Build list of all player entries with scores
	var all_entries: Array[Dictionary] = []
	
	for player_id in player_data.players.keys():
		var player_res: PlayerResource = player_data.players[player_id]
		if not player_res:
			continue
		
		# Calculate Krak count from inventory
		var krak_count: int = 0
		if player_res.inventory.has(KRAK_ITEM_ID):
			krak_count = player_res.inventory[KRAK_ITEM_ID].get("stack", 0)
		
		# Calculate composite score
		var score: float = (krak_count * KRAK_WEIGHT) + (player_res.golds * GOLD_WEIGHT) + (player_res.level * LEVEL_WEIGHT)
		
		var entry: Dictionary = {
			"player_id": player_res.player_id,
			"name": player_res.display_name,
			"class": player_res.character_class,
			"krak": krak_count,
			"level": player_res.level,
			"gold": player_res.golds,
			"score": score
		}
		
		all_entries.append(entry)
	
	# Sort all entries by score (descending)
	all_entries.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Build global leaderboard (top 50)
	cached_leaderboards["global"] = all_entries.slice(0, MAX_ENTRIES_PER_LEADERBOARD)
	
	# Build class-specific leaderboards
	for char_class in ["miner", "forager", "trapper"]:
		var class_entries: Array[Dictionary] = []
		for entry in all_entries:
			if entry["class"] == char_class:
				class_entries.append(entry)
				if class_entries.size() >= MAX_ENTRIES_PER_LEADERBOARD:
					break
		cached_leaderboards[char_class] = class_entries
	
	var elapsed_ms := Time.get_ticks_msec() - start_time
	print("[LeaderboardManager] Updated leaderboards in %d ms. Players processed: %d" % [elapsed_ms, all_entries.size()])
	print("  Global: %d entries, Miner: %d, Forager: %d, Trapper: %d" % [
		cached_leaderboards["global"].size(),
		cached_leaderboards["miner"].size(),
		cached_leaderboards["forager"].size(),
		cached_leaderboards["trapper"].size()
	])


func get_leaderboard_data() -> Dictionary:
	"""Returns all cached leaderboard data"""
	return cached_leaderboards.duplicate(true)
