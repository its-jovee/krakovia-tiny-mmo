extends Control


@onready var label: Label = $ProgressBar/Label
@onready var progress_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	Events.local_player_ready.connect(
		func(local_player: LocalPlayer) -> void:
			var ability_system_component: AbilitySystemComponent = local_player.get_node_or_null(^"AbilitySystemComponent")
			if not ability_system_component:
				return
			ability_system_component.mirror.attribute_local_changed.connect(_on_target_attribute_changed)
	)


func _on_target_attribute_changed(attr: StringName, value: float, max_value: float) -> void:
	if attr == &"energy":
		_on_energy_changed(value)
		_on_max_energy_changed(max_value)


func _on_energy_changed(new_energy: float) -> void:
	progress_bar.value = new_energy
	update_label()


func _on_max_energy_changed(new_max_energy: float) -> void:
	progress_bar.max_value = new_max_energy
	update_label()


func update_label() -> void:
	label.text = "%d / %d" % [progress_bar.value, progress_bar.max_value]

