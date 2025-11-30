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

# Trade quantity dialog variables
var trade_quantity_dialog: AcceptDialog = null
var trade_quantity_label: Label = null
var trade_quantity_spinbox: SpinBox = null
var trade_quantity_max_button: Button = null
var selected_trade_item_id: int = -1
var selected_trade_item_stack: int = 0

# Gold tracking
var current_gold: int = 0

# Energy tracking
var current_energy: float = 0.0
var current_energy_max: float = 100.0
var _energy_update_timer: float = 0.0
const ENERGY_UPDATE_THROTTLE: float = 0.5  # Only update UI every 0.5s

# XP/Level tracking
var current_exp: int = 0
var exp_required: int = 100
var current_level_display: int = 1

# Crafting system variables
var available_recipes: Array = []
var selected_recipe: CraftingRecipe = null
var player_class: String = ""
var player_level: int = 0

# Preload popup scenes to avoid runtime hitch
const CRAFT_XP_POPUP_SCENE = preload("res://source/client/ui/hud/craft_xp_popup.tscn")
const LEVEL_UP_POPUP_SCENE = preload("res://source/client/ui/hud/level_up_popup.tscn")

# View references
@onready var equipment_view: Control = $EquipmentView
@onready var materials_view: Control = $MaterialsView

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


# Gold display @onready references
@onready var equipment_gold_label: Label = $EquipmentView/HBoxContainer/VBoxContainer2/GoldDisplay/Label
@onready var trade_gold_label: Label = $TradeView/Screen/HBoxContainer/GoldDisplay/Label

# Crafting UI @onready references
@onready var crafting_view: Control = $CraftingView
@onready var recipe_grid: GridContainer = $CraftingView/HBoxContainer/VBoxContainer/RecipeList/RecipeGrid
@onready var class_filter: OptionButton = $CraftingView/HBoxContainer/VBoxContainer/FilterContainer/ClassFilter
@onready var search_box: LineEdit = $CraftingView/HBoxContainer/VBoxContainer/FilterContainer/SearchBox
@onready var crafting_level_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/StatsContainer/LevelLabel
@onready var crafting_exp_bar: ProgressBar = $CraftingView/HBoxContainer/VBoxContainer2/StatsContainer/ExpBar
@onready var crafting_energy_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/StatsContainer/EnergyLabel
@onready var crafting_energy_bar: ProgressBar = $CraftingView/HBoxContainer/VBoxContainer2/StatsContainer/EnergyBar
@onready var recipe_name_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RecipeName
@onready var recipe_description: RichTextLabel = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RecipeDescription
@onready var requirements_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RequirementsContainer/RequirementsLabel
@onready var inputs_container: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/RequirementsContainer/InputsContainer
@onready var outputs_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/OutputsContainer/OutputsLabel
@onready var outputs_list: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/OutputsContainer/OutputsList
@onready var costs_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/CostsContainer/CostsLabel
@onready var costs_list: VBoxContainer = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/CostsContainer/CostsList
@onready var craft_button: Button = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/CraftButton
@onready var status_label: Label = $CraftingView/HBoxContainer/VBoxContainer2/RecipeDetails/StatusLabel

# Inventory tabs reference
@onready var inventory_tabs: Control = $InventoryTabs


func _ready() -> void:
	print("Inventory menu _ready() called")
	InstanceClient.current.request_data(&"inventory.get", fill_inventory)
	visibility_changed.connect(_on_visibility_changed)
	
	# Setup trade quantity dialog
	_setup_trade_quantity_dialog()
	
	# Trade system setup
	your_ready_button.pressed.connect(_on_your_ready_pressed)
	your_gold_input.text_submitted.connect(_on_gold_input_submitted)
	your_gold_input.gui_input.connect(_on_gold_input_gui_input)
	close_button.pressed.connect(_on_close_button_pressed)

	# Subscribe to trade events
	InstanceClient.subscribe(&"trade.open", _on_trade_open)
	InstanceClient.subscribe(&"trade.update", _on_trade_update)
	InstanceClient.subscribe(&"trade.complete", _on_trade_complete)
	InstanceClient.subscribe(&"trade.cancel", _on_trade_cancel)
	
	# Subscribe to gold updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	
	# Subscribe to exp updates (for level up popup and XP bar)
	InstanceClient.subscribe(&"exp.update", _on_exp_update)
	
	# Request initial gold amount
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	
	# Request initial level/exp data
	InstanceClient.current.request_data(&"level.get", _on_level_received)
	
	# Setup energy tracking
	Events.local_player_ready.connect(_on_local_player_ready)
	# If local player already exists, set it up immediately
	if Events.local_player:
		_on_local_player_ready(Events.local_player)
	
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
	
	# Connect to language change events
	EventBus.language_changed.connect(_update_ui_text)
	
	# Initialize view visibility - hide all except equipment
	equipment_view.show()
	materials_view.hide()
	trade_view.hide()
	crafting_view.hide()
	
	# Update UI text on startup
	_update_ui_text()



