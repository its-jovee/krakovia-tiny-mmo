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

var has_shop_open: bool = false:
	set(value):
		has_shop_open = value
		_update_shop_indicator()

var shop_name: String = "":
	set(value):
		shop_name = value
		_update_shop_indicator()

var peer_id: int = -1

@onready var syn: StateSynchronizer = $StateSynchronizer
@onready var display_name_label: Label = $DisplayNameLabel
@onready var handle_name_label: Label = $HandleNameLabel
@onready var speech_bubble: Control = $SpeechBubble

var shop_indicator: Control = null


func _init() -> void:
	pass

func _set_handle_name(new_handle: String) -> void:
	handle_name = new_handle
	if is_node_ready():
		handle_name_label.text = "@" + new_handle

func _set_display_name(new_name: String) -> void:
	display_name_label.text = new_name
	display_name = new_name


func show_speech_bubble(text: String) -> void:
	if not is_node_ready():
		await ready
	if speech_bubble and speech_bubble.has_method("show_message"):
		speech_bubble.show_message(text)


func _update_shop_indicator() -> void:
	print("=== PLAYER: _update_shop_indicator called ===")
	print("Player name: ", name)
	print("peer_id: ", peer_id)
	print("has_shop_open: ", has_shop_open)
	print("shop_name: ", shop_name)
	print("is_node_ready: ", is_node_ready())
	
	if not is_node_ready():
		print("Node not ready yet, waiting...")
		return
	
	if has_shop_open and shop_name != "":
		print("Should show shop indicator!")
		# Show shop indicator
		if shop_indicator == null:
			print("Creating new shop indicator...")
			var shop_indicator_scene = preload("res://source/client/ui/shop/shop_indicator.tscn")
			shop_indicator = shop_indicator_scene.instantiate()
			add_child(shop_indicator)
			# Position is now handled by shop_indicator's _process() method (like speech bubble)
			shop_indicator.peer_id = peer_id
			print("Shop indicator created and added!")
		
		shop_indicator.shop_name = shop_name
		shop_indicator.visible = true
		print("Shop indicator should now be visible!")
	else:
		print("Should hide shop indicator")
		# Hide/remove shop indicator
		if shop_indicator != null:
			shop_indicator.visible = false
			print("Shop indicator hidden")
