extends Control
## Worker Hire UI - Interface for hiring workers and collecting loot

# Worker info from server
var worker_info: Dictionary = {}  # {type, name, icon, description, tiers}
var worker_status: Dictionary = {}  # {active_jobs, completed_jobs, hire_count, burnout_reset_seconds, current_costs}
var worker_type: String = ""

# Current gold
var current_gold: int = 0

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var description_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/DescriptionBox
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/GoldLabel
@onready var burnout_label: Label = $Panel/MarginContainer/VBoxContainer/BurnoutLabel
@onready var tiers_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TiersScroll/TiersContainer
@onready var jobs_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/JobsScroll/JobsContainer


func _ready() -> void:
	visible = false
	
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Subscribe to updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	InstanceClient.subscribe(&"worker.status", _on_worker_status_update)
	
	# Start update timer for job countdowns
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_job_timers)
	timer.autostart = true
	add_child(timer)


func open_worker(type: String) -> void:
	"""Open the worker hire UI for a specific worker type"""
	worker_type = type
	visible = true
	
	# Request current gold
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	
	# Request worker status
	InstanceClient.current.request_data(&"worker.status", _on_status_received, {"worker_type": type})


func _on_gold_received(data: Dictionary) -> void:
	if data.has("gold"):
		current_gold = data.gold
		_update_gold_display()


func _on_gold_update(data: Dictionary) -> void:
	if data.has("gold"):
		current_gold = data.gold
		_update_gold_display()


