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
	
	# Load configuration settings
	_load_config()


func load_world_database() -> void:
	if ResourceLoader.exists(database_path, "WorldPlayerData"):
		player_data = ResourceLoader.load(database_path, "WorldPlayerData")
	else:
		player_data = WorldPlayerData.new()


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
	Save the database atomically with backup rotation.
	Uses a temporary file and atomic rename to prevent corruption.
	"""
	var start_time := Time.get_ticks_msec()
	
	# Create temp file path
	var temp_path := database_path + ".tmp.%d" % Time.get_ticks_msec()
	
	# Save to temp file first
	var error: Error = ResourceSaver.save(player_data, temp_path)
	if error != OK:
		printerr("[WorldDatabase] ERROR: Failed to save to temp file: %s" % error_string(error))
		# Try to clean up temp file
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return
	
	# Create backup if enabled and main database exists
	if backup_on_save and FileAccess.file_exists(database_path):
		_create_backup()
	
	# Atomic rename: temp -> main
	error = DirAccess.rename_absolute(temp_path, database_path)
	if error != OK:
		printerr("[WorldDatabase] ERROR: Failed to rename temp to main: %s" % error_string(error))
		# Try to clean up temp file
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return
	
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
	
	var error := DirAccess.copy_absolute(database_path, backup_path)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[WorldDatabase] Server closing, performing final save...")
		save_world_database()
