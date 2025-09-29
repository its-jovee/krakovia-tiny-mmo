extends Control

const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")
const ErrorMessages = preload("res://source/common/utils/error_messages.gd")

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel

var target_line_edit: LineEdit
var is_handle_field: bool = true

signal validation_changed(is_valid: bool, message: String)

func _ready() -> void:
	# Hide by default - only show when there's an error
	visible = false

func setup_for_handle(line_edit: LineEdit) -> void:
	target_line_edit = line_edit
	is_handle_field = true
	line_edit.text_changed.connect(_on_text_changed)

func setup_for_password(line_edit: LineEdit) -> void:
	target_line_edit = line_edit
	is_handle_field = false
	line_edit.text_changed.connect(_on_text_changed)

func _on_text_changed(new_text: String) -> void:
	if is_handle_field:
		_update_handle_validation(new_text)
	else:
		_update_password_validation(new_text)

func _update_handle_validation(handle: String) -> void:
	if handle.is_empty():
		# Hide indicator when field is empty
		visible = false
		validation_changed.emit(false, "")
		return
	
	var result = CredentialsUtils.validate_handle(handle)
	if result.code == CredentialsUtils.HandleError.OK:
		# Hide indicator when handle format is valid
		visible = false
		validation_changed.emit(true, "")
	else:
		# Show indicator only when there's a format error
		visible = true
		var error_data = ErrorMessages.get_validation_error_message(result.code, "handle")
		status_label.text = "✗ Invalid Handle"
		status_label.modulate = Color.RED
		message_label.text = error_data["message"]
		validation_changed.emit(false, error_data["message"])

func _update_password_validation(password: String) -> void:
	if password.is_empty():
		# Hide indicator when field is empty
		visible = false
		validation_changed.emit(false, "")
		return
	
	var result = CredentialsUtils.validate_password(password)
	if result.code == CredentialsUtils.UsernameError.OK:
		# Hide indicator when password format is valid
		visible = false
		validation_changed.emit(true, "")
	else:
		# Show indicator only when there's a format error
		visible = true
		var error_data = ErrorMessages.get_validation_error_message(result.code, "password")
		status_label.text = "✗ Invalid Password"
		status_label.modulate = Color.RED
		message_label.text = error_data["message"]
		validation_changed.emit(false, error_data["message"])
