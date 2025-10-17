extends PanelContainer


@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var auto_dismiss_timer: Timer


func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Setup auto-dismiss timer
	auto_dismiss_timer = Timer.new()
	auto_dismiss_timer.one_shot = true
	auto_dismiss_timer.timeout.connect(_on_auto_dismiss)
	add_child(auto_dismiss_timer)
	
	hide()


func show_announcement(data: Dictionary) -> void:
	var title: String = data.get("title", "Announcement")
	var message: String = data.get("message", "A minigame is starting!")
	var duration: float = data.get("duration", 8.0)
	
	title_label.text = title
	message_label.text = message
	
	# Start auto-dismiss timer
	auto_dismiss_timer.wait_time = duration
	auto_dismiss_timer.start()
	
	# Animate in
	modulate.a = 0.0
	show()
	
	# Fade in animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _on_close_button_pressed() -> void:
	_close_with_animation()


func _on_auto_dismiss() -> void:
	_close_with_animation()


func _close_with_animation() -> void:
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hide)
