extends Node


func _ready() -> void:
	if OS.has_feature("web"):
		DisplayServer.window_set_title("Kraftovia")
	pass
