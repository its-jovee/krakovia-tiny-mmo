extends Control
## Floating damage popup with BBCode effects

var text: String = ""
var popup_color: Color = Color.WHITE
var lifetime: float = 1.5
var rise_speed: float = 50.0
var start_scale: float = 1.0
var effect_type: StringName = &"none"  # "wave", "shake", "rainbow", "pulse"
var drift_direction: float = 0.0  # Horizontal drift: negative = left, positive = right

var _time: float = 0.0
var _initial_position: Vector2
var _shake_offset: Vector2 = Vector2.ZERO

@onready var label: RichTextLabel = $RichTextLabel


func _ready() -> void:
	_initial_position = position
	
	# Apply the formatted text with BBCode (centered)
	label.clear()
	label.append_text("[center]")
	label.push_color(popup_color)
	
	match effect_type:
		&"wave":
			label.append_text("[wave amp=15 freq=4]%s[/wave]" % text)
		&"shake":
			label.append_text("[shake rate=15 level=8]%s[/shake]" % text)
		&"rainbow":
			label.append_text("[rainbow freq=0.4 sat=0.9 val=1][wave amp=12 freq=3]%s[/wave][/rainbow]" % text)
		&"pulse":
			label.append_text("[pulse freq=2.5 color=#ffffff60 ease=-2]%s[/pulse]" % text)
		_:
			label.append_text(text)
	
	label.pop()
	label.append_text("[/center]")
	
	# Set initial scale
	scale = Vector2.ONE * start_scale
	
	# Set pivot to center for proper scaling
	pivot_offset = size / 2
	
	# Adjust font size based on scale
	var font_size: int = int(16 * start_scale)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size + 2)


func _process(delta: float) -> void:
	_time += delta
	
	if _time >= lifetime:
		queue_free()
		return
	
	var t: float = _time / lifetime
	
	# Ease out rise
	var ease_t: float = 1.0 - pow(1.0 - t, 2)
	position.y = _initial_position.y - (ease_t * rise_speed * lifetime)
	
	# Horizontal drift + slight wobble
	var drift: float = ease_t * drift_direction * 30.0  # Drift outward
	var wobble: float = sin(_time * 3) * 3  # Small wobble
	position.x = _initial_position.x + drift + wobble
	
	# Scale: start big, shrink slightly, then normal
	if t < 0.1:
		# Pop in effect
		var pop_t: float = t / 0.1
		scale = Vector2.ONE * start_scale * (0.5 + pop_t * 0.5)
	elif t < 0.2:
		# Slight overshoot
		var overshoot_t: float = (t - 0.1) / 0.1
		scale = Vector2.ONE * start_scale * (1.0 + (1.0 - overshoot_t) * 0.15)
	
	# Fade out in last 30%
	if t > 0.7:
		var fade_t: float = (t - 0.7) / 0.3
		modulate.a = 1.0 - fade_t



