class_name RecipeItemValidator
extends RefCounted
## Validates recipes and items to detect gaps and issues in the crafting system


# Whitelist tags for raw materials that shouldn't have recipes
const RAW_MATERIAL_TAGS := ["ore", "wood", "hide", "meat", "herb", "plant", "gathered", "raw"]

# Validation results
var recipes_with_no_inputs: Array[Dictionary] = []
var items_without_recipes: Array[Dictionary] = []
var broken_recipe_references: Array[Dictionary] = []
var duplicate_recipes: Array[Dictionary] = []
var unused_crafted_items: Array[Dictionary] = []
var orphaned_outputs: Array[Dictionary] = []

var total_recipes: int = 0
var total_items: int = 0
var total_issues: int = 0


func validate_all() -> void:
	print("=== Starting Recipe & Item Validation ===")
	
	# Load registries
	var recipes_registry = ContentRegistryHub.registry_of(&"recipes")
	var items_registry = ContentRegistryHub.registry_of(&"items")
	
	if not recipes_registry:
		push_error("Failed to load recipes registry!")
		return
	
	if not items_registry:
		push_error("Failed to load items registry!")
		return
	
	# Collect all valid item slugs
	var valid_item_slugs: Dictionary = {}  # slug -> item_id
	var items_index: ContentIndex = load("res://source/common/registry/indexes/items_index.tres")
	total_items = items_index.entries.size()
	
	for entry in items_index.entries:
		var slug: StringName = entry.get(&"slug", &"")
		var id: int = entry.get(&"id", 0)
		if slug != &"":
			valid_item_slugs[slug] = id
	
	print("Loaded %d items" % total_items)
	
	# Collect all recipe data
	var recipes_index: ContentIndex = load("res://source/common/registry/indexes/recipes_index.tres")
	total_recipes = recipes_index.entries.size()
	
	var recipes_data: Array[Dictionary] = []
	var items_produced_by_recipes: Dictionary = {}  # item_slug -> [recipe_ids]
	var items_used_as_inputs: Dictionary = {}  # item_slug -> [recipe_ids]
	
	print("Loading %d recipes..." % total_recipes)
	
	for entry in recipes_index.entries:
		var recipe_id: int = entry.get(&"id", 0)
		var recipe_path: String = entry.get(&"path", "")
		var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
		
		if not recipe:
			print("WARNING: Could not load recipe ID %d at %s" % [recipe_id, recipe_path])
			continue
		
		var recipe_info = {
			"id": recipe_id,
			"path": recipe_path,
			"slug": recipe.slug,
			"name": recipe.recipe_name,
			"resource": recipe
		}
		recipes_data.append(recipe_info)
		
		# Track outputs
		if recipe.output_1_slug != &"":
			if not items_produced_by_recipes.has(recipe.output_1_slug):
				items_produced_by_recipes[recipe.output_1_slug] = []
			items_produced_by_recipes[recipe.output_1_slug].append(recipe_id)
		
		if recipe.output_2_slug != &"" and recipe.output_2_quantity > 0:
			if not items_produced_by_recipes.has(recipe.output_2_slug):
				items_produced_by_recipes[recipe.output_2_slug] = []
			items_produced_by_recipes[recipe.output_2_slug].append(recipe_id)
		
		# Track inputs
		for input_data in recipe.get_inputs():
			var input_slug: StringName = input_data.slug
			if not items_used_as_inputs.has(input_slug):
				items_used_as_inputs[input_slug] = []
			items_used_as_inputs[input_slug].append(recipe_id)
	
	print("Loaded %d valid recipes" % recipes_data.size())
	
	# Run validation checks
	print("\n--- Running Validation Checks ---")
	
	_check_recipes_with_no_inputs(recipes_data)
	_check_broken_references(recipes_data, valid_item_slugs)
	_check_duplicate_recipes(items_produced_by_recipes, recipes_data)
	_check_orphaned_outputs(recipes_data, valid_item_slugs)
	_check_items_without_recipes(valid_item_slugs, items_produced_by_recipes, items_registry)
	_check_unused_crafted_items(items_produced_by_recipes, items_used_as_inputs, recipes_data)
	
	# Calculate total issues
	total_issues = (
		recipes_with_no_inputs.size() +
		items_without_recipes.size() +
		broken_recipe_references.size() +
		duplicate_recipes.size() +
		unused_crafted_items.size() +
		orphaned_outputs.size()
	)
	
	print("\n=== Validation Complete ===")
	print("Total Issues Found: %d" % total_issues)


