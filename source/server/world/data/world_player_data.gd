class_name WorldPlayerData
extends Resource
# I can't recommend using Resources as a whole database, but for the demonstration,
# I found it interesting to use Godot exclusively to have a minimal setup.

## Used to store the different character IDs of registered accounts.[br][br]
## So if player with name ID "horizon" logs in to this world,
## we can retrieve its different character IDs thanks to this.[br][br]
## Here is how it should look like:
## [codeblock]
## print(accounts) # {"horizon": [6, 14], "another_guy": [2]}
## [/codeblock]
@export var accounts: Dictionary[String, PackedInt32Array]
@export var max_character_per_account: int = 3

@export var players: Dictionary[int, PlayerResource]
@export var next_player_id: int = 0

@export var admin_ids: PackedInt32Array
@export var user_roles: Dictionary[int, Array]

# Banned words for character names (lowercase for case-insensitive matching)
const BANNED_WORDS: Array[String] = [
	# Slurs and offensive terms
	"nigger", "nigga", "nig", "negro",
	"faggot", "fag", "dyke",
	"retard", "retarded",
	"cunt", "pussy", "dick", "cock", "penis", "vagina",
	"fuck", "shit", "ass", "bitch", "whore", "slut",
	"hitler", "nazi", "isis",
	"chink", "gook", "spic", "wetback", "beaner",
	"kike", "jew", "jews",
	"rape", "raping", "molest",
	"admin", "moderator", "gm", "gamemaster",
	"system", "server", "official",
	"rola", "pinto", "xereca", "cu",
	"macaco",
]
@export var guilds: Dictionary[String, Guild]

## Maps account_name to ban info
## Structure: {"account_name": {"reason": String, "until": int (unix timestamp), "banned_by": String}}
## until == 0 means permanent ban
@export var banned_players: Dictionary[String, Dictionary] = {}

## Maps account_name to mute info
## Structure: {"account_name": {"reason": String, "until": int (unix timestamp), "muted_by": String}}
## until == 0 means permanent mute
@export var muted_players: Dictionary[String, Dictionary] = {}


func get_player_resource(player_id: int) -> PlayerResource:
	if players.has(player_id):
		return players[player_id]
	return null


func create_player_character(handle: String, character_data: Dictionary) -> int:
	if (
		accounts.has(handle)
		and accounts[handle].size() > max_character_per_account
	):
		return -1
	
	# Validate character name
	var character_name: String = character_data.get("name", "")
	
	# Check if name is empty
	if character_name.is_empty():
		return 1
	
	# Check minimum length (4 characters)
	if character_name.length() < 4:
		return 2
	
	# Check maximum length (16 characters)
	if character_name.length() > 16:
		return 3
	
	# Check for banned words
	if _contains_banned_word(character_name):
		return 10
	
	next_player_id += 1
	var player_id: int = next_player_id
	var player_character := PlayerResource.new()
	
	# Temporary for fast test
	player_character.inventory = {}
	player_character.golds = 100
	player_character.available_attributes_points = 10
	
	player_character.init(
		player_id, handle,
		character_data["name"], character_data["class"]
	)
	players[player_id] = player_character
	if accounts.has(handle):
		accounts[handle].append(player_id)
	else:
		accounts[handle] = [player_id] as PackedInt32Array
	return player_id


func get_account_characters(handle: String) -> Dictionary:
	var data: Dictionary#[int, Dictionary]
	
	if accounts.has(handle):
		for player_id: int in accounts[handle]:
			var player_character := get_player_resource(player_id)
			if player_character:
				data[player_id] = {
					"name": player_character.display_name,
					"class": player_character.character_class,
					"level": player_character.level
				}
	return data


func create_guild(guild_name: String, player_id: int) -> bool:
	var player: PlayerResource = players.get(player_id)
	if not player or guilds.has(guild_name):
		return false
	var new_guild: Guild = Guild.new()
	new_guild.leader_id = player_id
	new_guild.guild_name = guild_name
	new_guild.add_member(player_id, "Leader")
	guilds[guild_name] = new_guild
	return true


## Check if an account is banned
func is_banned(account_name: String) -> bool:
	if not banned_players.has(account_name):
		return false
	var ban_info: Dictionary = banned_players[account_name]
	var until: int = ban_info.get("until", 0)
	# until == 0 means permanent
	if until == 0:
		return true
	# Check if ban has expired
	var now: int = int(Time.get_unix_time_from_system())
	if now >= until:
		banned_players.erase(account_name)
		return false
	return true


## Check if an account is muted
func is_muted(account_name: String) -> bool:
	if not muted_players.has(account_name):
		return false
	var mute_info: Dictionary = muted_players[account_name]
	var until: int = mute_info.get("until", 0)
	# until == 0 means permanent
	if until == 0:
		return true
	# Check if mute has expired
	var now: int = int(Time.get_unix_time_from_system())
	if now >= until:
		muted_players.erase(account_name)
		return false
	return true


## Add a ban for an account
func add_ban(account_name: String, reason: String, until: int, banned_by: String) -> void:
	banned_players[account_name] = {
		"reason": reason,
		"until": until,
		"banned_by": banned_by
	}


## Add a mute for an account
func add_mute(account_name: String, reason: String, until: int, muted_by: String) -> void:
	muted_players[account_name] = {
		"reason": reason,
		"until": until,
		"muted_by": muted_by
	}


## Remove a ban from an account
func remove_ban(account_name: String) -> bool:
	if banned_players.has(account_name):
		banned_players.erase(account_name)
		return true
	return false


## Remove a mute from an account
func remove_mute(account_name: String) -> bool:
	if muted_players.has(account_name):
		muted_players.erase(account_name)
		return true
	return false


func _contains_banned_word(name: String) -> bool:
	"""Check if character name contains any banned words (case-insensitive)"""
	var lowercase_name = name.to_lower()
	
	# Check for exact matches
	if lowercase_name in BANNED_WORDS:
		print("[WorldPlayerData] Banned word detected (exact): %s" % lowercase_name)
		return true
	
	# Check if name contains any banned word as substring
	for banned_word in BANNED_WORDS:
		if banned_word in lowercase_name:
			print("[WorldPlayerData] Banned word detected (substring): %s in %s" % [banned_word, lowercase_name])
			return true
	
	# Check for leet speak variations (basic patterns)
	var normalized_name = lowercase_name
	normalized_name = normalized_name.replace("0", "o")
	normalized_name = normalized_name.replace("1", "i")
	normalized_name = normalized_name.replace("3", "e")
	normalized_name = normalized_name.replace("4", "a")
	normalized_name = normalized_name.replace("5", "s")
	normalized_name = normalized_name.replace("7", "t")
	normalized_name = normalized_name.replace("8", "b")
	normalized_name = normalized_name.replace("@", "a")
	normalized_name = normalized_name.replace("$", "s")
	
	for banned_word in BANNED_WORDS:
		if banned_word in normalized_name:
			print("[WorldPlayerData] Banned word detected (leet speak): %s in %s (normalized from %s)" % [banned_word, normalized_name, lowercase_name])
			return true
	
	return false
