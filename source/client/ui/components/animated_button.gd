@tool
extends Button
class_name AnimatedButton
## AnimatedButton - A Button with automatic animation and sound feedback.
## Drop-in replacement for standard Button nodes.
## Automatically hooks into UIAnimations and UISounds autoloads.


# =============================================================================
# EXPORT SETTINGS
# =============================================================================

@export_group("Animation")
## Enable hover animation
@export var animate_hover: bool = true
## Enable press animation
@export var animate_press: bool = true
## Custom hover scale (1.0 = no scale change)
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.03

@export_group("Sound")
## Enable click sound
@export var play_click_sound: bool = true
## Enable hover sound
@export var play_hover_sound: bool = true
## Custom sound key (empty = default "click")
@export var custom_click_sound: String = ""
## Custom hover sound key (empty = default "hover")
@export var custom_hover_sound: String = ""


# =============================================================================
# STATE
# =============================================================================

var _is_hovered: bool = false
var _original_pivot: Vector2


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Set pivot to center for proper scaling
	_setup_pivot()
	
	# Connect signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)
	
	# Handle disabled state changes
	if not Engine.is_editor_hint():
		set_process(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Reset hover state if button becomes disabled while hovered
	if disabled and _is_hovered:
		_is_hovered = false
		_animate_hover_exit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_setup_pivot()


# =============================================================================
# PIVOT SETUP
# =============================================================================

func _setup_pivot() -> void:
	# Set pivot offset to center for proper scale animation
	pivot_offset = size / 2.0


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_mouse_entered() -> void:
	if Engine.is_editor_hint() or disabled:
		return
	
	_is_hovered = true
	
	if animate_hover:
		_animate_hover_enter()
	
	if play_hover_sound:
		_play_hover_sound()


func _on_mouse_exited() -> void:
	if Engine.is_editor_hint():
		return
	
	_is_hovered = false
	
	if animate_hover:
		_animate_hover_exit()


func _on_button_down() -> void:
	if Engine.is_editor_hint() or disabled:
		return
	
	if animate_press:
		_animate_press()


func _on_button_up() -> void:
	if Engine.is_editor_hint() or disabled:
		return
	
	if animate_press:
		_animate_release()


func _on_pressed() -> void:
	if Engine.is_editor_hint():
		return
	
	if play_click_sound:
		_play_click_sound()


# =============================================================================
# ANIMATION METHODS
# =============================================================================

func _animate_hover_enter() -> void:
	var anim = _get_ui_animations()
	if anim:
		anim.animate_hover_enter(self, hover_scale)
	else:
		# Fallback if autoload not available
		_fallback_scale(Vector2.ONE * hover_scale, 0.15)


func _animate_hover_exit() -> void:
	var anim = _get_ui_animations()
	if anim:
		anim.animate_hover_exit(self)
	else:
		_fallback_scale(Vector2.ONE, 0.15)


func _animate_press() -> void:
	var anim = _get_ui_animations()
	if anim:
		anim.animate_button_press(self)
	else:
		_fallback_scale(Vector2.ONE * 0.94, 0.08)


func _animate_release() -> void:
	var anim = _get_ui_animations()
	if anim:
		anim.animate_button_release(self)
	else:
		var target := Vector2.ONE * hover_scale if _is_hovered else Vector2.ONE
		_fallback_scale(target, 0.12)


func _fallback_scale(target: Vector2, duration: float) -> void:
	"""Fallback animation if UIAnimations autoload is not available"""
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "scale", target, duration)


# =============================================================================
# SOUND METHODS
# =============================================================================

func _play_click_sound() -> void:
	var sounds = _get_ui_sounds()
	if sounds:
		if custom_click_sound.is_empty():
			sounds.play_click()
		else:
			sounds.play(custom_click_sound)


func _play_hover_sound() -> void:
	var sounds = _get_ui_sounds()
	if sounds:
		if custom_hover_sound.is_empty():
			sounds.play_hover()
		else:
			sounds.play(custom_hover_sound)


# =============================================================================
# AUTOLOAD ACCESS
# =============================================================================

func _get_ui_animations() -> Node:
	if Engine.is_editor_hint():
		return null
	if has_node("/root/UIAnimations"):
		return get_node("/root/UIAnimations")
	return null


func _get_ui_sounds() -> Node:
	if Engine.is_editor_hint():
		return null
	if has_node("/root/UISounds"):
		return get_node("/root/UISounds")
	return null