func _check_recipes_with_no_inputs(recipes_data: Array[Dictionary]) -> void:
	print("Checking for recipes with no inputs...")
	
	for recipe_info in recipes_data:
		var recipe: CraftingRecipe = recipe_info.resource
		var inputs = recipe.get_inputs()
		
		if inputs.size() == 0:
			recipes_with_no_inputs.append({
				"recipe_id": recipe_info.id,
				"recipe_name": recipe.recipe_name,
				"recipe_slug": recipe.slug,
				"path": recipe_info.path,
				"gold_cost": recipe.gold_cost,
				"energy_cost": recipe.energy_cost
			})
	
	print("  Found %d recipes with no inputs" % recipes_with_no_inputs.size())


func _check_broken_references(recipes_data: Array[Dictionary], valid_item_slugs: Dictionary) -> void:
	print("Checking for broken item references in recipes...")
	
	for recipe_info in recipes_data:
		var recipe: CraftingRecipe = recipe_info.resource
		var broken_refs: Array[String] = []
		
		# Check inputs
		for input_data in recipe.get_inputs():
			var input_slug: StringName = input_data.slug
			if not valid_item_slugs.has(input_slug):
				broken_refs.append("input: %s" % input_slug)
		
		# Check outputs
		for output_data in recipe.get_outputs():
			var output_slug: StringName = output_data.slug
			if not valid_item_slugs.has(output_slug):
				broken_refs.append("output: %s" % output_slug)
		
		if broken_refs.size() > 0:
			broken_recipe_references.append({
				"recipe_id": recipe_info.id,
				"recipe_name": recipe.recipe_name,
				"recipe_slug": recipe.slug,
				"path": recipe_info.path,
				"broken_refs": broken_refs
			})
	
	print("  Found %d recipes with broken references" % broken_recipe_references.size())


func _check_duplicate_recipes(items_produced_by_recipes: Dictionary, recipes_data: Array[Dictionary]) -> void:
	print("Checking for duplicate recipes (same output)...")
	
	for item_slug in items_produced_by_recipes:
		var recipe_ids: Array = items_produced_by_recipes[item_slug]
		
		if recipe_ids.size() > 1:
			var duplicate_info: Array[Dictionary] = []
			
			for recipe_id in recipe_ids:
				# Find recipe data
				for recipe_info in recipes_data:
					if recipe_info.id == recipe_id:
						var recipe: CraftingRecipe = recipe_info.resource
						duplicate_info.append({
							"recipe_id": recipe_id,
							"recipe_name": recipe.recipe_name,
							"recipe_slug": recipe.slug,
							"path": recipe_info.path,
							"class": recipe.required_class,
							"level": recipe.required_level
						})
						break
			
			duplicate_recipes.append({
				"item_slug": item_slug,
				"recipe_count": recipe_ids.size(),
				"recipes": duplicate_info
			})
	
	print("  Found %d items with duplicate recipes" % duplicate_recipes.size())


func _check_orphaned_outputs(recipes_data: Array[Dictionary], valid_item_slugs: Dictionary) -> void:
	print("Checking for orphaned recipe outputs...")
	
	for recipe_info in recipes_data:
		var recipe: CraftingRecipe = recipe_info.resource
		
		for output_data in recipe.get_outputs():
			var output_slug: StringName = output_data.slug
			if not valid_item_slugs.has(output_slug):
				orphaned_outputs.append({
					"recipe_id": recipe_info.id,
					"recipe_name": recipe.recipe_name,
					"recipe_slug": recipe.slug,
					"path": recipe_info.path,
					"missing_output_slug": output_slug
				})
	
	print("  Found %d orphaned outputs" % orphaned_outputs.size())


