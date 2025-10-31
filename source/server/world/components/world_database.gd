class_name WorldDatabase
extends Node


var database_path: String

var player_data: WorldPlayerData

var auto_save_timer: Timer
var save_warning_timer: Timer

# Configuration from world_config.cfg
var backup_count: int = 3
var backup_on_save: bool = true
var log_save_stats: bool = true
var config_file: ConfigFile


func start_database(world_info: Dictionary) -> void:
	configure_database(world_info)
	load_world_database()
	setup_auto_save()


func configure_database(world_info: Dictionary) -> void:
	if OS.has_feature("editor"):
		database_path = "res://source/server/world/data/"
	else:
		database_path = "."
	database_path += str(world_info["name"] + ".tres").to_lower()
	
	print("[WorldDatabase] Using database path: %s" % database_path)
	
	# Load configuration settings
	_load_config()


func load_world_database() -> void:
	if ResourceLoader.exists(database_path, "WorldPlayerData"):
		# In editor, use CACHE_MODE_IGNORE to force reload from disk
		# This prevents stale cached data between editor runs
		if OS.has_feature("editor"):
			player_data = ResourceLoader.load(database_path, "WorldPlayerData", ResourceLoader.CACHE_MODE_IGNORE)
			print("[WorldDatabase] Loaded database from disk (cache ignored) - %d players, %d accounts" % [player_data.players.size(), player_data.accounts.size()])
		else:
			player_data = ResourceLoader.load(database_path, "WorldPlayerData")
			print("[WorldDatabase] Loaded database - %d players, %d accounts" % [player_data.players.size(), player_data.accounts.size()])
		
		# Debug: Check accounts dictionary integrity
		print("[WorldDatabase] Accounts dict type: %s, Players dict type: %s" % [typeof(player_data.accounts), typeof(player_data.players)])
		if player_data.accounts.size() > 0:
			var first_account_key = player_data.accounts.keys()[0]
			print("[WorldDatabase] First account key type: %s, value: %s" % [typeof(first_account_key), first_account_key])
		
		# Unconditional normalization: break any stale typed dictionaries and persist once
		# 1) Duplicate into fresh plain Dictionaries (deep copy)
		player_data.players = player_data.players.duplicate(true)
		player_data.accounts = player_data.accounts.duplicate(true)
		if typeof(player_data.guilds) == TYPE_DICTIONARY:
			player_data.guilds = player_data.guilds.duplicate(true)
		else:
			player_data.guilds = {}
		
		# 2) Rebuild accounts mapping from players if it is missing or smaller
		var rebuilt_accounts := {}
		for _pid in player_data.players.keys():
			var pid: int = _pid
			var p = player_data.players[pid]
			if p and not String(p.account_name).is_empty():
				var h := String(p.account_name)
				if not rebuilt_accounts.has(h):
					rebuilt_accounts[h] = PackedInt32Array()
				rebuilt_accounts[h].append(pid)
		# Only replace when it's strictly better or original is empty
		if rebuilt_accounts.size() >= player_data.accounts.size():
			player_data.accounts = rebuilt_accounts
		
		# 3) Persist normalized structure once so future runs load clean dicts
		save_world_database()

		# Fix data integrity after loading (handles typed dictionary corruption)
		_fix_database_integrity()
	else:
		player_data = WorldPlayerData.new()
		print("[WorldDatabase] No existing database found, created new WorldPlayerData")


func setup_auto_save() -> void:
	# Auto-save timer - saves every 30 seconds
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = 30.0
	auto_save_timer.timeout.connect(_auto_save)
	auto_save_timer.autostart = true
	add_child(auto_save_timer)
	
	# Warning timer - sends warning 1 minute before save
	save_warning_timer = Timer.new()
	save_warning_timer.wait_time = 29.0  # 1 second before auto-save
	save_warning_timer.timeout.connect(_send_save_warning)
	save_warning_timer.autostart = true
	add_child(save_warning_timer)


func _send_save_warning() -> void:
	pass
	#send_system_message("⚠️ The world will save in 1 minute...")


func _auto_save() -> void:
	save_world_database()
	#send_system_message("✅ World data saved successfully!")


func send_system_message(message: String) -> void:
	# Get the world server to send chat messages to all players
	var world_server = get_parent().get_node("WorldServer")
	if world_server and world_server.has_method("get_node"):
		var instance_manager = world_server.get_node("InstanceManager")
		if instance_manager:
			# Send to all connected instances
			for child in instance_manager.get_children():
				if child.has_method("propagate_rpc"):
					var chat_message = {
						"text": message,
						"name": "System",
						"id": 1
					}
					child.propagate_rpc(child.data_push.bind(&"chat.message", chat_message))


