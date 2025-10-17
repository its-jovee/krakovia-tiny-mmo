extends Control

## Shop Browse UI - Allows players to browse and purchase from other player shops

var seller_peer_id: int = -1
var seller_name: String = ""
var shop_name: String = ""
var shop_items: Dictionary = {}  # {item_id: {quantity: int, price: int, name: String}}

var selected_item_id: int = -1
var selected_item_price: int = 0
var selected_item_max_qty: int = 0

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var seller_label: Label = $Panel/MarginContainer/VBoxContainer/SellerLabel
@onready var items_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ItemsScroll/ItemsGrid
@onready var close_button: Button = $CloseButton
@onready var purchase_dialog: ConfirmationDialog = $PurchaseDialog
@onready var item_label: Label = $PurchaseDialog/VBoxContainer/ItemLabel
@onready var price_label: Label = $PurchaseDialog/VBoxContainer/PriceLabel
@onready var quantity_spinbox: SpinBox = $PurchaseDialog/VBoxContainer/HBoxContainer/QuantitySpinBox
@onready var total_label: Label = $PurchaseDialog/VBoxContainer/TotalLabel


func _ready() -> void:
	visible = false
	
	close_button.pressed.connect(_on_close_button_pressed)
	purchase_dialog.confirmed.connect(_on_purchase_confirmed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)
	
	# Subscribe to shop events
	InstanceClient.subscribe(&"shop.update", _on_shop_update)
	InstanceClient.subscribe(&"shop.status", _on_shop_status)
	InstanceClient.subscribe(&"shop.purchase_complete", _on_purchase_complete)


func open_shop(peer_id: int) -> void:
	seller_peer_id = peer_id
	
	# Request shop data from server
	InstanceClient.current.request_data(&"shop.browse", _on_shop_data_received, {
		"seller_peer": peer_id
	})


