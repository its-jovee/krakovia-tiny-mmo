extends Control


func _ready() -> void:
	# Update slider to match current zoom from Events.settings
	if Events.settings.has("zoom"):
		$VBoxContainer/HBoxContainer/HSlider.value = Events.settings["zoom"]
	else:
		Events.settings["zoom"] = 1.0
		$VBoxContainer/HBoxContainer/HSlider.value = 1.0


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	var h_slider: HSlider = $VBoxContainer/HBoxContainer/HSlider
	
	# Update the target zoom in the local player to sync with slider changes
	if Events.local_player:
		Events.local_player.target_zoom = h_slider.value
		Events.local_player.$Camera2D.zoom = Vector2.ONE * h_slider.value
	
	Events.settings["zoom"] = h_slider.value


func _on_button_pressed() -> void:
	hide()
