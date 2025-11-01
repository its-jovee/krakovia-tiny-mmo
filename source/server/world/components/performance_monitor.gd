class_name PerformanceMonitor
extends Node

var _stats_timer: Timer
var _log_interval: float = 10.0  # Log every 10 seconds
var _enable_logging: bool = true
var _enable_detailed: bool = false

# Metrics tracking
var _frame_times: Array = []
var _rpc_count: int = 0
var _data_request_count: int = 0
var _last_memory: int = 0


func _ready() -> void:
	# Load config
	_load_config()
	
	if not _enable_logging:
		return
	
	_stats_timer = Timer.new()
	_stats_timer.wait_time = _log_interval
	_stats_timer.autostart = true
	_stats_timer.timeout.connect(_log_performance_stats)
	add_child(_stats_timer)
	
	# Track process time
	set_process(true)


func _process(delta: float) -> void:
	_frame_times.append(delta)
	if _frame_times.size() > 600:  # Keep last 10 seconds at 60 FPS
		_frame_times.pop_front()


func _log_performance_stats() -> void:
	print("========================================")
	print("PERFORMANCE STATS")
	print("========================================")
	
	# Instance stats
	var instance_server: ServerInstance = _get_instance_server()
	if instance_server:
		print("Players: %d" % instance_server.connected_peers.size())
		print("Entities: %d" % instance_server.synchronizer_manager.entities.size())
		
		# Harvest stats
		if instance_server.harvest_manager:
			print("Active Harvesters: %d" % instance_server.harvest_manager.active_harvesters.size())
			print("Harvest Nodes: %d" % instance_server.harvest_manager.nodes_by_id.size())
	
	# Frame time stats
	if not _frame_times.is_empty():
		var avg_frame = _frame_times.reduce(func(acc, v): return acc + v, 0.0) / _frame_times.size()
		var max_frame = _frame_times.max()
		var fps = 1.0 / avg_frame if avg_frame > 0 else 0.0
		print("Avg Frame: %.2fms (%.1f FPS)" % [avg_frame * 1000, fps])
		print("Max Frame: %.2fms" % [max_frame * 1000])
	
	# Memory stats
	var current_memory = OS.get_static_memory_usage()
	var memory_mb = current_memory / 1024.0 / 1024.0
	var memory_delta = (current_memory - _last_memory) / 1024.0 / 1024.0
	print("Memory: %.2f MB (delta: %+.2f MB)" % [memory_mb, memory_delta])
	_last_memory = current_memory
	
	# Network stats (if detailed enabled)
	if _enable_detailed:
		print("RPC Calls: %d/s" % (_rpc_count / _log_interval))
		print("Data Requests: %d/s" % (_data_request_count / _log_interval))
	
	_rpc_count = 0
	_data_request_count = 0
	
	print("========================================")


func track_rpc() -> void:
	_rpc_count += 1


func track_data_request() -> void:
	_data_request_count += 1


func _load_config() -> void:
	# Try to get config from WorldMain
	if get_parent() and get_parent().has_node("../WorldMain"):
		var world_main = get_parent().get_node("../WorldMain")
		if world_main.world_config_file:
			_enable_logging = world_main.world_config_file.get_value("monitoring", "enable_logging", true)
			_log_interval = world_main.world_config_file.get_value("monitoring", "log_interval", 10.0)
			_enable_detailed = world_main.world_config_file.get_value("monitoring", "enable_detailed", false)


func _get_instance_server() -> ServerInstance:
	if get_parent() is ServerInstance:
		return get_parent()
	return null



