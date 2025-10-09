extends Control


@onready var level_label: Label = $Panel/VBoxContainer/LevelLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func setup(new_level: int) -> void:
	level_label.text = "LEVEL UP!\nLevel %d" % new_level
	
	# Play sound effect
	if audio_player:
		audio_player.play()
	
	# Play animation (fade in, scale, fade out)
	if animation_player and animation_player.has_animation("level_up"):
		animation_player.play("level_up")
	
	# Auto-cleanup after 3 seconds
	await get_tree().create_timer(3.0).timeout
	queue_free()

