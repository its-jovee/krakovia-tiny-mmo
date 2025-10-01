extends Control

enum State { NONE, WAITING, RECEIVED_REQUEST, TRADE_READY }

var current_state: State = State.NONE
var requester_peer: int = -1
var requester_name: String = ""
var trade_session_id: int = -1
var other_player_name: String = ""

@onready var title_label: RichTextLabel = $YourOffer/VBoxContainer/Title
@onready var message_label: Label = $YourOffer/VBoxContainer/PlayerRequesting
@onready var description_label: Label = $YourOffer/VBoxContainer/Description
@onready var accept_button: Button = $YourOffer/VBoxContainer/HBoxContainer/Accept
@onready var deny_button: Button = $YourOffer/VBoxContainer/HBoxContainer/CloseButton

func _ready():
	accept_button.pressed.connect(_on_accept_pressed)
	deny_button.pressed.connect(_on_deny_pressed)
	
	# Subscribe to trade events
	InstanceClient.subscribe(&"trade.request", _on_trade_request)
	InstanceClient.subscribe(&"trade.request_sent", _on_trade_request_sent)
	InstanceClient.subscribe(&"trade.open", _on_trade_open)
	InstanceClient.subscribe(&"trade.request_denied", _on_trade_request_denied)
	InstanceClient.subscribe(&"trade.complete", _on_trade_complete)
	InstanceClient.subscribe(&"trade.cancel", _on_trade_cancel)
	
	# Hide modal by default
	hide()
	
	# Make sure modal can be closed with Escape key
	set_process_unhandled_key_input(true)

func _on_trade_request_sent(data: Dictionary):
	# Requester sees "Waiting for response..."
	current_state = State.WAITING
	other_player_name = data.get("target_name", "Player")
	
	title_label.text = "[b]Trade Request Sent[/b]"
	message_label.text = "Waiting for response..."
	description_label.text = "Sent trade request to " + other_player_name
	
	accept_button.hide()
	deny_button.text = "Cancel"
	deny_button.show()
	
	show()

func _on_trade_request(data: Dictionary):
	# Receiver sees "Accept/Deny"
	current_state = State.RECEIVED_REQUEST
	requester_peer = data.get("requester_peer", -1)
	requester_name = data.get("requester_name", "Unknown")
	
	title_label.text = "[b]Trade Request[/b]"
	message_label.text = requester_name
	description_label.text = "would like to trade with you."
	
	accept_button.text = "Accept"
	accept_button.show()
	deny_button.text = "Deny"
	deny_button.show()
	
	show()

func _on_trade_open(data: Dictionary):
	# Both players see "Trade accepted! Click to open"
	current_state = State.TRADE_READY
	trade_session_id = data.get("session_id", -1)
	other_player_name = data.get("other_name", "Unknown")
	
	title_label.text = "[b]Trade Accepted![/b]"
	message_label.text = other_player_name
	description_label.text = "is ready to trade"
	
	accept_button.text = "Open Trade"
	accept_button.disabled = false
	accept_button.show()
	deny_button.text = "Cancel"
	deny_button.disabled = false
	deny_button.show()
	
	show()

func _on_accept_pressed():
	if current_state == State.RECEIVED_REQUEST:
		# Accept the trade request
		print("=== ACCEPTING TRADE ===")
		print("Requester peer: ", requester_peer)
		print("Sending trade.respond with accepted=true")
		
		InstanceClient.current.request_data(&"trade.respond", Callable(), {
			"accepted": true,
			"requester_peer": requester_peer
		})
		
		# Show "Processing..." feedback
		title_label.text = "[b]Processing...[/b]"
		message_label.text = "Please wait"
		description_label.text = "Setting up trade..."
		accept_button.disabled = true
		deny_button.disabled = true
	elif current_state == State.TRADE_READY:
		# Open the trade window
		var hud = get_parent().get_parent()  # sub_menu -> HUD
		if hud and hud.has_method("display_menu"):
			hud.display_menu(&"inventory")
		close_modal()

func _on_deny_pressed():
	if current_state == State.RECEIVED_REQUEST:
		# Deny the trade request
		InstanceClient.current.request_data(&"trade.respond", Callable(), {
			"accepted": false,
			"requester_peer": requester_peer
		})
		close_modal()
	elif current_state == State.WAITING:
		# Cancel the pending request (requester cancels)
		close_modal()
	elif current_state == State.TRADE_READY:
		# Cancel the trade
		InstanceClient.current.request_data(&"trade.cancel", Callable(), {
			"session_id": trade_session_id
		})
		close_modal()

func close_modal():
	hide()
	# Reset state
	current_state = State.NONE
	requester_peer = -1
	requester_name = ""
	trade_session_id = -1
	other_player_name = ""

func _on_trade_request_denied(data: Dictionary):
	var target_name = data.get("target_name", "Player")
	print("Trade request denied by " + target_name)
	close_modal()

func _on_trade_complete(data: Dictionary):
	# Close modal when trade completes
	close_modal()

func _on_trade_cancel(data: Dictionary):
	# Close modal when trade is cancelled
	close_modal()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE and visible:
		close_modal()
