extends Node

# Simple test script to verify crafting system works
# This can be attached to any node for testing

func _ready() -> void:
	print("=== CRAFTING SYSTEM TEST ===")
	
	# Test 1: Check if CraftingRecipe class exists
	if ClassDB.class_exists("CraftingRecipe"):
		print("✅ CraftingRecipe class found")
	else:
		print("❌ CraftingRecipe class not found")
	
	# Test 2: Check if recipes registry exists
	var registry = ContentRegistryHub.registry_of(&"recipes")
	if registry:
		print("✅ Recipes registry found")
		
		# Test loading a recipe
		var recipe = ContentRegistryHub.load_by_id(&"recipes", 1)
		if recipe:
			print("✅ Recipe loaded: ", recipe.recipe_name)
			print("   - Class: ", recipe.required_class)
			print("   - Level: ", recipe.required_level)
			print("   - Gold cost: ", recipe.gold_cost)
			print("   - Energy cost: ", recipe.energy_cost)
			
			# Test helper functions
			var inputs = recipe.get_inputs()
			print("   - Inputs: ", inputs)
			
			var outputs = recipe.get_outputs()
			print("   - Outputs: ", outputs)
			
			# Test can_craft function
			print("   - Can craft as miner lvl 1: ", recipe.can_craft("miner", 1))
			print("   - Can craft as forager lvl 1: ", recipe.can_craft("forager", 1))
		else:
			print("❌ Failed to load recipe")
	else:
		print("❌ Recipes registry not found")
	
	# Test 3: Check if items registry has new items
	var items_registry = ContentRegistryHub.registry_of(&"items")
	if items_registry:
		print("✅ Items registry found")
		
		# Test loading some new items
		var copper_ore = ContentRegistryHub.load_by_id(&"items", 7)
		if copper_ore:
			print("✅ Copper Ore loaded: ", copper_ore.item_name)
			print("   - Tags: ", copper_ore.tags)
		else:
			print("❌ Failed to load Copper Ore")
		
		var copper_ingot = ContentRegistryHub.load_by_id(&"items", 24)
		if copper_ingot:
			print("✅ Copper Ingot loaded: ", copper_ingot.item_name)
			print("   - Tags: ", copper_ingot.tags)
		else:
			print("❌ Failed to load Copper Ingot")
	else:
		print("❌ Items registry not found")
	
	# Test 4: Check data request handlers
	var handlers_registry = ContentRegistryHub.registry_of(&"data_request_handlers")
	if handlers_registry:
		print("✅ Data request handlers registry found")
		
		# Check if craft handlers exist
		var craft_execute_id = ContentRegistryHub.id_from_slug(&"data_request_handlers", &"craft.execute")
		var craft_get_recipes_id = ContentRegistryHub.id_from_slug(&"data_request_handlers", &"craft.get_recipes")
		
		if craft_execute_id > 0:
			print("✅ craft.execute handler registered (ID: ", craft_execute_id, ")")
		else:
			print("❌ craft.execute handler not found")
			
		if craft_get_recipes_id > 0:
			print("✅ craft.get_recipes handler registered (ID: ", craft_get_recipes_id, ")")
		else:
			print("❌ craft.get_recipes handler not found")
	else:
		print("❌ Data request handlers registry not found")
	
	print("=== CRAFTING SYSTEM TEST COMPLETE ===")
