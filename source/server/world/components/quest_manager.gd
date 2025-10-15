class_name QuestManager
extends Node
## Manages quest generation, tracking, and completion for all players


const QUESTS_PER_PLAYER: int = 5
const RESET_INTERVAL_SECONDS: int = 86400  # 24 hours
const GOLD_REWARD_MULTIPLIER: float = 1.2
const XP_REWARD_MULTIPLIER: float = 0.5

# Adventurer types and their preferred item pools
const ADVENTURER_TYPES: Dictionary = {
	"Knight": ["iron_sword", "steel_sword", "steel_chestplate", "iron_helmet", "iron_boots", "health_potion", "bandages"],
	"Archer": ["wooden_bow", "reinforced_bow", "arrows", "leather_chest", "feathers", "sinew", "raw_meat"],
	"Mage": ["health_potion", "fire_resistance_potion", "night_vision_potion", "herbs", "quartz_crystal", "amethyst", "sapphire", "obsidian", "lodestone"],
	"Alchemist": ["herbs", "mushrooms", "antidote", "greater_health_potion", "miracle_elixir", "sulfur", "saltpeter", "salt"],
	"Merchant": ["simple_jewelry", "ornate_jewelry", "fine_cloak", "storage_chest", "large_backpack", "explorer_pack", "leather_jacket"],
	"Lord": ["throne", "crown", "royal_garments", "royal_jewelry_set", "ornate_table", "fine_chair", "embroidered_tapestry", "decorative_statue"],
	"Blacksmith": ["iron_ore", "copper_ore", "gold_ore", "silver_ore", "iron_ingot", "copper_ingot", "coal", "forge_station", "workshop_tools"],
	"Builder": ["stone", "granite", "marble", "limestone", "wall_section", "bridge_section", "fortification_section", "construction_kit"],
	"Chef": ["hearty_stew", "honey_glazed_ham", "spiced_roast", "seasoned_meat", "luxury_pastries", "salt", "herbs", "raw_meat", "quality_honey"],
	"Priest": ["candle_set", "lantern", "health_potion", "bandages", "medical_kit", "memorial_plaque", "perfume", "soap"],
	"Farmer": ["wheat", "barley", "oats", "carrots", "onions", "cabbage", "apples", "berries", "agricultural_tools"],
	"Jeweler": ["diamond", "ruby", "emerald", "sapphire", "topaz", "gold_ore", "silver_ore", "simple_jewelry", "ornate_jewelry", "copper_ring"],
	"Carpenter": ["oak_wood", "pine_wood", "birch_wood", "maple_wood", "ironwood", "wooden_handle", "fine_chair", "ornate_table", "basic_tool_set"],
	"General": ["legendary_siege_engine", "fortification_section", "steel_sword", "masterwork_armor_set", "arrows", "reinforced_bow", "wall_section"],
	"Guild_Master": ["guild_hall_section", "forge_station", "alchemy_table", "tanning_rack", "ultimate_forge_core", "crafting_supplies", "premium_workshop_tools"],
	"Collector": ["trophy_mount", "champions_trophy", "grand_monument", "monument_base", "celestial_convergence", "essence_of_mastery", "display_cabinet"],
	"Tanner": ["leather_chest", "leather_grip", "leather_jacket", "tanning_rack", "sinew", "bone", "raw_hide"],
	"Innkeeper": ["blanket", "pillow", "soap", "candle_set", "lantern", "beer", "hearty_stew", "fine_chair", "ornate_table"]
}

# Player quest data structure:
# {
#   peer_id: {
#     "quests": [Quest, Quest, ...],
#     "last_reset_time": float,
#     "pinned_quest_id": int,
#     "stats": {
#       "total_completed": int,
#       "by_adventurer": {adventurer_type: count}
#     }
#   }
# }
var player_quest_data: Dictionary = {}
var next_quest_id: int = 1


func _ready() -> void:
	print("QuestManager initialized")


## Get or generate quests for a player
func get_quests_for_player(peer_id: int) -> Array:
	_ensure_player_data(peer_id)
	var data: Dictionary = player_quest_data[peer_id]
	
	# Check if reset is needed
	var current_time: float = Time.get_unix_time_from_system()
	if _should_reset_quests(data, current_time):
		_reset_player_quests(peer_id, current_time)
	
	# Convert quests to dict array for network transmission
	var quests_array: Array = []
	for quest in data["quests"]:
		if quest is Quest:
			quests_array.append(quest.to_dict())
	
	return quests_array


