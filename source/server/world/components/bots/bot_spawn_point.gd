@tool
@icon("res://assets/node_icons/blue/icon_person.png")
class_name BotSpawnPoint
extends Marker2D
## Placed in maps to define where bots spawn.
## The BotManager scans for these when the instance loads.

@export var bot_name: String = "Villager"
@export var bot_class: String = "forager"
@export var wander_radius: float = 150.0
@export var appearance_head_id: String = "head_a"

@export_multiline var dialogue_pool: String = "Hello there!\nNice weather today.\nHave you visited the market?"

## Visual indicator radius in editor
@export var show_wander_radius: bool = true


func get_dialogue_array() -> Array[String]:
	var lines: Array[String] = []
	for line in dialogue_pool.split("\n"):
		var trimmed = line.strip_edges()
		if not trimmed.is_empty():
			lines.append(trimmed)
	return lines


func _draw() -> void:
	if Engine.is_editor_hint() and show_wander_radius:
		draw_circle(Vector2.ZERO, wander_radius, Color(0.2, 0.6, 1.0, 0.15))
		draw_arc(Vector2.ZERO, wander_radius, 0, TAU, 64, Color(0.2, 0.6, 1.0, 0.5), 1.0)
		draw_circle(Vector2.ZERO, 4, Color(0.2, 0.6, 1.0, 0.8))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if bot_name.is_empty():
		warnings.append("Bot name is empty.")
	if bot_class.is_empty():
		warnings.append("Bot class is empty.")
	return warnings
