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
    visible = false
    _refresh()


func _refresh() -> void:
    if not is_inside_tree():
        return
    # Only show when we have a node and are harvesting
    visible = node_path != ""
    var summary: String = ""
    summary += "Players: %d  |  x%.1f\n" % [count, multiplier]
    # Show only the individual projected total (integer snapshot)
    summary += "Harvesting: %d\n" % harvesting_total
    summary += "State: %s\n" % String(state)
    if session_active:
        var tl: float = max(0.0, session_expires_at - (Time.get_ticks_msec() / 1000.0))
        summary += "Encourage: %d stacks  (%.0f%%)  %.1fs left" % [session_stacks, session_total_bonus * 100.0, tl]
    else:
        summary += "Encourage: inactive"
    var label: Label = get_node_or_null(^"Summary")
    if label:
        label.text = summary

