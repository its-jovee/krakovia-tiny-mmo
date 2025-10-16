class_name EnergyResource
extends GameplayResource


@export var regen_per_second: float = 1.0
@export var regen_delay_after_spend: float = 1.5
@export var sit_regen_multiplier: float = 5.0
@export var default_max: float = 100.0
@export var update_interval: float = 0.5  # Only sync every 0.5 seconds

var _time_since_spend: float = 0.0
var _time_since_last_update: float = 0.0
var _pending_delta: float = 0.0


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
	# Include pending delta in calculation
	var current = asc.get_value(&"energy") + _pending_delta
	return current >= amount


func pay(asc: AbilitySystemComponent, cost_tag: StringName, amount: float, _ctx: Dictionary) -> void:
	if cost_tag != &"energy":
		return
	# Flush pending delta before spending
	if _pending_delta != 0.0:
		asc.add_delta_server(&"energy", _pending_delta)
		_pending_delta = 0.0
	asc.add_delta_server(&"energy", -amount)
	_time_since_spend = 0.0
	_time_since_last_update = 0.0


func tick_server(asc: AbilitySystemComponent, dt: float) -> void:
	_time_since_spend += dt
	_time_since_last_update += dt
	
	if _time_since_spend < regen_delay_after_spend:
		return
	
	var mx: float = asc.get_max(&"energy")
	if mx <= 0.0:
		return
	
	var cur: float = asc.get_value(&"energy")
	if cur >= mx:
		_pending_delta = 0.0
		return
	
	if regen_per_second <= 0.0:
		return
	
	var is_sitting: bool = asc.get_value(&"is_sitting") > 0.5
	var rate: float = regen_per_second * (sit_regen_multiplier if is_sitting else 1.0)
	var regen_this_tick: float = rate * dt
	
	# Accumulate delta
	_pending_delta += regen_this_tick
	
	# Only sync to network when enough time has passed OR we're at max
	var new_value = cur + _pending_delta
	if _time_since_last_update >= update_interval or new_value >= mx:
		var clamped = min(mx, new_value)
		asc.set_value_server(&"energy", clamped)
		_pending_delta = 0.0
		_time_since_last_update = 0.0


func get_ui_snapshot(asc: AbilitySystemComponent) -> Dictionary:
	# Include pending delta for accurate UI display
	var current = asc.get_value(&"energy") + _pending_delta
	return {
		"id": id,
		"value": min(current, asc.get_max(&"energy")),
		"max": asc.get_max(&"energy"),
	}
