class_name HorseRacingGame
extends Node

var session_id: int
var minigame_manager: MinigameManager

# Game state
var phase: String = "betting"  # "betting", "racing", "finished"
var participants: Dictionary = {}  # peer_id -> {horse_id, bet_amount, ready, instance, player_name}
var horse_odds: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}  # total bets per horse

# Race results
var race_winner: int = -1
var race_second: int = -1
var horse_positions: Dictionary = {}  # Current race positions for animation

# Timers
var betting_timer: Timer
var race_timer: Timer
var race_update_timer: Timer

# Constants
const MAX_PLAYERS: int = 12
const BETTING_DURATION: float = 60.0
const RACE_DURATION: float = 30.0
const RACE_UPDATE_INTERVAL: float = 0.1  # Update positions every 100ms
const NUM_HORSES: int = 5

# Horse names for flavor
const HORSE_NAMES: Array[String] = ["Thunder", "Lightning", "Storm", "Blaze", "Shadow"]


func _ready() -> void:
	# Setup betting timer
	betting_timer = Timer.new()
	betting_timer.wait_time = BETTING_DURATION
	betting_timer.one_shot = true
	betting_timer.timeout.connect(_on_betting_timer_timeout)
	add_child(betting_timer)
	betting_timer.start()
	
	# Setup state broadcast timer (every second during betting)
	var state_broadcast_timer = Timer.new()
	state_broadcast_timer.wait_time = 1.0
	state_broadcast_timer.one_shot = false
	state_broadcast_timer.timeout.connect(func():
		if phase == "betting":
			broadcast_state()
	)
	add_child(state_broadcast_timer)
	state_broadcast_timer.start()
	
	# Setup race timer
	race_timer = Timer.new()
	race_timer.wait_time = RACE_DURATION
	race_timer.one_shot = true
	race_timer.timeout.connect(_on_race_finished)
	add_child(race_timer)
	
	# Setup race update timer (for animation updates)
	race_update_timer = Timer.new()
	race_update_timer.wait_time = RACE_UPDATE_INTERVAL
	race_update_timer.one_shot = false
	race_update_timer.timeout.connect(_broadcast_race_positions)
	add_child(race_update_timer)
	
	print("[HorseRacing:%d] Game created, betting phase started" % session_id)


func join_game(peer_id: int, instance: ServerInstance, player_name: String) -> Dictionary:
	print("[HorseRacing:%d] Join request from peer %d (%s)" % [session_id, peer_id, player_name])
	
	if participants.size() >= MAX_PLAYERS:
		print("[HorseRacing:%d] Join failed - game is full" % session_id)
		return {"error": "Game is full"}
	
	if phase != "betting":
		print("[HorseRacing:%d] Join failed - phase is %s" % [session_id, phase])
		return {"error": "Game has already started"}
	
	if participants.has(peer_id):
		print("[HorseRacing:%d] Join failed - already joined" % session_id)
		return {"error": "Already joined"}
	
	participants[peer_id] = {
		"horse_id": -1,
		"bet_amount": 0,
		"ready": false,
		"instance": instance,
		"player_name": player_name
	}
	
	print("[HorseRacing:%d] Player %s joined successfully (total: %d)" % [session_id, player_name, participants.size()])
	
	# Send initial state to the joining player immediately
	var state_data = {
		"session_id": session_id,
		"phase": phase,
		"participants": _get_participant_summary(),
		"horse_odds": horse_odds,
		"time_left": betting_timer.time_left,
		"horse_names": HORSE_NAMES
	}
	instance.data_push.rpc_id(peer_id, &"minigame.state", state_data)
	
	# Broadcast to all other participants
	broadcast_state()
	
	minigame_manager.send_system_message("%s joined the Horse Racing game!" % player_name)
	
	return {"success": true, "session_id": session_id}


