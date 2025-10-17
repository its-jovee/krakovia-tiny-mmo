extends Control

## Shop Indicator - Displayed above players with shops open
## Behaves like speech bubble: scales with zoom and positions above player

var shop_name: String = "":
	set(value):
		shop_name = value
		if is_node_ready():
			_update_display()

var peer_id: int = -1

@onready var panel: Panel = $Panel
@onready var shop_name_label: Label = $Panel/VBoxContainer/ShopNameLabel
@onready var click_area: Button = $ClickArea


func _ready() -> void:
	_update_display()
	click_area.pressed.connect(_on_clicked)


func _update_display() -> void:
	if shop_name_label:
		shop_name_label.text = shop_name


func _process(_delta: float) -> void:
	# Scale inversely with zoom to maintain consistent size (same as speech bubble)
	var camera_zoom: float = 1.0
	var viewport: Viewport = get_viewport()
	if viewport:
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			camera_zoom = camera.zoom.x
	
	# Scale inversely with zoom to maintain consistent size
	scale = Vector2.ONE / camera_zoom
	
	# Position the indicator above the player (same logic as speech bubble)
	if get_parent():
		var parent_pos: Vector2 = get_parent().global_position
		# Center horizontally on the player, accounting for scale and actual width
		var actual_width: float = panel.size.x if panel else 0
		var scaled_half_width: float = (actual_width / 2.0) * scale.x
		
		# Position above the player
		var actual_height: float = panel.size.y if panel else 0
		var scaled_height: float = actual_height * scale.y
		var y_offset: float = -scaled_height - 50  # 50px padding above the player
		
		global_position = parent_pos + Vector2(-scaled_half_width, y_offset)


func _on_clicked() -> void:
	# Open the shop browse UI
	if peer_id == -1:
		return
	
	# Find the shop browse UI in the scene tree
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("open_player_shop"):
		hud.open_player_shop(peer_id)