func save_world_database() -> void:
	"""
	Save the database directly to the target path. Atomic rename disabled per request.
	"""
	var start_time := Time.get_ticks_msec()
	
	# Direct save
	var error: Error = ResourceSaver.save(player_data, database_path)
	if error != OK:
		printerr("[WorldDatabase] ERROR: Failed to save database: %s" % error_string(error))
		return
	
	# Optional backup after successful save (kept enabled if configured)
	if backup_on_save and FileAccess.file_exists(database_path):
		_create_backup()
	
	# Log stats if enabled
	if log_save_stats:
		var elapsed_ms := Time.get_ticks_msec() - start_time
		var file_size := _get_file_size(database_path)
		print("[WorldDatabase] Save completed in %dms (%.2f KB)" % [elapsed_ms, file_size / 1024.0])
	
	# Cleanup old backups
	_cleanup_old_backups()


func _create_backup() -> void:
	"""Create a timestamped backup of the current database file"""
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var backup_path := "%s.backup.%s" % [database_path, timestamp]
	var abs_main := ProjectSettings.globalize_path(database_path)
	var abs_backup := ProjectSettings.globalize_path(backup_path)
	
	var error := DirAccess.copy_absolute(abs_main, abs_backup)
	if error != OK:
		push_warning("[WorldDatabase] Failed to create backup: %s" % error_string(error))
	else:
		if log_save_stats:
			print("[WorldDatabase] Backup created: %s" % backup_path.get_file())


func _cleanup_old_backups() -> void:
	"""Keep only the most recent N backups, delete older ones"""
	var dir_path := database_path.get_base_dir()
	var file_name := database_path.get_file()
	var backup_prefix := file_name + ".backup."
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	
	# Find all backup files
	var backups: Array[String] = []
	var dir := DirAccess.open(abs_dir)
	if dir:
		dir.list_dir_begin()
		var file_name_iter := dir.get_next()
		while file_name_iter != "":
			if file_name_iter.begins_with(backup_prefix):
				backups.append(abs_dir.path_join(file_name_iter))
			file_name_iter = dir.get_next()
		dir.list_dir_end()
	
	# Sort by modification time (newest first)
	backups.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b)
	)
	
	# Delete old backups beyond the configured count
	var deleted_count := 0
	for i in range(backup_count, backups.size()):
		var error := DirAccess.remove_absolute(backups[i])
		if error == OK:
			deleted_count += 1
		else:
			push_warning("[WorldDatabase] Failed to delete old backup %s: %s" % [backups[i], error_string(error)])
	
	if deleted_count > 0 and log_save_stats:
		print("[WorldDatabase] Deleted %d old backup(s)" % deleted_count)


func restore_from_backup(backup_index: int = 0) -> bool:
	"""
	Restore database from a backup file.
	backup_index: 0 = most recent, 1 = second most recent, etc.
	Returns true if restore was successful.
	"""
	var dir_path := database_path.get_base_dir()
	var file_name := database_path.get_file()
	var backup_prefix := file_name + ".backup."
	
	# Find all backup files
	var backups: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name_iter := dir.get_next()
		while file_name_iter != "":
			if file_name_iter.begins_with(backup_prefix):
				backups.append(dir_path.path_join(file_name_iter))
			file_name_iter = dir.get_next()
		dir.list_dir_end()
	
	if backups.is_empty():
		printerr("[WorldDatabase] No backup files found!")
		return false
	
	# Sort by modification time (newest first)
	backups.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b)
	)
	
	if backup_index >= backups.size():
		printerr("[WorldDatabase] Backup index %d out of range (only %d backups)" % [backup_index, backups.size()])
		return false
	
	var backup_to_restore := backups[backup_index]
	print("[WorldDatabase] Restoring from backup: %s" % backup_to_restore.get_file())
	
	# Copy backup to main database path
	var error := DirAccess.copy_absolute(backup_to_restore, database_path)
	if error != OK:
		printerr("[WorldDatabase] Failed to restore backup: %s" % error_string(error))
		return false
	
	# Reload the database
	load_world_database()
	print("[WorldDatabase] Database restored successfully")
	return true


