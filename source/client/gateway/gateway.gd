extends Control#can be refactor, 350 lines script too much?


# Helper class
const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")
const GatewayApi = preload("res://source/common/network/gateway_api.gd")

@export var world_server: WorldClient

var account_id: int
var account_name: String
var token: int = randi()

var current_world_id: int
var selected_skin: String = "rogue"

var menu_stack: Array[Control]

# Remember Me functionality
var remember_me_enabled: bool = false
var stored_credentials: Dictionary = {}

@onready var main_panel: PanelContainer = $MainPanel
@onready var login_panel: PanelContainer = $LoginPanel
@onready var popup_panel: PanelContainer = $PopupPanel

@onready var back_button: Button = $BackButton

@onready var http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	$SwapButton.toggled.connect(func(toggled_on: bool):
		if not $AudioStreamPlayer.playing:
			$AudioStreamPlayer.play()
		$Desert.visible = toggled_on == true
		$FairyForest.visible = toggled_on == false
		if toggled_on:
			theme = load("res://source/client/gateway/ui/theme_desert.tres")
		else:
			theme = preload("res://source/client/gateway/ui/theme_navy.tres")
	)
	menu_stack.append(main_panel)
	back_button.hide()
	back_button.pressed.connect(func():
		if menu_stack.size():
			menu_stack.pop_back().hide()
			if menu_stack.size():
				menu_stack.back().show()
			if menu_stack.size() < 2:
				back_button.hide()
		)
	
	var animated_sprite_2d: AnimatedSprite2D = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CenterContainer/Control/AnimatedSprite2D
	animated_sprite_2d.play(&"run")
	var v_box_container: GridContainer = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer
	for button: Button in v_box_container.get_children():
		button.pressed.connect(
		func():
			var sprite = ContentRegistryHub.load_by_slug(&"sprites", button.text.to_lower())
			if not sprite:
				return
			selected_skin = button.text.to_lower()
			animated_sprite_2d.sprite_frames = sprite
			animated_sprite_2d.play(&"run")
		)
	
	# Setup password strength indicators
	_setup_password_strength_indicators()
	
	# Setup password toggle buttons
	_setup_password_toggles()
	
	# Setup Remember Me functionality
	_setup_remember_me()
	
	# Check for saved credentials on startup
	_check_saved_credentials()


func _setup_password_strength_indicators() -> void:
	# Setup login password strength indicator
	var login_password_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	var login_strength_indicator = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/PasswordStrengthIndicator
	login_strength_indicator.setup_for_password(login_password_edit)
	
	# Setup create account password strength indicators
	var create_password_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	var create_password_repeat_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/HBoxContainer/LineEdit
	var create_strength_indicator = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/PasswordStrengthIndicator
	var create_match_indicator = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/PasswordMatchIndicator
	
	create_strength_indicator.setup_for_password(create_password_edit)
	create_match_indicator.setup_for_password_repeat(create_password_repeat_edit, create_password_edit)


func _setup_password_toggles() -> void:
	# Setup login password toggle
	var login_password_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	var login_toggle_button: Button = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/ToggleButton
	login_toggle_button.pressed.connect(_on_password_toggle_pressed.bind(login_password_edit, login_toggle_button))
	
	# Setup create account password toggle
	var create_password_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	var create_toggle_button: Button = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/ToggleButton
	create_toggle_button.pressed.connect(_on_password_toggle_pressed.bind(create_password_edit, create_toggle_button))
	
	# Setup password repeat toggle
	var repeat_password_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/HBoxContainer/LineEdit
	var repeat_toggle_button: Button = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/HBoxContainer/ToggleButton
	repeat_toggle_button.pressed.connect(_on_password_toggle_pressed.bind(repeat_password_edit, repeat_toggle_button))


func _on_password_toggle_pressed(password_edit: LineEdit, toggle_button: Button) -> void:
	if password_edit.secret:
		# Show password
		password_edit.secret = false
		toggle_button.text = "Hide"
	else:
		# Hide password
		password_edit.secret = true
		toggle_button.text = "Show"


