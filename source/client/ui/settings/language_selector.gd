extends OptionButton

## Language selector component for switching between available languages
## Automatically updates TranslationManager and refreshes UI

func _ready() -> void:
	# Clear any default items
	clear()
	
	# Add all available languages
	var languages := TranslationManager.get_available_languages()
	for lang_data in languages:
		add_item(lang_data["name"], lang_data["id"])
	
	# Set current selection to match saved language
	selected = TranslationManager.get_language()
	
	# Connect to selection change
	item_selected.connect(_on_language_selected)
	
	# Connect to language change events to update if changed elsewhere
	if EventBus:
		EventBus.language_changed.connect(_on_language_changed_externally)


func _on_language_selected(index: int) -> void:
	# Update the language through TranslationManager
	TranslationManager.set_language(index as TranslationManager.Language)


func _on_language_changed_externally() -> void:
	# Update selection if language was changed from another location
	selected = TranslationManager.get_language()