func _on_status_received(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to get worker status: %s" % data.error)
		return
	
	worker_info = data.get("worker", {})
	worker_status = data.get("status", {})
	
	_refresh_display()


func _on_worker_status_update(data: Dictionary) -> void:
	"""Handle real-time status updates"""
	if data.get("worker_type", "") != worker_type:
		return
	
	worker_status = data
	_refresh_jobs_display()
	_refresh_tiers_display()  # Update costs due to burnout changes


func _refresh_display() -> void:
	"""Refresh the entire UI"""
	_update_header()
	_refresh_tiers_display()
	_refresh_jobs_display()
	_update_burnout_display()


func _update_header() -> void:
	var name = worker_info.get("name", "Worker")
	var desc = worker_info.get("description", "")
	
	if title_label:
		title_label.text = "Hired %s" % name
	
	if description_label:
		description_label.text = "[i]%s[/i]" % desc


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "%d gold" % current_gold


func _update_burnout_display() -> void:
	if not burnout_label:
		return
	
	var hire_count = worker_status.get("hire_count", 0)
	var reset_seconds = worker_status.get("burnout_reset_seconds", 0)
	
	if hire_count > 0:
		var reset_text = _format_duration(reset_seconds)
		burnout_label.text = "Hired %dx today - Prices +%d%% (resets in %s)" % [
			hire_count,
			int((pow(1.25, hire_count) - 1) * 100),
			reset_text
		]
		burnout_label.visible = true
	else:
		burnout_label.visible = false


func _refresh_tiers_display() -> void:
	"""Refresh the tier selection UI"""
	if not tiers_container:
		return
	
	# Clear existing
	for child in tiers_container.get_children():
		child.queue_free()
	
	var tiers = worker_info.get("tiers", [])
	var current_costs = worker_status.get("current_costs", [])
	
	for i in range(tiers.size()):
		var tier_info = tiers[i]
		var tier = tier_info.get("tier", i + 1)
		var base_cost = tier_info.get("base_cost", 0)
		var duration = tier_info.get("duration", 0)
		var rolls = tier_info.get("rolls", 0)
		
		# Use current cost (with burnout) if available
		var cost = base_cost
		if i < current_costs.size():
			cost = current_costs[i]
		
		var tier_panel = _create_tier_panel(tier, cost, base_cost, duration, rolls)
		tiers_container.add_child(tier_panel)


func _create_tier_panel(tier: int, cost: int, base_cost: int, duration: int, rolls: int) -> PanelContainer:
	var panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(0, 50)
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add stylebox for tier color coding
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	style.border_color = _get_tier_color(tier)
	style.border_width_left = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel_container.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel_container.add_child(hbox)
	
	# Tier badge
	var tier_label = Label.new()
	tier_label.text = "T%d" % tier
	tier_label.add_theme_font_size_override("font_size", 16)
	tier_label.add_theme_color_override("font_color", _get_tier_color(tier))
	tier_label.custom_minimum_size = Vector2(36, 0)
	hbox.add_child(tier_label)
	
	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	# Duration and loot on same line
	var duration_label = Label.new()
	duration_label.text = "%s  |  ~%d items" % [_format_duration(duration), rolls]
	duration_label.add_theme_font_size_override("font_size", 13)
	duration_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	info_vbox.add_child(duration_label)
	
	# Cost display
	var cost_label = Label.new()
	if cost != base_cost:
		cost_label.text = "%d gold (was %d)" % [cost, base_cost]
		cost_label.add_theme_color_override("font_color", Color(1, 0.6, 0.4))  # Orange for inflated
	else:
		cost_label.text = "%d gold" % cost
		cost_label.add_theme_color_override("font_color", Color(1, 0.84, 0))  # Gold
	cost_label.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(cost_label)
	
	# Hire button
	var hire_btn = Button.new()
	hire_btn.text = "Hire"
	hire_btn.custom_minimum_size = Vector2(80, 36)
	hire_btn.disabled = current_gold < cost
	if hire_btn.disabled:
		hire_btn.tooltip_text = "Not enough gold"
	hire_btn.pressed.connect(_on_hire_pressed.bind(tier, cost))
	hbox.add_child(hire_btn)
	
	return panel_container


func _refresh_jobs_display() -> void:
	"""Refresh the active/completed jobs list"""
	if not jobs_container:
		return
	
	# Clear existing
	for child in jobs_container.get_children():
		child.queue_free()
	
	var active_jobs = worker_status.get("active_jobs", [])
	var completed_jobs = worker_status.get("completed_jobs", [])
	
	# Show collection banner if there are completed jobs
	if completed_jobs.size() > 0:
		var banner = _create_collection_banner(completed_jobs.size())
		jobs_container.add_child(banner)
	
	# Show completed jobs first (with collect button)
	for job in completed_jobs:
		var job_panel = _create_job_panel(job, true)
		jobs_container.add_child(job_panel)
	
	# Show active jobs (with countdown)
	for job in active_jobs:
		var job_panel = _create_job_panel(job, false)
		jobs_container.add_child(job_panel)
	
	# Show message if no jobs
	if active_jobs.is_empty() and completed_jobs.is_empty():
		var label = Label.new()
		label.text = "No active jobs. Hire a worker above!"
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		jobs_container.add_child(label)


func _create_collection_banner(count: int) -> PanelContainer:
	"""Create a prominent banner for collecting completed jobs"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 50)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.5, 0.15, 0.95)
	style.border_color = Color(0.3, 0.8, 0.3)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)
	
	var label = Label.new()
	label.text = "%d job%s ready to collect!" % [count, "s" if count > 1 else ""]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	var collect_btn = Button.new()
	collect_btn.text = "Collect All"
	collect_btn.custom_minimum_size = Vector2(110, 36)
	collect_btn.pressed.connect(_on_collect_pressed)
	hbox.add_child(collect_btn)
	
	return panel


func _create_job_panel(job: Dictionary, completed: bool) -> PanelContainer:
	var panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(0, 44)
	panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var tier = job.get("tier", 1)
	var remaining = job.get("remaining", 0)
	
	# Add stylebox
	var style = StyleBoxFlat.new()
	if completed:
		style.bg_color = Color(0.15, 0.35, 0.15, 0.8)
		style.border_color = Color(0.3, 0.7, 0.3)
	else:
		style.bg_color = Color(0.12, 0.12, 0.18, 0.8)
		style.border_color = _get_tier_color(tier).darkened(0.3)
	style.border_width_left = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel_container.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel_container.add_child(hbox)
	
	# Tier badge
	var tier_label = Label.new()
	tier_label.text = "T%d" % tier
	tier_label.add_theme_font_size_override("font_size", 14)
	tier_label.add_theme_color_override("font_color", _get_tier_color(tier))
	tier_label.custom_minimum_size = Vector2(32, 0)
	hbox.add_child(tier_label)
	
	# Status
	var status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 13)
	
	if completed:
		status_label.text = "Ready to collect!"
		status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		status_label.text = "%s remaining" % _format_duration(remaining)
		status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		status_label.name = "StatusLabel"  # For timer updates
	
	hbox.add_child(status_label)
	
	# Collect button (only for completed)
	if completed:
		var collect_btn = Button.new()
		collect_btn.text = "Collect"
		collect_btn.custom_minimum_size = Vector2(80, 32)
		collect_btn.pressed.connect(_on_collect_pressed)
		hbox.add_child(collect_btn)
	
	return panel_container


func _update_job_timers() -> void:
	"""Update countdown timers every second"""
	if not visible or not jobs_container:
		return
	
	# Decrement remaining time for active jobs
	var active_jobs = worker_status.get("active_jobs", [])
	var needs_refresh = false
	
	for job in active_jobs:
		var remaining = job.get("remaining", 0)
		if remaining > 0:
			job["remaining"] = remaining - 1
			if remaining - 1 <= 0:
				needs_refresh = true  # Job just completed
	
	# Update UI labels
	var idx = 0
	for child in jobs_container.get_children():
		if child is PanelContainer:
			var status_label = child.find_child("StatusLabel", true, false)
			if status_label and idx < active_jobs.size():
				var remaining = active_jobs[idx].get("remaining", 0)
				status_label.text = "%s remaining" % _format_duration(remaining)
				idx += 1
	
	# Refresh if any job completed
	if needs_refresh:
		# Request fresh status from server
		InstanceClient.current.request_data(&"worker.status", _on_status_received, {"worker_type": worker_type})
	
	# Update burnout timer
	var reset_seconds = worker_status.get("burnout_reset_seconds", 0)
	if reset_seconds > 0:
		worker_status["burnout_reset_seconds"] = reset_seconds - 1
		_update_burnout_display()


func _on_hire_pressed(tier: int, cost: int) -> void:
	"""Handle hire button press"""
	if current_gold < cost:
		_show_notification("Not enough gold!", "Error")
		return
	
	InstanceClient.current.request_data(&"worker.hire", _on_hire_response, {
		"worker_type": worker_type,
		"tier": tier
	})


func _on_hire_response(data: Dictionary) -> void:
	if data.has("error"):
		_show_notification(data.error, "Hire Failed")
		return
	
	var tier = data.get("tier", 1)
	var cost = data.get("cost", 0)
	var duration = data.get("duration_seconds", 0)
	
	_show_notification(
		"Hired T%d worker for %d gold. Returns in %s!" % [tier, cost, _format_duration(duration)],
		"Worker Hired"
	)


func _on_collect_pressed() -> void:
	"""Handle collect button press"""
	InstanceClient.current.request_data(&"worker.collect", _on_collect_response, {
		"worker_type": worker_type,
		"job_index": -1  # Collect all
	})


func _on_collect_response(data: Dictionary) -> void:
	if data.has("error"):
		_show_notification(data.error, "Collection Failed")
		return
	
	var items = data.get("items", [])
	var warning = data.get("warning", "")
	
	# Build items summary
	var summary = ""
	for item_data in items:
		if summary != "":
			summary += ", "
		summary += "%dx %s" % [item_data.get("quantity", 0), item_data.get("name", "?")]
	
	if summary.length() > 100:
		summary = summary.substr(0, 100) + "..."
	
	var title = "Loot Collected!"
	if warning != "":
		title = "Partial Collection"
		summary += "\n" + warning
	
	_show_notification(summary, title)


func _on_close_button_pressed() -> void:
	visible = false
	worker_type = ""
	worker_info = {}
	worker_status = {}


func _format_duration(seconds: int) -> String:
	"""Format seconds into readable duration"""
	if seconds < 60:
		return "%ds" % seconds
	elif seconds < 3600:
		var mins = seconds / 60
		var secs = seconds % 60
		if secs > 0:
			return "%dm %ds" % [mins, secs]
		return "%dm" % mins
	else:
		var hours = seconds / 3600
		var mins = (seconds % 3600) / 60
		if mins > 0:
			return "%dh %dm" % [hours, mins]
		return "%dh" % hours


func _get_tier_color(tier: int) -> Color:
	match tier:
		1: return Color(0.7, 0.7, 0.7)  # Gray
		2: return Color(0.4, 0.8, 0.4)  # Green
		3: return Color(0.4, 0.6, 1.0)  # Blue
		4: return Color(0.8, 0.4, 1.0)  # Purple
		5: return Color(1.0, 0.6, 0.2)  # Orange
		6: return Color(1.0, 0.84, 0.0)  # Gold
		_: return Color.WHITE


func _show_notification(message: String, title: String) -> void:
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message, title)


func _gui_input(event: InputEvent) -> void:
	"""Block scroll events from reaching the camera"""
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()

