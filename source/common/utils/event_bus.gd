extends Node

## Global event bus for decoupled communication across the game
## Allows systems to communicate without direct references

## Emitted when the user changes their language preference
## Systems should listen to this to refresh their UI text
signal language_changed()

## Emitted when settings are updated
signal settings_updated(setting_name: String, new_value: Variant)

## Add more global signals as needed for cross-system communication
