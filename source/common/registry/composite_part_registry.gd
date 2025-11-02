class_name CompositePartRegistry
extends Node
## Registry for composite character sprite parts (base, hair, head, accessory)
## Organizes parts by class to ensure animation compatibility

# Layer types
enum Layer {
	BASE,
	HAIR,
	HEAD,  # Changed from FACE - matches sprite organization
	ACCESSORY
}

# Static registry of available parts per class
# Structure: {class_name: {layer: [part_ids]}}
static var _parts_catalog: Dictionary = {}
static var _initialized: bool = false


static func _initialize() -> void:
	if _initialized:
		return
	
	_parts_catalog = {
		"miner": {
			Layer.BASE: ["default"],
			Layer.HAIR: [],  # Disabled initially
			Layer.HEAD: ["head_a", "head_b", "head_c", "head_d"],  # Head options
			Layer.ACCESSORY: []  # Disabled initially
		},
		"forager": {
			Layer.BASE: ["default"],
			Layer.HAIR: [],
			Layer.HEAD: ["head_a", "head_b", "head_c", "head_d"],
			Layer.ACCESSORY: []
		},
		"trapper": {
			Layer.BASE: ["default"],
			Layer.HAIR: [],
			Layer.HEAD: ["head_a", "head_b", "head_c", "head_d"],
			Layer.ACCESSORY: []
		}
	}
	
	_initialized = true


## Get available part IDs for a specific class and layer
static func get_parts_for_class(char_class: String, layer: Layer) -> Array[String]:
	if not _initialized:
		_initialize()
	
	if not _parts_catalog.has(char_class):
		push_error("CompositePartRegistry: Unknown class '%s'" % char_class)
		return []
	
	var class_parts: Dictionary = _parts_catalog[char_class]
	if not class_parts.has(layer):
		return []
	
	var parts: Array = class_parts[layer]
	var result: Array[String] = []
	result.assign(parts)
	return result


## Check if a part ID is valid for a given class and layer
static func is_valid_part(char_class: String, layer: Layer, part_id: String) -> bool:
	var available: Array[String] = get_parts_for_class(char_class, layer)
	return part_id in available or part_id == "none"


## Get the texture path for a static layer (accessory only - head is now animated)
static func get_static_texture_path(char_class: String, layer: Layer, part_id: String) -> String:
	if part_id == "none" or part_id.is_empty():
		return ""
	
	var layer_name: String = ""
	match layer:
		Layer.ACCESSORY:
			layer_name = "accessory"
		_:
			push_error("CompositePartRegistry: get_static_texture_path called for non-static layer (head is now animated)")
			return ""
	
	return "res://assets/sprites/characters/composite/%s/%s/%s.png" % [char_class, layer_name, part_id]


## Get the SpriteFrames path for an animated layer (base, head, hair)
## Path structure: composite/{class}/{layer}/{part_id}.tres
static func get_animated_spriteframes_path(char_class: String, layer: Layer, part_id: String) -> String:
	if part_id == "none" or part_id.is_empty():
		return ""
	
	var layer_name: String = ""
	match layer:
		Layer.BASE:
			layer_name = "base"
			# Base uses class name as filename: composite/miner/base/miner.tres
			return "res://source/common/gameplay/characters/sprite_frames/composite/%s/%s/%s.tres" % [char_class, layer_name, char_class]
		Layer.HEAD:
			layer_name = "head"
		Layer.HAIR:
			layer_name = "hair"
		_:
			push_error("CompositePartRegistry: get_animated_spriteframes_path called for non-animated layer")
			return ""
	
	# Head and Hair use: composite/{class}/{layer}/{part_id}.tres
	return "res://source/common/gameplay/characters/sprite_frames/composite/%s/%s/%s.tres" % [char_class, layer_name, part_id]


## Get head count for a class (for UI navigation)
static func get_head_count(char_class: String) -> int:
	return get_parts_for_class(char_class, Layer.HEAD).size()

