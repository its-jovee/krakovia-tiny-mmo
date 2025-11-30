class_name PlayerResource
extends Resource

const XP_AT_L1   := 1000   # cost to go 1 -> 2
const XP_AT_LMAX := 500000 # cost to go (MAX_LEVEL-1) -> MAX_LEVEL
const POWER_P    := 2.2    # 2.0..2.6 = nice back-loaded
const ATTRIBUTE_POINTS_PER_LEVEL: int = 3
const MAX_LEVEL: int = 30
const BASE_ENERGY_MAX: float = 100.0
const ENERGY_PER_LEVEL: float = 50.0

const BASE_STATS: Dictionary[StringName, float] = {
	StatsCatalog.HEALTH_MAX: 100.0,
	StatsCatalog.HEALTH: 100.0,
	StatsCatalog.AD: 20.0,
	StatsCatalog.ARMOR: 15.0,
	StatsCatalog.MR: 15.0,
	StatsCatalog.MOVE_SPEED: 200.0,
	StatsCatalog.ATTACK_SPEED: 0.8,   
}

func get_energy_max() -> float:
	return BASE_ENERGY_MAX + ENERGY_PER_LEVEL * (level - 1)

@export var player_id: int
@export var account_name: String

@export var display_name: String = "Player"
@export var character_class: String = "miner"

## Appearance customization
@export var appearance_head_id: String = "head_a"  # Head/face variant (head_a, head_b, head_c, head_d)
@export var appearance_hair_id: String = "none"  # Disabled initially
@export var appearance_accessory_id: String = "none"  # Disabled initially

## Equipped cosmetic items (item IDs)
@export var equipped_accessory_id: int = -1  # -1 = nothing equipped

@export var golds: int
@export var inventory: Dictionary

@export var attributes: Dictionary
@export var available_attributes_points: int

@export var level: int = 1
@export var experience: int = 0

@export var guild: Guild
##
@export var server_roles: Dictionary

## Persisted runtime state
@export var current_energy: float = -1.0

## Quest completion statistics
@export var quest_stats: Dictionary = {}

## Selected title (character-specific, even though unlocks are account-wide)
@export var selected_title_slug: String = ""

## Quick-Switch: Last logout timestamp (unix time) for energy regeneration
@export var last_logout_time: float = 0.0

## Quick-Switch: Last known position for respawning at same location
@export var last_position: Vector2 = Vector2.ZERO

## Hired Worker System - active jobs
## Each job: {worker_type: String, tier: int, start_time: int, duration_seconds: int}
@export var worker_jobs: Array[Dictionary] = []

## Hired Worker System - burnout tracking (cost increases with repeated hires)
## Structure: {worker_type: {hire_count: int, last_reset: int (unix timestamp)}}
@export var worker_burnout: Dictionary = {}

## Current Network ID
var current_peer_id: int


func init(
	_player_id: int,
	_account_name: String,
	_display_name: String = display_name,
	_character_class: String = character_class,
	_appearance_head_id: String = "head_a"
) -> void:
	player_id = _player_id
	account_name = _account_name
	display_name = _display_name
	character_class = _character_class
	appearance_head_id = _appearance_head_id



func get_stats_from_attributes() -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = {}
	# To Replace by constants
	if attributes == null:
		return stats
	for attr_name: StringName in attributes.keys():
		match attr_name:
			&"vitality":
				stats[StatsCatalog.HEALTH_MAX] = stats.get(StatsCatalog.HEALTH_MAX, 0.0) + 5.0
			&"strength":
				stats[StatsCatalog.AD] = stats.get(StatsCatalog.AD, 0.0) + 2.0
			&"agility":
				stats[StatsCatalog.MOVE_SPEED] = stats.get(StatsCatalog.MOVE_SPEED, 0.0) + 3.0
	return stats


static func get_exp_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	var L    := float(target_level)
	var Lmax := float(MAX_LEVEL)
	var t    := pow(L / Lmax, POWER_P)              # 0..1 (nonlinear)
	var t1   := pow(1.0 / Lmax, POWER_P)            # value at level 1
	# affine map t ∈ [t1,1] -> [XP_AT_L1, XP_AT_LMAX]
	var alpha := (XP_AT_LMAX - XP_AT_L1) / (1.0 - t1)
	var beta  := XP_AT_L1 - alpha * t1
	return int(max(1.0, round(alpha * t + beta)))


func get_exp_required() -> int:
	return get_exp_for_level(level + 1)