func _setup_trade_quantity_dialog() -> void:
	"""Create trade quantity dialog"""
	trade_quantity_dialog = AcceptDialog.new()
	trade_quantity_dialog.title = TranslationServer.translate("trade_dialog_title")
	trade_quantity_dialog.dialog_hide_on_ok = true
	trade_quantity_dialog.min_size = Vector2(300, 150)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	trade_quantity_dialog.add_child(vbox)
	
	trade_quantity_label = Label.new()
	trade_quantity_label.text = TranslationServer.translate("trade_dialog_question")
	trade_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(trade_quantity_label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	
	var qty_label = Label.new()
	qty_label.text = TranslationServer.translate("trade_dialog_label_quantity")
	hbox.add_child(qty_label)
	
	trade_quantity_spinbox = SpinBox.new()
	trade_quantity_spinbox.min_value = 1
	trade_quantity_spinbox.max_value = 999
	trade_quantity_spinbox.value = 1
	trade_quantity_spinbox.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(trade_quantity_spinbox)
	
	# Add Max button
	trade_quantity_max_button = Button.new()
	trade_quantity_max_button.text = TranslationServer.translate("trade_button_max")
	trade_quantity_max_button.custom_minimum_size = Vector2(60, 0)
	trade_quantity_max_button.pressed.connect(_on_trade_max_button_pressed)
	hbox.add_child(trade_quantity_max_button)
	
	add_child(trade_quantity_dialog)
	trade_quantity_dialog.confirmed.connect(_on_trade_quantity_confirmed)


func _process(delta: float) -> void:
	_energy_update_timer += delta


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)
		InstanceClient.current.request_data(&"gold.get", _on_gold_received)
		
		# If we have an active trade session when becoming visible, show TradeView
		if trade_session_id != -1:
			equipment_view.hide()
			materials_view.hide()
			trade_view.show()

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

func _on_local_player_ready(local_player: LocalPlayer) -> void:
	var ability_system_component: AbilitySystemComponent = local_player.get_node_or_null(^"AbilitySystemComponent")
	if not ability_system_component:
		return
	ability_system_component.mirror.attribute_local_changed.connect(_on_player_attribute_changed)
	
	# Get initial energy value and max
	current_energy = ability_system_component.mirror.get_value(&"energy")
	current_energy_max = ability_system_component.mirror.get_max(&"energy")
	print("Inventory menu: Initial energy set to ", current_energy, "/", current_energy_max)
	_update_crafting_bars()

func _on_player_attribute_changed(attr: StringName, value: float, max_value: float) -> void:
	if attr == &"energy":
		# Store energy values but don't update UI unless crafting view is visible
		current_energy = value
		current_energy_max = max_value
		
		# Only update UI if crafting view is visible AND enough time has passed
		if not crafting_view.visible:
			return
			
		if _energy_update_timer >= ENERGY_UPDATE_THROTTLE:
			print("Inventory menu: Energy changed to ", current_energy, "/", current_energy_max)
			_energy_update_timer = 0.0
			_update_crafting_bars()
			
			# Only update costs/status if we have a recipe with energy cost (lightweight update)
			if selected_recipe and selected_recipe.energy_cost > 0:
				_update_recipe_costs_and_status()  # Don't rebuild UI, just update labels

func _on_level_received(data: Dictionary) -> void:
	current_level_display = data.get("level", 1)
	player_level = current_level_display  # Also update player_level used for recipe filtering
	current_exp = data.get("experience", 0)
	exp_required = data.get("exp_required", 100)
	_update_crafting_bars()


func fill_inventory(inv_data: Dictionary) -> void:
	inventory = inv_data
	var slot_index: int = 0
	
	# Clear all slots first
	_clear_all_inventory_slots()
	
	# Get equipped item ID to exclude from grid
	var local_player = Events.local_player
	if local_player == null:
		local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
	var equipped_id: int = -1
	if local_player and local_player.player_resource:
		equipped_id = local_player.player_resource.equipped_accessory_id
	
	# Fill slots with items
	for item_id: int in inv_data.keys():
		# Skip equipped items - they show in equipment slot instead
		if item_id == equipped_id:
			print("[Inventory] Skipping equipped item ID %d (shown in AccessorySlot)" % item_id)
			continue
		
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		print("[Inventory] Loaded item ID %d: %s (Class: %s, Is EquipmentItem: %s)" % [
			item_id,
			item.item_name if item else "NULL",
			item.get_class() if item else "NULL",
			item is EquipmentItem if item else false
		])
		if item:
			var entry: Dictionary = inv_data[item_id]
			var stack: int = int(entry.get("stack", 1))
			
			# Find the next available Panel slot (skip Button nodes)
			var item_slot_panel: Panel = _get_next_panel_slot(slot_index)
			if item_slot_panel and item_slot_panel.has_method("set_item_data"):
				item_slot_panel.set_item_data(item_id, item, stack)
				gear_slots_cache.set(item_slot_panel, item)
				slot_index += 1
	
	# Update equipment slots (skip new Panel-based slots like EquipmentSlot)
	for child in equipment_slots.get_children():
		if child is GearSlotButton:
			var equipment_slot: GearSlotButton = child as GearSlotButton
			if equipment_slot.gear_slot:
				if equipment_slot.gear_slot == null:
					equipment_slot.text = TranslationServer.translate("inventory_equipment_empty")
			else:
				equipment_slot.icon = null
				equipment_slot.text = TranslationServer.translate("inventory_equipment_locked")
	
	# Sync AccessorySlot with equipped item
	_sync_accessory_slot()
	
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
			# Show quantity dialog instead of auto-adding
			var item_id = item_data.item_id
			var available = inventory.get(item_id, {}).get("stack", 0)
			var currently_offered = your_trade_items.get(item_id, 0)
			var remaining = available - currently_offered
			
			if remaining <= 0:
				push_warning("No more of this item available to trade")
				return
			
			# Store selection and show dialog
			selected_trade_item_id = item_id
			selected_trade_item_stack = remaining
			
			var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
			if item:
				var translated_name = ItemTooltipManager._get_translated_item_name(item)
				trade_quantity_label.text = TranslationServer.translate("inventory_trade_item").format({"item": translated_name})
				trade_quantity_spinbox.max_value = remaining
				trade_quantity_spinbox.value = min(1, remaining)
				trade_quantity_dialog.popup_centered()
			
			return
	
	# Original inventory logic
	var item_data = item_slot_panel.item_data
	if item_data.has("item") and item_data.item:
		selected_item = item_data.item
		selected_item_id = item_data.get("item_id", -1)
		rich_text_label.text = item_data.item.description
		
		print("[Inventory] Selected item: %s (Class: %s, Is EquipmentItem: %s)" % [
			selected_item.item_name,
			selected_item.get_class(),
			selected_item is EquipmentItem
		])
		
		if selected_item is EquipmentItem:
			var eq_item = selected_item as EquipmentItem
			print("[Inventory] EquipmentItem slot: %s (key: %s)" % [
				eq_item.slot.display_name if eq_item.slot else "NULL",
				eq_item.slot.key if eq_item.slot else "NULL"
			])
		
		# Show equip button for equipment items
		var equip_hbox = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/HBoxContainer")
		var equip_button = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/HBoxContainer/Button")
		
		if selected_item is EquipmentItem:
			print("[Inventory] EquipmentItem detected!")
			var equipment_item := selected_item as EquipmentItem
			
			# Check if this item is currently equipped
			var local_player = Events.local_player
			if local_player == null:
				local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
			
			var is_equipped := false
			if local_player and local_player.player_resource:
				# Check if this item ID matches the equipped accessory ID
				is_equipped = (local_player.player_resource.equipped_accessory_id == selected_item_id)
			
			print("  → Item equipped: %s" % is_equipped)
			
			if equip_hbox:
				equip_hbox.visible = true
			
			if equip_button:
				# Show "Equip" or "Unequip" based on current state
				if is_equipped:
					equip_button.text = "Unequip"
				else:
					equip_button.text = "Equip"
				
				equip_button.visible = true
				equip_button.disabled = false
				
				# Reconnect signal to handle both equip and unequip
				if equip_button.pressed.is_connected(_on_equip_button_pressed):
					equip_button.pressed.disconnect(_on_equip_button_pressed)
				equip_button.pressed.connect(_on_equip_button_pressed)
				
				print("  → Button text: '%s', visible: %s" % [equip_button.text, equip_button.visible])
		else:
			# Hide equip button for non-equipment items
			if equip_hbox and not (selected_item is GearItem or selected_item is WeaponItem):
				equip_hbox.visible = false


