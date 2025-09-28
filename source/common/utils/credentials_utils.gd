extends RefCounted


const HANDLE_MIN_LEN: int = 3
const HANDLE_MAX_LEN: int = 20
const HANDLE_RESERVED: PackedStringArray = ["admin", "moderator", "guest", "system"]

const PASSWORD_MIN_LEN: int = 6
const PASSWORD_MAX_LEN: int = 32

enum PasswordStrength {
	WEAK,
	FAIR,
	GOOD,
	STRONG
}

enum HandleError {
	OK,
	EMPTY,
	TOO_SHORT,
	TOO_LONG,
	INVALID_CHARS,
	RESERVED,
	ALREADY_EXISTS
}

enum UsernameError {
	OK,
	EMPTY,
	TOO_SHORT,
	TOO_LONG,
	INVALID_CHARS,
	RESERVED,
}


static func is_valid_handle(handle: String) -> bool:
	if handle.is_empty():
		return false
	return true


static func validate_handle(handle: String) -> Dictionary:
	if handle.is_empty():
		return _fail_handle(HandleError.EMPTY, "Player handle required.")
	if handle.length() < HANDLE_MIN_LEN:
		return _fail_handle(HandleError.TOO_SHORT, "Min %d characters." % HANDLE_MIN_LEN)
	if handle.length() > HANDLE_MAX_LEN:
		return _fail_handle(HandleError.TOO_LONG, "Max %d characters." % HANDLE_MAX_LEN)
	if not handle.is_valid_ascii_identifier():
		return _fail_handle(HandleError.INVALID_CHARS, "Use letters, digits, underscore.")
	if HANDLE_RESERVED.has(handle.to_lower()):
		return _fail_handle(HandleError.RESERVED, "This handle is reserved.")
	return {"code": HandleError.OK, "message": ""}


# Keep validate_username for backward compatibility if needed
static func validate_username(username: String) -> Dictionary:
	if username.is_empty():
		return _fail_username(UsernameError.EMPTY, "Username required.")
	if username.length() < HANDLE_MIN_LEN:
		return _fail_username(UsernameError.TOO_SHORT, "Min %d characters." % HANDLE_MIN_LEN)
	if username.length() > HANDLE_MAX_LEN:
		return _fail_username(UsernameError.TOO_LONG, "Max %d characters." % HANDLE_MAX_LEN)
	if not username.is_valid_ascii_identifier():
		return _fail_username(UsernameError.INVALID_CHARS, "Use letters, digits, underscore.")
	if HANDLE_RESERVED.has(username.to_lower()):
		return _fail_username(UsernameError.RESERVED, "This name is reserved.")
	return {"code": UsernameError.OK, "message": ""}


static func validate_password(password: String) -> Dictionary:
	if password.is_empty():
		return _fail_username(UsernameError.EMPTY, "Password required.")
	if password.length() < PASSWORD_MIN_LEN:
		return _fail_username(UsernameError.TOO_SHORT, "Min %d characters." % PASSWORD_MIN_LEN)
	if password.length() > PASSWORD_MAX_LEN:
		return _fail_username(UsernameError.TOO_LONG, "Max %d characters." % PASSWORD_MAX_LEN)
	if not password.is_valid_ascii_identifier():
		return _fail_username(UsernameError.INVALID_CHARS, "Use letters, digits, underscore.")
	return {"code": UsernameError.OK, "message": ""}


static func _fail_handle(code: HandleError, message: String) -> Dictionary:
	return {"code": code, "message": message}

static func _fail_username(code: UsernameError, message: String) -> Dictionary:
	return {"code": code, "message": message}


static func calculate_password_strength(password: String) -> Dictionary:
	if password.is_empty():
		return {"strength": PasswordStrength.WEAK, "score": 0, "message": "Password required"}
	
	var score: int = 0
	var message: String = ""
	
	# Length scoring
	if password.length() >= 6:
		score += 1
	if password.length() >= 8:
		score += 1
	if password.length() >= 12:
		score += 1
	
	# Character variety scoring
	var has_lower: bool = false
	var has_upper: bool = false
	var has_digit: bool = false
	var has_special: bool = false
	
	for char in password:
		if char >= 'a' and char <= 'z':
			has_lower = true
		elif char >= 'A' and char <= 'Z':
			has_upper = true
		elif char >= '0' and char <= '9':
			has_digit = true
		else:
			has_special = true
	
	if has_lower:
		score += 1
	if has_upper:
		score += 1
	if has_digit:
		score += 1
	if has_special:
		score += 1
	
	# Pattern detection (penalties)
	var has_repeated: bool = false
	for i in range(password.length() - 1):
		if password[i] == password[i + 1]:
			has_repeated = true
			break
	
	if has_repeated:
		score -= 1
	
	# Common password detection (basic)
	var common_passwords: PackedStringArray = ["password", "123456", "qwerty", "abc123", "password123"]
	if common_passwords.has(password.to_lower()):
		score = 0
	
	# Determine strength level
	var strength: PasswordStrength
	if score <= 2:
		strength = PasswordStrength.WEAK
		message = "Too weak. Add more characters and variety."
	elif score <= 4:
		strength = PasswordStrength.FAIR
		message = "Fair strength. Consider adding more variety."
	elif score <= 6:
		strength = PasswordStrength.GOOD
		message = "Good strength!"
	else:
		strength = PasswordStrength.STRONG
		message = "Excellent strength!"
	
	return {
		"strength": strength,
		"score": score,
		"message": message,
		"has_lower": has_lower,
		"has_upper": has_upper,
		"has_digit": has_digit,
		"has_special": has_special
	}
