class_name ErrorMessages
extends RefCounted

## Error message system with internationalization support
## Uses translation keys instead of hardcoded strings

# Preload required utilities
const CredentialsUtils = preload("res://source/common/utils/credentials_utils.gd")

# Error message categories
enum ErrorCategory {
	VALIDATION,
	NETWORK,
	SERVER,
	AUTHENTICATION,
	CHARACTER
}

# Error code mappings remain the same for server communication
const SERVER_ERROR_CODES: Dictionary = {
	# Account Creation Errors
	1: "handle_empty",
	2: "handle_too_short", 
	3: "handle_too_long",
	4: "password_empty",
	5: "password_too_short",
	6: "password_too_long",
	30: "handle_already_exists",
	
	# Login Errors
	50: "login_invalid_credentials",
	51: "login_already_connected",
	
	# Character Creation Errors
	7: "character_not_authenticated",
	8: "character_invalid_class",
	9: "character_missing_data",
	10: "character_name_banned"
}

# Character name error codes (reusing 1-3 for character creation context)
const CHARACTER_NAME_ERROR_CODES: Dictionary = {
	1: "character_name_empty",
	2: "character_name_too_short",
	3: "character_name_too_long",
	10: "character_name_banned"
}

# Validation error mappings - using string keys to avoid collisions
const VALIDATION_ERROR_CODES: Dictionary = {
	"handle_empty": "handle_empty",
	"handle_too_short": "handle_too_short",
	"handle_too_long": "handle_too_long",
	"handle_invalid_chars": "handle_invalid_chars",
	"handle_reserved": "handle_reserved",
	"handle_already_exists": "handle_already_exists",
	
	"password_empty": "password_empty",
	"password_too_short": "password_too_short",
	"password_too_long": "password_too_long",
	"password_invalid_chars": "password_invalid_chars"
}


## Get error message by key using translation system
static func get_error_message(error_key: String) -> Dictionary:
	# Build translation keys
	var title_key := "error_" + error_key + "_title"
	var message_key := "error_" + error_key + "_message"
	var suggestion_key := "error_" + error_key + "_suggestion"
	
	# Use TranslationServer for static context
	var title := TranslationServer.translate(title_key)
	var message := TranslationServer.translate(message_key)
	var suggestion := TranslationServer.translate(suggestion_key)
	
	# If translation failed (returns the key itself), use unknown error
	if title == title_key:
		return {
			"title": TranslationServer.translate("error_unknown_error_title"),
			"message": TranslationServer.translate("error_unknown_error_message"),
			"suggestion": TranslationServer.translate("error_unknown_error_suggestion")
		}
	
	return {
		"title": title,
		"message": message,
		"suggestion": suggestion
	}


## Get error message by server error code
static func get_server_error_message(error_code: int) -> Dictionary:
	# Check character name errors first (codes 1-3, 10)
	if CHARACTER_NAME_ERROR_CODES.has(error_code):
		var error_key = CHARACTER_NAME_ERROR_CODES[error_code]
		return get_error_message(error_key)
	
	if SERVER_ERROR_CODES.has(error_code):
		var error_key = SERVER_ERROR_CODES[error_code]
		var error_data = get_error_message(error_key)
		if error_key == "server_error_code":
			error_data["message"] = error_data["message"].format({"code": error_code})
		return error_data
	
	# Generic server error
	var error_data = get_error_message("server_error_code")
	error_data["message"] = error_data["message"].format({"code": error_code})
	return error_data


## Get error message by validation error code
static func get_validation_error_message(error_code: int, error_type: String = "handle") -> Dictionary:
	var error_key := ""
	
	# Map enum values to string keys
	if error_type == "handle":
		match error_code:
			CredentialsUtils.HandleError.EMPTY:
				error_key = "handle_empty"
			CredentialsUtils.HandleError.TOO_SHORT:
				error_key = "handle_too_short"
			CredentialsUtils.HandleError.TOO_LONG:
				error_key = "handle_too_long"
			CredentialsUtils.HandleError.INVALID_CHARS:
				error_key = "handle_invalid_chars"
			CredentialsUtils.HandleError.RESERVED:
				error_key = "handle_reserved"
			CredentialsUtils.HandleError.ALREADY_EXISTS:
				error_key = "handle_already_exists"
	elif error_type == "password":
		match error_code:
			CredentialsUtils.UsernameError.EMPTY:
				error_key = "password_empty"
			CredentialsUtils.UsernameError.TOO_SHORT:
				error_key = "password_too_short"
			CredentialsUtils.UsernameError.TOO_LONG:
				error_key = "password_too_long"
			CredentialsUtils.UsernameError.INVALID_CHARS:
				error_key = "password_invalid_chars"
	
	if error_key != "":
		return get_error_message(error_key)
	
	return get_error_message("server_error_generic")


## Format error message for display with BBCode formatting
static func format_error_message(error_data: Dictionary, show_suggestion: bool = true) -> String:
	var message: String = "[b]" + str(error_data["title"]) + "[/b]\n\n" + str(error_data["message"])
	if show_suggestion and error_data.has("suggestion") and error_data["suggestion"] != "":
		message += "\n\n[i]" + TranslationServer.translate("ui_tip") + "[/i] " + str(error_data["suggestion"])
	return message


## Get network error message by type
static func get_network_error_message(error_type: String = "connection_failed") -> Dictionary:
	match error_type:
		"connection_failed":
			return get_error_message("network_connection_failed")
		"timeout":
			return get_error_message("network_timeout")
		"server_unavailable":
			return get_error_message("network_server_unavailable")
		_:
			return get_error_message("network_connection_failed")