func _on_trade_quantity_confirmed() -> void:
	"""Handle trade quantity dialog confirmation"""
	if selected_trade_item_id == -1:
		return
	
	var quantity = int(trade_quantity_spinbox.value)
	
	if your_trade_items.has(selected_trade_item_id):
		your_trade_items[selected_trade_item_id] += quantity
	else:
		your_trade_items[selected_trade_item_id] = quantity
	
	_update_trade_ui()
	_send_trade_update()
	
	# Reset selection
	selected_trade_item_id = -1
	selected_trade_item_stack = 0


func _on_trade_max_button_pressed() -> void:
	"""Set quantity to maximum available"""
	trade_quantity_spinbox.value = trade_quantity_spinbox.max_value


func _on_equip_button_pressed() -> void:
	print("\n========== EQUIP BUTTON PRESSED ==========")
	print("[Inventory] Selected item: %s" % (selected_item.item_name if selected_item else "NULL"))
	print("[Inventory] Selected item ID: %d" % selected_item_id)
	print("[Inventory] Item type: %s" % (selected_item.get_class() if selected_item else "NULL"))
	
	if selected_item is GearItem or selected_item is WeaponItem:
		if selected_item_id != -1:
			InstanceClient.current.request_data(
				&"item.equip",
				Callable(),
				{"id": selected_item_id}
			)
	elif selected_item is EquipmentItem:
		# Handle equipment items (cosmetic accessories)
		print("[Inventory] Item is EquipmentItem!")
		
		var equipment_item := selected_item as EquipmentItem
		var slot_type: String = "accessory"
		if equipment_item.slot:
			slot_type = equipment_item.slot.key
		
		# Get the button to check its text
		var equip_button = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/HBoxContainer/Button")
		if not equip_button:
			print("  ✗ No equip button found!")
			return
		
		# Check button text to determine action (simpler than checking equipped state again)
		var is_unequip: bool = (equip_button.text == "Unequip")
		print("  → Button text: '%s', Action: %s" % [equip_button.text, "UNEQUIP" if is_unequip else "EQUIP"])
		
		if is_unequip:
			# UNEQUIP
			print("[Inventory] Unequipping EquipmentItem...")
			print("  → Sending server request: item.unequip_cosmetic")
			print("  → Slot: %s" % slot_type)
			
			InstanceClient.current.request_data(
				&"item.unequip_cosmetic",
				func(response: Dictionary):
					print("[Inventory] Unequip response received: %s" % response)
					if response.get("ok", false):
						print("  [OK] Successfully unequipped from %s slot!" % response.get("unequipped_slot", "slot"))
						# Update button to show "Equip"
						var btn = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/HBoxContainer/Button")
						if btn:
							btn.text = "Equip"
						
						# Clear the AccessorySlot visual
						var accessory_slot = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/EquipmentSlots/AccessorySlot")
						if accessory_slot and accessory_slot.has_method("clear_slot"):
							accessory_slot.clear_slot()
							print("  → Cleared AccessorySlot visual")
						
						# Refresh inventory to show item back in grid
						InstanceClient.current.request_data(&"inventory.get", fill_inventory)
					else:
						print("  ✗ Failed to unequip: %s" % response.get("error", "Unknown error")),
				{
					"slot": slot_type
				}
			)
		else:
			# EQUIP
			print("[Inventory] Equipping EquipmentItem...")
			print("  → Sending server request: item.equip_cosmetic")
			print("  → Item ID: %d, Slot: %s" % [selected_item_id, slot_type])
			
			InstanceClient.current.request_data(
				&"item.equip_cosmetic",
				func(response: Dictionary):
					print("[Inventory] Equip response received: %s" % response)
					if response.get("ok", false):
						print("  [OK] Successfully equipped %s!" % response.get("item_name", "item"))
						# Update button to show "Unequip"
						var btn = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/ItemInfo/VBoxContainer/HBoxContainer/Button")
						if btn:
							btn.text = "Unequip"
						
						# Update the AccessorySlot visual
						var accessory_slot = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/EquipmentSlots/AccessorySlot")
						if accessory_slot and accessory_slot.has_method("set_equipped_item"):
							accessory_slot.set_equipped_item(selected_item_id, selected_item)
							print("  → Updated AccessorySlot visual with %s" % selected_item.item_name)
						
						# Refresh inventory to remove item from grid
						InstanceClient.current.request_data(&"inventory.get", fill_inventory)
					else:
						print("  ✗ Failed to equip: %s" % response.get("error", "Unknown error")),
				{
					"item_id": selected_item_id,
					"slot": slot_type
				}
			)