## Toggle pin status on a quest
func pin_quest(peer_id: int, quest_id: int) -> Dictionary:
	if not player_quest_data.has(peer_id):
		return {"error": "Player quest data not found"}
	
	var data: Dictionary = player_quest_data[peer_id]
	
	# Find the quest
	var found_quest: Quest = null
	for quest in data["quests"]:
		if quest is Quest and quest.quest_id == quest_id:
			found_quest = quest
			break
	
	if not found_quest:
		return {"error": "Quest not found"}
	
	# Check if this quest is already pinned
	var was_pinned: bool = found_quest.is_pinned
	
	# Unpin all quests first
	for quest in data["quests"]:
		if quest is Quest:
			quest.is_pinned = false
	
	# If the quest wasn't pinned, pin it now
	if not was_pinned:
		found_quest.is_pinned = true
		data["pinned_quest_id"] = quest_id
	else:
		# Quest was pinned, so we unpinned it
		data["pinned_quest_id"] = -1
	
	return {"success": true, "quest_id": quest_id, "pinned": found_quest.is_pinned}


## Complete a quest for a player
func complete_quest(peer_id: int, quest_id: int, instance: Node) -> Dictionary:
	if not player_quest_data.has(peer_id):
		return {"error": "Player quest data not found"}
	
	var data: Dictionary = player_quest_data[peer_id]
	
	# Find the quest
	var quest_to_complete: Quest = null
	var quest_index: int = -1
	for i in range(data["quests"].size()):
		var quest = data["quests"][i]
		if quest is Quest and quest.quest_id == quest_id:
			quest_to_complete = quest
			quest_index = i
			break
	
	if not quest_to_complete:
		return {"error": "Quest not found"}
	
	# Get player
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"error": "Player not found"}
	
	var player_res: PlayerResource = player.player_resource
	
	# Check if player has all required items
	for item_id in quest_to_complete.required_items.keys():
		var required_quantity: int = quest_to_complete.required_items[item_id]
		if not player_res.inventory.has(item_id):
			return {"error": "Missing required items"}
		var player_quantity: int = player_res.inventory[item_id].get("stack", 0)
		if player_quantity < required_quantity:
			return {"error": "Insufficient quantity of required items"}
	
	# Remove items from inventory
	for item_id in quest_to_complete.required_items.keys():
		var required_quantity: int = quest_to_complete.required_items[item_id]
		var item_entry: Dictionary = player_res.inventory[item_id]
		item_entry["stack"] -= required_quantity
		if item_entry["stack"] <= 0:
			player_res.inventory.erase(item_id)
	
	# Award gold
	player_res.golds += quest_to_complete.gold_reward
	
	# Award XP
	var xp_gained: int = quest_to_complete.xp_reward
	if player_res.level < PlayerResource.MAX_LEVEL:
		player_res.experience += xp_gained
		
		# Check for level-ups
		var leveled_up: bool = false
		while player_res.can_level_up():
			var old_level: int = player_res.level
			player_res.level_up()
			leveled_up = true
			print("Player %s leveled up from quest: %d -> %d" % [player_res.display_name, old_level, player_res.level])
		
		# Update energy max on level-up
		if leveled_up:
			var asc: AbilitySystemComponent = player.ability_system_component
			if asc:
				var new_energy_max: float = player_res.get_energy_max()
				asc.set_max_server(&"energy", new_energy_max, true)
				asc.set_value_server(&"energy", new_energy_max)
		
		# Notify client of exp gain
		instance.data_push.rpc_id(peer_id, &"exp.update", {
			"exp": player_res.experience,
			"level": player_res.level,
			"exp_required": player_res.get_exp_required(),
			"leveled_up": leveled_up
		})
	
	# Update statistics
	data["stats"]["total_completed"] += 1
	var adv_type: String = quest_to_complete.adventurer_type
	if not data["stats"]["by_adventurer"].has(adv_type):
		data["stats"]["by_adventurer"][adv_type] = 0
	data["stats"]["by_adventurer"][adv_type] += 1
	
	# Update player resource quest stats
	if not player_res.quest_stats.has("total_completed"):
		player_res.quest_stats["total_completed"] = 0
	if not player_res.quest_stats.has("by_adventurer"):
		player_res.quest_stats["by_adventurer"] = {}
	
	player_res.quest_stats["total_completed"] += 1
	if not player_res.quest_stats["by_adventurer"].has(adv_type):
		player_res.quest_stats["by_adventurer"][adv_type] = 0
	player_res.quest_stats["by_adventurer"][adv_type] += 1
	
	# Remove quest from list
	data["quests"].remove_at(quest_index)
	
	# Notify client
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_res.inventory)
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player_res.golds})
	
	return {
		"success": true,
		"gold_reward": quest_to_complete.gold_reward,
		"xp_reward": xp_gained,
		"adventurer_type": adv_type
	}


