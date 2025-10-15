extends Control


@onready var sprite: TextureRect = $TextureRect


func _ready() -> void:
	hide()


func show_potato() -> void:
	show()


func hide_potato() -> void:
	hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	
	# Scale inversely with zoom to maintain consistent size
	var camera_zoom: float = 1.0
	var viewport: Viewport = get_viewport()
	if viewport:
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			camera_zoom = camera.zoom.x
	
	# Scale inversely with zoom to maintain consistent size
	scale = Vector2.ONE / camera_zoom
	
	# Position above the player
	if get_parent():
		var parent_pos: Vector2 = get_parent().global_position
		# Center horizontally above the player
		var y_offset: float = -80  # Position above player head
		global_position = parent_pos + Vector2(-16, y_offset)  # -16 to center 32px sprite
