class_name InstanceManagerClient
extends Node


signal instance_changed(instance: InstanceClient)

var current_ui: UI
var current_instance: InstanceClient


func _ready() -> void:
	pass


@rpc("authority", "call_remote", "reliable", 0)
func charge_new_instance(map_path: String, instance_id: String) -> void:
	var new_instance: InstanceClient = InstanceClient.new()
	new_instance.name = instance_id
	
	print("Loading new map: %s." % map_path)
	var map: Map = load(map_path).instantiate() as Map
	if not map:
		return
	new_instance.instance_map = map
	
	map.ready.connect(
		new_instance.ready_to_enter_instance.rpc_id.bind(1),
		CONNECT_ONE_SHOT
	)
	map.ready.connect(
		instance_changed.emit.bind(new_instance),
		CONNECT_ONE_SHOT
	)
	
	if current_instance:
		if current_instance.local_player:
			current_instance.instance_map.remove_child(current_instance.local_player)
			#current_instance.local_player.reparent(new_instance, false)
		current_instance.queue_free()
	current_instance = new_instance
	
	var map_bgcolor: Color = current_instance.instance_map.map_background_color
	RenderingServer.set_default_clear_color(map_bgcolor)

	new_instance.add_child(map, true)
	add_child(new_instance, true)
	
	# Set up day/night cycle
	_setup_day_night_cycle(map)
	
	# Charge different type of UI/HUD and clear old one,
	# for mini game / special instances that would require unique HUD ? 
	
	#if current_ui:
		#current_ui.queue_free()
	if not current_ui:
		current_ui = preload("res://source/client/ui/ui.tscn").instantiate()
		add_child(current_ui)


func _setup_day_night_cycle(map: Map) -> void:
	"""Set up the day/night cycle for the loaded map"""
	# Find the CanvasModulate in the map
	var canvas_modulate: CanvasModulate = null
	for child in map.get_children():
		if child is CanvasModulate:
			canvas_modulate = child
			break
	
	if not canvas_modulate:
		# Try finding it recursively
		canvas_modulate = map.find_child("CanvasModulate", true, false) as CanvasModulate
	
	if canvas_modulate:
		# Create and set up the DayNightCycle
		var day_night = DayNightCycle.new()
		day_night.name = "DayNightCycle"
		map.add_child(day_night)
		day_night.set_canvas_modulate(canvas_modulate)
		
		# Store reference for time updates
		InstanceClient.day_night_cycle = day_night
		print("[InstanceManager] Day/night cycle connected to CanvasModulate")
	else:
		print("[InstanceManager] No CanvasModulate found in map - day/night cycle disabled")
	
