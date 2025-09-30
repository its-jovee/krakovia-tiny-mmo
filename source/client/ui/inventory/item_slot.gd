extends Panel

@onready var icon: TextureRect = $Icon

func _get_drag_data(_at_position: Vector2) -> Variant:
	if icon.texture == null:
		return
	
	var preview = duplicate()
	var c = Control.new()
	c.add_child(preview)
	preview.self_modulate = Color.TRANSPARENT
	c.modulate = Color(c.modulate, 0.5)
	
	set_drag_preview(c)
	icon.hide()
	return icon

func _can_drop_data(at_position: Vector2, _data:Variant) -> bool:
	return true
	
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var tmp = icon.texture
	icon.texture = data.texture
	data.texture = null
	icon.show()
	data.show()

var data_bk
func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_DRAG_BEGIN:
		data_bk = get_viewport().gui_get_drag_data()
	if what == Node.NOTIFICATION_DRAG_END:
		if not is_drag_successful():
			if data_bk:
				data_bk.show()
