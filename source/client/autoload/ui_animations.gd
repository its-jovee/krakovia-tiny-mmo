extends Node
## UIAnimations - Centralized UI animation system
## Provides reusable tween-based animations for buttons, panels, and popups.
## BOTW-inspired: subtle, smooth, satisfying micro-interactions.


# =============================================================================
# ANIMATION SETTINGS
# =============================================================================

const BUTTON_PRESS_SCALE := 0.94
const BUTTON_PRESS_DURATION := 0.08
const BUTTON_RELEASE_DURATION := 0.12

const HOVER_SCALE := 1.03
const HOVER_DURATION := 0.15

const PANEL_OPEN_SCALE := 0.96
const PANEL_OPEN_DURATION := 0.2

const POPUP_SCALE := 0.85
const POPUP_DURATION := 0.25

const BAR_FILL_DURATION := 0.3


# =============================================================================
# ACTIVE TWEENS TRACKING (to prevent conflicts)
# =============================================================================

var _active_tweens: Dictionary = {}


# =============================================================================
# BUTTON ANIMATIONS
# =============================================================================

## Animate button press - scale down with slight darkening
func animate_button_press(button: Control) -> Tween:
	_kill_tween(button)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(button, "scale", Vector2.ONE * BUTTON_PRESS_SCALE, BUTTON_PRESS_DURATION)
	
	_active_tweens[button] = tween
	return tween


## Animate button release - bounce back to normal
func animate_button_release(button: Control) -> Tween:
	_kill_tween(button)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_RELEASE_DURATION)
	
	_active_tweens[button] = tween
	return tween


## Full button press animation (press + release)
func animate_button_click(button: Control) -> Tween:
	_kill_tween(button)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Press
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2.ONE * BUTTON_PRESS_SCALE, BUTTON_PRESS_DURATION)
	
	# Release with bounce
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_RELEASE_DURATION)
	
	_active_tweens[button] = tween
	return tween


# =============================================================================
# HOVER ANIMATIONS
# =============================================================================

## Animate hover enter - subtle scale up
func animate_hover_enter(control: Control, custom_scale: float = HOVER_SCALE) -> Tween:
	_kill_tween(control)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(control, "scale", Vector2.ONE * custom_scale, HOVER_DURATION)
	
	_active_tweens[control] = tween
	return tween


## Animate hover exit - return to normal
func animate_hover_exit(control: Control) -> Tween:
	_kill_tween(control)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(control, "scale", Vector2.ONE, HOVER_DURATION)
	
	_active_tweens[control] = tween
	return tween


# =============================================================================
# PANEL ANIMATIONS
# =============================================================================

## Animate panel opening - fade in with scale
func animate_panel_open(panel: Control, custom_duration: float = PANEL_OPEN_DURATION) -> Tween:
	_kill_tween(panel)
	
	# Set initial state
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * PANEL_OPEN_SCALE
	panel.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "modulate:a", 1.0, custom_duration)
	tween.tween_property(panel, "scale", Vector2.ONE, custom_duration)
	
	_active_tweens[panel] = tween
	return tween


## Animate panel closing - fade out with scale
func animate_panel_close(panel: Control, custom_duration: float = PANEL_OPEN_DURATION) -> Tween:
	_kill_tween(panel)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "modulate:a", 0.0, custom_duration)
	tween.tween_property(panel, "scale", Vector2.ONE * PANEL_OPEN_SCALE, custom_duration)
	
	# Hide after animation
	tween.chain().tween_callback(func(): panel.visible = false)
	
	_active_tweens[panel] = tween
	return tween


## Slide panel in from direction
func animate_panel_slide_in(panel: Control, from_direction: Vector2 = Vector2.DOWN, distance: float = 50.0, duration: float = PANEL_OPEN_DURATION) -> Tween:
	_kill_tween(panel)
	
	var target_pos := panel.position
	panel.position = target_pos + from_direction.normalized() * distance
	panel.modulate.a = 0.0
	panel.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "position", target_pos, duration)
	tween.tween_property(panel, "modulate:a", 1.0, duration)
	
	_active_tweens[panel] = tween
	return tween


## Slide panel out
func animate_panel_slide_out(panel: Control, to_direction: Vector2 = Vector2.DOWN, distance: float = 50.0, duration: float = PANEL_OPEN_DURATION) -> Tween:
	_kill_tween(panel)
	
	var start_pos := panel.position
	var target_pos := start_pos + to_direction.normalized() * distance
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "position", target_pos, duration)
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	
	tween.chain().tween_callback(func():
		panel.visible = false
		panel.position = start_pos
	)
	
	_active_tweens[panel] = tween
	return tween


# =============================================================================
# POPUP / NOTIFICATION ANIMATIONS
# =============================================================================

## Animate popup appearing - bouncy scale up
func animate_popup_in(popup: Control, custom_duration: float = POPUP_DURATION) -> Tween:
	_kill_tween(popup)
	
	popup.scale = Vector2.ONE * POPUP_SCALE
	popup.modulate.a = 0.0
	popup.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	
	tween.tween_property(popup, "scale", Vector2.ONE, custom_duration)
	tween.tween_property(popup, "modulate:a", 1.0, custom_duration * 0.6).set_trans(Tween.TRANS_QUAD)
	
	_active_tweens[popup] = tween
	return tween


