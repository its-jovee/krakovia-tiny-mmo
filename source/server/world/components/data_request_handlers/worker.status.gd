extends DataRequestHandler
## Handler for getting worker status (active jobs, completed jobs, burnout info)

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	var worker_type: String = args.get("worker_type", "")
	
	if worker_type.is_empty():
		return {"error": "Invalid worker type"}
	
	# Find the worker area for this type
	var worker: WorkerArea = _get_worker_by_type(instance, worker_type)
	if not worker:
		return {"error": "Worker type not found"}
	
	var player_resource = player.player_resource
	
	# Get worker info and player status
	var worker_info = worker.get_worker_info()
	var player_status = worker.get_player_status(player_resource)
	
	return {
		"success": true,
		"worker": worker_info,
		"status": player_status
	}


func _get_worker_by_type(instance: ServerInstance, worker_type: String) -> WorkerArea:
	"""Find a worker area by type"""
	var workers = instance.instance_map.find_children("*", "WorkerArea", true, false)
	for worker in workers:
		if worker is WorkerArea and worker.worker_type == worker_type:
			return worker
	return null