## Ensure player has quest data initialized
func _ensure_player_data(peer_id: int) -> void:
	if not player_quest_data.has(peer_id):
		player_quest_data[peer_id] = {
			"quests": [],
			"last_reset_time": 0.0,
			"pinned_quest_id": -1,
			"stats": {
				"total_completed": 0,
				"by_adventurer": {}
			}
		}


## Check if quests should be reset
func _should_reset_quests(data: Dictionary, current_time: float) -> bool:
	# Reset if no quests or time elapsed
	var quests: Array = data.get("quests", [])
	if quests.is_empty():
		return true
	
	var last_reset: float = data.get("last_reset_time", 0.0)
	return (current_time - last_reset) >= RESET_INTERVAL_SECONDS


## Reset and regenerate quests for a player
func _reset_player_quests(peer_id: int, current_time: float) -> void:
	var data: Dictionary = player_quest_data[peer_id]
	data["quests"].clear()
	data["last_reset_time"] = current_time
	data["pinned_quest_id"] = -1
	
	# Generate new quests
	for i in range(QUESTS_PER_PLAYER):
		var quest: Quest = _generate_quest()
		data["quests"].append(quest)
	
	print("Generated %d quests for peer %d" % [QUESTS_PER_PLAYER, peer_id])


## Generate a single random quest
func _generate_quest() -> Quest:
	# Pick random adventurer type
	var adventurer_keys: Array = ADVENTURER_TYPES.keys()
	var adventurer_type: String = adventurer_keys[randi() % adventurer_keys.size()]
	var item_pool: Array = ADVENTURER_TYPES[adventurer_type]
	
	# Determine number of items based on complexity
	# For now, random 1-3 items (will be enhanced with tier-based logic)
	var num_items: int = randi_range(1, 3)
	
	# Pick random items from pool
	var required_items: Dictionary = {}
	var total_value: int = 0
	
	for i in range(num_items):
		if item_pool.is_empty():
			break
		
		var item_slug: StringName = StringName(item_pool[randi() % item_pool.size()])
		var item_id: int = ContentRegistryHub.id_from_slug(&"items", item_slug)
		
		if item_id > 0:
			# Random quantity 1-5
			var quantity: int = randi_range(1, 5)
			required_items[item_id] = quantity
			
			# Calculate value for rewards
			var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
			if item:
				var item_value: int = _get_item_value(item)
				total_value += item_value * quantity
	
	# Calculate rewards
	var gold_reward: int = int(total_value * GOLD_REWARD_MULTIPLIER)
	var xp_reward: int = int(gold_reward * XP_REWARD_MULTIPLIER)
	
	# Ensure minimum rewards
	if gold_reward < 10:
		gold_reward = 10
	if xp_reward < 5:
		xp_reward = 5
	
	var quest: Quest = Quest.new(
		next_quest_id,
		adventurer_type,
		required_items,
		gold_reward,
		xp_reward
	)
	
	next_quest_id += 1
	
	return quest


## Get item value for reward calculation
func _get_item_value(item: Item) -> int:
	if item.minimum_price > 0:
		return item.minimum_price
	
	# Default pricing based on item tags
	if "ore" in item.tags:
		return 10
	elif "ingot" in item.tags:
		return 20
	elif "gem" in item.tags or "gemstone" in item.tags:
		return 50
	elif "weapon" in item.tags:
		return 100
	elif "armor" in item.tags:
		return 80
	elif "luxury" in item.tags:
		return 150
	elif "food" in item.tags:
		return 15
	elif "potion" in item.tags:
		return 25
	elif "material" in item.tags or "raw" in item.tags:
		return 5
	else:
		return 10  # Default value

