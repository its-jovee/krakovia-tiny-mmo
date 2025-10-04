class_name CraftingRecipe
extends Resource


## Recipe identification
@export var slug: StringName = &""
@export var recipe_name: StringName = &"RecipeDefault"
@export var recipe_icon: CompressedTexture2D
@export_multiline var description: String

## Class & Level Requirements
@export_enum("miner", "forager", "trapper", "blacksmith", "culinarian", "artisan") 
var required_class: String = "miner"
@export_range(1, 50, 1, "suffix:lvl") var required_level: int = 1

## Costs
@export var gold_cost: int = 0
@export var energy_cost: float = 0.0

## Inputs (up to 3 different item types)
@export var input_1_slug: StringName = &""
@export_range(1, 99) var input_1_quantity: int = 1

@export var input_2_slug: StringName = &""
@export_range(0, 99) var input_2_quantity: int = 0

@export var input_3_slug: StringName = &""
@export_range(0, 99) var input_3_quantity: int = 0

## Outputs (can produce multiple items)
@export var output_1_slug: StringName = &""
@export_range(1, 99) var output_1_quantity: int = 1

@export var output_2_slug: StringName = &""
@export_range(0, 99) var output_2_quantity: int = 0

## Tags for filtering/categorization
@export var tags: PackedStringArray = []


## Helper functions
func get_inputs() -> Array[Dictionary]:
	var inputs: Array[Dictionary] = []
	if input_1_slug != &"":
		inputs.append({"slug": input_1_slug, "quantity": input_1_quantity})
	if input_2_slug != &"" and input_2_quantity > 0:
		inputs.append({"slug": input_2_slug, "quantity": input_2_quantity})
	if input_3_slug != &"" and input_3_quantity > 0:
		inputs.append({"slug": input_3_slug, "quantity": input_3_quantity})
	return inputs


func get_outputs() -> Array[Dictionary]:
	var outputs: Array[Dictionary] = []
	if output_1_slug != &"":
		outputs.append({"slug": output_1_slug, "quantity": output_1_quantity})
	if output_2_slug != &"" and output_2_quantity > 0:
		outputs.append({"slug": output_2_slug, "quantity": output_2_quantity})
	return outputs


func can_craft(player_class: String, player_level: int) -> bool:
	return player_class == required_class and player_level >= required_level
