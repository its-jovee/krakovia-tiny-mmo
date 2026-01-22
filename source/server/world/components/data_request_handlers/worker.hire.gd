extends DataRequestHandler
## Handler for hiring a worker to gather resources

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	var worker_type: String = args.get("worker_type", "")
	var tier: int = args.get("tier", 1)
	
	if worker_type.is_empty():
		return {"error": "Invalid worker type"}
	
	if tier < 1 or tier > 6:
		return {"error": "Invalid tier (must be 1-6)"}
	
	# Find the worker area the player is at
	var worker: WorkerArea = _get_player_worker(player, instance, worker_type)
	if not worker:
		return {"error": "Must be at a %s worker to hire" % worker_type}
	
	var player_resource = player.player_resource
	
	# Calculate cost with burnout multiplier
	var base_cost = worker.get_base_cost(tier)
	var actual_cost = player_resource.calculate_worker_cost(worker_type, base_cost)
	
	# Check if player has enough gold
	if player_resource.golds < actual_cost:
		return {"error": "Not enough gold (need %d)" % actual_cost}
	
	# Deduct gold
	player_resource.golds -= actual_cost
	
	# Get job duration
	var duration = worker.get_duration(tier)
	
	# Create the job
	player_resource.add_worker_job(worker_type, tier, duration)
	
	# Increment burnout count
	player_resource.increment_worker_hire(worker_type)
	
	# Notify client of gold change
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player_resource.golds})
	
	# Push updated worker status to client
	var status = worker.get_player_status(player_resource)
	status["worker_type"] = worker_type
	instance.data_push.rpc_id(peer_id, &"worker.status", status)

	# Notify BotManager that worker is now busy (will walk away)
	if worker.has_method("notify_worker_hired"):
		worker.notify_worker_hired()

	print("[worker.hire] Player %s hired %s tier %d for %d gold (burnout count: %d)" % [
		player_resource.display_name,
		worker_type,
		tier,
		actual_cost,
		player_resource.get_worker_burnout(worker_type).get("hire_count", 0)
	])
	
	return {
		"success": true,
		"worker_type": worker_type,
		"tier": tier,
		"cost": actual_cost,
		"duration_seconds": duration,
		"start_time": int(Time.get_unix_time_from_system())
	}


func _get_player_worker(player: Player, instance: ServerInstance, worker_type: String) -> WorkerArea:
	"""Find the worker area of specific type the player is currently at"""
	var workers = instance.instance_map.find_children("*", "WorkerArea", true, false)
	for worker in workers:
		if worker is WorkerArea and worker.worker_type == worker_type:
			if player in worker.players_at_worker:
				return worker
	return null



