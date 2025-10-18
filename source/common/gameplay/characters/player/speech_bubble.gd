extends Control


@onready var panel_container: PanelContainer = $PanelContainer
@onready var label = $PanelContainer/MarginContainer/Label  # Can be Label or RichTextLabel
@onready var timer: Timer = $Timer


func _ready() -> void:
	# Start hidden
	hide()
	modulate.a = 0.0
	timer.timeout.connect(_on_timer_timeout)
	
	# Enable BBCode if it's a RichTextLabel
	if label is RichTextLabel:
		label.bbcode_enabled = true
		label.fit_content = true


func show_message(text: String) -> void:
	if text.is_empty():
		return
	
	# Set the text
	label.text = text
	
	# Calculate width based on visible text (strip BBCode for calculation)
	var visible_text = text
	if label is RichTextLabel:
		# Strip BBCode tags for width calculation (rough approximation)
		var regex = RegEx.new()
		regex.compile("\\[img=?\\d*\\][^\\[]+\\[\\/img\\]")
		# Replace [img] with a placeholder emoji for width (approximately 16px icon = 1 char)
		visible_text = regex.sub(visible_text, "🖼", true)
		# Remove other BBCode tags
		regex.compile("\\[[^\\]]+\\]")
		visible_text = regex.sub(visible_text, "", true)
	
	# Constrain label width for word wrapping
	var font = label.get_theme_default_font() if label is Label else label.get_theme_font("normal_font")
	var font_size = label.get_theme_font_size("font_size") if label is Label else label.get_theme_font_size("normal_font_size")
	var text_width: float = font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var constrained_width: float = clampf(text_width + 0, 10.0, 250.0)  # Add padding for icons
	label.custom_minimum_size = Vector2(constrained_width, 0)
	
	# Cancel existing timer if running
	if timer.time_left > 0:
		timer.stop()
	
	# Show the bubble with fade-in
	show()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Start 5-second timer
	timer.start(5.0)


func _on_timer_timeout() -> void:
	# Fade out and hide
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hide)


func _process(_delta: float) -> void:
	# Scale inversely with zoom to maintain consistent size
	var camera_zoom: float = 1.0
	var viewport: Viewport = get_viewport()
	if viewport:
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			camera_zoom = camera.zoom.x
	
	# Scale inversely with zoom to maintain consistent size
	scale = Vector2.ONE / camera_zoom
	
	# Position the bubble above the player
	if get_parent():
		var parent_pos: Vector2 = get_parent().global_position
		# Center horizontally on the player, accounting for scale and actual width
		# Use the actual panel size which changes based on message length
		var actual_width: float = panel_container.size.x if panel_container else 0
		var scaled_half_width: float = (actual_width / 2.0) * scale.x
		
		# Adjust Y offset based on bubble height so tall bubbles don't cover the character
		var actual_height: float = panel_container.size.y if panel_container else 0
		var scaled_height: float = actual_height * scale.y
		var y_offset: float = -scaled_height - 50  # 20px padding above the player
		
		global_position = parent_pos + Vector2(-scaled_half_width, y_offset)
