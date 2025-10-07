

## Shared keys (client + gateway)
const KEY_TOKEN_ID := "t-id"
const KEY_ACCOUNT_ID := "a-id"
const KEY_ACCOUNT_HANDLE := "a-h"
const KEY_WORLD_ID := "w-id"
const KEY_CHAR_ID := "c-id"


static func base_url() -> String:
	var url = "https://kraftovia.com"  # Or your config logic
	print("DEBUG: base_url is: ", url)  # ADD THIS LINE
	return url

static func get_endpoint(path: String) -> String:
	return "%s%s" % [base_url().rstrip("/"), path]


# Endpoints
static func login() -> String: return get_endpoint("/v1/login")
static func guest() -> String: return get_endpoint("/v1/guest")
static func worlds() -> String: return get_endpoint("/v1/worlds")
static func account_create() -> StringName:
		return get_endpoint(&"/v1/account/create")
static func world_characters() -> String: return get_endpoint("/v1/world/characters")
static func world_enter() -> String: return get_endpoint("/v1/world/enter")
static func world_create_char() -> String: return get_endpoint("/v1/world/character/create")
