extends Node
## UISoundManager - Centralized UI sound system
## Provides easy-to-use methods for playing UI feedback sounds.
## All sounds are preloaded for instant playback.

class_name UISoundManager


# =============================================================================
# SOUND PATHS
# =============================================================================

const SOUND_PATH := "res://assets/audio/sfx/ui/"

const SOUNDS := {
	"click": "click.wav",
	"hover": "hover.wav",
	"open": "open.wav",
	"close": "close.wav",
	"success": "success.wav",
	"error": "error.wav",
	"select": "select.wav",
	"back": "back.wav",
	"confirm": "confirm.wav",
}


# =============================================================================
# AUDIO SETTINGS
# =============================================================================

const BUS_NAME := "UI"
const DEFAULT_VOLUME_DB := 0.0
const HOVER_VOLUME_DB := -6.0  # Hover sounds are quieter


# =============================================================================
# STATE
# =============================================================================

var _players: Dictionary = {}
var _streams: Dictionary = {}
var _enabled: bool = true
var _volume_scale: float = 1.0


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_ensure_ui_bus()
	_preload_sounds()
	_create_players()


func _ensure_ui_bus() -> void:
	"""Ensure UI audio bus exists, if not we'll use Master"""
	var bus_idx := AudioServer.get_bus_index(BUS_NAME)
	if bus_idx == -1:
		# UI bus doesn't exist, sounds will use Master bus
		# You can add a UI bus in Godot's Audio tab for finer control
		pass


func _preload_sounds() -> void:
	"""Preload all sound resources"""
	for key in SOUNDS:
		var path: String = SOUND_PATH + SOUNDS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
		else:
			# Sound file not found - that's OK, we'll just skip it
			pass


func _create_players() -> void:
	"""Create audio players for each sound"""
	for key in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME if AudioServer.get_bus_index(BUS_NAME) != -1 else "Master"
		add_child(player)
		_players[key] = player
		
		if _streams.has(key):
			player.stream = _streams[key]


# =============================================================================
# PUBLIC API - PLAY SOUNDS
# =============================================================================

## Play button click sound
func play_click() -> void:
	_play("click")


## Play hover sound (quieter)
func play_hover() -> void:
	_play("hover", HOVER_VOLUME_DB)


## Play menu/panel open sound
func play_open() -> void:
	_play("open")


## Play menu/panel close sound
func play_close() -> void:
	_play("close")


## Play success/confirmation sound
func play_success() -> void:
	_play("success")


## Play error/deny sound
func play_error() -> void:
	_play("error")


## Play item/option selected sound
func play_select() -> void:
	_play("select")


## Play back/cancel sound
func play_back() -> void:
	_play("back")


## Play confirm action sound (heavier than click)
func play_confirm() -> void:
	_play("confirm")


## Play a sound by key name
func play(sound_key: String) -> void:
	_play(sound_key)


# =============================================================================
# SETTINGS
# =============================================================================

## Enable or disable UI sounds
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


## Check if UI sounds are enabled
func is_enabled() -> bool:
	return _enabled


## Set volume scale (0.0 to 1.0)
func set_volume_scale(scale: float) -> void:
	_volume_scale = clampf(scale, 0.0, 1.0)


## Get current volume scale
func get_volume_scale() -> float:
	return _volume_scale


# =============================================================================
# INTERNAL
# =============================================================================

func _play(key: String, volume_offset: float = 0.0) -> void:
	if not _enabled:
		return
	
	if not _players.has(key):
		return
	
	var player: AudioStreamPlayer = _players[key]
	if not player.stream:
		return
	
	# Calculate volume with scale
	var volume := DEFAULT_VOLUME_DB + volume_offset
	if _volume_scale < 1.0:
		# Convert scale to dB offset
		volume += linear_to_db(_volume_scale)
	
	player.volume_db = volume
	player.play()
