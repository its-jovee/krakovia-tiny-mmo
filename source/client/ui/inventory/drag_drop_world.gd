extends VBoxContainer

const HAND_CLOSED = preload("res://assets/audio/Vector/Basic/hand_closed.svg")
const HAND_POINT = preload("res://assets/audio/Vector/Basic/hand_point.svg")
const HAND_CLICK = preload("res://assets/audio/Vector/Basic/hand_small_point.svg")


func _ready() -> void:
	Input.set_custom_mouse_cursor(HAND_POINT, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(HAND_CLOSED, Input.CURSOR_FORBIDDEN)
	Input.set_custom_mouse_cursor(HAND_CLOSED, Input.CURSOR_CAN_DROP)
	Input.set_custom_mouse_cursor(HAND_CLOSED, Input.CURSOR_DRAG)
