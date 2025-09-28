extends Control

const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")

@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var strength_label: Label = $VBoxContainer/StrengthLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

var target_line_edit: LineEdit
var is_password_repeat: bool = false
var original_password: String = ""

signal strength_changed(strength: int, is_acceptable: bool)


func _ready() -> void:
	# Set up progress bar colors
	progress_bar.modulate = Color.RED
	strength_label.text = "Password Strength"
	message_label.text = ""


func setup_for_password(line_edit: LineEdit) -> void:
	target_line_edit = line_edit
	is_password_repeat = false
	line_edit.text_changed.connect(_on_password_changed)


func setup_for_password_repeat(line_edit: LineEdit, original_password_edit: LineEdit) -> void:
	target_line_edit = line_edit
	is_password_repeat = true
	original_password = original_password_edit.text
	line_edit.text_changed.connect(_on_password_changed)
	original_password_edit.text_changed.connect(_on_original_password_changed)


func _on_password_changed(new_text: String) -> void:
	if is_password_repeat:
		_update_password_match(new_text)
	else:
		_update_password_strength(new_text)


func _on_original_password_changed(new_text: String) -> void:
	original_password = new_text
	if is_password_repeat:
		_update_password_match(target_line_edit.text)


func _update_password_strength(password: String) -> void:
	var strength_data: Dictionary = CredentialsUtils.calculate_password_strength(password)
	var strength: int = strength_data["strength"]
	var message: String = strength_data["message"]
	
	# Update progress bar
	progress_bar.value = (strength + 1) * 25  # 0-100 range
	progress_bar.modulate = _get_strength_color(strength)
	
	# Update labels
	strength_label.text = _get_strength_text(strength)
	message_label.text = message
	
	# Emit signal
	var is_acceptable: bool = strength >= CredentialsUtils.PasswordStrength.FAIR
	strength_changed.emit(strength, is_acceptable)


func _update_password_match(password: String) -> void:
	if password.is_empty():
		progress_bar.value = 0
		progress_bar.modulate = Color.GRAY
		strength_label.text = "Password Match"
		message_label.text = ""
		strength_changed.emit(-1, false)
		return
	
	var matches: bool = password == original_password
	progress_bar.value = 100 if matches else 0
	progress_bar.modulate = Color.GREEN if matches else Color.RED
	strength_label.text = "Password Match"
	message_label.text = "Passwords match!" if matches else "Passwords don't match"
	strength_changed.emit(1 if matches else 0, matches)


func _get_strength_color(strength: int) -> Color:
	match strength:
		CredentialsUtils.PasswordStrength.WEAK:
			return Color.RED
		CredentialsUtils.PasswordStrength.FAIR:
			return Color.ORANGE
		CredentialsUtils.PasswordStrength.GOOD:
			return Color.YELLOW
		CredentialsUtils.PasswordStrength.STRONG:
			return Color.GREEN
		_:
			return Color.GRAY


func _get_strength_text(strength: int) -> String:
	match strength:
		CredentialsUtils.PasswordStrength.WEAK:
			return "Weak"
		CredentialsUtils.PasswordStrength.FAIR:
			return "Fair"
		CredentialsUtils.PasswordStrength.GOOD:
			return "Good"
		CredentialsUtils.PasswordStrength.STRONG:
			return "Strong"
		_:
			return "Unknown"
