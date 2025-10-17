extends Control

## Shop Setup UI - Allows players to configure and open their shop

var shop_open: bool = false
var shop_items: Dictionary = {}  # {item_id: {quantity: int, price: int}}
var player_inventory: Dictionary = {}

@onready var shop_name_input: LineEdit = $Panel/MarginContainer/VBoxContainer/ShopNameContainer/ShopNameInput
@onready var inventory_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/InventoryScroll/InventoryGrid
@onready var shop_items_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ShopItemsScroll/ShopItemsGrid
@onready var shop_items_label: Label = $Panel/MarginContainer/VBoxContainer/ShopItemsLabel
@onready var open_shop_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/OpenShopButton
@onready var close_shop_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/CloseShopButton
@onready var close_button: Button = $CloseButton
@onready var add_item_dialog: AcceptDialog = $AddItemDialog
@onready var item_name_label: Label = $AddItemDialog/VBoxContainer/ItemNameLabel
@onready var quantity_spinbox: SpinBox = $AddItemDialog/VBoxContainer/HBoxContainer/QuantitySpinBox
@onready var price_spinbox: SpinBox = $AddItemDialog/VBoxContainer/HBoxContainer2/PriceSpinBox

var selected_item_id: int = -1
var selected_source: String = ""  # "inventory" or "shop" - tracks where the click came from


