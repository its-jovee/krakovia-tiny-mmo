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


func _ready() -> void:
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
	
	#hide trade viewby default
	trade_view.hide()
	$EquipmentView.show()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		InstanceClient.current.request_data(&"inventory.get", fill_inventory)


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
			gear_slots_cache.erase(child)


func _get_next_panel_slot(slot_index: int) -> Panel:
	# Find the next Panel node (skip Button nodes) starting from slot_index
	var panel_count: int = 0
	for i in range(inventory_grid.get_child_count()):
		var child = inventory_grid.get_child(i)
		if child is Panel:
			if panel_count == slot_index:
				return child as Panel
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
		_enable_inventory_interaction()
	
	# Update their button
	if their_ready:
		their_ready_button.text = "Ready ✓"
		their_ready_button.disabled = true
	else:
		their_ready_button.text = "Ready"
		their_ready_button.disabled = true

func _update_offer_grid(grid: GridContainer, items: Dictionary):
	# Clear existing items (skip the first few buttons)
	var start_index = 0
	for i in range(start_index, grid.get_child_count()):
		var child = grid.get_child(i)
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Add items to grid
	var slot_index = start_index
	for item_id in items:
		if slot_index < grid.get_child_count():
			var slot = grid.get_child(slot_index)
			if slot is Panel and slot.has_method("set_item_data"):
				var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
				if item:
					slot.set_item_data(item_id, item, items[item_id])
			slot_index += 1

func _on_your_ready_pressed():
	if trade_locked:
		return
	
	if your_ready:
		# Cancel ready state
		InstanceClient.current.request_data(&"trade.confirm", Callable(), {
			"session_id": trade_session_id,
			"ready": false
		})
	else:
		# Set ready state
		InstanceClient.current.request_data(&"trade.confirm", Callable(), {
			"session_id": trade_session_id,
			"ready": true
		})

func _on_gold_input_changed(new_text: String):
	if trade_locked or your_ready:
		return
	
	your_trade_gold = int(new_text) if new_text.is_valid_int() else 0
	_send_trade_update()

func _send_trade_update():
	if trade_session_id == -1:
		return
	
	InstanceClient.current.request_data(&"trade.update", Callable(), {
		"session_id": trade_session_id,
		"items": your_trade_items,
		"gold": your_trade_gold
	})

func _reset_trade_state():
	your_trade_items.clear()
	their_trade_items.clear()
	your_trade_gold = 0
	their_trade_gold = 0
	your_ready = false
	their_ready = false
	trade_locked = false
	trade_session_id = -1

func _close_trade():
	trade_view.hide()
	$EquipmentView.show()
	_reset_trade_state()

func _enable_inventory_interaction():
	# Enable clicking items in trade inventory
	for i in range(player_inv_grid.get_child_count()):
		var child = player_inv_grid.get_child(i)
		if child is Panel:
			child.mouse_filter = Control.MOUSE_FILTER_PASS

func _disable_inventory_interaction():
	# Disable clicking items when ready or locked
	for i in range(player_inv_grid.get_child_count()):
		var child = player_inv_grid.get_child(i)
		if child is Panel:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _populate_trade_inventory():
	# Clear the trade inventory grid first
	for i in range(player_inv_grid.get_child_count()):
		var child = player_inv_grid.get_child(i)
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill with player's items
	var slot_index = 0
	for item_id in inventory.keys():
		if slot_index >= player_inv_grid.get_child_count():
			break
			
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if item:
			var entry: Dictionary = inventory[item_id]
			var stack: int = int(entry.get("stack", 1))
			
			# Find next panel slot
			var panel_slot = _get_next_trade_panel_slot(slot_index)
			if panel_slot and panel_slot.has_method("set_item_data"):
				panel_slot.set_item_data(item_id, item, stack)
				slot_index += 1

func _get_next_trade_panel_slot(slot_index: int) -> Panel:
	# Find the next Panel node in trade inventory grid
	var panel_count: int = 0
	for i in range(player_inv_grid.get_child_count()):
		var child = player_inv_grid.get_child(i)
		if child is Panel:
			if panel_count == slot_index:
				return child as Panel
			panel_count += 1
	return null
