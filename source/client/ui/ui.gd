class_name UI
extends CanvasLayer


@onready var hud: CanvasLayer = $HUD
@onready var invitation_popup = $InvitationPopup
@onready var horse_racing_ui = $HorseRacingUI


func _ready() -> void:
	# Subscribe to minigame invitation
	InstanceClient.subscribe(&"minigame.invitation", _on_minigame_invitation)


func _on_minigame_invitation(data: Dictionary) -> void:
	if invitation_popup:
		invitation_popup.show_invitation(data)
