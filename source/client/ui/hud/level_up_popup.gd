extends Control


@onready var level_label: Label = $Panel/VBoxContainer/LevelLabel
@onready var energy_label: Label = $Panel/VBoxContainer/EnergyLabel
@onready var recipes_label: Label = $Panel/VBoxContainer/RecipesLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer


func setup(new_level: int, unlocked_recipes: Array[String] = []) -> void:
	level_label.text = "LEVEL UP!\nLevel %d" % new_level
	
	# Show energy gained
	if energy_label:
		energy_label.text = "+50 Energy"
	
	# Show unlocked recipes
	if recipes_label:
		if unlocked_recipes.is_empty():
			recipes_label.text = ""
			recipes_label.visible = false
		else:
			recipes_label.visible = true
			var recipes_text = "Unlocked Recipes:\n"
			for recipe_name in unlocked_recipes:
				recipes_text += "• " + recipe_name + "\n"
			recipes_label.text = recipes_text.strip_edges()
	
	# Play sound effect
	if audio_player:
		audio_player.play()
	
	# Play animation (fade in, scale, fade out)
	if animation_player and animation_player.has_animation("level_up"):
		animation_player.play("level_up")
	
	# Auto-cleanup after 4 seconds (increased to allow reading recipes)
	await get_tree().create_timer(4.0).timeout
	queue_free()

