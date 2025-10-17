class_name UI
extends CanvasLayer


@onready var hud: CanvasLayer = $HUD
@onready var invitation_popup = $InvitationPopup
@onready var horse_racing_ui = $HorseRacingUI
@onready var announcement_popup = $AnnouncementPopup


func _ready() -> void:
	# Subscribe to minigame invitation
	InstanceClient.subscribe(&"minigame.invitation", _on_minigame_invitation)
	# Subscribe to minigame announcements
	InstanceClient.subscribe(&"minigame.announcement", _on_minigame_announcement)


func _on_minigame_invitation(data: Dictionary) -> void:
	if invitation_popup:
		invitation_popup.show_invitation(data)


func _on_minigame_announcement(data: Dictionary) -> void:
	if announcement_popup:
		announcement_popup.show_announcement(data)