func _sync_accessory_slot() -> void:
	"""Sync the AccessorySlot visual with the player's equipped item"""
	var local_player = Events.local_player
	if local_player == null:
		local_player = get_tree().get_root().find_child("LocalPlayer", true, false)
	
	if not local_player or not local_player.player_resource:
		return
	
	var equipped_id: int = local_player.player_resource.equipped_accessory_id
	var accessory_slot = get_node_or_null("EquipmentView/HBoxContainer/VBoxContainer2/EquipmentSlots/AccessorySlot")
	
	if not accessory_slot:
		return
	
	if equipped_id == -1:
		# Nothing equipped - clear slot
		if accessory_slot.has_method("clear_slot"):
			accessory_slot.clear_slot()
	else:
		# Item equipped - show it in slot
		var item: Item = ContentRegistryHub.load_by_id(&"items", equipped_id)
		if item and item is EquipmentItem:
			if accessory_slot.has_method("set_equipped_item"):
				accessory_slot.set_equipped_item(equipped_id, item)
				print("[Inventory] Synced AccessorySlot with equipped item: %s" % item.item_name)


func _find_equipment_slot_for_item(item: EquipmentItem) -> Node:
	"""Find the equipment slot node that matches the item's slot property"""
	if not item.slot:
		print("[Inventory] Item has no slot property!")
		return null
	
	if not equipment_slots:
		print("[Inventory] equipment_slots not found!")
		return null
	
	print("[Inventory] Looking for slot matching: %s" % item.slot.key)
	print("[Inventory] Available equipment slots:")
	for child in equipment_slots.get_children():
		if child is EquipmentSlot:
			var slot = child as EquipmentSlot
			print("  - EquipmentSlot '%s': slot key = %s" % [slot.name, slot.gear_slot.key if slot.gear_slot else "NULL"])
		elif child is GearSlotButton:
			var slot = child as GearSlotButton
			print("  - GearSlotButton '%s': slot key = %s" % [slot.name, slot.gear_slot.key if slot.gear_slot else "NULL"])
	
	# Iterate through all equipment slots to find a match
	for child in equipment_slots.get_children():
		# Check EquipmentSlot (Panel-based)
		if child is EquipmentSlot:
			var slot = child as EquipmentSlot
			if slot.gear_slot and item.slot and slot.gear_slot.key == item.slot.key:
				print("  [OK] Found matching EquipmentSlot: %s (key: %s)" % [slot.name, slot.gear_slot.key])
				return slot
		
		# Check GearSlotButton (Button-based) - though EquipmentItem might not use these
		if child is GearSlotButton:
			var slot = child as GearSlotButton
			if slot.gear_slot and item.slot and slot.gear_slot.key == item.slot.key:
				print("  [OK] Found matching GearSlotButton: %s (key: %s)" % [slot.name, slot.gear_slot.key])
				return slot
	
	print("  ✗ No matching slot found!")
	return null


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
	# Play close sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_close()
	
	if trade_view.visible:
		# Cancel trade if in trade view
		if trade_session_id != -1:
			InstanceClient.current.request_data(&"trade.cancel", Callable(), {
				"session_id": trade_session_id
			})
		_close_trade()
	else:
		# Normal close behavior with animation
		if has_node("/root/UIAnimations"):
			get_node("/root/UIAnimations").animate_panel_close(self)
		else:
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
	
	your_offer_title.text = TranslationServer.translate("inventory_trade_your_offer")
	their_offer_title.text = other_player_name + "'s Offer"
	
	# Switch to trade view and hide other UI elements
	equipment_view.hide()
	materials_view.hide()
	crafting_view.hide()
	inventory_tabs.hide()  # Hide tabs during trade
	
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
	their_gold_label.text = TranslationServer.translate("inventory_trade_gold").format({"amount": their_trade_gold})
	
	# Update button states
	if trade_locked:
		your_ready_button.disabled = true
		your_ready_button.text = TranslationServer.translate("inventory_trade_locked")
		your_gold_input.editable = false
		_disable_inventory_interaction()
	else:
		your_ready_button.disabled = false
		if your_ready:
			your_ready_button.text = TranslationServer.translate("inventory_trade_ready_check")
		else:
			your_ready_button.text = TranslationServer.translate("inventory_trade_ready")
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
	# Commit any pending gold input before marking ready
	_commit_pending_gold_input()
	
	your_ready = not your_ready
	_update_trade_ui()
	# Send confirmation status to server
	InstanceClient.current.request_data(&"trade.confirm", Callable(), {
		"session_id": trade_session_id,
		"ready": your_ready
	})

