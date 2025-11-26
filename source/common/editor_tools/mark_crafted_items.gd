@tool
extends EditorScript
## Run this script in the Godot Editor to mark all recipe outputs as is_crafted = true
## To run: Open this file in the Script Editor, then go to File -> Run

func _run() -> void:
	print("=" .repeat(60))
	print("Marking all recipe outputs as is_crafted = true")
	print("=" .repeat(60))
	
	# Collect all output slugs from recipes
	var output_slugs: Dictionary = {}  # slug -> true
	
	# Get all recipe files
	var recipes_dir = "res://source/common/gameplay/crafting/recipes/"
	var recipe_paths = _get_all_files_recursive(recipes_dir, "tres")
	
	print("\n1. Found %d recipe files" % recipe_paths.size())
	
	for recipe_path in recipe_paths:
		var recipe = load(recipe_path) as CraftingRecipe
		if recipe:
			# Check output_1_slug
			if recipe.output_1_slug != &"":
				output_slugs[recipe.output_1_slug] = true
			# Check output_2_slug
			if recipe.output_2_slug != &"":
				output_slugs[recipe.output_2_slug] = true
	
	print("2. Found %d unique output item slugs" % output_slugs.size())
	
	# Also collect vendor stock_recipes outputs (by ID)
	var vendor_output_ids: Dictionary = {}
	var overworld = load("res://source/common/gameplay/maps/maps/overworld.tscn") as PackedScene
	if overworld:
		var overworld_state = overworld.get_state()
		for i in range(overworld_state.get_node_count()):
			var props = {}
			for j in range(overworld_state.get_node_property_count(i)):
				var prop_name = overworld_state.get_node_property_name(i, j)
				var prop_value = overworld_state.get_node_property_value(i, j)
				props[prop_name] = prop_value
			
			if props.has("stock_recipes"):
				var recipes = props["stock_recipes"] as Dictionary
				for output_id in recipes.keys():
					vendor_output_ids[output_id] = true
	
	print("3. Found %d vendor stock recipe outputs" % vendor_output_ids.size())
	
	# Map slugs to item IDs using the registry
	var items_to_update: Dictionary = {}  # path -> true
	
	# From recipe output slugs
	for slug in output_slugs.keys():
		var item_id = ContentRegistryHub.id_from_slug(&"items", slug)
		if item_id > 0:
			var item_path = ContentRegistryHub.path_from_id(&"items", item_id)
			if item_path != "":
				items_to_update[item_path] = true
		else:
			print("   Warning: No item found for slug '%s'" % slug)
	
	# From vendor recipe output IDs
	for item_id in vendor_output_ids.keys():
		var item_path = ContentRegistryHub.path_from_id(&"items", item_id)
		if item_path != "":
			items_to_update[item_path] = true
		else:
			print("   Warning: No item found for ID %d" % item_id)
	
	print("4. Total items to update: %d" % items_to_update.size())
	
	# Update items
	var updated = 0
	var already_marked = 0
	var errors = 0
	
	for item_path in items_to_update.keys():
		var item = load(item_path) as Item
		if item:
			if item.is_crafted:
				already_marked += 1
			else:
				item.is_crafted = true
				var err = ResourceSaver.save(item, item_path)
				if err == OK:
					updated += 1
					print("   ✓ %s" % item_path.get_file())
				else:
					errors += 1
					print("   ✗ Failed to save: %s" % item_path)
		else:
			errors += 1
			print("   ✗ Failed to load: %s" % item_path)
	
	print("\n" + "=" .repeat(60))
	print("SUMMARY:")
	print("  Updated: %d" % updated)
	print("  Already marked: %d" % already_marked)
	print("  Errors: %d" % errors)
	print("=" .repeat(60))


func _get_all_files_recursive(path: String, extension: String) -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path + file_name
			if dir.current_is_dir():
				files.append_array(_get_all_files_recursive(full_path + "/", extension))
			elif file_name.ends_with("." + extension):
				files.append(full_path)
			file_name = dir.get_next()
	return files

