class_name WorldDatabase
extends Node


var database_path: String

var player_data: WorldPlayerData

var auto_save_timer: Timer
var save_warning_timer: Timer


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
	var error: Error = ResourceSaver.save(player_data, database_path)
	if error:
		printerr("Error while saving player_data %s." % error_string(error))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_world_database()
