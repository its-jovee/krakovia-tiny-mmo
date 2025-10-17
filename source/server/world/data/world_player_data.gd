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
