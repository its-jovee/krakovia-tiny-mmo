class_name BotController
extends RefCounted
## Controls a single bot's behavior - movement, actions, dialogue.
## Uses a simple state machine: idle -> walking -> chatting -> idle
## Supports different NPC types with type-specific behavior.

var bot: Player
var entity_id: int
var activity_mode: BotManager.ActivityMode = BotManager.ActivityMode.DECORATIVE
var server_instance: ServerInstance

# NPC Type
var npc_type: NPCType.Type = NPCType.Type.VILLAGER_AMBIENT

# Worker-specific (for VILLAGER_WORKER type)
var linked_worker_id: String = ""  # WorkerArea.worker_id
var is_busy: bool = false  # True when worker is hired/working
var return_position: Vector2 = Vector2.ZERO  # Position to return to after job

# Interaction pausing (for VILLAGER_WORKER type)
var is_paused_for_interaction: bool = false  # True when player is at WorkerArea

# Movement
var home_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var wander_radius: float = 150.0
var movement_speed: float = 100.0
var is_moving: bool = false

# State machine
var current_state: StringName = &"idle"
var state_timer: float = 0.0

# Behavior timing
var _think_accumulator: float = 0.0
var _base_think_interval: float = 3.0

# Chat
var dialogue_pool: Array = []
var chat_cooldown: float = 0.0
var min_chat_interval: float = 30.0
var max_chat_interval: float = 90.0


func setup() -> void:
	# Randomize initial think time to stagger bots
	_think_accumulator = randf() * _base_think_interval
	chat_cooldown = randf_range(min_chat_interval, max_chat_interval)
	state_timer = randf_range(2.0, 5.0)


func tick(delta: float) -> void:
	# Workers that are busy (hired) or paused for interaction don't wander
	if is_busy or is_paused_for_interaction:
		return

	var effective_delta: float = delta * _get_activity_multiplier()

	# Update cooldowns
	chat_cooldown -= effective_delta
	state_timer -= effective_delta
	_think_accumulator += effective_delta

	# Process current state
	match current_state:
		&"idle":
			_process_idle(effective_delta)
		&"walking":
			_process_walking(effective_delta)
		&"chatting":
			_process_chatting(effective_delta)
		&"leaving":
			_process_leaving(effective_delta)
		&"returning":
			_process_returning(effective_delta)


func _process_idle(_delta: float) -> void:
	if state_timer <= 0:
		if _think_accumulator >= _base_think_interval:
			_think_accumulator = 0.0
			_decide_next_action()


func _process_walking(delta: float) -> void:
	if not is_moving:
		_transition_to(&"idle", randf_range(2.0, 6.0))
		return

	var direction: Vector2 = (target_position - bot.global_position).normalized()
	var distance: float = bot.global_position.distance_to(target_position)

	if distance < 10.0:
		# Reached destination
		is_moving = false
		_update_animation(Character.Animations.IDLE)
		_transition_to(&"idle", randf_range(3.0, 8.0))
	else:
		# Move toward target
		var step: Vector2 = direction * movement_speed * delta
		bot.global_position += step

		# Update sync
		bot.syn.set_by_path(^":position", bot.global_position)
		bot.syn.set_by_path(^":flipped", direction.x < 0)
		_update_animation(Character.Animations.RUN)


func _process_chatting(_delta: float) -> void:
	if state_timer <= 0:
		_transition_to(&"idle", randf_range(2.0, 5.0))


func _decide_next_action() -> void:
	var roll: float = randf()

	if roll < 0.6:
		# Wander (60% chance)
		_start_wandering()
	elif roll < 0.8 and chat_cooldown <= 0 and not dialogue_pool.is_empty():
		# Chat (20% chance, if cooldown ready and has dialogue)
		_say_something()
	else:
		# Stay idle a bit longer (20% chance)
		_transition_to(&"idle", randf_range(3.0, 8.0))


func _start_wandering() -> void:
	var offset: Vector2 = Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	target_position = home_position + offset
	is_moving = true
	_transition_to(&"walking", 30.0)  # Max walk time (timeout)
	_update_animation(Character.Animations.RUN)

	# Set initial facing direction
	var direction: Vector2 = (target_position - bot.global_position).normalized()
	bot.syn.set_by_path(^":flipped", direction.x < 0)


func _say_something() -> void:
	if dialogue_pool.is_empty():
		return

	var message: String = dialogue_pool[randi() % dialogue_pool.size()]

	# Broadcast chat message via BotManager
	if server_instance and server_instance.has_node("BotManager"):
		var bot_manager: BotManager = server_instance.get_node("BotManager")
		# Check if message is a translation key (starts with "npc_worker_dialog_")
		var is_i18n_key: bool = message.begins_with("npc_worker_dialog_")
		bot_manager.broadcast_bot_chat(entity_id, message, is_i18n_key)

	chat_cooldown = randf_range(min_chat_interval, max_chat_interval)
	_transition_to(&"chatting", 3.0)