## Animate popup disappearing
func animate_popup_out(popup: Control, custom_duration: float = POPUP_DURATION * 0.7) -> Tween:
	_kill_tween(popup)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(popup, "scale", Vector2.ONE * POPUP_SCALE, custom_duration)
	tween.tween_property(popup, "modulate:a", 0.0, custom_duration)
	
	tween.chain().tween_callback(func(): popup.visible = false)
	
	_active_tweens[popup] = tween
	return tween


## Floating notification that rises and fades (for +gold, +exp, etc.)
func animate_floating_text(label: Control, rise_distance: float = 40.0, duration: float = 1.2) -> Tween:
	_kill_tween(label)
	
	var start_pos := label.position
	var target_pos := start_pos - Vector2(0, rise_distance)
	label.modulate.a = 1.0
	label.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	# Rise up
	tween.tween_property(label, "position", target_pos, duration)
	
	# Hold then fade
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	
	tween.chain().tween_callback(func():
		label.visible = false
		label.position = start_pos
		label.modulate.a = 1.0
	)
	
	_active_tweens[label] = tween
	return tween


# =============================================================================
# PROGRESS BAR ANIMATIONS
# =============================================================================

## Animate progress bar value change
func animate_bar_fill(bar: ProgressBar, target_value: float, duration: float = BAR_FILL_DURATION) -> Tween:
	_kill_tween(bar)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(bar, "value", target_value, duration)
	
	_active_tweens[bar] = tween
	return tween


## Animate progress bar with overshoot (for level up, etc.)
func animate_bar_fill_bounce(bar: ProgressBar, target_value: float, duration: float = BAR_FILL_DURATION) -> Tween:
	_kill_tween(bar)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(bar, "value", target_value, duration)
	
	_active_tweens[bar] = tween
	return tween


# =============================================================================
# ITEM SLOT / INVENTORY ANIMATIONS
# =============================================================================

## Highlight item slot on hover
func animate_slot_highlight(slot: Control, highlight: bool) -> Tween:
	_kill_tween(slot)
	
	var target_scale := Vector2.ONE * (1.08 if highlight else 1.0)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(slot, "scale", target_scale, 0.1)
	
	_active_tweens[slot] = tween
	return tween


## Shake animation for errors
func animate_shake(control: Control, intensity: float = 8.0, duration: float = 0.4) -> Tween:
	_kill_tween(control)
	
	var start_pos := control.position
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	var shake_count := 4
	var shake_duration := duration / shake_count
	
	for i in range(shake_count):
		var offset := intensity * (1.0 - float(i) / shake_count)
		var direction := 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(control, "position:x", start_pos.x + offset * direction, shake_duration)
	
	tween.tween_property(control, "position", start_pos, shake_duration * 0.5)
	
	_active_tweens[control] = tween
	return tween


## Pulse animation (for available craft, new item, etc.)
func animate_pulse(control: Control, scale_factor: float = 1.1, duration: float = 0.6, loops: int = -1) -> Tween:
	_kill_tween(control)
	
	var tween := create_tween()
	if loops != 0:
		tween.set_loops(loops)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	tween.tween_property(control, "scale", Vector2.ONE * scale_factor, duration * 0.5)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.5)
	
	_active_tweens[control] = tween
	return tween


## Stop pulsing
func stop_pulse(control: Control) -> void:
	_kill_tween(control)
	control.scale = Vector2.ONE


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

## Crossfade between two controls
func crossfade(from_control: Control, to_control: Control, duration: float = 0.2) -> Tween:
	_kill_tween(from_control)
	_kill_tween(to_control)
	
	to_control.modulate.a = 0.0
	to_control.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	
	tween.tween_property(from_control, "modulate:a", 0.0, duration)
	tween.tween_property(to_control, "modulate:a", 1.0, duration)
	
	tween.chain().tween_callback(func(): from_control.visible = false)
	
	return tween


## Fade in
func fade_in(control: Control, duration: float = 0.2) -> Tween:
	_kill_tween(control)
	
	control.modulate.a = 0.0
	control.visible = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(control, "modulate:a", 1.0, duration)
	
	_active_tweens[control] = tween
	return tween


## Fade out
func fade_out(control: Control, duration: float = 0.2, hide_after: bool = true) -> Tween:
	_kill_tween(control)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(control, "modulate:a", 0.0, duration)
	
	if hide_after:
		tween.chain().tween_callback(func(): control.visible = false)
	
	_active_tweens[control] = tween
	return tween


## Reset control to default state
func reset(control: Control) -> void:
	_kill_tween(control)
	control.scale = Vector2.ONE
	control.modulate.a = 1.0


# =============================================================================
# INTERNAL
# =============================================================================

func _kill_tween(control: Control) -> void:
	if _active_tweens.has(control):
		var tween: Tween = _active_tweens[control]
		if tween and tween.is_valid():
			tween.kill()
		_active_tweens.erase(control)
