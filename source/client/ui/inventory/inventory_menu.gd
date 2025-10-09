extends Control


## All items of the player inventory.
var inventory: Dictionary
var selected_item_id: int = -1
## Filtered inventory showing equipment only.
var equipment_inventory: Dictionary
## Filtered inventory showing equipment only.
var materials_inventory: Dictionary

var latest_items: Dictionary
var gear_slots_cache: Dictionary[Panel, Item]
var selected_item: Item

# Trade system variables
var trade_session_id: int = -1
var other_player_name: String = ""
var other_player_peer: int = -1
var your_trade_items: Dictionary = {}  # {item_id: quantity}
var their_trade_items: Dictionary = {}
var your_trade_gold: int = 0
var their_trade_gold: int = 0
var your_ready: bool = false
var their_ready: bool = false
var trade_locked: bool = false

# Market/sell variables
var in_market: bool = false

# Gold tracking
var current_gold: int = 0

# Crafting system variables
var available_recipes: Array = []
var selected_recipe: CraftingRecipe = null
var player_class: String = ""
var player_level: int = 0

@onready var inventory_grid: GridContainer = $EquipmentView/HBoxContainer/VBoxContainer/InventoryGrid
@onready var equipment_slots: GridContainer = $EquipmentView/HBoxContainer/VBoxContainer2/EquipmentSlots
@onready var rich_text_label: RichTextLabel = $EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/RichTextLabel

# Trade system @onready references
@onready var trade_view: Control = $TradeView
@onready var your_offer_title: Label = $TradeView/Screen/HBoxContainer/TradePanel/YourOffer/VBoxContainer/TabTitle
@onready var their_offer_title: Label = $TradeView/Screen/HBoxContainer/TradePanel/TheirOffer/VBoxContainer/TabTitle
@onready var your_offer_grid: GridContainer = $TradeView/Screen/HBoxContainer/TradePanel/YourOffer/VBoxContainer/GridContainer
@onready var their_offer_grid: GridContainer = $TradeView/Screen/HBoxContainer/TradePanel/TheirOffer/VBoxContainer/GridContainer
@onready var your_gold_input: LineEdit = $TradeView/Screen/HBoxContainer/TradePanel/YourOffer/VBoxContainer/HBoxContainer/LineEdit
@onready var their_gold_label: Label = $TradeView/Screen/HBoxContainer/TradePanel/TheirOffer/VBoxContainer/HBoxContainer/Label
@onready var your_ready_button: Button = $TradeView/Screen/HBoxContainer/TradePanel/YourOffer/VBoxContainer/Button
@onready var their_ready_button: Button = $TradeView/Screen/HBoxContainer/TradePanel/TheirOffer/VBoxContainer/Button
@onready var player_inv_grid: GridContainer = $TradeView/Screen/HBoxContainer/PlayerInv/InventoryGrid
@onready var close_button: Button = $CloseButton

# Market/sell @onready references
@onready var sell_button: Button = $EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/SellButton
@onready var sell_price_label: Label = $EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/SellPriceLabel

# Gold display @onready references
@onready var equipment_gold_label: Label = $EquipmentView/HBoxContainer/VBoxContainer2/GoldDisplay/Label
@onready var trade_gold_label: Label = $TradeView/Screen/HBoxContainer/GoldDisplay/Label

# Crafting UI @onready references
@onready var crafting_view: Control = $CraftingView
@onready var recipe_grid: GridContainer = $CraftingView/HBoxContainer/VBoxContainer/RecipeList/RecipeGrid
@onready var class_filter: OptionButton = $CraftingView/HBoxContainer/VBoxContainer/FilterContainer/ClassFilter
@onready var search_box: LineEdit = $CraftingView/HBoxContainer/VBoxContainer/FilterContainer/SearchBox
@onready var recipe_name_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RecipeName
@onready var recipe_description: RichTextLabel = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RecipeDescription
@onready var inputs_container: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RequirementsContainer/InputsContainer
@onready var outputs_list: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/OutputsContainer/OutputsList
@onready var costs_list: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/CostsContainer/CostsList
@onready var craft_button: Button = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/CraftButton
@onready var status_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/StatusLabel


