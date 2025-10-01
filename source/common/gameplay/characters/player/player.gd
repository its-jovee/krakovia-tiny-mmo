class_name Player
extends Character


var player_resource: PlayerResource

var display_name: String = "Unknown":
	set = _set_display_name

var handle_name: String = " ":
	set = _set_handle_name

var is_in_pvp_zone: bool = false
var just_teleported: bool = false:
	set(value):
		just_teleported = value
		if not is_inside_tree():
			await tree_entered
		if just_teleported:
			await get_tree().create_timer(0.5).timeout
			just_teleported = false

@onready var syn: StateSynchronizer = $StateSynchronizer
@onready var display_name_label: Label = $DisplayNameLabel
@onready var handle_name_label: Label = $HandleNameLabel


func _init() -> void:
	pass

func _set_handle_name(new_handle: String) -> void:
	handle_name = new_handle
	if is_node_ready():
		handle_name_label.text = "@" + new_handle

func _set_display_name(new_name: String) -> void:
	display_name_label.text = new_name
	display_name = new_name
	