func _transition_to(state: StringName, duration: float) -> void:
	current_state = state
	state_timer = duration


func _update_animation(anim: Character.Animations) -> void:
	bot.syn.set_by_path(^":anim", anim)


func _get_activity_multiplier() -> float:
	match activity_mode:
		BotManager.ActivityMode.ACTIVE:
			return 1.0
		BotManager.ActivityMode.REDUCED:
			return 0.25
		BotManager.ActivityMode.DECORATIVE:
			return 0.1
	return 1.0


# === WORKER-SPECIFIC BEHAVIOR ===


## Called when worker is hired - starts walking away from station
func start_leaving() -> void:
	if npc_type != NPCType.Type.VILLAGER_WORKER:
		return

	return_position = bot.global_position
	# Pick a direction away from home
	var away_direction: Vector2 = (bot.global_position - home_position).normalized()
	if away_direction.length_squared() < 0.01:
		away_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	target_position = bot.global_position + away_direction * (wander_radius + 50.0)
	is_moving = true
	_transition_to(&"leaving", 15.0)  # Max time to walk away
	_update_animation(Character.Animations.RUN)

	var direction: Vector2 = (target_position - bot.global_position).normalized()
	bot.syn.set_by_path(^":flipped", direction.x < 0)


## Called when worker job is complete - starts walking back to station
func start_returning(spawn_position: Vector2) -> void:
	if npc_type != NPCType.Type.VILLAGER_WORKER:
		return

	# Spawn at edge of wander radius, walk back to home
	var return_direction: Vector2 = (home_position - spawn_position).normalized()
	if return_direction.length_squared() < 0.01:
		return_direction = Vector2(1, 0)

	bot.global_position = spawn_position
	bot.syn.set_by_path(^":position", bot.global_position)

	target_position = home_position
	is_moving = true
	is_busy = false
	_transition_to(&"returning", 30.0)
	_update_animation(Character.Animations.RUN)

	bot.syn.set_by_path(^":flipped", return_direction.x < 0)


func _process_leaving(delta: float) -> void:
	if not is_moving:
		# Done walking away - mark as busy and stop
		is_busy = true
		_update_animation(Character.Animations.IDLE)
		return

	var direction: Vector2 = (target_position - bot.global_position).normalized()
	var distance: float = bot.global_position.distance_to(target_position)

	if distance < 10.0 or state_timer <= 0:
		# Reached edge or timeout - worker is now "away"
		is_moving = false
		is_busy = true
		_update_animation(Character.Animations.IDLE)
		# Signal to BotManager that we've fully left (can despawn if desired)
		if server_instance and server_instance.has_node("BotManager"):
			var bot_manager: BotManager = server_instance.get_node("BotManager")
			bot_manager._on_worker_left(entity_id)
	else:
		# Move toward target
		var step: Vector2 = direction * movement_speed * delta
		bot.global_position += step
		bot.syn.set_by_path(^":position", bot.global_position)
		bot.syn.set_by_path(^":flipped", direction.x < 0)


func _process_returning(delta: float) -> void:
	if not is_moving:
		_transition_to(&"idle", randf_range(2.0, 5.0))
		return

	var direction: Vector2 = (target_position - bot.global_position).normalized()
	var distance: float = bot.global_position.distance_to(target_position)

	if distance < 10.0:
		# Arrived back at station
		is_moving = false
		_update_animation(Character.Animations.IDLE)
		_transition_to(&"idle", randf_range(3.0, 6.0))
		# Signal to BotManager that we're back
		if server_instance and server_instance.has_node("BotManager"):
			var bot_manager: BotManager = server_instance.get_node("BotManager")
			bot_manager._on_worker_returned(entity_id)
	else:
		# Move toward home
		var step: Vector2 = direction * movement_speed * delta
		bot.global_position += step
		bot.syn.set_by_path(^":position", bot.global_position)
		bot.syn.set_by_path(^":flipped", direction.x < 0)
		_update_animation(Character.Animations.RUN)


# === INTERACTION PAUSING ===


## Called when a player enters the WorkerArea - stop wandering and face them
func pause_for_interaction(player_position: Vector2) -> void:
	if npc_type != NPCType.Type.VILLAGER_WORKER:
		return

	is_paused_for_interaction = true
	is_moving = false
	_update_animation(Character.Animations.IDLE)

	# Face the player
	bot.syn.set_by_path(^":flipped", player_position.x < bot.global_position.x)


## Called when all players leave the WorkerArea - resume wandering
func resume_wandering() -> void:
	if npc_type != NPCType.Type.VILLAGER_WORKER:
		return

	is_paused_for_interaction = false
	_transition_to(&"idle", randf_range(1.0, 3.0))
