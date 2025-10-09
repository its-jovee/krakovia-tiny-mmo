class_name EnergyResource
extends GameplayResource


@export var regen_per_second: float = 1.0
@export var regen_delay_after_spend: float = 1.5
@export var sit_regen_multiplier: float = 1.5
@export var default_max: float = 100.0

var _time_since_spend: float = 0.0


func _init() -> void:
	id = &"energy"
	ui_color = Color(0.5, 0.85, 0.25, 1.0)


func setup(asc: AbilitySystemComponent, base_stats: Dictionary) -> void:
	var mx: float = float(base_stats.get(&"energy_max", default_max))
	var cur: float = float(base_stats.get(&"energy", mx))
	asc.ensure_attr(&"energy", cur, mx)
	asc.set_max_server(&"energy", mx, true)
	asc.set_value_server(&"energy", cur)
	_time_since_spend = regen_delay_after_spend


func can_pay(asc: AbilitySystemComponent, cost_tag: StringName, amount: float, _ctx: Dictionary) -> bool:
	if cost_tag != &"energy":
		return false
	return asc.get_value(&"energy") >= amount


func pay(asc: AbilitySystemComponent, cost_tag: StringName, amount: float, _ctx: Dictionary) -> void:
	if cost_tag != &"energy":
		return
	asc.add_delta_server(&"energy", -amount)
	_time_since_spend = 0.0


func tick_server(asc: AbilitySystemComponent, dt: float) -> void:
	_time_since_spend += dt
	if _time_since_spend < regen_delay_after_spend:
		return
	var mx: float = asc.get_max(&"energy")
	if mx <= 0.0:
		return
	var cur: float = asc.get_value(&"energy")
	if cur < mx and regen_per_second > 0.0:
		var is_sitting: bool = asc.get_value(&"is_sitting") > 0.5
		var rate: float = regen_per_second * (sit_regen_multiplier if is_sitting else 1.0)

		asc.set_value_server(&"energy", min(mx, cur + rate * dt))


func get_ui_snapshot(asc: AbilitySystemComponent) -> Dictionary:
	return {
		"id": id,
		"value": asc.get_value(&"energy"),
		"max": asc.get_max(&"energy"),
	}