func place_bet(peer_id: int, horse_id: int, amount: int) -> Dictionary:
	if not participants.has(peer_id):
		return {"error": "Not in game"}
	
	if phase != "betting":
		return {"error": "Betting phase is over"}
	
	if horse_id < 0 or horse_id >= NUM_HORSES:
		return {"error": "Invalid horse"}
	
	if amount < 0:
		return {"error": "Invalid bet amount"}
	
	var participant = participants[peer_id]
	var instance: ServerInstance = participant["instance"]
	var player: Player = instance.get_player(peer_id)
	
	if not player:
		return {"error": "Player not found"}
	
	# Check if player has enough gold
	if player.player_resource.golds < amount:
		return {"error": "Not enough gold"}
	
	# Refund previous bet if changing
	if participant["bet_amount"] > 0:
		player.player_resource.golds += participant["bet_amount"]
		horse_odds[participant["horse_id"]] -= participant["bet_amount"]
	
	# Deduct new bet
	player.player_resource.golds -= amount
	
	# Update participant data
	participant["horse_id"] = horse_id
	participant["bet_amount"] = amount
	participant["ready"] = false  # Reset ready when bet changes
	
	# Update horse odds
	horse_odds[horse_id] += amount
	
	# Notify player of gold change
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player.player_resource.golds})
	
	broadcast_state()
	
	return {"success": true}


func set_ready(peer_id: int, ready: bool) -> Dictionary:
	if not participants.has(peer_id):
		return {"error": "Not in game"}
	
	if phase != "betting":
		return {"error": "Betting phase is over"}
	
	var participant = participants[peer_id]
	
	if participant["bet_amount"] <= 0:
		return {"error": "Must place a bet first"}
	
	participant["ready"] = ready
	
	broadcast_state()
	
	# Check if all players are ready
	if ready and _all_players_ready():
		_start_race_early()
	
	return {"success": true}


func leave_game(peer_id: int) -> Dictionary:
	if not participants.has(peer_id):
		return {"error": "Not in game"}
	
	var participant = participants[peer_id]
	var instance: ServerInstance = participant["instance"]
	var player: Player = instance.get_player(peer_id)
	
	# Only refund if still in betting phase and not ready
	if phase == "betting" and not participant["ready"] and player:
		if participant["bet_amount"] > 0:
			player.player_resource.golds += participant["bet_amount"]
			horse_odds[participant["horse_id"]] -= participant["bet_amount"]
			instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player.player_resource.golds})
	
	participants.erase(peer_id)
	
	broadcast_state()
	
	# If no players left, cancel game
	if participants.size() == 0:
		_cancel_game()
	
	return {"success": true}


func _all_players_ready() -> bool:
	for peer_id in participants:
		if not participants[peer_id]["ready"]:
			return false
	return participants.size() > 0


func _start_race_early() -> void:
	betting_timer.stop()
	_on_betting_timer_timeout()


func _on_betting_timer_timeout() -> void:
	if participants.size() == 0:
		_cancel_game()
		return
	
	# Count players who actually placed bets
	var players_with_bets = 0
	for peer_id in participants:
		if participants[peer_id]["bet_amount"] > 0:
			players_with_bets += 1
	
	# Need at least 1 player with a bet to continue
	if players_with_bets == 0:
		print("[HorseRacing:%d] No players placed bets, cancelling" % session_id)
		_cancel_game()
		return
	
	# Remove players who didn't bet (they can spectate)
	var to_remove: Array = []
	for peer_id in participants:
		if participants[peer_id]["bet_amount"] <= 0:
			to_remove.append(peer_id)
			print("[HorseRacing:%d] Removing peer %d - no bet placed" % [session_id, peer_id])
	
	for peer_id in to_remove:
		participants.erase(peer_id)
	
	print("[HorseRacing:%d] Starting race with %d betting players" % [session_id, participants.size()])
	start_race()