func _ready() -> void:
	visible = false
	
	open_shop_button.pressed.connect(_on_open_shop_pressed)
	close_shop_button.pressed.connect(_on_close_shop_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	add_item_dialog.confirmed.connect(_on_add_item_confirmed)
	
	# Subscribe to shop events
	InstanceClient.subscribe(&"shop.opened", _on_shop_opened)
	InstanceClient.subscribe(&"shop.closed", _on_shop_closed)
	InstanceClient.subscribe(&"shop.item_sold", _on_item_sold)
	InstanceClient.subscribe(&"inventory.update", _on_inventory_update)
	
	_update_ui_state()
	
	# Note: Item slots already handle clicks via item_slot.gd
	# They call _on_item_slot_clicked() on their parent automatically



func show_menu(inventory: Dictionary = {}) -> void:
	print("=== SHOP SETUP: show_menu called ===")
	# Request fresh inventory from server instead of using passed parameter
	InstanceClient.current.request_data(&"inventory.get", _on_inventory_received)
	shop_items.clear()
	visible = true


func _on_inventory_received(inv_data: Dictionary) -> void:
	print("=== SHOP SETUP: _on_inventory_received ===")
	print("Inventory data received: ", inv_data)
	print("Inventory size: ", inv_data.size())
	player_inventory = inv_data
	_refresh_inventory_grid()
	_refresh_shop_items()


func _refresh_inventory_grid() -> void:
	print("=== SHOP SETUP: _refresh_inventory_grid ===")
	print("Player inventory size: ", player_inventory.size())
	
	# Clear all existing item data from slots
	for child in inventory_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
	
	# Fill slots with inventory items (only sellable ones)
	var slot_index = 0
	for item_id in player_inventory.keys():
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		if not item.can_sell:
			continue
		
		var item_entry = player_inventory[item_id]
		var stack = item_entry.stack
		
		# Get the next available panel slot
		var item_slot_panel = _get_panel_slot(slot_index)
		if item_slot_panel and item_slot_panel.has_method("set_item_data"):
			item_slot_panel.set_item_data(item_id, item, stack)
			slot_index += 1
		else:
			break  # No more slots available
	
	print("Total items displayed in grid: ", slot_index)


func _get_panel_slot(index: int) -> Panel:
	# Get the Panel child at the given index
	var panel_count = 0
	for child in inventory_grid.get_children():
		if child is Panel:
			if panel_count == index:
				return child
			panel_count += 1
	return null


func _on_item_slot_clicked(item_slot_panel: Panel) -> void:
	print("=== SHOP SETUP: _on_item_slot_clicked called ===")
	print("=== Item slot panel: ", item_slot_panel.name)
	print("=== Shop open: ", shop_open)
	
	if shop_open:
		push_warning("Cannot modify shop while it's open")
		return
	
	# Get item data from the panel
	var item_data = item_slot_panel.item_data
	print("=== Item data: ", item_data)
	
	if not item_data or not item_data.has("item_id") or item_data.item_id == -1:
		print("=== Empty slot clicked")
		return  # Empty slot
	
	var item_id = item_data.item_id
	var item = item_data.item
	
	print("Item ID: ", item_id)
	print("Item: ", item.item_name if item else "NULL")
	
	# Determine if this is from inventory or shop grid
	var is_from_inventory = item_slot_panel.get_parent() == inventory_grid
	var is_from_shop = item_slot_panel.get_parent() == shop_items_grid
	
	print("From inventory: ", is_from_inventory)
	print("From shop: ", is_from_shop)
	
	if is_from_inventory:
		# Adding item from inventory to shop
		if shop_items.size() >= 20 and not shop_items.has(item_id):
			push_warning("Shop is full (max 20 items)")
			return
		
		selected_source = "inventory"
		selected_item_id = item_id
		item_name_label.text = "Add to Shop: %s" % item.item_name
		
		var max_qty = player_inventory[item_id].stack
		quantity_spinbox.max_value = max_qty
		quantity_spinbox.value = min(1, max_qty)
		
		# Suggest a price (could be based on minimum_price)
		var suggested_price = item.minimum_price if item.minimum_price > 0 else 10
		price_spinbox.value = suggested_price
		
		add_item_dialog.popup_centered()
		
	elif is_from_shop:
		# Editing/removing item from shop
		selected_source = "shop"
		selected_item_id = item_id
		
		var shop_item = shop_items[item_id]
		item_name_label.text = "Edit Shop Item: %s" % item.item_name
		
		quantity_spinbox.max_value = player_inventory[item_id].stack if player_inventory.has(item_id) else shop_item.quantity
		quantity_spinbox.value = shop_item.quantity
		price_spinbox.value = shop_item.price
		
		add_item_dialog.popup_centered()


func _on_add_item_confirmed() -> void:
	print("=== DIALOG CONFIRMED ===")
	print("Selected item ID: ", selected_item_id)
	print("Selected source: ", selected_source)
	
	if selected_item_id == -1:
		print("ERROR: No item selected!")
		return
	
	var quantity = int(quantity_spinbox.value)
	var price = int(price_spinbox.value)
	
	print("Quantity: ", quantity)
	print("Price: ", price)
	
	if quantity <= 0:
		# Remove item from shop if quantity is 0
		print("Removing item from shop")
		shop_items.erase(selected_item_id)
	else:
		# Add or update shop item
		var item: Item = ContentRegistryHub.load_by_id(&"items", selected_item_id)
		print("Adding/updating item: ", item.item_name if item else "NULL")
		shop_items[selected_item_id] = {
			"quantity": quantity,
			"price": price,
			"name": item.item_name if item else "Unknown"
		}
	
	print("Shop items count: ", shop_items.size())
	_refresh_shop_items()
	selected_item_id = -1
	selected_source = ""


func _refresh_shop_items() -> void:
	# Clear all shop item slots
	for child in shop_items_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
			# Also clear the price label if it exists
			if child.has_node("PriceLabel"):
				child.get_node("PriceLabel").text = ""
	
	# Update label
	shop_items_label.text = "Items in Shop (%d/20)" % shop_items.size()
	
	# Fill slots with shop items
	var slot_index = 0
	for item_id in shop_items.keys():
		var shop_item = shop_items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		
		# Get the next available panel slot
		var shop_slot_panel = _get_shop_slot(slot_index)
		if shop_slot_panel and shop_slot_panel.has_method("set_item_data"):
			shop_slot_panel.set_item_data(item_id, item, shop_item.quantity)
			
			# Set the price label
			if shop_slot_panel.has_node("PriceLabel"):
				var price_label = shop_slot_panel.get_node("PriceLabel")
				price_label.text = "%dg" % shop_item.price
			
			slot_index += 1
		else:
			break  # No more slots available


func _get_shop_slot(index: int) -> Panel:
	# Get the Panel child at the given index from shop grid
	var panel_count = 0
	for child in shop_items_grid.get_children():
		if child is Panel:
			if panel_count == index:
				return child
			panel_count += 1
	return null


func _on_remove_item(item_id: int) -> void:
	shop_items.erase(item_id)
	_refresh_shop_items()


func _on_open_shop_pressed() -> void:
	if shop_items.is_empty():
		push_warning("Add items to your shop first")
		return
	
	var shop_name = shop_name_input.text.strip_edges()
	
	# First open the shop on the server
	InstanceClient.current.request_data(&"shop.open", _on_shop_open_response, {
		"shop_name": shop_name
	})


func _on_shop_open_response(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to open shop: " + data.error)
		return
	
	# Now add all items to the shop
	for item_id in shop_items.keys():
		var shop_item = shop_items[item_id]
		InstanceClient.current.request_data(&"shop.add_item", func(result): pass, {
			"item_id": item_id,
			"quantity": shop_item.quantity,
			"price": shop_item.price
		})


func _on_close_shop_pressed() -> void:
	InstanceClient.current.request_data(&"shop.close", _on_shop_close_response, {})


func _on_shop_close_response(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to close shop: " + data.error)


func _on_shop_opened(data: Dictionary) -> void:
	shop_open = true
	_update_ui_state()
	print("Shop opened successfully: ", data.shop_name)


func _on_shop_closed(data: Dictionary) -> void:
	shop_open = false
	shop_items.clear()
	_update_ui_state()
	_refresh_shop_items()
	print("Shop closed")


func _on_item_sold(data: Dictionary) -> void:
	print("Item sold: ", data.quantity, "x ", data.item_name, " for ", data.total_price, " gold to ", data.buyer_name)
	
	# Update local shop items
	var item_id = data.item_id
	if shop_items.has(item_id):
		shop_items[item_id].quantity -= data.quantity
		if shop_items[item_id].quantity <= 0:
			shop_items.erase(item_id)
		_refresh_shop_items()


func _on_inventory_update(inventory: Dictionary) -> void:
	player_inventory = inventory
	_refresh_inventory_grid()


func _update_ui_state() -> void:
	open_shop_button.disabled = shop_open
	close_shop_button.disabled = not shop_open
	shop_name_input.editable = not shop_open


func _on_close_button_pressed() -> void:
	visible = false