func _on_gold_input_gui_input(event: InputEvent):
	"""Filter input to only allow numeric characters and prevent exceeding gold balance"""
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.as_text_keycode()
		# Allow navigation keys
		if key in ["Backspace", "Delete", "Left", "Right", "Home", "End"]:
			return
		
		# Check if it's a numeric key
		if key.is_valid_int():
			# Preview what the text would be after this key press
			var current_text = your_gold_input.text
			var caret_pos = your_gold_input.caret_column
			var preview_text = current_text.insert(caret_pos, key)
			
			# Check if the new value would exceed current gold
			var preview_value = int(preview_text) if preview_text.is_valid_int() else 0
			if preview_value > current_gold:
				get_viewport().set_input_as_handled()
				return
		else:
			# Block non-numeric keys
			get_viewport().set_input_as_handled()

func _on_gold_input_submitted(new_text: String):
	"""Called when user presses Enter or loses focus"""
	var gold_value = int(new_text) if new_text.is_valid_int() else 0
	# Clamp to available gold
	gold_value = min(gold_value, current_gold)
	your_trade_gold = gold_value
	your_gold_input.text = str(your_trade_gold)
	_send_trade_update()

func _commit_pending_gold_input() -> void:
	"""Ensure the gold input field value is sent to server before marking ready"""
	if not your_gold_input:
		return
	
	# Parse the current text value
	var text = your_gold_input.text.strip_edges()
	var gold_value = 0
	
	if text.length() > 0:
		# Remove thousand separators (both . and ,) and parse
		var cleaned = text.replace(".", "").replace(",", "")
		gold_value = int(cleaned) if cleaned.is_valid_int() else 0
	
	# Clamp to available gold
	gold_value = clampi(gold_value, 0, current_gold)
	
	# If the parsed value differs from what we last sent, send an update
	# (This handles the case where user typed but didn't press Enter)
	if gold_value != your_trade_gold:
		your_trade_gold = gold_value
		your_gold_input.text = str(your_trade_gold)
		_send_trade_update()

func _close_trade():
	trade_view.hide()
	equipment_view.show()
	inventory_tabs.show()  # Show tabs again when trade closes
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
	# Play tab switch sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_select()
	show_tab(tab_index)


func show_tab(tab_index: int) -> void:
	"""Switch to a specific tab view"""
	# Play tab switch sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_select()
	
	# Get the view to show
	var target_view: Control = null
	match tab_index:
		0: # Equipment
			target_view = equipment_view
		1: # Materials  
			target_view = materials_view
		2: # Consumables
			target_view = equipment_view # For now, show equipment view
		3: # Key Items
			target_view = equipment_view # For now, show equipment view
		4: # Crafting
			target_view = crafting_view
			_load_crafting_data()
			# Update energy display immediately when showing crafting view
			_update_crafting_bars()
	
	# Animate tab switch with crossfade
	var anim = _get_ui_animations()
	if anim and target_view:
		# Find current visible view
		var current_view: Control = null
		if equipment_view.visible:
			current_view = equipment_view
		elif materials_view.visible:
			current_view = materials_view
		elif crafting_view.visible:
			current_view = crafting_view
		elif trade_view.visible:
			current_view = trade_view
		
		# Hide all views first
		equipment_view.hide()
		trade_view.hide()
		materials_view.hide()
		crafting_view.hide()
		
		# Show and animate the target view
		if current_view and current_view != target_view:
			anim.crossfade(current_view, target_view, 0.15)
		else:
			anim.fade_in(target_view, 0.15)
	else:
		# Fallback: just show/hide without animation
		equipment_view.hide()
		trade_view.hide()
		materials_view.hide()
		crafting_view.hide()
		if target_view:
			target_view.show()


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
		print("[OK] Recipes registry found")
		# Load the content index to get all recipe entries
		var recipes_index: ContentIndex = load("res://source/common/registry/indexes/recipes_index.tres")
		if recipes_index:
			print("[OK] Recipes index loaded with ", recipes_index.entries.size(), " entries")
			# Iterate through all entries in the registry
			for entry in recipes_index.entries:
				var recipe_id: int = entry.get(&"id", 0)
				if recipe_id == 0:
					continue
				var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
				if recipe:
					print("[OK] Loaded recipe: ", recipe.recipe_name, " (ID: ", recipe_id, ")")
					available_recipes.append(recipe)
				else:
					print("❌ Failed to load recipe ID: ", recipe_id)
		else:
			print("❌ Failed to load recipes index!")
	else:
		print("❌ Recipes registry not found!")
	
	print("Total recipes loaded: ", available_recipes.size())
	print("===============================")
	
	_setup_class_filter()
	_set_default_class_filter()
	_filter_recipes()  # Use filter instead of populate to apply class filter

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
	button.custom_minimum_size = Vector2(200, 70)
	
	# Create HBoxContainer for the button content
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Get the first output item to show its icon
	var outputs = recipe.get_outputs()
	if outputs.size() > 0:
		var output = outputs[0]
		var item_id = ContentRegistryHub.id_from_slug(&"items", output.slug)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		
		if item and item.item_icon:
			# Add icon
			var icon_texture = TextureRect.new()
			icon_texture.texture = item.item_icon
			icon_texture.custom_minimum_size = Vector2(48, 48)
			icon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(icon_texture)
	
	# Create VBoxContainer for text content
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add recipe name
	var name_label = Label.new()
	name_label.text = recipe.recipe_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	# Add required level
	var level_label = Label.new()
	level_label.text = TranslationServer.translate("crafting_required_level").format({"level": recipe.required_level})
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(level_label)
	
	hbox.add_child(vbox)
	button.add_child(hbox)
	
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