func _load_config() -> void:
	"""Load configuration from world_config.cfg"""
	var parsed_arguments := CmdlineUtils.get_parsed_args()
	var config_path := "res://data/config/world_config.cfg"
	
	if parsed_arguments.has("config"):
		config_path = parsed_arguments["config"]
	
	config_file = ConfigFile.new()
	var error := config_file.load(config_path)
	if error != OK:
		push_warning("[WorldDatabase] Could not load config file, using defaults")
		return
	
	# Load database settings
	backup_count = config_file.get_value("database", "backup_count", 3)
	backup_on_save = config_file.get_value("database", "backup_on_save", true)
	log_save_stats = config_file.get_value("database", "log_save_stats", true)
	
	print("[WorldDatabase] Configuration loaded: backups=%d, backup_on_save=%s" % [backup_count, backup_on_save])


func _get_file_size(path: String) -> int:
	"""Get file size in bytes"""
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var size := file.get_length()
		file.close()
		return size
	return 0


func _fix_database_integrity() -> void:
	"""
	Fix database integrity issues after loading.
	Handles corrupted typed dictionaries from older versions.
	"""
	var fixed_issues := 0
	var needs_full_rebuild := false
	
	# Test if accounts dictionary is functional (typed dict serialization bug)
	# Typed dicts can read old keys but can't add/retrieve new string keys
	var accounts_functional := true
	var test_handle := "__integrity_test__"
	var test_value := PackedInt32Array([999999])
	
	# Try to add and retrieve a test key
	player_data.accounts[test_handle] = test_value
	if not player_data.accounts.has(test_handle):
		print("[WorldDatabase] CRITICAL: accounts dictionary is corrupted (typed dict bug - can't add new keys) - forcing rebuild...")
		accounts_functional = false
		needs_full_rebuild = true
		fixed_issues += 1
	else:
		# Clean up test key
		player_data.accounts.erase(test_handle)
	
	# Test if players dictionary is functional
	var players_functional := true
	if player_data.players.size() > 0:
		var test_key = player_data.players.keys()[0]
		if not player_data.players.has(test_key):
			print("[WorldDatabase] CRITICAL: players dictionary is corrupted (typed dict bug) - forcing rebuild...")
			players_functional = false
			needs_full_rebuild = true
			fixed_issues += 1
	
	# If dictionaries are corrupted, rebuild them
	if needs_full_rebuild:
		print("[WorldDatabase] Rebuilding dictionaries from corrupted typed format...")
		
		# Rebuild players dict if needed
		if not players_functional and player_data.players.size() > 0:
			var old_players = player_data.players
			var new_players := {}
			print("[WorldDatabase] Attempting to recover %d players..." % old_players.size())
			
			var recovered := 0
			for key in old_players.keys():
				var value = old_players[key]
				if value != null:
					new_players[key] = value
					recovered += 1
			
			player_data.players = new_players
			print("[WorldDatabase] Recovered %d players" % recovered)
		
		# Rebuild accounts dict from players
		var old_accounts = player_data.accounts
		var new_accounts := {}
		
		print("[WorldDatabase] Rebuilding accounts dictionary from %d players..." % player_data.players.size())
		
		for player_id in player_data.players.keys():
			var player_res = player_data.players[player_id]
			if player_res and String(player_res.account_name) != "":
				var handle: String = player_res.account_name
				if not new_accounts.has(handle):
					new_accounts[handle] = PackedInt32Array()
				new_accounts[handle].append(player_id)
		
		player_data.accounts = new_accounts
		print("[WorldDatabase] Rebuilt accounts dictionary - now has %d accounts" % player_data.accounts.size())
	
	# Final check: if accounts is still empty but players exist, rebuild
	if player_data.accounts.size() == 0 and player_data.players.size() > 0:
		print("[WorldDatabase] Accounts dict empty but players exist - rebuilding...")
		for player_id in player_data.players.keys():
			var player_res = player_data.players[player_id]
			if player_res and String(player_res.account_name) != "":
				var handle: String = player_res.account_name
				if not player_data.accounts.has(handle):
					player_data.accounts[handle] = PackedInt32Array()
				player_data.accounts[handle].append(player_id)
				fixed_issues += 1
		print("[WorldDatabase] Rebuilt accounts dictionary - now has %d accounts" % player_data.accounts.size())
	
	if fixed_issues > 0:
		print("[WorldDatabase] Fixed %d database integrity issues - saving corrected database..." % fixed_issues)
		save_world_database()
	else:
		print("[WorldDatabase] Database integrity check passed")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[WorldDatabase] Server closing, performing final save...")
		save_world_database()
