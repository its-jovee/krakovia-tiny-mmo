extends Control


@onready var label: Label = $Panel/Label

var lifetime: float = 2.0
var elapsed: float = 0.0
var float_speed: float = 40.0


func setup(exp_amount: int) -> void:
	if label:
		label.text = "+%d XP" % exp_amount
	
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
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.15)


func _process(delta: float) -> void:
	elapsed += delta
	
	# Float upward
	position.y -= float_speed * delta
	
	# Start fading out after 1.0 seconds
	if elapsed > 1.0:
		modulate.a = max(0.0, 1.0 - ((elapsed - 1.0) / 1.0))
	
	# Remove after lifetime
	if elapsed >= lifetime:
		queue_free()