func get_exp_progress() -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var required = get_exp_required()
	return float(experience) / float(required) if required > 0 else 0.0


func add_experience(amount: int) -> void:
	if amount <= 0:
		return
	if level >= MAX_LEVEL:
		return  # ignore or store "prestige XP" if you want

	experience += amount
	# Consume overflow and allow multi-level ups
	while level < MAX_LEVEL:
		var required := get_exp_required()
		if experience < required:
			break
		experience -= required
		_level_up_single_step()

func _level_up_single_step() -> void:
	# Single step up (used by add_experience loop)
	level += 1
	available_attributes_points += ATTRIBUTE_POINTS_PER_LEVEL
	if level >= MAX_LEVEL:
		experience = 0  # clear at cap (or keep as "post-cap XP")

func can_level_up() -> bool:
	return level < MAX_LEVEL and experience >= get_exp_required()

# convenience if we call level_up() from UI
func level_up() -> void:
	if can_level_up():
		# Respect overflow instead of nuking XP
		var required := get_exp_required()
		experience -= required
		_level_up_single_step()
	if level >= MAX_LEVEL:
		return


func get_appearance_data() -> Dictionary:
	"""Get appearance data for syncing"""
	return {
		"head": appearance_head_id,
		"hair": appearance_hair_id,
		"accessory": appearance_accessory_id
	}


## === HIRED WORKER SYSTEM ===

const WORKER_DAY_DURATION: int = 45 * 60  # 45 minutes in seconds
const WORKER_BURNOUT_MULTIPLIER: float = 1.25  # 25% increase per hire

## Get burnout info for a worker type, resetting if a new "day" has started
func get_worker_burnout(worker_type: String) -> Dictionary:
	var now = int(Time.get_unix_time_from_system())
	
	if not worker_burnout.has(worker_type):
		worker_burnout[worker_type] = {"hire_count": 0, "last_reset": now}
	
	var info = worker_burnout[worker_type]
	var elapsed = now - info.get("last_reset", now)
	
	# Reset if a "day" (45 min) has passed
	if elapsed >= WORKER_DAY_DURATION:
		info["hire_count"] = 0
		info["last_reset"] = now
	
	return info


## Calculate the cost with burnout multiplier applied
func calculate_worker_cost(worker_type: String, base_cost: int) -> int:
	var info = get_worker_burnout(worker_type)
	var hire_count = info.get("hire_count", 0)
	var multiplier = pow(WORKER_BURNOUT_MULTIPLIER, hire_count)
	return int(ceil(base_cost * multiplier))


## Increment hire count for burnout tracking
func increment_worker_hire(worker_type: String) -> void:
	var info = get_worker_burnout(worker_type)
	info["hire_count"] = info.get("hire_count", 0) + 1


## Get time until burnout resets (in seconds)
func get_burnout_reset_time(worker_type: String) -> int:
	var info = get_worker_burnout(worker_type)
	var now = int(Time.get_unix_time_from_system())
	var elapsed = now - info.get("last_reset", now)
	return maxi(0, WORKER_DAY_DURATION - elapsed)


## Add a new worker job
func add_worker_job(worker_type: String, tier: int, duration_seconds: int) -> void:
	var job = {
		"worker_type": worker_type,
		"tier": tier,
		"start_time": int(Time.get_unix_time_from_system()),
		"duration_seconds": duration_seconds
	}
	worker_jobs.append(job)


## Get all jobs for a specific worker type
func get_worker_jobs(worker_type: String) -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	for job in worker_jobs:
		if job.get("worker_type") == worker_type:
			jobs.append(job)
	return jobs


## Get completed jobs ready for collection
func get_completed_jobs(worker_type: String = "") -> Array[Dictionary]:
	var now = int(Time.get_unix_time_from_system())
	var completed: Array[Dictionary] = []
	
	for job in worker_jobs:
		if worker_type != "" and job.get("worker_type") != worker_type:
			continue
		var end_time = job.get("start_time", 0) + job.get("duration_seconds", 0)
		if now >= end_time:
			completed.append(job)
	
	return completed


## Remove a specific job (after collection)
func remove_worker_job(job: Dictionary) -> bool:
	var idx = worker_jobs.find(job)
	if idx >= 0:
		worker_jobs.remove_at(idx)
		return true
	return false


## Check if player has any completed jobs (for visual indicator)
func has_completed_worker_jobs() -> bool:
	return get_completed_jobs().size() > 0