func start_race() -> void:
	phase = "racing"
	
	# Initialize random positions for each horse
	for horse_id in range(NUM_HORSES):
		horse_positions[horse_id] = {
			"position": 0.0,
			"speed": randf_range(0.8, 1.2),  # Random speed multiplier
			"finish_time": -1.0
		}
	
	broadcast_state()
	
	race_timer.start()
	race_update_timer.start()
	
	minigame_manager.send_system_message("🏁 The race has begun!")
	
	print("[HorseRacing:%d] Race started with %d participants" % [session_id, participants.size()])


func _broadcast_race_positions() -> void:
	if phase != "racing":
		return
	
	var elapsed: float = RACE_DURATION - race_timer.time_left
	var progress: float = elapsed / RACE_DURATION
	
	# Update horse positions
	for horse_id in horse_positions:
		var horse_data = horse_positions[horse_id]
		# Position is speed-modified progress
		horse_data["position"] = progress * horse_data["speed"]
		
		# Check if finished
		if horse_data["position"] >= 1.0 and horse_data["finish_time"] < 0:
			horse_data["finish_time"] = elapsed
	
	# Broadcast positions to participants
	var position_data = {}
	for horse_id in horse_positions:
		position_data[horse_id] = horse_positions[horse_id]["position"]
	
	_broadcast_to_participants(&"minigame.race_update", {
		"positions": position_data,
		"elapsed": elapsed,
		"duration": RACE_DURATION
	})


func _on_race_finished() -> void:
	race_update_timer.stop()
	phase = "finished"
	
	# Ensure all horses have finish times (some may not have reached 1.0)
	for horse_id in horse_positions:
		if horse_positions[horse_id]["finish_time"] < 0:
			horse_positions[horse_id]["finish_time"] = 999.0  # Didn't finish
	
	# Determine winners based on finish times (or final position if didn't finish)
	var finish_order: Array = []
	for horse_id in horse_positions:
		var finish_time = horse_positions[horse_id]["finish_time"]
		var final_position = horse_positions[horse_id]["position"]
		finish_order.append({
			"horse_id": horse_id,
			"finish_time": finish_time,
			"position": final_position
		})
	
	# Sort by finish time (lower is better), or by position if didn't finish
	finish_order.sort_custom(func(a, b): 
		if a["finish_time"] < 999.0 and b["finish_time"] < 999.0:
			return a["finish_time"] < b["finish_time"]
		elif a["finish_time"] < 999.0:
			return true  # a finished, b didn't
		elif b["finish_time"] < 999.0:
			return false  # b finished, a didn't
		else:
			return a["position"] > b["position"]  # Both didn't finish, use position
	)
	
	race_winner = finish_order[0]["horse_id"]
	race_second = finish_order[1]["horse_id"]
	
	print("[HorseRacing:%d] Race finished!" % session_id)
	print("  1st: %s (time: %.2f, pos: %.2f)" % [HORSE_NAMES[race_winner], finish_order[0]["finish_time"], finish_order[0]["position"]])
	print("  2nd: %s (time: %.2f, pos: %.2f)" % [HORSE_NAMES[race_second], finish_order[1]["finish_time"], finish_order[1]["position"]])
	
	# Calculate and distribute winnings
	calculate_winnings()
	
	# Cleanup after 10 seconds
	await get_tree().create_timer(10.0).timeout
	minigame_manager.remove_session(session_id)


