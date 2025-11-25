extends Control


# Current character info
var character_name: String = ""
var character_class: String = ""
var character_id: int = 0
var energy_current: float = 0.0
var energy_max: float = 100.0
var level: int = 1
var exp_progress: float = 0.0

# Account characters list (for dropdown)
var account_characters: Dictionary = {}  # char_id -> {name, class, level, energy}

# Cooldown tracking
var switch_cooldown_remaining: float = 0.0
var is_on_cooldown: bool = false

# UI References
@onready var icon_button: Button = $IconButton
@onready var dropdown_panel: Panel = $DropdownPanel
@onready var dropdown_vbox: VBoxContainer = $DropdownPanel/MarginContainer/VBoxContainer
@onready var cooldown_overlay: Panel = $CooldownOverlay
@onready var cooldown_label: Label = $CooldownOverlay/CooldownLabel

# Character creation modal reference (set by HUD)
var character_creation_modal = null


func _ready() -> void:
	dropdown_panel.hide()
	cooldown_overlay.hide()
	
	icon_button.pressed.connect(_on_icon_button_pressed)
	
	# Subscribe to local player ready
	Events.local_player_ready.connect(_on_local_player_ready)
	
	# Subscribe to character switch complete event
	InstanceClient.subscribe(&"character.switch.complete", _on_character_switch_complete_portrait)
	
	# Subscribe to energy updates
	Events.local_player_ready.connect(
		func(local_player: LocalPlayer) -> void:
			var ability_system_component: AbilitySystemComponent = local_player.get_node_or_null(^"AbilitySystemComponent")
			if not ability_system_component:
				return
			ability_system_component.mirror.attribute_local_changed.connect(_on_attribute_changed)
	)


func _process(delta: float) -> void:
	if is_on_cooldown:
		switch_cooldown_remaining -= delta
		if switch_cooldown_remaining <= 0.0:
			is_on_cooldown = false
			cooldown_overlay.hide()
		else:
			cooldown_label.text = "%d s" % int(ceil(switch_cooldown_remaining))


func _on_local_player_ready(local_player: LocalPlayer) -> void:
	if not local_player or not local_player.player_resource:
		return
	
	var player_resource: PlayerResource = local_player.player_resource
	character_name = player_resource.display_name
	character_class = player_resource.character_class
	character_id = player_resource.player_id
	level = player_resource.level
	exp_progress = player_resource.get_exp_progress()
	
	# Get energy from ASC if available
	if local_player.ability_system_component:
		var asc: AbilitySystemComponent = local_player.ability_system_component
		energy_current = asc.get_value(&"energy")
		energy_max = asc.get_max(&"energy")
	
	_update_display()
	_request_character_list()


func _on_attribute_changed(attr: StringName, value: float, max_value: float) -> void:
	if attr == &"energy":
		energy_current = value
		energy_max = max_value
		_update_display()


func _update_display() -> void:
	# Update tooltip with current character info
	var tooltip_text = "%s (%s) - Lv %d\nEnergy: %.0f/%.0f" % [
		character_name,
		character_class,
		level,
		energy_current,
		energy_max
	]
	icon_button.tooltip_text = tooltip_text


func _on_icon_button_pressed() -> void:
	if is_on_cooldown:
		return
	
	if dropdown_panel.visible:
		dropdown_panel.hide()
	else:
		_request_character_list()
		dropdown_panel.show()


func _request_character_list() -> void:
	# Request account characters from the world server
	InstanceClient.current.request_data(
		&"character.list",
		_on_character_list_response,
		{}
	)


func _on_character_list_response(data: Dictionary) -> void:
	if not data.get("ok", false):
		print("[CharacterPortrait] Failed to fetch character list: ", data.get("err", "unknown"))
		return
	
	var characters: Dictionary = data.get("characters", {})
	_populate_dropdown(characters)


func _populate_dropdown(characters: Dictionary) -> void:
	# Clear existing buttons
	for child in dropdown_vbox.get_children():
		child.queue_free()
	
	account_characters = characters
	
	# Add button for each character
	for char_id in characters.keys():
		var char_data: Dictionary = characters[char_id]
		
		# Skip current character
		if int(char_id) == character_id:
			continue
		
		var button: Button = Button.new()
		var char_energy: float = char_data.get("energy", 0.0)
		var char_energy_max: float = char_data.get("energy_max", 100.0)
		button.text = "%s (%s) Lv %d - Energy: %.0f/%.0f" % [
			char_data.get("name", ""),
			char_data.get("class", ""),
			char_data.get("level", 1),
			char_energy,
			char_energy_max
		]
		button.pressed.connect(_on_character_selected.bind(int(char_id)))
		dropdown_vbox.add_child(button)
	
	# Add "Create Character" button if less than 3 characters
	if characters.size() < 3:
		var create_button: Button = Button.new()
		create_button.text = "+ Create Character"
		create_button.pressed.connect(_on_create_character_pressed)
		dropdown_vbox.add_child(create_button)


func _on_character_selected(char_id: int) -> void:
	dropdown_panel.hide()
	
	if is_on_cooldown:
		print("[CharacterPortrait] Cannot switch - on cooldown")
		return
	
	print("[CharacterPortrait] Requesting character switch to ID: %d" % char_id)
	
	# Request character switch
	InstanceClient.current.request_data(
		&"character.switch",
		_on_character_switch_response,
		{"character_id": char_id}
	)


func _on_character_switch_response(data: Dictionary) -> void:
	print("[CharacterPortrait] Character switch response: ", data)
	
	if not data.get("ok", false):
		var err: StringName = data.get("err", &"unknown")
		
		if err == &"cooldown":
			var remaining: float = float(data.get("cooldown_remaining", 30.0))
			switch_cooldown_remaining = remaining
			is_on_cooldown = true
			cooldown_overlay.show()
			print("[CharacterPortrait] Switch on cooldown: %.1f seconds remaining" % remaining)
		else:
			print("[CharacterPortrait] Switch failed: ", err)
		
		return
	
	# Success - the server will handle despawn/spawn
	print("[CharacterPortrait] Switch successful!")


func _on_character_switch_complete_portrait(data: Dictionary) -> void:
	"""Update portrait info when switch completes"""
	print("[CharacterPortrait] Character switch complete - updating portrait")
	
	# Update character info
	character_id = data.get("character_id", character_id)
	character_name = data.get("character_name", character_name)
	character_class = data.get("character_class", character_class)
	
	# The level and energy will be updated through the normal systems
	# (Events.local_player_ready and attribute_local_changed)
	_update_display()


func set_character_creation_modal(modal) -> void:
	"""Set the character creation modal reference (called by HUD)"""
	character_creation_modal = modal
	
	# Connect to the character_created signal
	if character_creation_modal and not character_creation_modal.is_connected("character_created", _on_character_created):
		character_creation_modal.character_created.connect(_on_character_created)


func _on_create_character_pressed() -> void:
	dropdown_panel.hide()
	print("[CharacterPortrait] Opening character creation modal")
	
	if not character_creation_modal:
		print("[CharacterPortrait] ERROR: Character creation modal not set!")
		return
	
	character_creation_modal.show_modal()


func _on_character_created() -> void:
	"""Called when a new character is created - refresh the character list"""
	print("[CharacterPortrait] Character created - refreshing list")
	_request_character_list()


func start_cooldown(duration: float) -> void:
	"""Manually start a cooldown (e.g., after switching)"""
	switch_cooldown_remaining = duration
	is_on_cooldown = true
	cooldown_overlay.show()