func _set_default_class_filter() -> void:
	if not class_filter:
		return
	
	# Map player class to filter index
	var class_to_index = {
		"miner": 1,
		"forager": 2,
		"trapper": 3,
	}
	
	var player_class_lower = player_class.to_lower()
	if class_to_index.has(player_class_lower):
		class_filter.selected = class_to_index[player_class_lower]
	else:
		class_filter.selected = 0  # Default to "All Classes" if unknown

func _on_recipe_selected(recipe: CraftingRecipe) -> void:
	selected_recipe = recipe
	_update_recipe_details()

func _update_recipe_details() -> void:
	"""Full update of recipe details - rebuilds UI"""
	if not selected_recipe:
		recipe_name_label.text = TranslationServer.translate("crafting_select_recipe")
		recipe_description.text = TranslationServer.translate("crafting_select_recipe_desc")
		craft_button.disabled = true
		status_label.text = ""
		return
	
	# Update recipe info
	recipe_name_label.text = selected_recipe.recipe_name
	recipe_description.text = selected_recipe.description
	
	# Clear and populate inputs with ItemSlots in a grid
	_clear_container(inputs_container)
	var input_grid = GridContainer.new()
	input_grid.columns = 3  # 3 items per row
	input_grid.add_theme_constant_override("h_separation", 10)
	input_grid.add_theme_constant_override("v_separation", 10)
	inputs_container.add_child(input_grid)
	
	var inputs = selected_recipe.get_inputs()
	for input in inputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", input.slug)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var available = inventory.get(item_id, {}).get("stack", 0)
			var item_slot = _create_crafting_item_slot(item, input.quantity, available)
			input_grid.add_child(item_slot)
	
	# Clear and populate outputs with ItemSlots in a grid
	_clear_container(outputs_list)
	var output_grid = GridContainer.new()
	output_grid.columns = 3  # 3 items per row
	output_grid.add_theme_constant_override("h_separation", 10)
	output_grid.add_theme_constant_override("v_separation", 10)
	outputs_list.add_child(output_grid)
	
	var outputs = selected_recipe.get_outputs()
	for output in outputs:
		var item_id = ContentRegistryHub.id_from_slug(&"items", output.slug)
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var item_slot = _create_crafting_item_slot(item, output.quantity, -1)  # -1 means no "Have:" text
			output_grid.add_child(item_slot)
	
	# Populate costs and update status
	_update_recipe_costs_and_status()


func _update_recipe_costs_and_status() -> void:
	"""Updates only the cost labels and button state - does NOT rebuild UI"""
	if not selected_recipe:
		return
	
	# Clear and populate costs (still use labels for gold/energy)
	_clear_container(costs_list)
	if selected_recipe.gold_cost > 0:
		var gold_label = Label.new()
		gold_label.text = TranslationServer.translate("crafting_cost_gold").format({"required": selected_recipe.gold_cost, "have": current_gold})
		if current_gold < selected_recipe.gold_cost:
			gold_label.modulate = Color(1, 0.5, 0.5)
		costs_list.add_child(gold_label)
	
	if selected_recipe.energy_cost > 0:
		var energy_label = Label.new()
		energy_label.text = TranslationServer.translate("crafting_cost_energy").format({"required": "%.1f" % selected_recipe.energy_cost, "have": "%.1f" % current_energy})
		if current_energy < selected_recipe.energy_cost:
			energy_label.modulate = Color(1, 0.5, 0.5)
		costs_list.add_child(energy_label)
	
	# Update craft button and status
	var can_craft = selected_recipe.can_craft(player_class, player_level)
	var has_materials = _check_recipe_materials(selected_recipe)
	var has_gold = current_gold >= selected_recipe.gold_cost
	var has_energy = current_energy >= selected_recipe.energy_cost
	
	craft_button.disabled = not (can_craft and has_materials and has_gold and has_energy)
	
	if not can_craft:
		# Get translated class name
		var class_key = "crafting_filter_" + selected_recipe.required_class.to_lower()
		var class_display = TranslationServer.translate(class_key)
		status_label.text = TranslationServer.translate("crafting_status_level_required").format({"class": class_display, "level": selected_recipe.required_level})
	elif not has_materials:
		status_label.text = TranslationServer.translate("crafting_status_missing_materials")
	elif not has_gold:
		status_label.text = TranslationServer.translate("crafting_status_not_enough_gold")
	elif not has_energy:
		status_label.text = TranslationServer.translate("crafting_status_not_enough_energy")
	else:
		status_label.text = TranslationServer.translate("crafting_status_ready")

func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

# Helper function to create ItemSlots for crafting UI
func _create_crafting_item_slot(item: Item, required_quantity: int, available_quantity: int) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(64, 0)
	
	# Create the item slot panel
	var item_slot = Panel.new()
	item_slot.custom_minimum_size = Vector2(64, 64)
	item_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect hover events for tooltip
	item_slot.mouse_entered.connect(func(): ItemTooltipManager.show_item_tooltip(item, item_slot.get_global_mouse_position(), item_slot))
	item_slot.mouse_exited.connect(func(): ItemTooltipManager.hide_tooltip())
	
	# Add icon
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = item.item_icon
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.layout_mode = 1
	icon.anchors_preset = Control.PRESET_CENTER
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -24.0
	icon.offset_top = -24.0
	icon.offset_right = 24.0
	icon.offset_bottom = 24.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	item_slot.add_child(icon)
	
	# Add quantity label to the slot
	var amount_label = Label.new()
	amount_label.name = "ItemAmount"
	amount_label.text = str(required_quantity)
	amount_label.layout_mode = 1
	amount_label.anchors_preset = Control.PRESET_TOP_RIGHT
	amount_label.anchor_left = 1.0
	amount_label.anchor_top = 0.0
	amount_label.anchor_right = 1.0
	amount_label.anchor_bottom = 0.0
	amount_label.offset_left = -25.0
	amount_label.offset_top = 2.0
	amount_label.offset_right = -2.0
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.offset_bottom = 20.0
	amount_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	item_slot.add_child(amount_label)
	
	container.add_child(item_slot)
	
	# Show availability counter below the slot (for inputs)
	if available_quantity >= 0:
		var avail_label = Label.new()
		avail_label.text = "%d/%d" % [available_quantity, required_quantity]
		avail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avail_label.custom_minimum_size = Vector2(64, 0)
		if available_quantity < required_quantity:
			avail_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))  # Red
		else:
			avail_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))  # Green
		container.add_child(avail_label)
	
	return container

