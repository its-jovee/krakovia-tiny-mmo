class_name WorldMain
extends Node


var world_config_file: ConfigFile

var world_info: Dictionary


func _ready() -> void:
	# Server tick rate
	# For comparaison:
	# Eve Online - 1 tick par second.
	# Fortnite (Battle royale 100 players) - 30 ticks per second.
	# Albion Online - 2 ticks per second (to verify).
	# Valorant (5v5 FPS game) - 128 ticks per second.
	# I believe it depends of your game and architecture, it's a large topic.
	Engine.set_physics_ticks_per_second(10) # 60 by default
	
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("World Server")
	
	# Default config path. to use another one, override this;
	# or write --config=config_file_path.cfg as a launch argument.
	var error: bool = load_world_config("res://data/config/world_config.cfg")
	if error:
		printerr("World server loading configuration failed.")
	else:
		# Pre-load game resources if enabled in config
		_preload_resources()
		
		$Database.start_database(world_info)
		$WorldManagerClient.start_client_to_master_server(world_info)
		$WorldServer.start_world_server()


func load_world_config(config_path: String) -> bool:
	var config_file := ConfigFile.new()
	var parsed_arguments: Dictionary = CmdlineUtils.get_parsed_args()
	
	if parsed_arguments.has("config"):
		config_path = parsed_arguments["config"]
	
	var error: Error = config_file.load(config_path)
	if error != OK:
		printerr("Failed to load config at \"%s\".\nError: %s" % [config_path, error_string(error)])
		return true
	
	world_info = {
		"name": config_file.get_value("world-server", "name", "NoName"),
		"max_players": config_file.get_value("world-server", "max_players", 200),
		"hardcore": config_file.get_value("world-server", "hardcore", false),
		"motd": config_file.get_value("world-server", "motd", "Welcome!"),
		"bonus_xp": config_file.get_value("world-server", "bonus_xp", 0.0),
		"max_character": config_file.get_value("world-server", "max_character", 5),
		"pvp": config_file.get_value("world-server", "pvp", true)
	}
	
	world_config_file = config_file
	return false


func _preload_resources() -> void:
	"""Pre-load game resources into memory for better performance"""
	if world_config_file == null:
		return
	
	var preload_enabled: bool = world_config_file.get_value("performance", "preload_resources", true)
	var preload_items: bool = world_config_file.get_value("performance", "preload_items", true)
	var preload_recipes: bool = world_config_file.get_value("performance", "preload_recipes", true)
	
	if not preload_enabled:
		print("[WorldMain] Resource preloading disabled in config")
		return
	
	print("[WorldMain] ========================================")
	print("[WorldMain] PRE-LOADING GAME RESOURCES")
	print("[WorldMain] ========================================")
	
	var total_start_time := Time.get_ticks_msec()
	var total_start_memory := OS.get_static_memory_usage()
	var total_loaded := 0
	
	# Preload items
	if preload_items:
		var item_stats := ContentRegistryHub.preload_all_content(&"items")
		if item_stats.get("success", false):
			total_loaded += item_stats.get("loaded_count", 0)
	
	# Preload recipes
	if preload_recipes:
		var recipe_stats := ContentRegistryHub.preload_all_content(&"recipes")
		if recipe_stats.get("success", false):
			total_loaded += recipe_stats.get("loaded_count", 0)
	
	var total_elapsed_ms := Time.get_ticks_msec() - total_start_time
	var total_memory_increase := OS.get_static_memory_usage() - total_start_memory
	
	print("[WorldMain] ========================================")
	print("[WorldMain] PRELOAD COMPLETE")
	print("[WorldMain] Total resources: %d" % total_loaded)
	print("[WorldMain] Total time: %.2fs" % (total_elapsed_ms / 1000.0))
	print("[WorldMain] Memory increase: %.2f MB" % (total_memory_increase / 1024.0 / 1024.0))
	print("[WorldMain] ========================================")
	
	# Display cache stats
	var cache_stats := ContentRegistryHub.get_cache_stats()
	print("[WorldMain] Cache: %d resources cached (enabled: %s)" % [
		cache_stats.get("cached_count", 0),
		cache_stats.get("enabled", false)
	])
