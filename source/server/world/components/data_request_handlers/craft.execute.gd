extends DataRequestHandler


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var recipe_id: int = args.get("recipe_id", -1)
	
	if recipe_id == -1:
		return {"success": false, "error": "Invalid recipe"}
	
	# Load recipe
	var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
	if not recipe:
		return {"success": false, "error": "Recipe not found"}
	
	# Get player
	var player: Player = instance.get_player(peer_id)
	if not player or not player.player_resource:
		return {"success": false, "error": "Player not found"}
	
	var player_res: PlayerResource = player.player_resource
	
	# Validate class
	if not recipe.can_craft(player_res.character_class, player_res.level):
		return {"success": false, "error": "Requirements not met"}
	
	# Validate gold
	if player_res.golds < recipe.gold_cost:
		return {"success": false, "error": "Not enough gold"}
	
	# Validate energy
	var asc: AbilitySystemComponent = player.get_node_or_null(^"AbilitySystemComponent")
	if asc:
		var current_energy = asc.get_value(&"energy")
		if current_energy < recipe.energy_cost:
			return {"success": false, "error": "Not enough energy"}
	
	# Validate inputs (check inventory)
	var inputs = recipe.get_inputs()
	for input in inputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", input.slug)
		if item_id <= 0:
			return {"success": false, "error": "Invalid input item"}
		
		var inv_entry = player_res.inventory.get(item_id, {})
		var available = inv_entry.get("stack", 0)
		
		if available < input.quantity:
			return {"success": false, "error": "Not enough materials"}
	
	# All checks passed - deduct costs
	player_res.golds -= recipe.gold_cost
	
	if asc:
		asc.try_pay_costs({&"energy": recipe.energy_cost}, {&"reason": &"craft"})
	
	# Remove input items
	for input in inputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", input.slug)
		var inv_entry = player_res.inventory[item_id]
		inv_entry.stack -= input.quantity
		
		if inv_entry.stack <= 0:
			player_res.inventory.erase(item_id)
	
	# Add output items
	var outputs = recipe.get_outputs()
	for output in outputs:
		if not instance.give_item(peer_id, output.slug, output.quantity):
			push_error("Failed to give crafted item")
	
	# Calculate and award EXP based on recipe level
	var exp_gained: int = _calculate_crafting_exp(recipe, player_res, instance, peer_id)
		
	# Push updates to client
	instance.data_push.rpc_id(peer_id, &"inventory.update", player_res.inventory)
	instance.data_push.rpc_id(peer_id, &"gold.update", {"gold": player_res.golds})
	
	return {
		"success": true,
		"recipe_name": recipe.recipe_name,
		"crafted": outputs,
		"exp_gained": exp_gained
	}

	
func _calculate_crafting_exp(recipe: CraftingRecipe, player_res: PlayerResource, instance: ServerInstance, peer_id: int) -> int:
	# Don't award XP if already max level
	if player_res.level >= PlayerResource.MAX_LEVEL:
		return 0
	
	# Level-based EXP: required_level * 5
	# Level 1 recipe = 5 XP, Level 20 recipe = 100 XP, etc.
	var exp_amount = recipe.required_level * 250
	
	player_res.experience += exp_amount
	
	# Check for level-ups
	var leveled_up = false
	while player_res.can_level_up():
		var old_level = player_res.level
		player_res.level_up()
		leveled_up = true
		print("Player %s leveled up from crafting: %d -> %d" % [player_res.display_name, old_level, player_res.level])
	
	# Update energy max on level-up
	if leveled_up:
		var player: Player = instance.get_player(peer_id)
		if player:
			var asc: AbilitySystemComponent = player.ability_system_component
			if asc:
				var new_energy_max: float = player_res.get_energy_max()
				asc.set_max_server(&"energy", new_energy_max, true)
				asc.set_value_server(&"energy", new_energy_max)
	
	# Notify client of exp gain
	instance.data_push.rpc_id(peer_id, &"exp.update", {
		"exp": player_res.experience,
		"level": player_res.level,
		"exp_required": player_res.get_exp_required(),
		"leveled_up": leveled_up
	})
	
	return exp_amount
	
	