func _check_items_without_recipes(valid_item_slugs: Dictionary, items_produced_by_recipes: Dictionary, items_registry: ContentRegistry) -> void:
	print("Checking for items without recipes...")
	
	for item_slug in valid_item_slugs:
		# Skip if item is produced by a recipe
		if items_produced_by_recipes.has(item_slug):
			continue
		
		# Load the item to check if it's a raw material
		var item_id: int = valid_item_slugs[item_slug]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		
		if not item:
			continue
		
		# Check if it's a whitelisted raw material
		if _is_raw_material(item, item_slug):
			continue
		
		# Get item path
		var item_path: String = items_registry.path_from_id(item_id)
		
		items_without_recipes.append({
			"item_slug": item_slug,
			"item_name": item.item_name,
			"item_id": item_id,
			"path": item_path,
			"tags": item.tags
		})
	
	print("  Found %d items without recipes (excluding raw materials)" % items_without_recipes.size())


func _check_unused_crafted_items(items_produced_by_recipes: Dictionary, items_used_as_inputs: Dictionary, recipes_data: Array[Dictionary]) -> void:
	print("Checking for unused crafted items...")
	
	for item_slug in items_produced_by_recipes:
		# Skip if item is used as an input somewhere
		if items_used_as_inputs.has(item_slug):
			continue
		
		# This item is crafted but never used
		var recipe_ids: Array = items_produced_by_recipes[item_slug]
		var producing_recipes: Array[Dictionary] = []
		
		for recipe_id in recipe_ids:
			for recipe_info in recipes_data:
				if recipe_info.id == recipe_id:
					producing_recipes.append({
						"recipe_id": recipe_id,
						"recipe_name": recipe_info.resource.recipe_name,
						"path": recipe_info.path
					})
					break
		
		unused_crafted_items.append({
			"item_slug": item_slug,
			"recipe_count": recipe_ids.size(),
			"recipes": producing_recipes
		})
	
	print("  Found %d crafted items never used as inputs" % unused_crafted_items.size())


func _is_raw_material(item: Item, item_slug: StringName) -> bool:
	# Check tags
	for tag in item.tags:
		if tag in RAW_MATERIAL_TAGS:
			return true
	
	# Check if it's in materials folder (likely raw)
	var item_id = ContentRegistryHub.id_from_slug(&"items", item_slug)
	var item_path: String = ContentRegistryHub.registry_of(&"items").path_from_id(item_id)
	
	# Raw materials are typically in the materials folder with specific naming
	if "materials/" in item_path:
		# Check for common raw material patterns in slug
		var raw_patterns = ["_ore", "_wood", "_hide", "_meat", "_herb", "_plant"]
		for pattern in raw_patterns:
			if item_slug.ends_with(pattern):
				return true
	
	return false


func generate_report() -> String:
	var report := ""
	
	report += "# Recipe & Item Validation Report\n\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	
	# Summary
	report += "## Summary\n\n"
	report += "- Total Recipes: %d\n" % total_recipes
	report += "- Total Items: %d\n" % total_items
	report += "- **Total Issues Found: %d**\n\n" % total_issues
	
	# Issue breakdown
	report += "### Issue Breakdown\n\n"
	report += "| Issue Type | Count | Severity |\n"
	report += "|------------|-------|----------|\n"
	report += "| Recipes with No Inputs | %d | %s |\n" % [recipes_with_no_inputs.size(), "Warning"]
	report += "| Items Without Recipes | %d | %s |\n" % [items_without_recipes.size(), "Info"]
	report += "| Broken Recipe References | %d | %s |\n" % [broken_recipe_references.size(), "Critical"]
	report += "| Duplicate Recipes | %d | %s |\n" % [duplicate_recipes.size(), "Warning"]
	report += "| Unused Crafted Items | %d | %s |\n" % [unused_crafted_items.size(), "Info"]
	report += "| Orphaned Outputs | %d | %s |\n" % [orphaned_outputs.size(), "Critical"]
	report += "\n"
	
	# Detailed sections
	if broken_recipe_references.size() > 0:
		report += _generate_broken_refs_section()
	
	if orphaned_outputs.size() > 0:
		report += _generate_orphaned_outputs_section()
	
	if recipes_with_no_inputs.size() > 0:
		report += _generate_no_inputs_section()
	
	if duplicate_recipes.size() > 0:
		report += _generate_duplicates_section()
	
	if items_without_recipes.size() > 0:
		report += _generate_no_recipe_section()
	
	if unused_crafted_items.size() > 0:
		report += _generate_unused_items_section()
	
	return report


