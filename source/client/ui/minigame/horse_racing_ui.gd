extends PanelContainer


# UI Nodes
@onready var betting_phase: Control = $MarginContainer/VBoxContainer/BettingPhase
@onready var racing_phase: Control = $MarginContainer/VBoxContainer/RacingPhase
@onready var results_phase: Control = $MarginContainer/VBoxContainer/ResultsPhase

# Betting Phase nodes
@onready var timer_label: Label = $MarginContainer/VBoxContainer/BettingPhase/TopInfo/TimerLabel
@onready var bet_amount_input: LineEdit = $MarginContainer/VBoxContainer/BettingPhase/BettingControls/BetAmountInput
@onready var ready_button: Button = $MarginContainer/VBoxContainer/BettingPhase/BettingControls/ReadyButton
@onready var leave_button: Button = $MarginContainer/VBoxContainer/BettingPhase/BettingControls/LeaveButton
@onready var horse_buttons_container: VBoxContainer = $MarginContainer/VBoxContainer/BettingPhase/HorseSelection/HorseButtonsContainer
@onready var players_list: VBoxContainer = $MarginContainer/VBoxContainer/BettingPhase/PlayersList
@onready var players_container: VBoxContainer = $MarginContainer/VBoxContainer/BettingPhase/PlayersList/ScrollContainer/PlayersContainer

# Racing Phase nodes
@onready var race_container: VBoxContainer = $MarginContainer/VBoxContainer/RacingPhase/RaceContainer
@onready var race_timer_label: Label = $MarginContainer/VBoxContainer/RacingPhase/RaceTimerLabel

# Results Phase nodes
@onready var winner_label: Label = $MarginContainer/VBoxContainer/ResultsPhase/WinnerLabel
@onready var winnings_label: Label = $MarginContainer/VBoxContainer/ResultsPhase/WinningsLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/ResultsPhase/CloseButton

# Game state
var session_id: int = -1
var current_phase: String = "betting"
var selected_horse: int = -1
var bet_amount: int = 0
var is_ready: bool = false
var horse_names: Array = []
var horse_buttons: Array = []
var horse_race_bars: Array = []
var participants: Array = []  # Store for race setup

# Race animation
var race_tween: Tween