func _on_craft_button_pressed() -> void:
	if not selected_recipe:
		return
	
	# Play click sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_click()
	
	# Get recipe ID
	var recipe_id = ContentRegistryHub.id_from_slug(&"recipes", selected_recipe.slug)
	if recipe_id <= 0:
		status_label.text = TranslationServer.translate("crafting_recipe_not_found")
		return
	
	# Request crafting from server
	InstanceClient.current.request_data(&"craft.execute", _on_craft_response, {
		"recipe_id": recipe_id
	})

func _on_craft_response(data: Dictionary) -> void:
	if data.get("success", false):
		# Play success sound
		if has_node("/root/UISounds"):
			get_node("/root/UISounds").play_success()
		
		status_label.text = TranslationServer.translate("crafting_success")
		# Refresh inventory to show new items
		InstanceClient.current.request_data(&"inventory.get", _on_inventory_refreshed_after_craft)
		
		# Show XP popup if XP was gained
		if data.has("exp_gained") and data.exp_gained > 0:
			_show_craft_xp_popup(data.exp_gained)
	else:
		# Play error sound
		if has_node("/root/UISounds"):
			get_node("/root/UISounds").play_error()
		status_label.text = TranslationServer.translate("crafting_error").format({"error": data.get("error", "Unknown error")})

func _on_inventory_refreshed_after_craft(inv_data: Dictionary) -> void:
	# Update inventory data
	fill_inventory(inv_data)
	# Refresh the recipe list to update button states and maintain sorting
	_filter_recipes()
	# Refresh recipe details to update material counts
	_update_recipe_details()

func _show_craft_xp_popup(exp_amount: int) -> void:
	"""Create and display a crafting XP notification popup"""
	if not CRAFT_XP_POPUP_SCENE:
		print("[Craft] +%d XP" % exp_amount)
		return
	
	var popup: Control = CRAFT_XP_POPUP_SCENE.instantiate()
	popup.name = "CraftXpPopup_" + str(Time.get_ticks_msec())
	
	# Add to the scene tree (add to parent HUD or root)
	# We'll add it to the inventory menu itself for now
	add_child(popup)
	
	# Position popup next to the cursor
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	
	# Count existing popups to stack them
	var existing_popups: int = 0
	for child in get_children():
		if child.name.begins_with("CraftXpPopup_"):
			existing_popups += 1
	
	# Offset slightly to the right and stack vertically
	popup.position = Vector2(mouse_pos.x + 20.0, mouse_pos.y - 20.0 - (existing_popups * 50.0))
	
	# Setup the popup
	if popup.has_method("setup"):
		popup.setup(exp_amount)

func _on_exp_update(data: Dictionary) -> void:
	"""Handle exp updates - show level up popup if we're in crafting view and update bars"""
	var leveled_up: bool = data.get("leveled_up", false)
	var new_level: int = data.get("level", 1)
	
	# Update stored values
	current_level_display = new_level
	player_level = new_level  # Also update player_level used for recipe filtering
	current_exp = data.get("exp", current_exp)
	exp_required = data.get("exp_required", exp_required)
	
	# Update the crafting bars
	_update_crafting_bars()
	
	# If player leveled up and crafting view is visible, refresh recipe list to show newly unlocked recipes
	if leveled_up and crafting_view.visible:
		print("Player leveled up to ", new_level, " - refreshing recipe list")
		_filter_recipes()  # Refresh the recipe list to update available recipes
		_show_level_up_popup(new_level)

func _update_crafting_bars() -> void:
	"""Update the XP and Energy bars in the crafting view"""
	if crafting_level_label:
		crafting_level_label.text = TranslationServer.translate("level_display").format({"level": current_level_display})
	
	if crafting_exp_bar:
		crafting_exp_bar.max_value = exp_required
		# Animate progress bar value change
		var anim = _get_ui_animations()
		if anim:
			anim.animate_bar_fill(crafting_exp_bar, current_exp)
		else:
			crafting_exp_bar.value = current_exp
	
	if crafting_energy_label:
		crafting_energy_label.text = TranslationServer.translate("crafting_label_energy").format({"current": "%.0f" % current_energy, "max": "%.0f" % current_energy_max})
	
	if crafting_energy_bar:
		crafting_energy_bar.max_value = current_energy_max
		# Animate progress bar value change
		var anim = _get_ui_animations()
		if anim:
			anim.animate_bar_fill(crafting_energy_bar, current_energy)
		else:
			crafting_energy_bar.value = current_energy