func _setup_remember_me() -> void:
	# Connect Remember Me checkbox signal
	var remember_me_checkbox: CheckBox = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/RememberMeCheckBox
	remember_me_checkbox.toggled.connect(_on_remember_me_toggled)


func _on_remember_me_toggled(enabled: bool) -> void:
	remember_me_enabled = enabled
	# If user unchecks Remember Me, clear saved credentials
	if not enabled:
		_clear_saved_credentials()


func _check_saved_credentials() -> void:
	# Check if we have saved credentials
	var config = ConfigFile.new()
	var err = config.load("user://remember_me.cfg")
	if err == OK:
		var handle = config.get_value("credentials", "handle", "")
		if handle != "":
			stored_credentials["handle"] = handle
			_prefill_login_form()


func _prefill_login_form() -> void:
	if stored_credentials.has("handle"):
		# Pre-fill the login form with saved handle
		var handle_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/LineEdit
		var remember_me_checkbox: CheckBox = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/RememberMeCheckBox
		
		handle_edit.text = stored_credentials["handle"]
		remember_me_checkbox.button_pressed = true


func _save_credentials(handle: String, password: String) -> void:
	if remember_me_enabled:
		stored_credentials["handle"] = handle
		
		# Only save the handle, not the password for security
		var config = ConfigFile.new()
		config.set_value("credentials", "handle", handle)
		config.save("user://remember_me.cfg")


func _clear_saved_credentials() -> void:
	stored_credentials.clear()
	
	# Delete config file for both web and desktop builds
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("remember_me.cfg")