func _generate_broken_refs_section() -> String:
	var section := "\n## 🔴 CRITICAL: Broken Recipe References\n\n"
	section += "Recipes referencing non-existent items. These will cause runtime errors!\n\n"
	
	for issue in broken_recipe_references:
		section += "### %s (ID: %d)\n\n" % [issue.recipe_name, issue.recipe_id]
		section += "- **Path:** `%s`\n" % issue.path
		section += "- **Slug:** `%s`\n" % issue.recipe_slug
		section += "- **Broken References:**\n"
		for ref in issue.broken_refs:
			section += "  - %s\n" % ref
		section += "\n"
	
	return section


func _generate_orphaned_outputs_section() -> String:
	var section := "\n## 🔴 CRITICAL: Orphaned Recipe Outputs\n\n"
	section += "Recipes producing items that don't exist in the item registry.\n\n"
	
	for issue in orphaned_outputs:
		section += "### %s (ID: %d)\n\n" % [issue.recipe_name, issue.recipe_id]
		section += "- **Path:** `%s`\n" % issue.path
		section += "- **Missing Output Slug:** `%s`\n" % issue.missing_output_slug
		section += "\n"
	
	return section


func _generate_no_inputs_section() -> String:
	var section := "\n## ⚠️ WARNING: Recipes with No Inputs\n\n"
	section += "Recipes that require only gold/energy but no material inputs.\n\n"
	
	for issue in recipes_with_no_inputs:
		section += "### %s (ID: %d)\n\n" % [issue.recipe_name, issue.recipe_id]
		section += "- **Path:** `%s`\n" % issue.path
		section += "- **Slug:** `%s`\n" % issue.recipe_slug
		section += "- **Cost:** %d gold, %.1f energy\n" % [issue.gold_cost, issue.energy_cost]
		section += "\n"
	
	return section


func _generate_duplicates_section() -> String:
	var section := "\n## ⚠️ WARNING: Duplicate Recipes\n\n"
	section += "Multiple recipes producing the same item. May cause confusion or balance issues.\n\n"
	
	for issue in duplicate_recipes:
		section += "### Item: %s (%d recipes)\n\n" % [issue.item_slug, issue.recipe_count]
		for recipe in issue.recipes:
			section += "- **%s** (ID: %d)\n" % [recipe.recipe_name, recipe.recipe_id]
			section += "  - Path: `%s`\n" % recipe.path
			section += "  - Class: %s, Level: %d\n" % [recipe["class"], recipe.level]
		section += "\n"
	
	return section


func _generate_no_recipe_section() -> String:
	var section := "\n## ℹ️ INFO: Items Without Recipes\n\n"
	section += "Craftable items that have no recipe. Excluding raw materials.\n\n"
	
	for issue in items_without_recipes:
		section += "### %s\n\n" % issue.item_name
		section += "- **Slug:** `%s`\n" % issue.item_slug
		section += "- **ID:** %d\n" % issue.item_id
		section += "- **Path:** `%s`\n" % issue.path
		section += "- **Tags:** %s\n" % str(issue.tags)
		section += "\n"
	
	return section


func _generate_unused_items_section() -> String:
	var section := "\n## ℹ️ INFO: Unused Crafted Items\n\n"
	section += "Items that are crafted but never used as inputs in other recipes. Potential dead ends.\n\n"
	
	for issue in unused_crafted_items:
		section += "### Item: %s\n\n" % issue.item_slug
		section += "- **Produced by %d recipe(s):**\n" % issue.recipe_count
		for recipe in issue.recipes:
			section += "  - %s (ID: %d) - `%s`\n" % [recipe.recipe_name, recipe.recipe_id, recipe.path]
		section += "\n"
	
	return section


func save_report(file_path: String) -> void:
	var report = generate_report()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		file.store_string(report)
		file.close()
		print("Report saved to: %s" % file_path)
	else:
		push_error("Failed to save report to: %s" % file_path)

