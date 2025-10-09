class_name HarvestLootTable
extends Resource


## Loot entry structure:
## {
##   "item_slug": StringName,
##   "weight": float (percentage chance, e.g., 40.0 = 40%),
##   "quantity_min": int,
##   "quantity_max": int
## }
@export var loot_entries: Array[Dictionary] = []

## Rare bonus entry structure:
## {
##   "item_slug": StringName,
##   "chance": float (independent roll, e.g., 0.02 = 2%),
##   "quantity": int
## }
@export var rare_bonus_entries: Array[Dictionary] = []


## Rolls the loot table and returns a dictionary of item_slug: quantity pairs
func roll_loot() -> Dictionary:
	var result: Dictionary = {}
	
	# Roll main loot entries
	for entry in loot_entries:
		var item_slug: StringName = entry.get("item_slug", &"")
		var weight: float = entry.get("weight", 0.0)
		var quantity_min: int = entry.get("quantity_min", 1)
		var quantity_max: int = entry.get("quantity_max", 1)
		
		if item_slug.is_empty():
			continue
		
		# Roll against weight (treat as percentage)
		var roll: float = randf() * 100.0
		if roll <= weight:
			var quantity: int = randi_range(quantity_min, quantity_max)
			result[item_slug] = result.get(item_slug, 0) + quantity
	
	# Roll rare bonuses independently
	for bonus in rare_bonus_entries:
		var item_slug: StringName = bonus.get("item_slug", &"")
		var chance: float = bonus.get("chance", 0.0)
		var quantity: int = bonus.get("quantity", 1)
		
		if item_slug.is_empty():
			continue
		
		# Roll against chance (0.0 to 1.0)
		var roll: float = randf()
		if roll <= chance:
			result[item_slug] = result.get(item_slug, 0) + quantity
	
	return result


## Helper function to add a loot entry
func add_loot_entry(item_slug: StringName, weight: float, quantity_min: int = 1, quantity_max: int = 1) -> void:
	loot_entries.append({
		"item_slug": item_slug,
		"weight": weight,
		"quantity_min": quantity_min,
		"quantity_max": quantity_max
	})


## Helper function to add a rare bonus entry
func add_rare_bonus(item_slug: StringName, chance: float, quantity: int = 1) -> void:
	rare_bonus_entries.append({
		"item_slug": item_slug,
		"chance": chance,
		"quantity": quantity
	})

