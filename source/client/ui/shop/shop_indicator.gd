extends Control

## Shop Indicator - Displayed above players with shops open

var shop_name: String = "":
	set(value):
		shop_name = value
		if is_node_ready():
			_update_display()

var peer_id: int = -1

@onready var shop_name_label: Label = $Panel/VBoxContainer/ShopNameLabel
@onready var click_area: Button = $ClickArea


func _ready() -> void:
	_update_display()
	click_area.pressed.connect(_on_clicked)


func _update_display() -> void:
	if shop_name_label:
		shop_name_label.text = shop_name


func _on_clicked() -> void:
	# Open the shop browse UI
	if peer_id == -1:
		return
	
	# Find the shop browse UI in the scene tree
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("open_player_shop"):
		hud.open_player_shop(peer_id)
