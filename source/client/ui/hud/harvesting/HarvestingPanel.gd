extends Control


var node_path: String = ""
var count: int = 0
var multiplier: float = 1.0
var state: StringName = &""
var pool: float = 0.0
var earned_total: float = 0.0 # kept for potential future use, not displayed
var harvesting_total: int = 0
var next_progress: float = 0.0

var session_active: bool = false
var session_expires_at: float = 0.0
var session_stacks: int = 0
var session_total_bonus: float = 0.0

# New fields for class/level requirements
var tier: int = 1
var required_class: StringName = &""
var required_level: int = 1
var last_error: String = ""


func _ready() -> void:
    visible = false


func on_status(data: Dictionary) -> void:
    if data.is_empty():
        return
    node_path = String(data.get("node", node_path))
    count = int(data.get("count", count))
    multiplier = float(data.get("multiplier", multiplier))
    state = data.get("state", state)
    pool = float(data.get("pool", pool))
    earned_total = float(data.get("earned_total", earned_total))
    harvesting_total = int(data.get("projected_total_int", harvesting_total))
    next_progress = float(data.get("next_progress", next_progress))
    tier = int(data.get("tier", tier))
    required_class = data.get("required_class", required_class)
    required_level = int(data.get("required_level", required_level))
    _refresh()


func on_session(data: Dictionary) -> void:
    if data.is_empty():
        return
    visible = true
    session_active = true
    session_stacks = 1
    session_total_bonus = 0.0
    var window: float = float(data.get("window", 10.0))
    session_expires_at = Time.get_ticks_msec() / 1000.0 + window
    _refresh()


func on_hit(data: Dictionary) -> void:
    if data.is_empty():
        return
    session_active = true
    session_stacks = int(data.get("stack_index", session_stacks))
    session_total_bonus = float(data.get("total_bonus_pct", session_total_bonus))
    var time_left: float = float(data.get("time_left", 0.0))
    if time_left > 0.0:
        session_expires_at = Time.get_ticks_msec() / 1000.0 + time_left
    _refresh()


func on_end(data: Dictionary) -> void:
    session_active = false
    session_stacks = 0
    session_total_bonus = 0.0
    session_expires_at = 0.0
    _refresh()


func _process(_delta: float) -> void:
    if session_active and session_expires_at > 0.0:
        if (Time.get_ticks_msec() / 1000.0) >= session_expires_at:
            session_active = false
            session_stacks = 0
            session_total_bonus = 0.0
            session_expires_at = 0.0
            _refresh()


func reset() -> void:
    node_path = ""
    count = 0
    multiplier = 1.0
    state = &""
    pool = 0.0
    earned_total = 0.0
    harvesting_total = 0
    next_progress = 0.0
    session_active = false
    session_stacks = 0
    session_total_bonus = 0.0
    session_expires_at = 0.0
    tier = 1
    required_class = &""
    required_level = 1
    last_error = ""
    visible = false
    _refresh()


func show_error(error_data: Dictionary) -> void:
    """Display error message for failed harvest attempt"""
    var err: StringName = error_data.get("err", &"")
    match err:
        &"wrong_class":
            var req_class: String = String(error_data.get("required_class", ""))
            last_error = "Requires %s class" % req_class.capitalize()
        &"level_too_low":
            var req_level: int = int(error_data.get("required_level", 1))
            last_error = "Requires level %d" % req_level
        &"node_depleted":
            last_error = "Node is depleted"
        &"out_of_range":
            last_error = "Out of range"
        _:
            last_error = "Cannot harvest"
    visible = true
    _refresh()
    # Auto-hide error after 3 seconds
    await get_tree().create_timer(3.0).timeout
    if last_error != "":
        last_error = ""
        visible = false
        _refresh()


func _refresh() -> void:
    if not is_inside_tree():
        return
    
    var summary: String = ""
    
    # Show error message if present
    if last_error != "":
        summary = "[color=red]%s[/color]" % last_error
        visible = true
    # Only show when we have a node and are harvesting
    elif node_path != "":
        visible = true
        # Display tier badge
        if tier > 0:
            summary += "[Tier %d] " % tier
        # Display class requirement
        if not required_class.is_empty():
            summary += "%s " % String(required_class).capitalize()
        # Display level requirement
        if required_level > 1:
            summary += "(Lvl %d+)\n" % required_level
        else:
            summary += "\n"
        
        summary += "Players: %d  |  x%.1f\n" % [count, multiplier]
        # Show only the individual projected total (integer snapshot)
        summary += "Harvesting: %d\n" % harvesting_total
        summary += "State: %s\n" % String(state)
        if session_active:
            var tl: float = max(0.0, session_expires_at - (Time.get_ticks_msec() / 1000.0))
            summary += "Encourage: %d stacks  (%.0f%%)  %.1fs left" % [session_stacks, session_total_bonus * 100.0, tl]
        else:
            summary += "Encourage: inactive"
    else:
        visible = false
    
    var label: Label = get_node_or_null(^"Summary")
    if label:
        label.text = summary