func _ready() -> void:
	print("Inventory menu _ready() called")
	InstanceClient.current.request_data(&"inventory.get", fill_inventory)
	visibility_changed.connect(_on_visibility_changed)
	
	# Trade system setup
	your_ready_button.pressed.connect(_on_your_ready_pressed)
	your_gold_input.text_changed.connect(_on_gold_input_changed)
	close_button.pressed.connect(_on_close_button_pressed)

	# Subscribe to trade events
	InstanceClient.subscribe(&"trade.open", _on_trade_open)
	InstanceClient.subscribe(&"trade.update", _on_trade_update)
	InstanceClient.subscribe(&"trade.complete", _on_trade_complete)
	InstanceClient.subscribe(&"trade.cancel", _on_trade_cancel)
	
	# Subscribe to market status updates
	print("Subscribing to market.status signal")
	InstanceClient.subscribe(&"market.status", _on_market_status_update)
	
	# Subscribe to gold updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	
	# Request initial gold amount
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	
	# Connect sell button
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
	
	# Connect tab buttons
	var inventory_tabs = $InventoryTabs
	if inventory_tabs:
		var buttons = inventory_tabs.get_children()
		for i in range(buttons.size()):
			if buttons[i] is Button:
				buttons[i].pressed.connect(_on_tab_button_pressed.bind(i))
	
	# Connect crafting UI
	if craft_button:
		craft_button.pressed.connect(_on_craft_button_pressed)
	if class_filter:
		class_filter.item_selected.connect(_on_class_filter_changed)
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
	
	#hide trade viewby default
	trade_view.hide()
	$EquipmentView.show()


func _on_visibility_changed() -> void:
	print("Inventory menu visibility changed: ", is_visible_in_tree())
	if is_visible_in_tree():
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)
		# Request fresh gold amount when opening inventory
		InstanceClient.current.request_data(&"gold.get", _on_gold_received)
		# Always sync market status from HUD when inventory becomes visible
		_sync_market_status_from_hud()
		
		# If we have an active trade session when becoming visible, show TradeView
		# Note: _populate_trade_inventory() will be called in fill_inventory() after data arrives
		if trade_session_id != -1:
			$EquipmentView.hide()
			$MaterialsView.hide()
			trade_view.show()

func _sync_market_status_from_hud() -> void:
	# Try to find HUD through the UI scene structure
	var ui = get_viewport().get_node_or_null("UI")
	var hud = null
	if ui:
		hud = ui.get_node_or_null("HUD")
	
	print("UI node found: ", ui != null)
	print("HUD node found: ", hud != null)
	if hud:
		print("HUD has get_market_status method: ", hud.has_method("get_market_status"))
		if hud.has_method("get_market_status"):
			var hud_market_status = hud.get_market_status()
			print("HUD market status: ", hud_market_status)
			in_market = hud_market_status
			print("Inventory synced market status from HUD: ", in_market)
			_update_sell_ui()
		else:
			print("HUD does not have get_market_status method")
	else:
		print("HUD node not found")

func _on_market_status_update(data: Dictionary) -> void:
	print("Inventory received market status signal: ", data)
	in_market = data.get("in_market", false)
	print("Inventory received market status: ", in_market)
	_update_sell_ui()

func _update_sell_ui() -> void:
	if not sell_button or not sell_price_label:
		return
	
	# Use the inventory menu's own in_market variable (should be updated by market status signal)
	if selected_item and in_market:
		sell_button.visible = true
		sell_price_label.visible = true
		# Calculate sell price
		var sell_price = selected_item.minimum_price if selected_item.minimum_price > 0 else 1
		sell_price_label.text = "Sell Price: %d gold" % sell_price
	else:
		sell_button.visible = false
		sell_price_label.visible = false

func _on_sell_button_pressed() -> void:
	if not selected_item or not in_market:
		return
	
	# Request to sell the selected item
	InstanceClient.current.request_data(&"item.sell", _on_sell_response, {
		"item_id": selected_item_id,
		"quantity": 1
	})

func _on_sell_response(data: Dictionary) -> void:
	if data.has("error"):
		print("Sell error: ", data["error"])
		# Could show error message to user
	else:
		print("Sold item for ", data["total_price"], " gold")
		# Refresh inventory to show updated quantities
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)

