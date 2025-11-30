@tool
extends HBoxContainer
class_name IconLabel
## IconLabel - A reusable component that displays an icon with text.
## Uses the UIIcons system for icon lookup.


# =============================================================================
# SIGNALS
# =============================================================================

signal pressed


# =============================================================================
# EXPORTS
# =============================================================================

@export_group("Icon")
## Icon key from UIIcons registry
@export var icon_key: String = "":
	set(value):
		icon_key = value
		_update_icon()

## Icon size
@export var icon_size: Vector2 = Vector2(16, 16):
	set(value):
		icon_size = value
		_update_icon()

## Icon color modulation
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		_update_icon()

@export_group("Text")
## Label text
@export var text: String = "":
	set(value):
		text = value
		_update_text()

## Text color
@export var text_color: Color = Color.WHITE:
	set(value):
		text_color = value
		_update_text()

## Font size (0 = use theme default)
@export var font_size: int = 0:
	set(value):
		font_size = value
		_update_text()

@export_group("Layout")
## Spacing between icon and text
@export var spacing: int = 4:
	set(value):
		spacing = value
		add_theme_constant_override("separation", spacing)

## Icon position (before or after text)
@export var icon_after_text: bool = false:
	set(value):
		icon_after_text = value
		_update_order()

## Vertical alignment
@export_enum("Top", "Center", "Bottom") var vertical_align: int = 1:
	set(value):
		vertical_align = value
		_update_alignment()


# =============================================================================
# INTERNAL NODES
# =============================================================================

var _icon_rect: TextureRect
var _label: Label


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_nodes()
	_update_icon()
	_update_text()
	_update_order()
	_update_alignment()
	add_theme_constant_override("separation", spacing)


func _setup_nodes() -> void:
	# Create icon TextureRect
	_icon_rect = TextureRect.new()
	_icon_rect.name = "Icon"
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	
	# Create Label
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


# =============================================================================
# UPDATE METHODS
# =============================================================================

func _update_icon() -> void:
	if not _icon_rect:
		return
	
	_icon_rect.custom_minimum_size = icon_size
	_icon_rect.modulate = icon_color
	
	if icon_key.is_empty():
		_icon_rect.texture = null
		_icon_rect.visible = false
		return
	
	_icon_rect.visible = true
	
	# Get icon from UIIcons autoload
	if Engine.is_editor_hint():
		# In editor, try to load directly
		var path := _get_icon_path_direct(icon_key)
		if not path.is_empty() and ResourceLoader.exists(path):
			_icon_rect.texture = load(path)
	else:
		# At runtime, use the autoload
		if has_node("/root/UIIcons"):
			var ui_icons = get_node("/root/UIIcons")
			_icon_rect.texture = ui_icons.get_icon(icon_key)


func _update_text() -> void:
	if not _label:
		return
	
	_label.text = text
	_label.add_theme_color_override("font_color", text_color)
	
	if font_size > 0:
		_label.add_theme_font_size_override("font_size", font_size)
	else:
		_label.remove_theme_font_size_override("font_size")


func _update_order() -> void:
	if not _icon_rect or not _label:
		return
	
	if icon_after_text:
		move_child(_label, 0)
		move_child(_icon_rect, 1)
	else:
		move_child(_icon_rect, 0)
		move_child(_label, 1)


func _update_alignment() -> void:
	match vertical_align:
		0: # Top
			alignment = BoxContainer.ALIGNMENT_BEGIN
		1: # Center
			alignment = BoxContainer.ALIGNMENT_CENTER
		2: # Bottom
			alignment = BoxContainer.ALIGNMENT_END


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Set icon and text in one call
func set_content(p_icon_key: String, p_text: String) -> void:
	icon_key = p_icon_key
	text = p_text


## Set icon by key
func set_icon(p_icon_key: String) -> void:
	icon_key = p_icon_key


## Set text value
func set_text(p_text: String) -> void:
	text = p_text


## Set both colors
func set_colors(p_icon_color: Color, p_text_color: Color) -> void:
	icon_color = p_icon_color
	text_color = p_text_color


## Get the internal Label node
func get_label() -> Label:
	return _label


## Get the internal TextureRect node
func get_icon_rect() -> TextureRect:
	return _icon_rect


# =============================================================================
# STATIC HELPER - Direct path lookup for editor
# =============================================================================

func _get_icon_path_direct(key: String) -> String:
	# Simplified lookup for editor preview
	const ICON_BASE := "res://assets/Raven Fantasy Icons/Separated Files/32x32/"
	const ICONS := {
		"gold": "coroa.png",
		"checkmark": "fb1094.png",
		"check": "fb1094.png",
		"close": "fb1093.png",
		"x": "fb1093.png",
		"star": "fb130.png",
		"fire": "fb83.png",
		"lightning": "fb81.png",
		"timer": "fb1098.png",
		"trophy": "fb129.png",
		"potato": "fb1171.png",
		"horse": "fb1155.png",
		"hammer": "fb22.png",
		"shop": "fb44.png",
		"arrow_up": "fb1087.png",
		"arrow_down": "fb1088.png",
	}
	if ICONS.has(key):
		return ICON_BASE + ICONS[key]
	return ""

