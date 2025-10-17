class_name ErrorMessages
extends RefCounted

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

# Comprehensive error message mapping
const ERROR_MESSAGES: Dictionary = {
	# Handle Validation Errors
	"handle_empty": {
		"title": "Handle Required",
		"message": "Please enter a player handle.",
		"suggestion": "Choose a unique handle that represents you in the game."
	},
	"handle_too_short": {
		"title": "Handle Too Short",
		"message": "Handle must be at least 3 characters long.",
		"suggestion": "Try adding more characters to make it unique."
	},
	"handle_too_long": {
		"title": "Handle Too Long",
		"message": "Handle must be no more than 20 characters long.",
		"suggestion": "Try shortening your handle while keeping it memorable."
	},
	"handle_invalid_chars": {
		"title": "Invalid Characters",
		"message": "Handle can only contain letters, numbers, and underscores.",
		"suggestion": "Remove special characters and spaces from your handle."
	},
	"handle_reserved": {
		"title": "Handle Reserved",
		"message": "This handle is reserved and cannot be used.",
		"suggestion": "Try a different handle that's available."
	},
	"handle_already_exists": {
		"title": "Handle Taken",
		"message": "This player handle is already taken.",
		"suggestion": "Try adding numbers or variations to make it unique."
	},
	
	# Password Validation Errors
	"password_empty": {
		"title": "Password Required",
		"message": "Please enter a password.",
		"suggestion": "Create a secure password to protect your account."
	},
	"password_too_short": {
		"title": "Password Too Short",
		"message": "Password must be at least 6 characters long.",
		"suggestion": "Add more characters to strengthen your password."
	},
	"password_too_long": {
		"title": "Password Too Long",
		"message": "Password must be no more than 32 characters long.",
		"suggestion": "Shorten your password while keeping it secure."
	},
	"password_invalid_chars": {
		"title": "Invalid Characters",
		"message": "Password can only contain letters, numbers, and underscores.",
		"suggestion": "Remove special characters and spaces from your password."
	},
	"password_weak": {
		"title": "Password Too Weak",
		"message": "Password is too weak and cannot be used.",
		"suggestion": "Use a mix of uppercase, lowercase, numbers, and special characters."
	},
	"password_match_failed": {
		"title": "Passwords Don't Match",
		"message": "The passwords you entered do not match.",
		"suggestion": "Make sure both password fields contain the same password."
	},
	
	# Authentication Errors
	"login_invalid_credentials": {
		"title": "Login Failed",
		"message": "Invalid handle or password. Please check your credentials.",
		"suggestion": "Make sure your handle and password are correct, or try creating a new account."
	},
	"login_already_connected": {
		"title": "Already Logged In",
		"message": "This account is already logged in elsewhere.",
		"suggestion": "Log out from other devices or wait a few minutes and try again."
	},
	"login_network_error": {
		"title": "Connection Failed",
		"message": "Unable to connect to the server.",
		"suggestion": "Check your internet connection and try again."
	},
	"login_timeout": {
		"title": "Login Timeout",
		"message": "Login request timed out.",
		"suggestion": "The server may be busy. Please try again in a moment."
	},
	
	# Network Errors
	"network_connection_failed": {
		"title": "Connection Failed",
		"message": "Unable to connect to the game server.",
		"suggestion": "Check your internet connection and ensure the game servers are online."
	},
	"network_timeout": {
		"title": "Request Timeout",
		"message": "The request took too long to complete.",
		"suggestion": "Try again in a moment. The server may be experiencing high traffic."
	},
	"network_server_unavailable": {
		"title": "Server Unavailable",
		"message": "The game server is currently unavailable.",
		"suggestion": "Please try again later or check the game status."
	},
	
	# Character Creation Errors
	"character_name_empty": {
		"title": "Character Name Required",
		"message": "Please enter a character name.",
		"suggestion": "Choose a unique name for your character."
	},
	"character_name_too_short": {
		"title": "Character Name Too Short",
		"message": "Character name must be at least 4 characters long.",
		"suggestion": "Try adding more characters to make it unique."
	},
	"character_name_too_long": {
		"title": "Character Name Too Long",
		"message": "Character name must be no more than 16 characters long.",
		"suggestion": "Try shortening your character name."
	},
	"character_invalid_class": {
		"title": "Invalid Character Class",
		"message": "Please select a valid character class.",
		"suggestion": "Choose from Miner, Forager, or Trapper."
	},
	"character_missing_data": {
		"title": "Incomplete Character Data",
		"message": "Character creation data is incomplete.",
		"suggestion": "Make sure to provide both name and class for your character."
	},
	"character_not_authenticated": {
		"title": "Not Authenticated",
		"message": "You must be logged in to create a character.",
		"suggestion": "Please log in first, then try creating your character."
	},
	"character_name_banned": {
		"title": "Inappropriate Name",
		"message": "This character name contains prohibited words or phrases.",
		"suggestion": "Please choose a different name that follows our community guidelines."
	},
	
	# Generic Server Errors
	"server_error_generic": {
		"title": "Server Error",
		"message": "An unexpected error occurred on the server.",
		"suggestion": "Please try again. If the problem persists, contact support."
	},
	"server_error_code": {
		"title": "Server Error",
		"message": "Server returned error code: {code}",
		"suggestion": "Please try again or contact support if the problem continues."
	}
}

# Error code mappings
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
	10: "character_name_banned"  # New: Banned/inappropriate name
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

# Get error message by key
static func get_error_message(error_key: String) -> Dictionary:
	if ERROR_MESSAGES.has(error_key):
		return ERROR_MESSAGES[error_key]
	return {
		"title": "Unknown Error",
		"message": "An unexpected error occurred.",
		"suggestion": "Please try again or contact support."
	}

# Get error message by server error code
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

# Get error message by validation error code
static func get_validation_error_message(error_code: int, error_type: String = "handle") -> Dictionary:
	var error_key = ""
	
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

# Format error message for display
static func format_error_message(error_data: Dictionary, show_suggestion: bool = true) -> String:
	var message = "[b]" + error_data["title"] + "[/b]\n\n" + error_data["message"]
	if show_suggestion and error_data.has("suggestion"):
		message += "\n\n[i]Tip:[/i] " + error_data["suggestion"]
	return message

# Get network error message
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