func _show_level_up_popup(new_level: int) -> void:
	"""Create and display a level up popup on top of the crafting view"""
	if not LEVEL_UP_POPUP_SCENE:
		print("[LevelUp] Level %d!" % new_level)
		return
	
	var popup: Control = LEVEL_UP_POPUP_SCENE.instantiate()
	popup.name = "LevelUpPopup_" + str(Time.get_ticks_msec())
	
	# Add to inventory menu so it appears on top
	add_child(popup)
	
	# Position at center of screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	popup.position = Vector2(viewport_size.x / 2.0 - 200.0, viewport_size.y / 2.0 - 150.0)
	
	# Get unlocked recipes for this level
	var unlocked_recipes = _get_unlocked_recipes_for_level(new_level)
	
	# Setup the popup
	if popup.has_method("setup"):
		popup.setup(new_level, unlocked_recipes)


func _get_unlocked_recipes_for_level(level: int) -> Array[String]:
	"""Get all recipes that are unlocked at this specific level for the player's class"""
	var unlocked: Array[String] = []
	
	# Check available recipes that are unlocked at this level for player's class
	for recipe: CraftingRecipe in available_recipes:
		if recipe.required_level == level and recipe.required_class == player_class:
			unlocked.append(String(recipe.recipe_name))
	
	return unlocked

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
	var class_names = ["", "miner", "forager", "trapper"]
	var filter_class = class_names[selected_class_index] if selected_class_index < class_names.size() else ""
	
	var filtered_recipes = []
	# Filter and display recipes
	for recipe in available_recipes:
		# Apply class filter (0 = "All Classes")
		if filter_class != "" and recipe.required_class != filter_class:
			continue
		
		# Apply search filter
		if search_text != "" and not recipe.recipe_name.to_lower().contains(search_text):
			continue
		
		filtered_recipes.append(recipe)
		
	# Sort by required level (ascending)
	filtered_recipes.sort_custom(func(a, b): return a.required_level < b.required_level)
		
		# Recipe passes all filters - create and add button
	for recipe in filtered_recipes:
		var recipe_button = _create_recipe_button(recipe)
		recipe_grid.add_child(recipe_button)


## Update all UI text when language changes
func _update_ui_text() -> void:
	# Equipment view labels
	if has_node("EquipmentView/HBoxContainer/VBoxContainer/TabTitle"):
		$EquipmentView/HBoxContainer/VBoxContainer/TabTitle.text = TranslationServer.translate("inventory_tab_equipment")
	
	# Gold labels
	if equipment_gold_label:
		equipment_gold_label.text = TranslationServer.translate("inventory_label_gold_display").format({"amount": current_gold})
	if trade_gold_label:
		trade_gold_label.text = TranslationServer.translate("inventory_label_gold_display").format({"amount": current_gold})
	
	# Trade view labels
	if your_offer_title:
		your_offer_title.text = TranslationServer.translate("trade_title_your_offer")
	if their_offer_title:
		their_offer_title.text = TranslationServer.translate("trade_title_their_offer")
	if your_ready_button:
		your_ready_button.text = TranslationServer.translate("trade_button_ready")
	if their_ready_button:
		their_ready_button.text = TranslationServer.translate("trade_button_ready")
	if close_button:
		close_button.text = TranslationServer.translate("trade_button_close")
	
	# Trade quantity dialog
	if trade_quantity_dialog:
		trade_quantity_dialog.title = TranslationServer.translate("trade_dialog_title")
	if trade_quantity_label:
		trade_quantity_label.text = TranslationServer.translate("trade_dialog_question")
	if trade_quantity_max_button:
		trade_quantity_max_button.text = TranslationServer.translate("trade_button_max")
	
	# Crafting view labels
	if recipe_name_label and not selected_recipe:
		recipe_name_label.text = TranslationServer.translate("crafting_select_recipe")
	if recipe_description and not selected_recipe:
		recipe_description.text = TranslationServer.translate("crafting_choose_recipe_desc")
	if craft_button:
		craft_button.text = TranslationServer.translate("crafting_button_craft")
	if search_box:
		search_box.placeholder_text = TranslationServer.translate("crafting_placeholder_search")
	
	# Crafting section labels
	if requirements_label:
		requirements_label.text = TranslationServer.translate("crafting_label_requirements")
	if outputs_label:
		outputs_label.text = TranslationServer.translate("crafting_label_outputs")
	if costs_label:
		costs_label.text = TranslationServer.translate("crafting_label_costs")
	
	# Update class filter if present
	if class_filter and class_filter.item_count > 0:
		class_filter.set_item_text(0, TranslationServer.translate("crafting_filter_all_classes"))
		class_filter.set_item_text(1, TranslationServer.translate("crafting_filter_miner"))
		class_filter.set_item_text(2, TranslationServer.translate("crafting_filter_forager"))
		class_filter.set_item_text(3, TranslationServer.translate("crafting_filter_trapper"))
	
	# Update inventory tabs if present
	if inventory_tabs:
		var tab_buttons = inventory_tabs.get_children()
		if tab_buttons.size() >= 5:
			if tab_buttons[0] is Button:
				tab_buttons[0].text = TranslationServer.translate("inventory_tab_equipment")
			if tab_buttons[1] is Button:
				tab_buttons[1].text = TranslationServer.translate("inventory_tab_materials")
			if tab_buttons[2] is Button:
				tab_buttons[2].text = TranslationServer.translate("inventory_tab_consumables")
			if tab_buttons[3] is Button:
				tab_buttons[3].text = TranslationServer.translate("inventory_tab_key_items")
			if tab_buttons[4] is Button:
				tab_buttons[4].text = TranslationServer.translate("inventory_tab_crafting")
	
	# Update crafting bars display
	_update_crafting_bars()
	
	# Update recipe details if one is selected
	if selected_recipe:
		_update_recipe_costs_and_status()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _get_ui_animations() -> Node:
	"""Get UIAnimations autoload singleton"""
	if has_node("/root/UIAnimations"):
		return get_node("/root/UIAnimations")
	return null