func _ready() -> void:
	# Connect signals
	bet_amount_input.text_changed.connect(_on_bet_amount_changed)
	ready_button.pressed.connect(_on_ready_button_pressed)
	leave_button.pressed.connect(_on_leave_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Subscribe to minigame events
	InstanceClient.subscribe(&"minigame.state", _on_minigame_state)
	InstanceClient.subscribe(&"minigame.race_update", _on_race_update)
	InstanceClient.subscribe(&"minigame.results", _on_results)
	
	hide()


func show_game(session_id_param: int) -> void:
	session_id = session_id_param
	current_phase = "betting"
	selected_horse = -1
	bet_amount = 0
	is_ready = false
	
	bet_amount_input.text = ""
	ready_button.disabled = true
	
	_show_phase("betting")
	show()


func _show_phase(phase: String) -> void:
	betting_phase.hide()
	racing_phase.hide()
	results_phase.hide()
	
	match phase:
		"betting":
			betting_phase.show()
		"racing":
			racing_phase.show()
		"finished":
			results_phase.show()


func _on_minigame_state(data: Dictionary) -> void:
	var received_session_id: int = data.get("session_id", -1)
	
	# If we don't have a session or this is a new session, show the UI
	if session_id == -1 or (received_session_id != session_id and not visible):
		print("[HorseRacingUI] Showing UI for session: ", received_session_id)
		show_game(received_session_id)
	
	# Only process if this is our current session
	if data.get("session_id") != session_id:
		return
	
	var phase: String = data.get("phase", "betting")
	participants = data.get("participants", [])
	var horse_odds: Dictionary = data.get("horse_odds", {})
	var time_left: float = data.get("time_left", 0.0)
	horse_names = data.get("horse_names", ["Horse 1", "Horse 2", "Horse 3", "Horse 4", "Horse 5"])
	
	print("[HorseRacingUI] State update - Phase: %s, Participants: %d, Time: %.1f" % [phase, participants.size(), time_left])
	
	# Update phase if changed
	if phase != current_phase:
		current_phase = phase
		_show_phase(phase)
		
		if phase == "racing":
			_setup_race_track()
	
	# Update betting phase UI
	if phase == "betting":
		_update_timer(time_left)
		_update_horse_buttons(horse_odds)
		_update_players_list(participants)


func _update_timer(time_left: float) -> void:
	var minutes: int = int(time_left) / 60
	var seconds: int = int(time_left) % 60
	timer_label.text = "Time Left: %02d:%02d" % [minutes, seconds]


func _update_horse_buttons(horse_odds: Dictionary) -> void:
	# Create buttons if they don't exist
	if horse_buttons.is_empty():
		for i in range(horse_names.size()):
			var button = Button.new()
			button.custom_minimum_size = Vector2(300, 50)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.focus_mode = Control.FOCUS_ALL
			button.pressed.connect(_on_horse_selected.bind(i))
			horse_buttons.append(button)
			horse_buttons_container.add_child(button)
		print("[HorseRacingUI] Created %d horse buttons" % horse_buttons.size())
	
	# Update button text with odds
	for i in range(horse_buttons.size()):
		var total_bets: int = horse_odds.get(i, 0)
		var horse_name: String = horse_names[i] if i < horse_names.size() else "Horse %d" % (i + 1)
		horse_buttons[i].text = "🐎 %s - %d gold bet" % [horse_name, total_bets]
		
		# Highlight selected horse
		if i == selected_horse:
			horse_buttons[i].modulate = Color(1.2, 1.2, 0.6)
			horse_buttons[i].text = "✓ %s - %d gold bet (SELECTED)" % [horse_name, total_bets]
		else:
			horse_buttons[i].modulate = Color.WHITE


func _update_players_list(participants: Array) -> void:
	print("[HorseRacingUI] _update_players_list called with %d participants" % participants.size())
	
	if not players_container:
		print("[HorseRacingUI] ERROR: PlayersContainer not found!")
		return
	
	print("[HorseRacingUI] Found PlayersContainer, clearing existing entries...")
	
	# Clear existing player entries
	for child in players_container.get_children():
		child.queue_free()
	
	# Add each participant
	for p in participants:
		var label = Label.new()
		var player_name: String = p.get("player_name", "Unknown")
		var player_peer: int = p.get("peer_id", -1)
		var bet: int = p.get("bet_amount", 0)
		var ready: bool = p.get("ready", false)
		var ready_text: String = "✓" if ready else "○"
		
		var horse_name: String = ""
		var horse_id: int = p.get("horse_id", -1)
		if horse_id >= 0 and horse_id < horse_names.size():
			horse_name = horse_names[horse_id]
		
		# Check if this is the local player
		var is_me: bool = (player_peer == multiplayer.get_unique_id())
		var me_indicator: String = " (You)" if is_me else ""
		
		if bet > 0 and horse_name != "":
			label.text = "%s %s%s: 🐎%s - %dg" % [ready_text, player_name, me_indicator, horse_name, bet]
			if ready:
				label.modulate = Color(0.7, 1.0, 0.7)  # Green tint for ready
		else:
			label.text = "%s %s%s: Waiting..." % [ready_text, player_name, me_indicator]
			label.modulate = Color(0.7, 0.7, 0.7)  # Gray for not ready
		
		print("[HorseRacingUI] Adding player label: %s" % label.text)
		
		# Add to the players container
		players_container.add_child(label)
	
	print("[HorseRacingUI] Finished adding %d player labels" % participants.size())


func _on_horse_selected(horse_id: int) -> void:
	selected_horse = horse_id
	print("[HorseRacingUI] ===== HORSE SELECTED: %d (%s) =====" % [horse_id, horse_names[horse_id] if horse_id < horse_names.size() else "Unknown"])
	_check_ready_button()
	
	# Force update the button visuals immediately
	for i in range(horse_buttons.size()):
		if i == selected_horse:
			horse_buttons[i].modulate = Color(1.2, 1.2, 0.6)
			var horse_name: String = horse_names[i] if i < horse_names.size() else "Horse %d" % (i + 1)
			horse_buttons[i].text = "✓ %s (SELECTED)" % horse_name
		else:
			horse_buttons[i].modulate = Color.WHITE
			var horse_name: String = horse_names[i] if i < horse_names.size() else "Horse %d" % (i + 1)
			horse_buttons[i].text = "🐎 %s - 0 gold bet" % horse_name


func _on_bet_amount_changed(new_text: String) -> void:
	# Only allow numeric input
	var numeric_only = ""
	for c in new_text:
		if c.is_valid_int():
			numeric_only += c
	
	if new_text != numeric_only:
		bet_amount_input.text = numeric_only
		bet_amount_input.caret_column = numeric_only.length()
		return
	
	bet_amount = int(numeric_only) if numeric_only != "" else 0
	_check_ready_button()


func _check_ready_button() -> void:
	ready_button.disabled = (selected_horse == -1 or bet_amount <= 0)


func _on_ready_button_pressed() -> void:
	if selected_horse == -1 or bet_amount <= 0:
		return
	
	# Place bet
	InstanceClient.current.request_data(&"minigame.bet", _on_bet_response, {
		"session_id": session_id,
		"horse_id": selected_horse,
		"amount": bet_amount
	})


func _on_bet_response(response: Dictionary) -> void:
	if response.has("error"):
		print("[HorseRacingUI] Bet failed: ", response["error"])
		# Show error to player via chat
		var ui = get_viewport().get_node_or_null("UI")
		if ui:
			var chat = ui.get_node_or_null("ChatMenu")
			if chat:
				chat._on_chat_message({
					"text": "Bet failed: " + response["error"],
					"name": "System",
					"id": 1
				})
	else:
		# Mark as ready after successful bet
		InstanceClient.current.request_data(&"minigame.ready", func(_r): pass, {
			"session_id": session_id,
			"ready": true
		})
		is_ready = true
		ready_button.disabled = true
		ready_button.text = "Ready ✓"


func _on_leave_button_pressed() -> void:
	InstanceClient.current.request_data(&"minigame.leave", func(_r): pass, {
		"session_id": session_id
	})
	hide()


func _setup_race_track() -> void:
	# Clear existing race bars
	for child in race_container.get_children():
		child.queue_free()
	horse_race_bars.clear()
	
	# Calculate prize pool
	var total_pot: int = 0
	for p in participants:
		total_pot += p.get("bet_amount", 0)
	
	var first_place_prize: int = int(total_pot * 0.7)
	var second_place_prize: int = int(total_pot * 0.3)
	
	# Add title
	var title = Label.new()
	title.text = "🏁 THE RACE IS ON!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	race_container.add_child(title)
	
	# Create progress bar for each horse
	for i in range(horse_names.size()):
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.custom_minimum_size = Vector2(120, 0)
		name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.text = horse_names[i]
		
		# Highlight player's horse
		if i == selected_horse:
			name_label.text = "★ " + horse_names[i]
			name_label.modulate = Color(1.0, 0.9, 0.3)  # Gold color
		
		hbox.add_child(name_label)
		
		var progress_bar = ProgressBar.new()
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_bar.custom_minimum_size = Vector2(0, 30)
		progress_bar.min_value = 0.0
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		
		# Highlight player's horse progress bar
		if i == selected_horse:
			progress_bar.modulate = Color(1.2, 1.1, 0.6)
		
		hbox.add_child(progress_bar)
		
		race_container.add_child(hbox)
		horse_race_bars.append(progress_bar)
	
	# Add prize pool info
	var prize_info = Label.new()
	prize_info.text = "💰 Prize Pool: %d gold | 🥇 1st: %d | 🥈 2nd: %d" % [total_pot, first_place_prize, second_place_prize]
	prize_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prize_info.add_theme_font_size_override("font_size", 16)
	race_container.add_child(prize_info)
	
	# Add spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	race_container.add_child(spacer)
	
	# Add players betting section
	var players_title = Label.new()
	players_title.text = "👥 Players & Their Bets:"
	players_title.add_theme_font_size_override("font_size", 14)
	race_container.add_child(players_title)
	
	# Group players by horse
	var players_by_horse: Dictionary = {}
	for i in range(horse_names.size()):
		players_by_horse[i] = []
	
	for p in participants:
		var horse_id = p.get("horse_id", -1)
		if horse_id >= 0 and horse_id < horse_names.size():
			players_by_horse[horse_id].append(p)
	
	# Display players grouped by horse
	for horse_id in range(horse_names.size()):
		var players_on_horse = players_by_horse[horse_id]
		if players_on_horse.size() > 0:
			var horse_label = Label.new()
			var horse_name = horse_names[horse_id]
			var is_my_horse = (horse_id == selected_horse)
			
			# Build player list for this horse
			var player_names: Array = []
			for p in players_on_horse:
				var player_name = p.get("player_name", "Unknown")
				var bet_amount = p.get("bet_amount", 0)
				var peer_id = p.get("peer_id", -1)
				var is_me = (peer_id == multiplayer.get_unique_id())
				
				if is_me:
					player_names.append("%s (%dg) YOU" % [player_name, bet_amount])
				else:
					player_names.append("%s (%dg)" % [player_name, bet_amount])
			
			horse_label.text = "  🐎 %s: %s" % [horse_name, ", ".join(player_names)]
			
			# Highlight your horse
			if is_my_horse:
				horse_label.modulate = Color(1.0, 0.9, 0.3)
			
			race_container.add_child(horse_label)


func _on_race_update(data: Dictionary) -> void:
	var positions: Dictionary = data.get("positions", {})
	var elapsed: float = data.get("elapsed", 0.0)
	var duration: float = data.get("duration", 30.0)
	
	# Update timer
	var time_left: float = duration - elapsed
	race_timer_label.text = "Time: %.1fs" % time_left
	
	# Update progress bars with smooth animation
	for horse_id in positions:
		if horse_id < horse_race_bars.size():
			var target_position: float = min(positions[horse_id], 1.0)
			horse_race_bars[horse_id].value = target_position


func _on_results(data: Dictionary) -> void:
	var winner_horse: int = data.get("winner_horse", 0)
	var second_horse: int = data.get("second_horse", 1)
	var results: Dictionary = data.get("results", {})
	var total_pot: int = data.get("total_pot", 0)
	
	var winner_name: String = data.get("winner_name", "Unknown")
	var second_name: String = data.get("second_name", "Unknown")
	
	print("[HorseRacingUI] Results received:")
	print("  Winner: %s (horse %d)" % [winner_name, winner_horse])
	print("  Second: %s (horse %d)" % [second_name, second_horse])
	print("  My selected horse: %d" % selected_horse)
	print("  My peer_id: %d" % multiplayer.get_unique_id())
	print("  Results data: %s" % results)
	
	# Show results
	winner_label.text = "🏆 Winner: %s | 🥈 Second: %s" % [winner_name, second_name]
	
	# Check our result
	var my_peer_id: int = multiplayer.get_unique_id()
	if results.has(my_peer_id):
		var my_result: Dictionary = results[my_peer_id]
		var place: int = my_result.get("place", 0)
		var winnings: int = my_result.get("winnings", 0)
		
		print("  My result: place=%d, winnings=%d" % [place, winnings])
		
		if place == 1:
			winnings_label.text = "🎉 You won %d gold! (1st place)" % winnings
		elif place == 2:
			winnings_label.text = "🎉 You won %d gold! (2nd place)" % winnings
		else:
			winnings_label.text = "😔 You lost. Better luck next time!"
	else:
		print("  I'm not in the results!")
		winnings_label.text = "Total pot: %d gold" % total_pot
	
	_show_phase("finished")


func _on_close_button_pressed() -> void:
	hide()
	session_id = -1
	current_phase = "betting"
	selected_horse = -1
	bet_amount = 0
	is_ready = false
