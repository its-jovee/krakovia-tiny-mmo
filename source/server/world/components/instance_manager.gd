class_name InstanceManagerServer
extends SubViewportContainer

const InstanceResourceClass = preload("res://source/common/gameplay/maps/instance/instance_resource.gd")
const INSTANCE_COLLECTION_PATH: String = "res://source/common/gameplay/maps/instance/instance_collection/"

var loading_instances: Dictionary[InstanceResource, ServerInstance]
var instance_collection: Array[InstanceResource]

@export var world_server: WorldServer


func start_instance_manager() -> void:
	ServerInstance.world_server = world_server

	configure_global_roles_and_commands()

	set_instance_collection.call_deferred()

	# Timer which will call unload_unused_instances
	var timer: Timer = Timer.new()
	timer.wait_time = 20.0 # 20.0 is for testing, consider increasing it

	timer.autostart = true
	timer.timeout.connect(unload_unused_instances)
	add_sibling(timer)


func configure_global_roles_and_commands() -> void:
	ServerInstance.global_chat_commands = {
		"/heal" = load("res://source/server/world/components/chat_command/heal_command.gd").new(),
		"/size" = load("res://source/server/world/components/chat_command/size_command.gd").new(),
		"/getid" = load("res://source/server/world/components/chat_command/getid_command.gd").new(),
		"/help" = load("res://source/server/world/components/chat_command/help_command.gd").new(),
		"/set" = load("res://source/server/world/components/chat_command/set_command.gd").new(),
		"/trade" = load("res://source/server/world/components/chat_command/trade_command.gd").new(),
		# Admin commands
		"/give" = load("res://source/server/world/components/chat_command/give_command.gd").new(),
		"/setgold" = load("res://source/server/world/components/chat_command/setgold_command.gd").new(),
		"/setlevel" = load("res://source/server/world/components/chat_command/setlevel_command.gd").new(),
		"/ban" = load("res://source/server/world/components/chat_command/ban_command.gd").new(),
		"/mute" = load("res://source/server/world/components/chat_command/mute_command.gd").new(),
		"/tp" = load("res://source/server/world/components/chat_command/tp_command.gd").new(),
	}

	ServerInstance.global_role_definitions = {
		"senior_admin": {
			"commands": ["/heal", "/size", "/set", "/give", "/setgold", "/setlevel", "/ban", "/mute", "/tp"],
			"priority": 5,
		},
		"moderator": {
			"commands": ["/heal", "/size", "/mute"],
			"priority": 1,
			},
		"default": {
			"commands": ["/help", "/getid", "/trade"]
		}
	}

	if OS.has_feature("debug") or OS.has_feature("editor"):
		ServerInstance.global_chat_commands["/selfadmin"] = load("res://source/server/world/components/chat_command/selfadmin_command.gd").new()
		ServerInstance.global_role_definitions["default"]["commands"].append("/selfadmin")


@rpc("authority", "call_remote", "reliable", 0)
func charge_new_instance(_map_path: String, _instance_id: String) -> void:
	pass


func _on_player_entered_warper(player: Player, current_instance: ServerInstance, warper: Warper) -> void:
	var instance_index: int = -1 # Will be useful later
	var target_instance: ServerInstance
	var instance_resource: InstanceResource = warper.target_instance
	if not instance_resource:
		return

	if instance_resource.can_join_instance(player, instance_index):
		target_instance = instance_resource.get_instance()
		if target_instance:
			player_switch_instance(target_instance, warper.target_id, player, current_instance)
		else:
			queue_charge_instance(
				instance_resource,
				player_switch_instance.bind(warper.target_id, player, current_instance)
			)
	else:
		return


func queue_charge_instance(instance_resource: InstanceResource, callback: Callable) -> void:
	if loading_instances.has(instance_resource):
		loading_instances[instance_resource].ready.connect(
			callback.bind(loading_instances[instance_resource])
		)
		return
	var new_instance: ServerInstance = prepare_instance(instance_resource)
	new_instance.ready.connect(callback.bind(new_instance), CONNECT_ONE_SHOT)
	add_child(new_instance, true)


func player_switch_instance(
	target_instance: ServerInstance,
	warper_target_id: int,
	player: Player,
	current_instance: ServerInstance,
) -> void:
	var peer_id: int = player.name.to_int()
	if current_instance.connected_peers.has(peer_id):
		current_instance.despawn_player(peer_id, false)
	else:
		return
	charge_new_instance.rpc_id(
		peer_id,
		target_instance.instance_resource.map_path,
		target_instance.name
	)
	target_instance.awaiting_peers[peer_id] = {
		"player": player,
		"target_id": warper_target_id
	}


func charge_instance(instance_resource: InstanceResource) -> void:
	if loading_instances.has(instance_resource):
		return
	var new_instance: ServerInstance = prepare_instance(instance_resource)
	add_child.call_deferred(new_instance, true)


func prepare_instance(instance_resource: InstanceResource) -> ServerInstance:
	var instance: ServerInstance = ServerInstance.new()
	loading_instances[instance_resource] = instance
	instance.name = str(instance.get_instance_id())
	instance.instance_resource = instance_resource
	instance.player_entered_warper.connect(_on_player_entered_warper)
	instance.ready.connect(
		func():
			loading_instances.erase(instance_resource)
			instance_resource.charged_instances.append(instance),
		CONNECT_ONE_SHOT
	)
	instance.load_map(instance_resource.map_path)
	return instance


func set_instance_collection() -> void:
	var default_instance: InstanceResource

	for file_path: String in FileUtils.get_all_file_at(INSTANCE_COLLECTION_PATH):
		print(file_path)
		var resource = ResourceLoader.load(file_path)
		if resource:
			instance_collection.append(resource)
		else:
			push_error("Failed to load:" + file_path)
	#for file_path: String in ResourceLoader.list_directory(INSTANCE_COLLECTION_PATH):
		#print(INSTANCE_COLLECTION_PATH + file_path)
		#instance_collection.append(ResourceLoader.load(INSTANCE_COLLECTION_PATH + file_path))
		#instance_collection.append(ResourceLoader.load(file_path, "InstanceResource"))

	for instance_resource: InstanceResource in instance_collection:
		if instance_resource.load_at_startup:
			charge_instance(instance_resource)
		if instance_resource.instance_name == "Overworld":
			default_instance = instance_resource

	world_server.multiplayer_api.peer_connected.connect(
		func(peer_id: int):
			charge_new_instance.rpc_id(
				peer_id,
				default_instance.map_path,
				default_instance.charged_instances[0].name
			)
	)


func unload_unused_instances() -> void:
	print("Checking unload_unused_instances")
	for instance: ServerInstance in get_children():
		if instance.instance_resource.load_at_startup:
			continue
		if instance.connected_peers:
			continue
		instance.instance_resource.charged_instances.erase(instance)
		instance.queue_free()
