extends Node

## Debug script to inspect translation files directly

func _ready() -> void:
	print("========== TRANSLATION DEBUG ==========")
	
	# Load translation files
	var en_trans := load("res://localization/translations.en.translation") as Translation
	var pt_trans := load("res://localization/translations.pt_BR.translation") as Translation
	
	if en_trans:
		print("\n✅ English translation loaded")
		print("Locale: ", en_trans.locale)
		
		# Test individual keys
		var keys_to_test := [
			"error_login_invalid_credentials_title",
			"error_login_invalid_credentials_message",
			"error_login_invalid_credentials_suggestion",
			"ui_button_confirm",
			"ui_button_cancel"
		]
		
		for key in keys_to_test:
			var value := en_trans.get_message(key)
			print("  ", key, " => '", value, "'")
	else:
		print("❌ English translation NOT loaded")
	
	if pt_trans:
		print("\n✅ Portuguese translation loaded")
		print("Locale: ", pt_trans.locale)
		
		# Test a few keys
		print("  error_login_invalid_credentials_title => '", pt_trans.get_message("error_login_invalid_credentials_title"), "'")
		print("  error_login_invalid_credentials_message => '", pt_trans.get_message("error_login_invalid_credentials_message"), "'")
	else:
		print("❌ Portuguese translation NOT loaded")
	
	print("\n========================================")
	get_tree().quit()