func do_request(
	method: HTTPClient.Method,
	path: String,
	payload: Dictionary,
) -> Dictionary:
	if http_request.get_http_client_status() == HTTPClient.Status.STATUS_CONNECTED:
		return {"error": "request_error"}
	
	var custom_headers: PackedStringArray
	custom_headers.append("Content-Type: application/json")
	
	var error: Error = http_request.request(
		path,
		custom_headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return {ok=false, error="request_error", code=error}
	
	var args: Array = await http_request.request_completed
	var result: int = args[0]
	if result != OK:
		print("ERROR?, TIMEOUT?")
		return {"error": 1, "ERROR?": "TIMEOUT?"}
	
	var response_code: int = args[1]
	var headers: PackedStringArray = args[2]
	var body: PackedByteArray = args[3]
	
	var data = JSON.parse_string(body.get_string_from_ascii())
	if data is Dictionary:
		return data
	return {"error": 1}


func _show(next: Control, can_back: bool = true) -> void:
	if menu_stack.size():
		menu_stack.back().hide()
	if not can_back:
		menu_stack.clear()
	next.show()
	menu_stack.append(next)
	back_button.visible = can_back


func _maybe_autoselect_world(world_info: Dictionary) -> bool:
	# If only one world exists, skip the selection UI and proceed directly
	if world_info.size() == 1:
		var world_id_str: String = world_info.keys()[0]
		_on_world_selected(world_id_str.to_int())
		return true
	return false


func _on_login_button_pressed() -> void:
	_show(login_panel)


func _on_login_login_button_pressed() -> void:
	var handle_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/LineEdit
	var password_edit: LineEdit = $LoginPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	
	var handle: String = handle_edit.text
	var password: String = password_edit.text
	
	var login_button: Button = $LoginPanel/VBoxContainer/VBoxContainer/LoginButton
	login_button.disabled = true
	if (
		CredentialsUtils.validate_handle(handle).code != CredentialsUtils.HandleError.OK
		or CredentialsUtils.validate_password(password).code != CredentialsUtils.UsernameError.OK
	):
		login_button.disabled = false
		return

	popup_panel.display_waiting_popup()
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.login(),
		{"h": handle, "p": password,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		var error_message: String = "Login failed."
		var error_code = d["error"]
		
		# Handle both integer and dictionary error formats
		if error_code is int:
			if error_code == 50:
				error_message = "Invalid handle or password. Please check your credentials."
			elif error_code == 51:
				error_message = "This account is already logged in elsewhere."
			else:
				error_message = "Login failed with error code: " + str(error_code)
		elif error_code is Dictionary:
			# If error is a dictionary, try to get the error code from it
			if error_code.has("code"):
				var code = error_code["code"]
				if code == 50:
					error_message = "Invalid handle or password. Please check your credentials."
				elif code == 51:
					error_message = "This account is already logged in elsewhere."
				else:
					error_message = "Login failed with error code: " + str(code)
			else:
				error_message = "Login failed: " + str(error_code)
		else:
			error_message = "Login failed with error: " + str(error_code)
		
		# Clear saved credentials on login failure
		_clear_saved_credentials()
		
		await popup_panel.confirm_message(error_message)
		login_button.disabled = false
		return
	
	# Save credentials on successful login if Remember Me is enabled
	_save_credentials(handle, password)
	
	populate_worlds(d.get("w", {}))
	fill_connection_info(d["a"]["name"], d["a"]["id"])
	
	popup_panel.hide()
	if not _maybe_autoselect_world(d.get("w", {})):
		_show($WorldSelection, false)


func _on_guest_button_pressed() -> void:
	popup_panel.display_waiting_popup()

	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.guest(),
		{GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		await popup_panel.confirm_message(str(d))
		return
	
	fill_connection_info(d["a"]["name"], d["a"]["id"])
	populate_worlds(d.get("w", {}))
	
	popup_panel.hide()
	if not _maybe_autoselect_world(d.get("w", {})):
		_show($WorldSelection, false)


func _on_world_selected(world_id: int) -> void:
	$WorldSelection.hide()
	popup_panel.display_waiting_popup()
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.world_characters(),
		{GatewayApi.KEY_WORLD_ID: world_id,
		GatewayApi.KEY_ACCOUNT_ID: account_id,
		GatewayApi.KEY_ACCOUNT_HANDLE: account_name,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		await popup_panel.confirm_message(str(d))
		$WorldSelection.show()
		return
	
	var container: HBoxContainer = $CharacterSelection/VBoxContainer/HBoxContainer
	var i: int
	var character_id: String
	for button: Button in container.get_children():
		if button.pressed.is_connected(_on_character_selected):
			button.pressed.disconnect(_on_character_selected)
		if d["data"].size() > i:
			character_id = d["data"].keys()[i]
			button.text = "%s\nClass: %s\nLevel: %d" % [
				d["data"][character_id]["name"],
				d["data"][character_id]["class"],
				d["data"][character_id]["level"],
			]
			button.pressed.connect(_on_character_selected.bind(world_id, character_id.to_int()))
		else:
			button.text = "Create New Character"
			button.pressed.connect(_on_character_selected.bind(world_id, -1))
		i += 1
	popup_panel.hide()
	_show($CharacterSelection)


func _on_character_selected(world_id: int, character_id: int) -> void:
	current_world_id = world_id
	if character_id == -1:
		_show($CharacterCreation)
		return
	
	$CharacterSelection.hide()
	$BackButton.hide()
	popup_panel.display_waiting_popup()
	
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.world_enter(),
		{
			GatewayApi.KEY_TOKEN_ID: token,
			GatewayApi.KEY_ACCOUNT_HANDLE: account_name,
			GatewayApi.KEY_WORLD_ID: world_id,
			GatewayApi.KEY_CHAR_ID: character_id
		}
	)
	if d.has("error"):
		await popup_panel.confirm_message(str(d))
		$CharacterSelection.show()
		$BackButton.show()
		return
	
	world_server.connect_to_server(d["adress"], d["port"], d["token"])
	queue_free.call_deferred()


func _on_create_character_button_pressed() -> void:
	var username_edit: LineEdit = $CharacterCreation/VBoxContainer/VBoxContainer/HBoxContainer2/LineEdit

	var create_button: Button = $CharacterCreation/VBoxContainer/VBoxContainer/CreateButton
	create_button.disabled = true
	
	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.world_create_char(),
		{
			GatewayApi.KEY_TOKEN_ID: token,
			"data": {
				"name": username_edit.text,
				"class": selected_skin,
			},
			GatewayApi.KEY_ACCOUNT_HANDLE: account_name,
			GatewayApi.KEY_WORLD_ID: current_world_id
		}
	)
	if d.has("error"):
		await popup_panel.confirm_message(str(d))
		create_button.disabled = false
		return
	
	world_server.connect_to_server(
		d["data"]["address"],
		d["data"]["port"],
		d["data"]["auth-token"]
	)
	queue_free.call_deferred()


func create_account() -> void:
	var handle_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer/HBoxContainer/LineEdit
	var password_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
	var password_repeat_edit: LineEdit = $CreateAccountPanel/VBoxContainer/VBoxContainer/VBoxContainer3/HBoxContainer/LineEdit

	if password_edit.text != password_repeat_edit.text:
		await popup_panel.confirm_message("Passwords don't match")
		return
	
	var result: Dictionary
	result = CredentialsUtils.validate_handle(handle_edit.text)
	if result.code != CredentialsUtils.HandleError.OK:
		await popup_panel.confirm_message("Player Handle:\n" + result.message)
		return
	
	# Check password strength - prevent weak passwords
	var strength_result: Dictionary = CredentialsUtils.calculate_password_strength(password_edit.text)
	if strength_result["strength"] == CredentialsUtils.PasswordStrength.WEAK:
		await popup_panel.confirm_message("Password is too weak. Please choose a stronger password with more characters and variety.")
		return
	
	result = CredentialsUtils.validate_password(password_edit.text)
	if result.code != CredentialsUtils.UsernameError.OK:
		await popup_panel.confirm_message("Password:\n" + result.message)
		return
	
	$CreateAccountPanel.hide()
	popup_panel.display_waiting_popup()

	var d: Dictionary = await do_request(
		HTTPClient.Method.METHOD_POST,
		GatewayApi.account_create(),
		{"h": handle_edit.text, "p": password_edit.text,
		GatewayApi.KEY_TOKEN_ID: token}
	)
	if d.has("error"):
		var error_message: String = "Account creation failed."
		if d["error"] == 30:
			error_message = "This player handle is already taken. Please choose a different handle."
		elif d["error"] == 1:
			error_message = "Handle is required."
		elif d["error"] == 2:
			error_message = "Handle must be at least 3 characters long."
		elif d["error"] == 3:
			error_message = "Handle must be no more than 20 characters long."
		elif d["error"] == 4:
			error_message = "Password is required."
		elif d["error"] == 5:
			error_message = "Password must be at least 6 characters long."
		elif d["error"] == 6:
			error_message = "Password must be no more than 32 characters long."
		else:
			error_message = "Account creation failed with error code: " + str(d["error"])
		
		await popup_panel.confirm_message(error_message)
		$CreateAccountPanel.show()
		return
	
	fill_connection_info(d["a"]["name"], d["a"]["id"])
	populate_worlds(d.get("w", {}))
	
	popup_panel.hide()
	if not _maybe_autoselect_world(d.get("w", {})):
		_show($WorldSelection, false)


func _on_create_account_button_pressed() -> void:
	_show($CreateAccountPanel)


func populate_worlds(world_info: Dictionary) -> void:
	var container: HBoxContainer = $WorldSelection/VBoxContainer/HBoxContainer
	
	var i: int
	for button: Button in container.get_children():
		if button.pressed.is_connected(_on_world_selected):
			button.pressed.disconnect(_on_world_selected)
		if i < world_info.size():
			var world_id: String = world_info.keys()[i]
			button.text = "%s\n\n%s" % [
				world_info[world_id].get("name", "name"),
				" \n".join(str(world_info[world_id]["info"]).split(", "))
			]
			button.pressed.connect(_on_world_selected.bind(world_id.to_int()))
			
		else:
			button.hide()
		i += 1


func fill_connection_info(_account_name: String, _account_id: int) -> void:
	account_name = _account_name
	account_id = _account_id
	$ConnectionInfo.text = "Account-name: %s\nAccount-ID: %s" % [
		account_name, account_id
	]
