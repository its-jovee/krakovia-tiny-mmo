extends Control

## Translation System Test Scene
## Tests language switching and translation functionality

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var test_results: RichTextLabel = $VBoxContainer/ScrollContainer/TestResults
@onready var language_selector: OptionButton = $VBoxContainer/LanguageSelector
@onready var test_button: Button = $VBoxContainer/TestButton

var test_count := 0
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	status_label.text = "Translation System Test"
	
	# Setup language selector
	language_selector.clear()
	language_selector.add_item("English", TranslationManager.Language.EN)
	language_selector.add_item("Português (BR)", TranslationManager.Language.PT_BR)
	language_selector.selected = TranslationManager.get_language()
	language_selector.item_selected.connect(_on_language_selected)
	
	# Setup test button
	test_button.pressed.connect(_run_all_tests)
	
	# Connect to language changed event
	if EventBus:
		EventBus.language_changed.connect(_on_language_changed)
	
	# Run tests automatically
	await get_tree().create_timer(0.5).timeout
	_run_all_tests()


func _on_language_selected(index: int) -> void:
	TranslationManager.set_language(index as TranslationManager.Language)


func _on_language_changed() -> void:
	_log("[COLOR=yellow]Language changed event received![/COLOR]")
	_update_ui_text()


func _update_ui_text() -> void:
	test_button.text = TranslationServer.translate("ui_button_confirm")


func _run_all_tests() -> void:
	test_count = 0
	pass_count = 0
	fail_count = 0
	test_results.clear()
	
	_log("[COLOR=cyan][b]===== TRANSLATION SYSTEM TESTS =====[/b][/COLOR]\n")
	
	# Test 1: Translation Manager exists
	_test_translation_manager_exists()
	
	# Test 2: EventBus exists
	_test_event_bus_exists()
	
	# Test 3: Basic translation (English)
	_test_basic_translation_en()
	
	# Test 4: Basic translation (Portuguese)
	_test_basic_translation_pt()
	
	# Test 5: Error messages (English)
	_test_error_messages_en()
	
	# Test 6: Error messages (Portuguese)
	_test_error_messages_pt()
	
	# Test 7: Dynamic translation
	_test_dynamic_translation()
	
	# Test 8: Settings persistence
	_test_settings_persistence()
	
	# Test 9: Language switching
	_test_language_switching()
	
	# Test 10: Missing translation fallback
	_test_missing_translation()
	
	# Summary
	_log("\n[COLOR=cyan][b]===== TEST SUMMARY =====[/b][/COLOR]")
	_log("Total Tests: " + str(test_count))
	_log("[COLOR=green]Passed: " + str(pass_count) + "[/COLOR]")
	_log("[COLOR=red]Failed: " + str(fail_count) + "[/COLOR]")
	
	if fail_count == 0:
		_log("\n[COLOR=lime][b]✅ ALL TESTS PASSED! 🎉[/b][/COLOR]")
		status_label.text = "✅ All Tests Passed!"
		status_label.modulate = Color.GREEN
	else:
		_log("\n[COLOR=red][b]❌ SOME TESTS FAILED[/b][/COLOR]")
		status_label.text = "❌ " + str(fail_count) + " Test(s) Failed"
		status_label.modulate = Color.RED


func _test_translation_manager_exists() -> void:
	_log("\n[b]Test 1: TranslationManager Exists[/b]")
	var result := TranslationManager != null
	_assert(result, "TranslationManager should exist")


func _test_event_bus_exists() -> void:
	_log("\n[b]Test 2: EventBus Exists[/b]")
	var result := EventBus != null
	_assert(result, "EventBus should exist as autoload")


func _test_basic_translation_en() -> void:
	_log("\n[b]Test 3: Basic Translation (English)[/b]")
	TranslationManager.set_language(TranslationManager.Language.EN)
	var text := TranslationServer.translate("ui_button_confirm")
	_log("  Translation: '" + text + "'")
	_assert(text == "Confirm", "Should translate to 'Confirm' in English")


func _test_basic_translation_pt() -> void:
	_log("\n[b]Test 4: Basic Translation (Portuguese)[/b]")
	TranslationManager.set_language(TranslationManager.Language.PT_BR)
	var text := TranslationServer.translate("ui_button_confirm")
	_log("  Translation: '" + text + "'")
	_assert(text == "Confirmar", "Should translate to 'Confirmar' in Portuguese")


