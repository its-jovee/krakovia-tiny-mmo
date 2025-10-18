class_name TranslationManager
extends RefCounted

## Central translation and localization management system
## Handles language switching, persistence, and dynamic UI updates

enum Language {
	EN = 0,      ## English
	PT_BR = 1    ## Portuguese (Brazil)
}

## Current active language
static var current_language: Language = Language.EN

## Language locale mappings
const LOCALE_MAP: Dictionary = {
	Language.EN: "en",
	Language.PT_BR: "pt_BR"
}

## Language display names
const LANGUAGE_NAMES: Dictionary = {
	Language.EN: "English",
	Language.PT_BR: "Português (BR)"
}

## Settings file path
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "localization"
const LANGUAGE_KEY: String = "language"


## Set the active language and update TranslationServer
static func set_language(lang: Language) -> void:
	current_language = lang
	
	# Update Godot's TranslationServer
	var locale: String = LOCALE_MAP.get(lang, "en")
	TranslationServer.set_locale(locale)
	
	# Save preference
	save_language_preference(lang)
	
	# Emit signal for UI refresh (EventBus is an autoload)
	if EventBus:
		EventBus.language_changed.emit()
	
	print("[TranslationManager] Language changed to: ", LANGUAGE_NAMES.get(lang, "Unknown"))


## Get the current active language
static func get_language() -> Language:
	return current_language


## Get the current locale string (e.g., "en", "pt_BR")
static func get_current_locale() -> String:
	return LOCALE_MAP.get(current_language, "en")


## Get display name for a language
static func get_language_name(lang: Language) -> String:
	return LANGUAGE_NAMES.get(lang, "Unknown")


## Load saved language preference from settings file
static func load_saved_language() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	
	if err == OK:
		var saved_lang: int = config.get_value(SETTINGS_SECTION, LANGUAGE_KEY, Language.EN)
		# Validate the saved language
		if saved_lang >= 0 and saved_lang < Language.size():
			set_language(saved_lang as Language)
			print("[TranslationManager] Loaded saved language: ", LANGUAGE_NAMES.get(saved_lang, "Unknown"))
		else:
			print("[TranslationManager] Invalid saved language, using default: English")
			set_language(Language.EN)
	else:
		print("[TranslationManager] No saved language found, using default: English")
		set_language(Language.EN)


## Save language preference to settings file
static func save_language_preference(lang: Language) -> void:
	var config := ConfigFile.new()
	
	# Load existing settings if they exist
	config.load(SETTINGS_PATH)
	
	# Set language value
	config.set_value(SETTINGS_SECTION, LANGUAGE_KEY, lang as int)
	
	# Save to disk
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[TranslationManager] Failed to save language preference: " + str(err))


## Helper function for dynamic translations with formatting
## Usage: TranslationManager.tr_dynamic("minigame_winner", {"player": "João"})
static func tr_dynamic(key: String, args: Dictionary = {}) -> String:
	var text: String = TranslationServer.translate(key)
	if args.is_empty():
		return text
	return text.format(args)


## Helper function to translate with pluralization
## Usage: TranslationManager.tr_plural("item_count", 5)
static func tr_plural(key_base: String, count: int) -> String:
	var key: String = key_base + ("_single" if count == 1 else "_plural")
	return TranslationServer.translate(key).format({"count": count})


## Get all available languages as an array of dictionaries
## Returns: [{id: Language.EN, name: "English"}, ...]
static func get_available_languages() -> Array[Dictionary]:
	var languages: Array[Dictionary] = []
	for lang in Language.values():
		languages.append({
			"id": lang,
			"name": LANGUAGE_NAMES.get(lang, "Unknown"),
			"locale": LOCALE_MAP.get(lang, "en")
		})
	return languages


## Debug function to test translations
static func test_translation(key: String) -> void:
	print("[TranslationManager] Testing key: ", key)
	for lang in Language.values():
		set_language(lang)
		print("  ", LANGUAGE_NAMES.get(lang), ": ", TranslationServer.translate(key))
