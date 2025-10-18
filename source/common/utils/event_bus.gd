extends Node

## Global event bus for decoupled communication across the game
## Allows systems to communicate without direct references

## Emitted when the user changes their language preference
## Systems should listen to this to refresh their UI text
signal language_changed()

## Emitted when settings are updated
signal settings_updated(setting_name: String, new_value: Variant)

## Emitted when a new character is created (for first-time guide)
signal character_created()

## Flag to track if a character was just created (persists across scene changes)
var just_created_character: bool = false

## Add more global signals as needed for cross-system communication