func _on_gold_received(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _on_gold_update(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _update_gold_display() -> void:
	var gold_text = "Gold: %d" % current_gold
	if equipment_gold_label:
		equipment_gold_label.text = gold_text
	if trade_gold_label:
		trade_gold_label.text = gold_text


func fill_inventory(inv_data: Dictionary) -> void:
	inventory = inv_data
	var slot_index: int = 0
	
	# Clear all slots first
	_clear_all_inventory_slots()
	
	# Fill slots with items
	for item_id: int in inv_data.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry: Dictionary = inv_data[item_id]
			var stack: int = int(entry.get("stack", 1))
			
			# Find the next available Panel slot (skip Button nodes)
			var item_slot_panel: Panel = _get_next_panel_slot(slot_index)
			if item_slot_panel and item_slot_panel.has_method("set_item_data"):
				item_slot_panel.set_item_data(item_id, item, stack)
				gear_slots_cache.set(item_slot_panel, item)
				slot_index += 1
	
	# Update equipment slots
	for equipment_slot: GearSlotButton in equipment_slots.get_children():
		if equipment_slot.gear_slot:
			if equipment_slot.gear_slot == null:
				equipment_slot.text = "Empty"
		else:
			equipment_slot.icon = null
			equipment_slot.text = "Lock"
	
	# If we're in a trade, populate the trade inventory now that we have the data
	if trade_session_id != -1:
		_populate_trade_inventory()


func add_item() -> void:
	pass


func _on_item_slot_clicked(item_slot_panel: Panel) -> void:
	# If we're in trade view, handle trade logic
	if trade_view.visible and not trade_locked and not your_ready:
		var item_data = item_slot_panel.item_data
		if item_data.has("item_id") and item_data.item_id != -1:
			# Add item to trade
			var item_id = item_data.item_id
			var quantity = item_data.get("stack", 1)
			
			var available = inventory.get(item_id, {}).get("stack", 0)
			var currently_offered = your_trade_items.get(item_id, 0)
			
			if currently_offered + quantity <= available:
				if your_trade_items.has(item_id):
					your_trade_items[item_id] += quantity
				else:
					your_trade_items[item_id] = quantity
			
			_update_trade_ui()
			_send_trade_update()
	else:
		# Original inventory logic
		var item_data = item_slot_panel.item_data
		if item_data.has("item") and item_data.item:
			selected_item = item_data.item
			selected_item_id = item_data.get("item_id", -1)
			rich_text_label.text = item_data.item.description
			
			# Sync market status and update sell UI when item is selected
			_sync_market_status_from_hud()
			_update_sell_ui()


func _on_equip_button_pressed() -> void:
	if selected_item is GearItem or selected_item is WeaponItem:
		if selected_item_id != -1:
			InstanceClient.current.request_data(
				&"item.equip",
				Callable(),
				{"id": selected_item_id}
			)


func _clear_all_inventory_slots() -> void:
	# Clear all Panel slots in the inventory grid
	for i in range(inventory_grid.get_child_count()):
		var child = inventory_grid.get_child(i)
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	gear_slots_cache.clear()


func _get_next_panel_slot(start_index: int) -> Panel:
	# Find the next available Panel slot starting from start_index
	var panel_count: int = 0
	for i in range(inventory_grid.get_child_count()):
		var child = inventory_grid.get_child(i)
		if child is Panel:
			if panel_count >= start_index:
				return child
			panel_count += 1
	return null


# Trade system functions
func _on_close_button_pressed():
	if trade_view.visible:
		# Cancel trade if in trade view
		if trade_session_id != -1:
			InstanceClient.current.request_data(&"trade.cancel", Callable(), {
				"session_id": trade_session_id
			})
		_close_trade()
	else:
		# Normal close behavior
		hide()

func _on_trade_open(data: Dictionary):
	_reset_trade_state()
		#clear past offers
	_update_offer_grid(your_offer_grid, {})
	_update_offer_grid(their_offer_grid, {})
	your_gold_input.text = "0"
	
	trade_session_id = data.get("session_id", -1)
	other_player_peer = data.get("other_peer", -1)
	other_player_name = data.get("other_name", "Unknown")
	
	your_offer_title.text = "Your Offer"
	their_offer_title.text = other_player_name + "'s Offer"
	
	# Switch to trade view
	$EquipmentView.hide()
	$MaterialsView.hide()
	trade_view.show()
	
	# Populate the player inventory in trade view
	_populate_trade_inventory()


func _on_trade_update(data: Dictionary):
	if data.get("session_id") != trade_session_id:
		return
	
	your_trade_items = data.get("your_items", {})
	their_trade_items = data.get("their_items", {})
	your_trade_gold = data.get("your_gold", 0)
	their_trade_gold = data.get("their_gold", 0)
	your_ready = data.get("your_confirmed", false)
	their_ready = data.get("their_confirmed", false)
	trade_locked = data.get("locked", false)
	
	_update_trade_ui()

func _on_trade_complete(data: Dictionary):
	print("Trade completed successfully!")
	_close_trade()
	# Refresh inventory to show newly traded items
	InstanceClient.current.request_data(&"inventory.get", fill_inventory)

func _on_trade_cancel(data: Dictionary):
	var cancelled_by = data.get("cancelled_by", "")
	if cancelled_by != "":
		print("Trade cancelled by " + cancelled_by)
	else:
		print("Trade cancelled")
	_close_trade()

func _update_trade_ui():
	# Update your offer grid
	_update_offer_grid(your_offer_grid, your_trade_items)
	
	# Update their offer grid
	_update_offer_grid(their_offer_grid, their_trade_items)
	
	# Update gold
	your_gold_input.text = str(your_trade_gold)
	their_gold_label.text = "Gold: " + str(their_trade_gold)
	
	# Update button states
	if trade_locked:
		your_ready_button.disabled = true
		your_ready_button.text = "Locked"
		your_gold_input.editable = false
		_disable_inventory_interaction()
	else:
		your_ready_button.disabled = false
		if your_ready:
			your_ready_button.text = "Ready ✓"
		else:
			your_ready_button.text = "Ready"
		your_gold_input.editable = true
		_enable_inventory_interaction()

func _update_offer_grid(grid: GridContainer, items: Dictionary):
	# Clear all item slots first
	for child in grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill item slots with trade items
	var slot_index: int = 0
	for item_id in items:
		var quantity = items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			# Find the next available Panel slot
			if slot_index < grid.get_child_count():
				var item_slot_panel = grid.get_child(slot_index)
				if item_slot_panel is Panel and item_slot_panel.has_method("set_item_data"):
					item_slot_panel.set_item_data(item_id, item, quantity)
					slot_index += 1

func _populate_trade_inventory():
	# Clear all item slots first
	for child in player_inv_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill item slots with inventory items
	var slot_index: int = 0
	for item_id: int in inventory.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry: Dictionary = inventory[item_id]
			var stack: int = int(entry.get("stack", 1))
			
			# Find the next available Panel slot
			if slot_index < player_inv_grid.get_child_count():
				var item_slot_panel = player_inv_grid.get_child(slot_index)
				if item_slot_panel is Panel and item_slot_panel.has_method("set_item_data"):
					item_slot_panel.set_item_data(item_id, item, stack)
					slot_index += 1

func _add_item_to_trade(item_id: int, quantity: int):
	var available = inventory.get(item_id, {}).get("stack", 0)
	var currently_offered = your_trade_items.get(item_id, 0)
	
	if currently_offered + quantity <= available:
		if your_trade_items.has(item_id):
			your_trade_items[item_id] += quantity
		else:
			your_trade_items[item_id] = quantity
	
	_update_trade_ui()
	_send_trade_update()

func _send_trade_update():
	InstanceClient.current.request_data(&"trade.update", Callable(), {
		"session_id": trade_session_id,
		"items": your_trade_items,
		"gold": your_trade_gold
	})

func _on_your_ready_pressed():
	your_ready = not your_ready
	_update_trade_ui()
	# Send confirmation status to server
	InstanceClient.current.request_data(&"trade.confirm", Callable(), {
		"session_id": trade_session_id,
		"ready": your_ready
	})

func _on_gold_input_changed(new_text: String):
	# Only process numeric characters
	var numeric_only = ""
	for c in new_text:
		if c.is_valid_int():
			numeric_only += c
	
	# Update the gold amount
	your_trade_gold = int(numeric_only) if numeric_only != "" else 0
	
	# If the text contains non-numeric characters, update the field to show only numbers
	if new_text != numeric_only:
		your_gold_input.text = numeric_only
		# Move cursor to end
		your_gold_input.caret_column = numeric_only.length()
		return  # Don't send update yet, it will be sent when the corrected text triggers this again
	
	_send_trade_update()

func _close_trade():
	trade_view.hide()
	$EquipmentView.show()
	_reset_trade_state()

func _reset_trade_state():
	trade_session_id = -1
	other_player_name = ""
	other_player_peer = -1
	your_trade_items = {}
	their_trade_items = {}
	your_trade_gold = 0
	their_trade_gold = 0
	your_ready = false
	their_ready = false
	trade_locked = false

func _disable_inventory_interaction():
	# Disable inventory interactions during locked trade
	pass

func _enable_inventory_interaction():
	# Re-enable inventory interactions
	pass


# Tab switching logic
func _on_tab_button_pressed(tab_index: int) -> void:
	# Hide all views
	$EquipmentView.hide()
	$TradeView.hide()
	$MaterialsView.hide()
	crafting_view.hide()
	
	# Show appropriate view based on tab
	match tab_index:
		0: # Equipment
			$EquipmentView.show()
		1: # Materials  
			$MaterialsView.show()
		2: # Consumables
			$EquipmentView.show() # For now, show equipment view
		3: # Key Items
			$EquipmentView.show() # For now, show equipment view
		4: # Crafting
			crafting_view.show()
			_load_crafting_data()


# Crafting system methods
func _load_crafting_data() -> void:
	# Request available recipes from server
	InstanceClient.current.request_data(&"craft.get_recipes", _on_recipes_received)

func _on_recipes_received(data: Dictionary) -> void:
	print("=== RECIPES RECEIVED DEBUG ===")
	print("Raw server data: ", data)
	
	player_class = data.get("player_class", "")
	player_level = data.get("player_level", 0)
	
	print("Player class: '", player_class, "'")
	print("Player level: ", player_level)
	
	# Load all recipes from registry
	available_recipes.clear()
	var registry = ContentRegistryHub.registry_of(&"recipes")
	if registry:
		print("✅ Recipes registry found")
		# Get all recipe IDs and load them
		for recipe_id in range (1,146):
			var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
			if recipe:
				print("✅ Loaded recipe: ", recipe.recipe_name)
				available_recipes.append(recipe)
			else:
				print("❌ Failed to load recipe ID: ", recipe_id)
	else:
		print("❌ Recipes registry not found!")
	
	print("Total recipes loaded: ", available_recipes.size())
	print("===============================")
	
	_populate_recipe_list()
	_setup_class_filter()

func _populate_recipe_list() -> void:
	# Clear existing recipe buttons
	for child in recipe_grid.get_children():
		child.queue_free()
	
	# Create recipe buttons
	for recipe in available_recipes:
		var recipe_button = _create_recipe_button(recipe)
		recipe_grid.add_child(recipe_button)

func _create_recipe_button(recipe: CraftingRecipe) -> Button:
	print("Creating button for recipe: ", recipe.recipe_name)
	
	var button = Button.new()
	button.text = recipe.recipe_name
	button.custom_minimum_size = Vector2(200, 60)
	
	# Set visual state based on availability
	var can_craft = recipe.can_craft(player_class, player_level)
	var has_materials = _check_recipe_materials(recipe)
	
	print("  - Player class: '", player_class, "' vs Required: '", recipe.required_class, "'")
	print("  - Player level: ", player_level, " vs Required: ", recipe.required_level)
	print("  - Can craft: ", can_craft)
	print("  - Has materials: ", has_materials)
	
	if not can_craft:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5, 0.7) # Dimmed
		print("  - Button state: LOCKED (wrong class/level)")
	elif not has_materials:
		# DON'T disable button - player can click to see what's missing
		button.modulate = Color(1, 0.8, 0.8, 0.8) # Slightly red
		print("  - Button state: MISSING MATERIALS (clickable)")
	else:
		button.modulate = Color.WHITE
		print("  - Button state: AVAILABLE")
	
	button.pressed.connect(_on_recipe_selected.bind(recipe))
	return button

func _check_recipe_materials(recipe: CraftingRecipe) -> bool:
	var inputs = recipe.get_inputs()
	for input in inputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", input.slug)
		if item_id <= 0:
			return false
		
		var inv_entry = inventory.get(item_id, {})
		var available = inv_entry.get("stack", 0)
		
		if available < input.quantity:
			return false
	
	return true

func _setup_class_filter() -> void:
	if not class_filter:
		return
	
	class_filter.clear()
	class_filter.add_item("All Classes")
	class_filter.add_item("Miner")
	class_filter.add_item("Forager") 
	class_filter.add_item("Trapper")
	class_filter.add_item("Blacksmith")
	class_filter.add_item("Culinarian")
	class_filter.add_item("Artisan")

func _on_recipe_selected(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	_update_recipe_details()

func _update_recipe_details() -> void:
	if not selected_recipe:
		recipe_name_label.text = "Select a recipe"
		recipe_description.text = "Choose a recipe from the list to see details."
		craft_button.disabled = true
		status_label.text = ""
		return
	
	# Update recipe info
	recipe_name_label.text = selected_recipe.recipe_name
	recipe_description.text = selected_recipe.description
	
	# Clear and populate inputs
	_clear_container(inputs_container)
	var inputs = selected_recipe.get_inputs()
	for input in inputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", input.slug)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var input_label = Label.new()
			var available = inventory.get(item_id, {}).get("stack", 0)
			input_label.text = "%s x%d (Have: %d)" % [item.item_name, input.quantity, available]
			if available < input.quantity:
				input_label.modulate = Color(1, 0.5, 0.5)
			inputs_container.add_child(input_label)
	
	# Clear and populate outputs
	_clear_container(outputs_list)
	var outputs = selected_recipe.get_outputs()
	for output in outputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", output.slug)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var output_label = Label.new()
			output_label.text = "%s x%d" % [item.item_name, output.quantity]
			outputs_list.add_child(output_label)
	
	# Clear and populate costs
	_clear_container(costs_list)
	if selected_recipe.gold_cost > 0:
		var gold_label = Label.new()
		gold_label.text = "Gold: %d (Have: %d)" % [selected_recipe.gold_cost, current_gold]
		if current_gold < selected_recipe.gold_cost:
			gold_label.modulate = Color(1, 0.5, 0.5)
		costs_list.add_child(gold_label)
	
	if selected_recipe.energy_cost > 0:
		var energy_label = Label.new()
		energy_label.text = "Energy: %.1f" % selected_recipe.energy_cost
		costs_list.add_child(energy_label)
	
	# Update craft button and status
	var can_craft = selected_recipe.can_craft(player_class, player_level)
	var has_materials = _check_recipe_materials(selected_recipe)
	var has_gold = current_gold >= selected_recipe.gold_cost
	
	craft_button.disabled = not (can_craft and has_materials and has_gold)
	
	if not can_craft:
		status_label.text = "Requires %s level %d" % [selected_recipe.required_class, selected_recipe.required_level]
	elif not has_materials:
		status_label.text = "Missing required materials"
	elif not has_gold:
		status_label.text = "Not enough gold"
	else:
		status_label.text = "Ready to craft!"

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_craft_button_pressed() -> void:
	if not selected_recipe:
		return
	
	# Get recipe ID
	var recipe_id = ContentRegistryHub.id_from_slug(&"recipes", selected_recipe.slug)
	if recipe_id <= 0:
		status_label.text = "Recipe not found!"
		return
	
	# Request crafting from server
	InstanceClient.current.request_data(&"craft.execute", _on_craft_response, {
		"recipe_id": recipe_id
	})

func _on_craft_response(data: Dictionary) -> void:
	if data.get("success", false):
		status_label.text = "Crafted successfully!"
		# Refresh inventory to show new items
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)
		# Refresh recipe details to update material counts
		_update_recipe_details()
	else:
		status_label.text = "Error: " + data.get("error", "Unknown error")

func _on_class_filter_changed(index: int) -> void:
	_filter_recipes()

func _on_search_text_changed(new_text: String) -> void:
	_filter_recipes()

func _filter_recipes() -> void:
	# Clear existing recipe buttons
	for child in recipe_grid.get_children():
		child.queue_free()
	
	# Get filter criteria
	var selected_class_index = class_filter.selected if class_filter else 0
	var search_text = search_box.text.to_lower() if search_box else ""
	
	# Map class filter index to class name
	var class_names = ["", "miner", "forager", "trapper", "blacksmith", "culinarian", "artisan"]
	var filter_class = class_names[selected_class_index] if selected_class_index < class_names.size() else ""
	
	# Filter and display recipes
	for recipe in available_recipes:
		# Apply class filter (0 = "All Classes")
		if filter_class != "" and recipe.required_class != filter_class:
			continue
		
		# Apply search filter
		if search_text != "" and not recipe.recipe_name.to_lower().contains(search_text):
			continue
		
		# Recipe passes all filters - create and add button
		var recipe_button = _create_recipe_button(recipe)
		recipe_grid.add_child(recipe_button)
