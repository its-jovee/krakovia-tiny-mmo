extends DataRequestHandler
## Handler for collecting loot from completed worker jobs

func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player = instance.players_by_peer_id.get(peer_id, null)
	if not player:
		return {"error": "Player not found"}
	
	var worker_type: String = args.get("worker_type", "")
	var job_index: int = args.get("job_index", -1)  # -1 means collect all completed
	
	if worker_type.is_empty():
		return {"error": "Invalid worker type"}
	
	# Find the worker area for this type
	var worker: WorkerArea = _get_worker_by_type(instance, worker_type)
	if not worker:
		return {"error": "Worker type not found"}
	
	var player_resource = player.player_resource
	var now = int(Time.get_unix_time_from_system())
	
	# Find completed jobs for this worker type
	var completed_jobs: Array[Dictionary] = []
	var completed_indices: Array[int] = []
	
	for i in range(player_resource.worker_jobs.size()):
		var job = player_resource.worker_jobs[i]
		if job.get("worker_type") != worker_type:
			continue
		
		var end_time = job.get("start_time", 0) + job.get("duration_seconds", 0)
		if now >= end_time:
			if job_index == -1 or job_index == i:
				completed_jobs.append(job)
				completed_indices.append(i)
	
	if completed_jobs.is_empty():
		return {"error": "No completed jobs to collect"}
	
	# Calculate total loot from all completed jobs
	var total_loot: Dictionary = {}  # item_slug -> quantity
	
	for job in completed_jobs:
		var tier = job.get("tier", 1)
		var job_loot = worker.roll_loot(tier)
		print("[worker.collect] Tier %d rolled %d item types: %s" % [tier, job_loot.size(), job_loot])
		for item_slug in job_loot.keys():
			total_loot[item_slug] = total_loot.get(item_slug, 0) + job_loot[item_slug]
	
	print("[worker.collect] Total loot to add: %s" % total_loot)
	
	# Check inventory space and add items
	var items_added: Dictionary = {}  # item_id -> quantity actually added
	var items_failed: Dictionary = {}  # item_id -> quantity that couldn't be added
	
	for item_slug in total_loot.keys():
		var quantity = total_loot[item_slug]
		var item_id = ContentRegistryHub.id_from_slug(&"items", item_slug)
		
		if item_id <= 0:
			push_warning("[worker.collect] Unknown item slug: %s" % item_slug)
			continue
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		
		# Check how many we can add (respecting stack limits)
		var current_stack = 0
		if player_resource.inventory.has(item_id):
			current_stack = player_resource.inventory[item_id].get("stack", 0)
		
		var can_add = quantity
		if item.stack_limit > 0:
			var space_left = item.stack_limit - current_stack
			can_add = mini(quantity, space_left)
		
		if can_add > 0:
			# Add items to inventory
			if player_resource.inventory.has(item_id):
				player_resource.inventory[item_id]["stack"] = current_stack + can_add
			else:
				player_resource.inventory[item_id] = {"stack": can_add}
			
			items_added[item_id] = can_add
		
		var failed = quantity - can_add
		if failed > 0:
			items_failed[item_id] = failed
	
	# Remove collected jobs (in reverse order to preserve indices)
	completed_indices.sort()
	completed_indices.reverse()
	for idx in completed_indices:
		player_resource.worker_jobs.remove_at(idx)
	
	# Notify client of inventory change
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_resource.inventory)
	
	# Push updated worker status
	var status = worker.get_player_status(player_resource)
	status["worker_type"] = worker_type
	instance.data_push.rpc_id(peer_id, &"worker.status", status)

	# Notify BotManager that worker can return (job collected)
	# Only respawn if there are no more active jobs for this worker
	var remaining_jobs = player_resource.get_worker_jobs(worker_type)
	if remaining_jobs.is_empty() and worker.has_method("notify_worker_job_complete"):
		worker.notify_worker_job_complete()
	
	# Push item received notifications (like harvest popups)
	var items_for_popup: Array[Dictionary] = []
	print("[worker.collect] Building popup list from %d loot entries, %d items added" % [total_loot.size(), items_added.size()])
	for item_slug in total_loot.keys():
		var quantity = total_loot[item_slug]
		var item_id = ContentRegistryHub.id_from_slug(&"items", item_slug)
		print("[worker.collect]  - Slug '%s' -> id %d, in items_added: %s" % [item_slug, item_id, items_added.has(item_id)])
		if item_id > 0 and items_added.has(item_id):
			items_for_popup.append({
				"slug": item_slug,
				"amount": items_added[item_id]
			})
	
	print("[worker.collect] Sending %d items for popup notification" % items_for_popup.size())
	if not items_for_popup.is_empty():
		instance.data_push.rpc_id(peer_id, &"worker.items_received", {
			"items": items_for_popup,
			"worker_type": worker_type
		})
	else:
		push_warning("[worker.collect] No items to show in popup!")
	
	# Build response with item names for UI
	var collected_items: Array[Dictionary] = []
	for item_id in items_added.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		collected_items.append({
			"id": item_id,
			"name": item.item_name if item else "Unknown",
			"quantity": items_added[item_id]
		})
	
	var failed_items: Array[Dictionary] = []
	for item_id in items_failed.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		failed_items.append({
			"id": item_id,
			"name": item.item_name if item else "Unknown",
			"quantity": items_failed[item_id]
		})
	
	print("[worker.collect] Player %s collected from %s - %d items types, %d failed due to full inventory" % [
		player_resource.display_name,
		worker_type,
		collected_items.size(),
		failed_items.size()
	])
	
	var result = {
		"success": true,
		"worker_type": worker_type,
		"jobs_collected": completed_jobs.size(),
		"items": collected_items
	}
	
	if not failed_items.is_empty():
		result["warning"] = "Some items couldn't fit in inventory"
		result["failed_items"] = failed_items
	
	return result


func _get_worker_by_type(instance: ServerInstance, worker_type: String) -> WorkerArea:
	"""Find a worker area by type"""
	if not instance.instance_map:
		push_error("[worker.collect] No instance_map!")
		return null
	
	var workers = instance.instance_map.find_children("*", "WorkerArea", true, false)
	print("[worker.collect] Found %d WorkerArea nodes in instance_map" % workers.size())
	
	for worker in workers:
		if worker is WorkerArea and worker.worker_type == worker_type:
			print("[worker.collect] Found worker '%s' with %d loot tables loaded" % [worker.worker_name, worker._loot_tables.size()])
			return worker
	
	push_error("[worker.collect] No worker found of type: %s" % worker_type)
	return null

