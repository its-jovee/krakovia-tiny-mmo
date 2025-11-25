extends Control


@onready var icon: TextureRect = $Panel/HBoxContainer/Icon
@onready var label: Label = $Panel/HBoxContainer/Label
@onready var exp_label: Label = $Panel/HBoxContainer/ExpLabel

var lifetime: float = 2.0
var elapsed: float = 0.0


func setup(item_name: String, item_icon: Texture2D, amount: int, exp_amount: int = 0) -> void:
	if icon:
		icon.texture = item_icon
	if label:
		label.text = TranslationServer.translate("popup_harvest").format({"amount": amount, "item": item_name})
	if exp_label:
		if exp_amount > 0:
			exp_label.text = TranslationServer.translate("popup_harvest_exp").format({"exp": exp_amount})
			exp_label.show()
		else:
			exp_label.hide()
	
	# Start animation
	modulate = Color(1, 1, 1, 0)  # Start transparent
	_animate_in()


func _animate_in() -> void:
	# Fade in with scale pop
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Scale pop
	scale = Vector2(0.8, 0.8)
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.15)


func _process(delta: float) -> void:
	elapsed += delta
	
	# Start fading out after showing for a bit
	if elapsed > 1.2:
		var fade_progress: float = (elapsed - 1.2) / 0.8
		modulate.a = max(0.0, 1.0 - fade_progress)
	
	# Remove after lifetime
	if elapsed >= lifetime:
		queue_free()
