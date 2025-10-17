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
		child.queue_free()
	
	if shop_items.is_empty():
		var label = Label.new()
		label.text = "No items available"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_grid.add_child(label)
		return
	
	# Add shop items
	for item_id in shop_items.keys():
		var shop_item = shop_items[item_id]
		var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
		if not item:
			continue
		
		var panel = PanelContainer.new()
		var vbox = VBoxContainer.new()
		
		# Item name
		var name_label = Label.new()
		name_label.text = shop_item.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
		
		# Quantity available
		var qty_label = Label.new()
		qty_label.text = "Available: %d" % shop_item.quantity
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(qty_label)
		
		# Price
		var price_label = Label.new()
		price_label.text = "%d gold each" % shop_item.price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(price_label)
		
		# Buy button
		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy_button_pressed.bind(item_id, shop_item))
		vbox.add_child(buy_btn)
		
		panel.add_child(vbox)
		panel.custom_minimum_size = Vector2(200, 0)
		items_grid.add_child(panel)


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


func _on_purchase_complete(data: Dictionary) -> void:
	print("Purchase successful: ", data.quantity, "x ", data.item_name, " for ", data.total_price, " gold")
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