func calculate_winnings() -> void:
	var total_pot: int = 0
	var winner_bets: Dictionary = {}
	var second_bets: Dictionary = {}
	var winner_total: int = 0
	var second_total: int = 0
	
	print("[HorseRacing:%d] Calculating winnings - Winner: %d, Second: %d" % [session_id, race_winner, race_second])
	
	# Categorize bets and calculate totals
	for peer_id in participants:
		var bet_data = participants[peer_id]
		var player_horse = bet_data["horse_id"]
		var bet_amount = bet_data["bet_amount"]
		total_pot += bet_amount
		
		print("  Player %s bet %d on horse %d (%s)" % [bet_data["player_name"], bet_amount, player_horse, HORSE_NAMES[player_horse]])
		
		if player_horse == race_winner:
			winner_bets[peer_id] = bet_amount
			winner_total += bet_amount
			print("    -> Winner bet!")
		elif player_horse == race_second:
			second_bets[peer_id] = bet_amount
			second_total += bet_amount
			print("    -> Second place bet!")
		else:
			print("    -> Lost")
	
	# Calculate prize pools (70% to 1st, 30% to 2nd)
	var first_prize_pool: int = int(total_pot * 0.7)
	var second_prize_pool: int = int(total_pot * 0.3)
	
	var results: Dictionary = {}
	
	# Distribute proportionally to first place winners
	if winner_total > 0:
		for peer_id in winner_bets:
			var bet_amount: int = winner_bets[peer_id]
			var proportion: float = float(bet_amount) / float(winner_total)
			var winnings: int = int(first_prize_pool * proportion)
			_award_winnings(peer_id, winnings, 1)
			results[peer_id] = {"place": 1, "winnings": winnings}
	
	# Distribute proportionally to second place winners
	if second_total > 0:
		for peer_id in second_bets:
			var bet_amount: int = second_bets[peer_id]
			var proportion: float = float(bet_amount) / float(second_total)
			var winnings: int = int(second_prize_pool * proportion)
			_award_winnings(peer_id, winnings, 2)
			results[peer_id] = {"place": 2, "winnings": winnings}
	
	# Mark losers
	for peer_id in participants:
		if not results.has(peer_id):
			results[peer_id] = {"place": 0, "winnings": 0}
	
	# Broadcast results
	_broadcast_to_participants(&"minigame.results", {
		"game_type": "horse_racing",
		"winner_horse": race_winner,
		"second_horse": race_second,
		"winner_name": HORSE_NAMES[race_winner],
		"second_name": HORSE_NAMES[race_second],
		"results": results,
		"total_pot": total_pot
	})
	
	# Send system message
	minigame_manager.send_system_message("🏆 %s wins the race! %s came in second!" % [HORSE_NAMES[race_winner], HORSE_NAMES[race_second]])


func _award_winnings(peer_id: int, amount: int, place: int) -> void:
	if not participants.has(peer_id):
		return
	
	var participant = participants[peer_id]
	var instance: ServerInstance = participant["instance"]
	var player: Player = instance.get_player(peer_id)
	
	if player:
		player.player_resource.golds += amount
		instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player.player_resource.golds})
		
		var place_text = "1st" if place == 1 else "2nd"
		instance.data_push.rpc_id(
			peer_id,
			&"chat.message",
			{"text": "🎉 You won %d gold for betting on %s place!" % [amount, place_text], "name": "System", "id": 1}
		)


func broadcast_state() -> void:
	var state_data = {
		"session_id": session_id,
		"phase": phase,
		"participants": _get_participant_summary(),
		"horse_odds": horse_odds,
		"time_left": betting_timer.time_left if phase == "betting" else 0.0,
		"horse_names": HORSE_NAMES
	}
	
	_broadcast_to_participants(&"minigame.state", state_data)


func _get_participant_summary() -> Array:
	var summary: Array = []
	for peer_id in participants:
		var p = participants[peer_id]
		summary.append({
			"peer_id": peer_id,
			"player_name": p["player_name"],
			"horse_id": p["horse_id"],
			"bet_amount": p["bet_amount"],
			"ready": p["ready"]
		})
	return summary


func _broadcast_to_participants(event: StringName, data: Dictionary) -> void:
	for peer_id in participants:
		var participant = participants[peer_id]
		var instance: ServerInstance = participant["instance"]
		instance.data_push.rpc_id(peer_id, event, data)


func _cancel_game() -> void:
	print("[HorseRacing:%d] Game cancelled - no participants" % session_id)
	minigame_manager.send_system_message("Horse Racing game cancelled - not enough players")
	minigame_manager.remove_session(session_id)