func _on_shop_data_received(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to browse shop: " + data.error)
		return
	
	var shop_data = data.shop_data
	seller_name = shop_data.seller_name
	shop_name = shop_data.shop_name
	shop_items = shop_data.items
	
	title_label.text = shop_name
	seller_label.text = "Seller: %s" % seller_name
	
	_refresh_items()
	visible = true


func _refresh_items() -> void:
	# Clear existing items
	for child in items_grid.get_children():
		if child is Panel and child.has_method("clear_item_data"):
			child.clear_item_data()
			# Clear price label
			if child.has_node("PriceLabel"):
				child.get_node("PriceLabel").text = ""
			# Clear buy button callback
			if child.has_node("BuyButton"):
				var buy_btn = child.get_node("BuyButton")
				# Disconnect all signals
				for connection in buy_btn.pressed.get_connections():
					buy_btn.pressed.disconnect(connection["callable"])
		else:
			child.queue_free()
	
	if shop_items.is_empty():
		var label = Label.new()
		label.text = "No items available"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_grid.add_child(label)
		return
	
	# Fill slots with shop items (using same pattern as shop setup UI)
	var slot_index = 0
	for item_id in shop_items.keys():
		var shop_item = shop_items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		
		# Get or create a slot panel
		var slot_panel = _get_or_create_slot(slot_index)
		if not slot_panel:
			break  # No more slots available
		
		# Set item data (icon, quantity, tooltip)
		if slot_panel.has_method("set_item_data"):
			slot_panel.set_item_data(item_id, item, shop_item.quantity)
		
		# Set price label
		if slot_panel.has_node("PriceLabel"):
			var price_label = slot_panel.get_node("PriceLabel")
			price_label.text = "%dg" % shop_item.price
		
		# Setup buy button
		if slot_panel.has_node("BuyButton"):
			var buy_btn = slot_panel.get_node("BuyButton")
			# Clear old connections first
			for connection in buy_btn.pressed.get_connections():
				buy_btn.pressed.disconnect(connection["callable"])
			# Connect new callback
			buy_btn.pressed.connect(_on_buy_button_pressed.bind(item_id, shop_item))
			buy_btn.visible = true
		
		slot_index += 1


func _get_or_create_slot(index: int) -> Panel:
	# Try to get existing slot from grid
	var slot_count = 0
	for child in items_grid.get_children():
		if child is Panel:
			if slot_count == index:
				return child
			slot_count += 1
	
	# Need to create a new slot
	var slot_panel = Panel.new()
	slot_panel.custom_minimum_size = Vector2(64, 64)
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Add script for item_slot functionality
	var item_slot_script = load("res://source/client/ui/inventory/item_slot.gd")
	slot_panel.set_script(item_slot_script)
	
	# Create Icon
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(8, 8)
	slot_panel.add_child(icon)
	
	# Create ItemAmount label
	var amount_label = Label.new()
	amount_label.name = "ItemAmount"
	amount_label.text = ""
	amount_label.position = Vector2(40, 44)
	amount_label.add_theme_font_size_override("font_size", 12)
	slot_panel.add_child(amount_label)
	
	# Create PriceLabel
	var price_label = Label.new()
	price_label.name = "PriceLabel"
	price_label.text = ""
	price_label.position = Vector2(4, 66)
	price_label.add_theme_font_size_override("font_size", 11)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold color
	slot_panel.add_child(price_label)
	
	# Create Buy button (small, at bottom)
	var buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(60, 20)
	buy_btn.position = Vector2(2, 84)
	buy_btn.add_theme_font_size_override("font_size", 10)
	slot_panel.add_child(buy_btn)
	
	# Adjust panel size to fit everything
	slot_panel.custom_minimum_size = Vector2(64, 108)
	
	items_grid.add_child(slot_panel)
	return slot_panel


func _on_buy_button_pressed(item_id: int, shop_item: Dictionary) -> void:
	selected_item_id = item_id
	selected_item_price = shop_item.price
	selected_item_max_qty = shop_item.quantity
	
	item_label.text = "Item: %s" % shop_item.name
	price_label.text = "Price: %d gold each" % shop_item.price
	
	quantity_spinbox.max_value = shop_item.quantity
	quantity_spinbox.value = 1
	
	_update_total_label()
	
	purchase_dialog.popup_centered()


func _on_quantity_changed(value: float) -> void:
	_update_total_label()


func _update_total_label() -> void:
	var quantity = int(quantity_spinbox.value)
	var total = selected_item_price * quantity
	total_label.text = "Total: %d gold" % total


func _on_purchase_confirmed() -> void:
	if selected_item_id == -1:
		return
	
	var quantity = int(quantity_spinbox.value)
	
	InstanceClient.current.request_data(&"shop.purchase", _on_purchase_response, {
		"seller_peer": seller_peer_id,
		"item_id": selected_item_id,
		"quantity": quantity
	})


func _on_purchase_response(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Purchase failed: " + data.error)
		# Show error notification
		var hud = get_tree().get_root().find_child("HUD", true, false)
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Purchase failed: " + data.error, "✗ Purchase Failed")


func _on_purchase_complete(data: Dictionary) -> void:
	print("Purchase successful: ", data.quantity, "x ", data.item_name, " for ", data.total_price, " gold")
	
	# Show success notification to buyer
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("show_notification"):
		var message = "Purchased %dx %s for %dg" % [data.quantity, data.item_name, data.total_price]
		hud.show_notification(message, "✓ Purchase Complete")
	
	# Inventory and gold updates are handled via separate data pushes


func _on_shop_update(data: Dictionary) -> void:
	# Check if this update is for the shop we're viewing
	if data.seller_peer_id == seller_peer_id:
		shop_items = data.items
		_refresh_items()


func _on_shop_status(data: Dictionary) -> void:
	# Check if the shop we're viewing closed
	if data.seller_peer_id == seller_peer_id and data.status == "closed":
		push_warning("Shop has closed")
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	visible = false
	seller_peer_id = -1
	shop_items.clear()