func _test_error_messages_en() -> void:
	_log("\n[b]Test 5: Error Messages (English)[/b]")
	TranslationManager.set_language(TranslationManager.Language.EN)
	
	# Debug: Check what locale is actually set
	_log("  Current locale: " + TranslationServer.get_locale())
	_log("  Loaded translations: " + str(TranslationServer.get_loaded_locales()))
	
	# Test direct translation of each part
	var title_test := TranslationServer.translate("error_login_invalid_credentials_title")
	var message_test := TranslationServer.translate("error_login_invalid_credentials_message")
	var suggestion_test := TranslationServer.translate("error_login_invalid_credentials_suggestion")
	_log("  Direct title test: '" + str(title_test) + "'")
	_log("  Direct message test: '" + str(message_test) + "'")
	_log("  Direct suggestion test: '" + str(suggestion_test) + "'")
	
	# Test with simple keys to see if it's a CSV structure issue
	var simple_title := TranslationServer.translate("test_title")
	var simple_message := TranslationServer.translate("test_message")
	var simple_suggestion := TranslationServer.translate("test_suggestion")
	_log("  SIMPLE title: '" + str(simple_title) + "'")
	_log("  SIMPLE message: '" + str(simple_message) + "'")
	_log("  SIMPLE suggestion: '" + str(simple_suggestion) + "'")
	
	var error := ErrorMessages.get_error_message("login_invalid_credentials")
	_log("  Via ErrorMessages - Title: '" + str(error["title"]) + "'")
	_log("  Via ErrorMessages - Message: '" + str(error["message"]) + "'")
	_log("  Via ErrorMessages - Suggestion: '" + str(error.get("suggestion", "N/A")) + "'")
	
	# Check if translations are loaded
	if error["title"] == "error_login_invalid_credentials_title":
		_log("  [COLOR=orange]⚠ WARNING: Translation files not loaded![/COLOR]")
		_log("  [COLOR=orange]→ Translations exist but TranslationServer can't find them[/COLOR]")
		_fail("Translation files exist but aren't being loaded by TranslationServer")
	else:
		_assert(error["title"] == "Login Failed", "Error title should be in English")
		_assert("Invalid" in error["message"] or "handle" in error["message"], "Error message should contain English text")


func _test_error_messages_pt() -> void:
	_log("\n[b]Test 6: Error Messages (Portuguese)[/b]")
	TranslationManager.set_language(TranslationManager.Language.PT_BR)
	
	# Debug: Check what locale is actually set
	_log("  Current locale: " + TranslationServer.get_locale())
	
	var error := ErrorMessages.get_error_message("login_invalid_credentials")
	_log("  Title: '" + str(error["title"]) + "'")
	_log("  Message: '" + str(error["message"]) + "'")
	_log("  Suggestion: '" + str(error.get("suggestion", "N/A")) + "'")
	
	# Check if translations are loaded
	if error["title"] == "error_login_invalid_credentials_title":
		_log("  [COLOR=orange]⚠ WARNING: Translation files not loaded![/COLOR]")
		_fail("Translation files exist but aren't being loaded by TranslationServer")
	else:
		_assert(error["title"] == "Falha no Login", "Error title should be in Portuguese")
		_assert("Identificador" in error["message"] or "senha" in error["message"], "Error message should contain Portuguese text")


func _test_dynamic_translation() -> void:
	_log("\n[b]Test 7: Dynamic Translation with Formatting[/b]")
	TranslationManager.set_language(TranslationManager.Language.EN)
	
	# Add a test key to CSV first, for now we'll test with existing keys
	var text := TranslationServer.translate("error_server_error_code_message")
	var formatted := text.format({"code": 404})
	_log("  Formatted: '" + formatted + "'")
	_assert("404" in formatted, "Should contain the formatted code")


func _test_settings_persistence() -> void:
	_log("\n[b]Test 8: Settings Persistence[/b]")
	
	# Save Portuguese preference
	TranslationManager.set_language(TranslationManager.Language.PT_BR)
	
	# Load settings
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	_log("  Settings file loaded: " + ("OK" if err == OK else "FAILED"))
	
	if err == OK:
		var saved_lang: int = config.get_value("localization", "language", -1)
		_log("  Saved language: " + str(saved_lang))
		_assert(saved_lang == TranslationManager.Language.PT_BR, "Should save PT_BR preference")
	else:
		_fail("Settings file should exist and be readable")


func _test_language_switching() -> void:
	_log("\n[b]Test 9: Language Switching[/b]")
	
	# Switch to English
	TranslationManager.set_language(TranslationManager.Language.EN)
	var en_text := TranslationServer.translate("ui_button_cancel")
	_log("  EN: '" + en_text + "'")
	
	# Switch to Portuguese
	TranslationManager.set_language(TranslationManager.Language.PT_BR)
	var pt_text := TranslationServer.translate("ui_button_cancel")
	_log("  PT: '" + pt_text + "'")
	
	_assert(en_text == "Cancel", "Should be 'Cancel' in English")
	_assert(pt_text == "Cancelar", "Should be 'Cancelar' in Portuguese")
	_assert(en_text != pt_text, "Translations should be different")


func _test_missing_translation() -> void:
	_log("\n[b]Test 10: Missing Translation Fallback[/b]")
	var text := TranslationServer.translate("nonexistent_key_12345")
	_log("  Result: '" + text + "'")
	_assert(text == "nonexistent_key_12345", "Should return the key itself when translation missing")


func _assert(condition: bool, message: String) -> void:
	test_count += 1
	if condition:
		pass_count += 1
		_log("  [COLOR=green]✓ PASS:[/COLOR] " + message)
	else:
		fail_count += 1
		_log("  [COLOR=red]✗ FAIL:[/COLOR] " + message)


func _fail(message: String) -> void:
	_assert(false, message)


func _log(message: String) -> void:
	test_results.append_text(message + "\n")
	print(message)
