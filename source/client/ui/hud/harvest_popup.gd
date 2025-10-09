extends Control


@onready var icon: TextureRect = $Panel/HBoxContainer/Icon
@onready var label: Label = $Panel/HBoxContainer/Label

var lifetime: float = 2.5
var elapsed: float = 0.0
var float_speed: float = 30.0


func setup(item_name: String, item_icon: Texture2D, amount: int) -> void:
	if icon:
		icon.texture = item_icon
	if label:
		label.text = "+%d %s" % [amount, item_name]
	
	# Start animation
	modulate = Color(1, 1, 1, 0)  # Start transparent
	_animate_in()


func _animate_in() -> void:
	# Fade in and float up animation
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Scale pop
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.2)


func _process(delta: float) -> void:
	elapsed += delta
	
	# Float upward
	position.y -= float_speed * delta
	
	# Start fading out after 1.5 seconds
	if elapsed > 1.5:
		modulate.a = max(0.0, 1.0 - ((elapsed - 1.5) / 1.0))
	
	# Remove after lifetime
	if elapsed >= lifetime:
		queue_free()

