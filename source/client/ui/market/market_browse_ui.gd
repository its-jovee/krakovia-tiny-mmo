extends Control
## Vendor UI - Unified interface for buying AND selling items at vendors
## Each vendor has their own inventory and local supply/demand pricing

# Vendor info
var vendor_info: Dictionary = {}  # {id, name, icon, type, catalog_size}
var sell_catalog: Array = []  # Items player can BUY from vendor
var buy_catalog: Array = []   # Items vendor will BUY from player

# Current event (if any)
var current_event: Variant = null

# Selection state
var selected_item_id: int = -1
var selected_item_price: int = 0
var selected_item_name: String = ""
var is_selling: bool = false  # true = selling TO vendor, false = buying FROM vendor

# Filtering
var search_filter: String = ""
var tag_filter: String = ""

# Item cache to avoid repeated loads
var _item_cache: Dictionary = {}  # {item_id: Item}

# Player inventory reference
var player_inventory: Dictionary = {}

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var tabs: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var buy_tab: Control = $Panel/MarginContainer/VBoxContainer/TabContainer/Buy
@onready var sell_tab: Control = $Panel/MarginContainer/VBoxContainer/TabContainer/Sell
@onready var buy_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Buy/BuyScroll/BuyGrid
@onready var sell_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Sell/SellScroll/SellGrid
@onready var search_box: LineEdit = $Panel/MarginContainer/VBoxContainer/FilterContainer/SearchBox
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton
@onready var transaction_dialog: ConfirmationDialog = $TransactionDialog
@onready var item_label: Label = $TransactionDialog/VBoxContainer/ItemLabel
@onready var price_label: Label = $TransactionDialog/VBoxContainer/PriceLabel
@onready var quantity_spinbox: SpinBox = $TransactionDialog/VBoxContainer/HBoxContainer/QuantitySpinBox
@onready var max_button: Button = $TransactionDialog/VBoxContainer/HBoxContainer/MaxButton
@onready var total_label: Label = $TransactionDialog/VBoxContainer/TotalLabel
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/InfoContainer/GoldContainer/GoldLabel
@onready var event_banner: Panel = $Panel/MarginContainer/VBoxContainer/EventBanner

# Info tab references
@onready var info_tab: Control = $Panel/MarginContainer/VBoxContainer/TabContainer/Info
@onready var description_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TabContainer/Info/InfoScroll/InfoContent/DescriptionLabel
@onready var rates_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TabContainer/Info/InfoScroll/InfoContent/RatesSection/RatesLabel
@onready var production_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TabContainer/Info/InfoScroll/InfoContent/ProductionSection/ProductionLabel

# For responsive grid columns
const MIN_ITEM_WIDTH: int = 95
const MAX_COLUMNS: int = 8
const MIN_COLUMNS: int = 2

var current_gold: int = 0


func _ready() -> void:
	visible = false
	
	close_button.pressed.connect(_on_close_button_pressed)
	transaction_dialog.confirmed.connect(_on_transaction_confirmed)
	quantity_spinbox.value_changed.connect(_on_quantity_changed)
	max_button.pressed.connect(_on_max_button_pressed)
	
	if search_box:
		search_box.text_changed.connect(_on_search_changed)
	
	if tabs:
		tabs.tab_changed.connect(_on_tab_changed)
	
	# Connect to resize for responsive columns
	resized.connect(_on_resized)
	
	# Subscribe to updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	InstanceClient.subscribe(&"inventory.update", _on_inventory_update)
	InstanceClient.subscribe(&"vendor.price_update", _on_vendor_price_update)
	InstanceClient.subscribe(&"vendor.catalog_update", _on_vendor_catalog_update)
	InstanceClient.subscribe(&"market.event", _on_market_event)


func _on_resized() -> void:
	"""Adjust grid columns based on available width"""
	_update_grid_columns()


func _update_grid_columns() -> void:
	"""Calculate optimal number of columns based on panel width"""
	if not buy_grid or not sell_grid:
		return
	
	# Get available width (panel width minus margins and padding)
	var available_width = size.x - 120  # Account for margins
	var columns = clampi(int(available_width / MIN_ITEM_WIDTH), MIN_COLUMNS, MAX_COLUMNS)
	
	buy_grid.columns = columns
	sell_grid.columns = columns


func open_vendor() -> void:
	"""Request vendor catalog from server and display UI"""
	print("[VendorUI] open_vendor() called")
	
	# Update grid columns for current size
	call_deferred("_update_grid_columns")
	
	# Request fresh gold and inventory
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	InstanceClient.current.request_data(&"inventory.get", _on_inventory_received)
	
	# Request catalog
	InstanceClient.current.request_data(&"market.catalog", _on_catalog_received)


func _on_catalog_received(data: Dictionary) -> void:
	if data.has("error"):
		push_error("Failed to get vendor catalog: " + data.error)
		_show_notification(data.error, "Vendor Error")
		return
	
	vendor_info = data.get("vendor", {})
	var catalog_data = data.get("catalog", {})
	sell_catalog = catalog_data.get("sells", [])  # Items player can buy
	buy_catalog = catalog_data.get("buys", [])    # Items vendor will buy
	current_event = data.get("event", null)
	
	# Update title with vendor info
	var vendor_name = vendor_info.get("name", "Vendor")
	if title_label:
		title_label.text = vendor_name
	
	# Show event banner if active
	_update_event_banner()
	
	# Refresh displays
	_refresh_buy_items()
	_refresh_sell_items()
	_refresh_info_tab()
	
	visible = true
	print("[VendorUI] Opened vendor: %s - sells %d items, buys %d items" % [
		vendor_name, sell_catalog.size(), buy_catalog.size()
	])


func _update_event_banner() -> void:
	if not event_banner:
		return
	
	if current_event:
		event_banner.visible = true
		var event_label = event_banner.get_node_or_null("Label")
		if event_label:
			var title = current_event.get("title", "Market Event")
			var description = current_event.get("description", "")
			var affected_items: Array = current_event.get("affected_items", [])
			
			# Build price change indicators
			var price_info = _format_event_price_changes(affected_items)
			
			if price_info.is_empty():
				event_label.text = "%s - %s" % [title, description]
			else:
				event_label.text = "%s | %s" % [title, price_info]
	else:
		event_banner.visible = false


func _format_event_price_changes(affected_item_ids: Array) -> String:
	"""Format price change indicators for affected items"""
	if affected_item_ids.is_empty():
		return ""
	
	var changes: Array[String] = []
	
	# Find affected items in our current catalog and show their trend
	for catalog_entry in sell_catalog:
		var item_id = catalog_entry.get("id", 0)
		if item_id in affected_item_ids:
			var item = _get_cached_item(item_id)
			if item:
				var supply = catalog_entry.get("supply", 0.0)
				# If supply is negative (scarce), prices are up
				# Event affects demand, so negative supply = high demand = price up
				if supply < -0.05:
					changes.append("[+] %s" % item.item_name)
				elif supply > 0.05:
					changes.append("[-] %s" % item.item_name)
	
	# Also check buy catalog
	for catalog_entry in buy_catalog:
		var item_id = catalog_entry.get("id", 0)
		if item_id in affected_item_ids:
			var item = _get_cached_item(item_id)
			if item and not _item_already_listed(changes, item.item_name):
				var supply = catalog_entry.get("supply", 0.0)
				if supply < -0.05:
					changes.append("[+] %s" % item.item_name)
				elif supply > 0.05:
					changes.append("[-] %s" % item.item_name)
	
	if changes.is_empty():
		return "Prices affected!"
	
	# Limit to 3 items to keep it readable
	if changes.size() > 3:
		return " ".join(changes.slice(0, 3)) + " +%d more" % (changes.size() - 3)
	
	return " ".join(changes)


func _item_already_listed(changes: Array[String], item_name: String) -> bool:
	for change in changes:
		if item_name in change:
			return true
	return false


func _refresh_buy_items() -> void:
	"""Refresh the Buy tab with items from vendor's sell catalog"""
	if not buy_grid:
		return
	
	# Clear existing items
	for child in buy_grid.get_children():
		child.queue_free()
	
	if sell_catalog.is_empty():
		var label = Label.new()
		label.text = "This vendor has no items for sale"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buy_grid.add_child(label)
		return
	
	# Display items vendor sells (with stock info)
	for item_data in sell_catalog:
		var item_id: int = item_data.get("id", 0)
		var item: Item = _get_cached_item(item_id)
		if not item:
			continue
		
		# Apply search filter
		if search_filter != "" and not item.item_name.to_lower().contains(search_filter.to_lower()):
			continue
		
		var buy_price = item_data.get("price", 0)
		var supply = item_data.get("supply", 0.0)
		var stock = item_data.get("stock", 0)
		var producing = item_data.get("producing", 0)
		var next_ready_in = item_data.get("next_ready_in", 0)
		var stock_full = item_data.get("stock_full", false)
		var recipe = item_data.get("recipe", {})
		var pending = item_data.get("pending", {})
		
		var slot = _create_buy_item_slot(item, item_id, buy_price, supply, stock, producing, next_ready_in, stock_full, recipe, pending)
		buy_grid.add_child(slot)


func _refresh_sell_items() -> void:
	"""Refresh the Sell tab with items from player's inventory that vendor will buy"""
	if not sell_grid:
		return
	
	# Clear existing items
	for child in sell_grid.get_children():
		child.queue_free()
	
	if player_inventory.is_empty():
		var label = Label.new()
		label.text = "You have no items to sell"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sell_grid.add_child(label)
		return
	
	# Build lookup for what vendor will pay (from buy_catalog)
	var vendor_buy_prices: Dictionary = {}
	var vendor_buy_ids: Array = []
	var supply_levels: Dictionary = {}
	var produces_info: Dictionary = {}  # item_id -> [{id, name, needs}, ...]
	var max_buy_qty: Dictionary = {}  # item_id -> max quantity vendor will buy
	for item_data in buy_catalog:
		var item_id = item_data.get("id", 0)
		vendor_buy_prices[item_id] = item_data.get("price", 0)
		supply_levels[item_id] = item_data.get("supply", 0.0)
		vendor_buy_ids.append(item_id)
		if item_data.has("produces"):
			produces_info[item_id] = item_data.get("produces", [])
		if item_data.has("max_buy"):
			max_buy_qty[item_id] = item_data.get("max_buy", -1)  # -1 = unlimited
	
	# Display items from inventory that vendor will buy
	var has_sellable_items = false
	for item_id in player_inventory.keys():
		var item: Item = _get_cached_item(item_id)
		if not item or not item.can_sell:
			continue
		
		# Check if vendor buys this item
		if not vendor_buy_ids.is_empty() and item_id not in vendor_buy_ids:
			continue  # Vendor doesn't buy this item
		
		# Apply search filter
		if search_filter != "" and not item.item_name.to_lower().contains(search_filter.to_lower()):
			continue
		
		var stack = player_inventory[item_id].get("stack", 0)
		if stack <= 0:
			continue
		
		var sell_price = vendor_buy_prices.get(item_id, int(item.minimum_price * 0.7))
		var supply = supply_levels.get(item_id, 0.0)
		var produces = produces_info.get(item_id, [])
		var max_buy = max_buy_qty.get(item_id, -1)  # -1 = unlimited
		
		# Skip items that vendor doesn't need anymore
		if max_buy == 0:
			continue
		
		var slot = _create_item_slot(item, item_id, sell_price, supply, true, stack, produces, max_buy)
		sell_grid.add_child(slot)
		has_sellable_items = true
	
	# Show message if vendor doesn't buy any of player's items
	if not has_sellable_items:
		var label = Label.new()
		label.text = "This vendor doesn't buy any of your items"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sell_grid.add_child(label)


func _refresh_info_tab() -> void:
	"""Refresh the Info tab with vendor details"""
	if not description_label or not rates_label or not production_label:
		return
	
	var vendor_name = vendor_info.get("name", "Merchant")
	var vendor_type = vendor_info.get("type", "general")
	var description = vendor_info.get("description", "A friendly merchant.")
	var buy_mult = vendor_info.get("buy_multiplier", 0.7)
	var sell_mult = vendor_info.get("sell_multiplier", 1.3)
	var production_time = vendor_info.get("production_time", 60.0)
	var restock_time = vendor_info.get("restock_time", 30.0)
	var recipes: Array = vendor_info.get("recipes", [])
	
	# Description section
	var desc_text = "[b]%s[/b]\n" % vendor_name
	desc_text += "[color=#AAAAAA]%s specialist[/color]\n\n" % vendor_type.capitalize()
	desc_text += "[i]%s[/i]" % description
	description_label.text = desc_text
	
	# Trading rates section
	var buy_percent = int((1.0 - buy_mult) * 100)
	var sell_percent = int((sell_mult - 1.0) * 100)
	var specialty_bonus_val = vendor_info.get("specialty_bonus", 1.0)
	var crafted_bonus_val = vendor_info.get("crafted_bonus", 1.0)
	var specialty_percent = int((specialty_bonus_val - 1.0) * 100)
	var crafted_percent = int((crafted_bonus_val - 1.0) * 100)
	
	var rates_text = ""
	rates_text += "[color=#FF6666]Base buy rate:[/color] %d%% below base price\n" % buy_percent
	rates_text += "[color=#66FF66]Sells to you:[/color] %d%% above base price\n\n" % sell_percent
	
	# Show profit opportunities
	rates_text += "[b]Profit Opportunities:[/b]\n"
	if specialty_percent > 0:
		rates_text += "[color=#88FF88]• Specialty items: +%d%% bonus[/color]\n" % specialty_percent
		rates_text += "  [color=#AAAAAA](Items this vendor needs)[/color]\n"
	if crafted_percent > 0:
		rates_text += "[color=#88FF88]• Crafted goods: +%d%% bonus[/color]\n" % crafted_percent
		rates_text += "  [color=#AAAAAA](Processed/refined items)[/color]\n"
	
	rates_text += "\n[color=#AAAAAA]Tip: Gather raw materials, craft them, and sell to specialists![/color]"
	rates_label.text = rates_text
	
	# Production section
	var production_text = ""
	
	if recipes.is_empty():
		production_text = "[color=#888888]This vendor doesn't produce items from raw materials.[/color]"
	else:
		production_text += "[color=#88CCFF]Converts raw materials into goods:[/color]\n\n"
		
		for recipe in recipes:
			var output_name = recipe.get("output_name", "Item")
			var inputs: Array = recipe.get("inputs", [])
			
			# Format inputs
			var input_str = ""
			for input_data in inputs:
				var input_name = input_data.get("name", "Material")
				var input_amount = input_data.get("amount", 1)
				if input_str != "":
					input_str += " + "
				input_str += "%dx %s" % [input_amount, input_name]
			
			production_text += "• %s → [b]%s[/b]\n" % [input_str, output_name]
			production_text += "  [color=#AAAAAA]Production time: %s[/color]\n\n" % _format_time(production_time)
	
	# Restock info
	production_text += "[color=#FFD700]Natural restock:[/color] Every %s" % _format_time(restock_time * 60)
	
	production_label.text = production_text


func _format_time(seconds: float) -> String:
	"""Format seconds into a readable time string"""
	if seconds < 60:
		return "%d seconds" % int(seconds)
	elif seconds < 3600:
		var mins = int(seconds / 60)
		return "%d minute%s" % [mins, "s" if mins > 1 else ""]
	else:
		var hours = seconds / 3600.0
		if hours < 1.5:
			return "1 hour"
		return "%.1f hours" % hours


func _create_item_slot(item: Item, item_id: int, price: int, supply: float, is_sell: bool, stack: int = 0, produces: Array = [], max_buy: int = -1) -> Panel:
	"""Create a compact item slot for selling to vendor"""
	var slot_panel = Panel.new()
	slot_panel.custom_minimum_size = Vector2(85, 105)
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Calculate effective max sellable (min of stack and vendor's need)
	var effective_max = stack
	if max_buy >= 0:
		effective_max = mini(stack, max_buy)
	
	# Highlight if this is a needed material
	if not produces.is_empty():
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.18, 0.1, 1.0)
		style.border_color = Color(0.4, 0.7, 0.3)
		style.border_width_bottom = 3
		slot_panel.add_theme_stylebox_override("panel", style)
	
	# Make the whole panel clickable
	slot_panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_action_button_pressed(item_id, price, item.item_name, true, effective_max)
	)
	
	# Use a Control for absolute positioning - set mouse to pass so panel gets events
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	slot_panel.add_child(container)
	
	# Center icon (80 width - 40 icon = 40, so offset 20)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.position = Vector2(20, 6)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.item_icon:
		icon.texture = item.item_icon
	container.add_child(icon)
	
	# Stack count in upper-right corner (show how much vendor will buy vs what player has)
	var stack_lbl = Label.new()
	stack_lbl.position = Vector2(52, 2)
	stack_lbl.add_theme_font_size_override("font_size", 11)
	stack_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	stack_lbl.add_theme_constant_override("outline_size", 2)
	stack_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if max_buy >= 0 and max_buy < stack:
		# Show limited: e.g. "×5/20" (vendor needs 5 of your 20)
		stack_lbl.text = "×%d" % mini(stack, max_buy)
		stack_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))  # Yellow = limited
	else:
		stack_lbl.text = "×%d" % stack
		stack_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	container.add_child(stack_lbl)
	
	# Price in bottom-left corner of icon area
	var price_lbl = Label.new()
	price_lbl.position = Vector2(2, 44)
	price_lbl.add_theme_font_size_override("font_size", 11)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	price_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	price_lbl.add_theme_constant_override("outline_size", 2)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_lbl.text = "%dg" % price
	container.add_child(price_lbl)
	
	# Trend indicator in bottom-right of icon area
	var trend = _get_trend_indicator(supply, is_sell)
	if trend.text != "" and trend.text != "→":
		var trend_lbl = Label.new()
		trend_lbl.position = Vector2(52, 44)
		trend_lbl.add_theme_font_size_override("font_size", 10)
		trend_lbl.add_theme_color_override("font_color", trend.color)
		trend_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		trend_lbl.add_theme_constant_override("outline_size", 2)
		trend_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trend_lbl.text = trend.text
		container.add_child(trend_lbl)
	
	# Item name at bottom
	var name_label = Label.new()
	name_label.position = Vector2(0, 60)
	name_label.size = Vector2(80, 18)
	var display_name = item.item_name if item.item_name.length() <= 12 else item.item_name.left(11) + "…"
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# "Produces" info at very bottom - show how much vendor needs
	var info_lbl = Label.new()
	info_lbl.position = Vector2(0, 78)
	info_lbl.size = Vector2(85, 22)
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	info_lbl.add_theme_constant_override("outline_size", 2)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not produces.is_empty():
		if max_buy > 0:
			# Show how much vendor needs
			info_lbl.text = "Need %d" % max_buy
			info_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		elif max_buy == 0:
			info_lbl.text = "Stocked"
			info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		else:
			# Show what it produces
			var first_output = produces[0].get("name", "?")
			if first_output.length() > 10:
				first_output = first_output.left(9) + "..."
			info_lbl.text = "> %s" % first_output
			info_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		info_lbl.text = "Sellable"
		info_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	
	container.add_child(info_lbl)
	
	# Tooltip and hover effect
	var base_price = item.minimum_price if item.minimum_price > 0 else 1
	slot_panel.mouse_entered.connect(func():
		# Hover effect - brighten
		slot_panel.modulate = Color(1.2, 1.2, 1.2, 1.0)
		ItemTooltipManager.set_market_context({
			"price": price,
			"base_price": base_price,
			"supply_level": supply,
			"is_sell": is_sell,
			"produces": produces
		})
		ItemTooltipManager.show_item_tooltip(item, slot_panel.get_global_mouse_position(), slot_panel)
	)
	slot_panel.mouse_exited.connect(func():
		# Reset modulate
		slot_panel.modulate = Color(1, 1, 1, 1)
		ItemTooltipManager.clear_market_context()
		ItemTooltipManager.hide_tooltip()
	)
	
	return slot_panel


func _create_buy_item_slot(item: Item, item_id: int, price: int, supply: float, stock: int, producing: int = 0, next_ready_in: int = 0, stock_full: bool = false, recipe: Dictionary = {}, pending: Dictionary = {}) -> Panel:
	"""Create a compact item slot for buying from vendor"""
	var slot_panel = Panel.new()
	slot_panel.custom_minimum_size = Vector2(85, 105)
	slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store original modulate for hover effect
	var base_modulate = Color(1, 1, 1, 1) if stock > 0 else Color(0.5, 0.5, 0.5, 0.8)
	slot_panel.modulate = base_modulate
	
	# Make the whole panel clickable (if in stock)
	if stock > 0:
		slot_panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_action_button_pressed(item_id, price, item.item_name, false, stock)
		)
	
	# Use a Control for absolute positioning - set mouse to pass so panel gets events
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	slot_panel.add_child(container)
	
	# Center icon (80 width - 40 icon = 40, so offset 20)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.position = Vector2(20, 6)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.item_icon:
		icon.texture = item.item_icon
	container.add_child(icon)
	
	# Stock in upper-right corner
	var stock_lbl = Label.new()
	stock_lbl.position = Vector2(52, 2)
	stock_lbl.add_theme_font_size_override("font_size", 11)
	stock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	stock_lbl.add_theme_constant_override("outline_size", 2)
	stock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stock > 0:
		stock_lbl.text = "x%d" % stock
		stock_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	else:
		stock_lbl.text = "0"
		stock_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	container.add_child(stock_lbl)
	
	# Price in bottom-left corner of icon area
	var price_lbl = Label.new()
	price_lbl.position = Vector2(2, 44)
	price_lbl.add_theme_font_size_override("font_size", 11)
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	price_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	price_lbl.add_theme_constant_override("outline_size", 2)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_lbl.text = "%dg" % price
	container.add_child(price_lbl)
	
	# Trend indicator in bottom-right of icon area
	var trend = _get_trend_indicator(supply, false)
	if trend.text != "" and trend.text != "→":
		var trend_lbl = Label.new()
		trend_lbl.position = Vector2(52, 44)
		trend_lbl.add_theme_font_size_override("font_size", 10)
		trend_lbl.add_theme_color_override("font_color", trend.color)
		trend_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		trend_lbl.add_theme_constant_override("outline_size", 2)
		trend_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trend_lbl.text = trend.text
		container.add_child(trend_lbl)
	
	# Item name at bottom
	var name_label = Label.new()
	name_label.position = Vector2(0, 60)
	name_label.size = Vector2(80, 18)
	var display_name = item.item_name if item.item_name.length() <= 12 else item.item_name.left(11) + "…"
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# Production status at very bottom - make it prominent!
	var prod_lbl = Label.new()
	prod_lbl.position = Vector2(0, 78)
	prod_lbl.size = Vector2(80, 22)
	prod_lbl.add_theme_font_size_override("font_size", 11)
	prod_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	prod_lbl.add_theme_constant_override("outline_size", 2)
	prod_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prod_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if stock_full:
		prod_lbl.text = "Full"
		prod_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif producing > 0:
		var mins = next_ready_in / 60
		var secs = next_ready_in % 60
		prod_lbl.text = "+%d in %d:%02d" % [producing, mins, secs]
		prod_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	elif stock <= 0 and not recipe.is_empty():
		prod_lbl.text = "Need mats"
		prod_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	elif stock <= 0:
		prod_lbl.text = "Out"
		prod_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		# In stock - show that instead of blank
		prod_lbl.text = "In stock"
		prod_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	
	container.add_child(prod_lbl)
	
	# Tooltip and hover effect
	var base_price = item.minimum_price if item.minimum_price > 0 else 1
	slot_panel.mouse_entered.connect(func():
		# Hover effect - brighten
		if stock > 0:
			slot_panel.modulate = Color(1.2, 1.2, 1.2, 1.0)
		ItemTooltipManager.set_market_context({
			"price": price,
			"base_price": base_price,
			"supply_level": supply,
			"stock": stock,
			"is_sell": false,
			"producing": producing,
			"next_ready_in": next_ready_in,
			"recipe": recipe,
			"pending": pending
		})
		ItemTooltipManager.show_item_tooltip(item, slot_panel.get_global_mouse_position(), slot_panel)
	)
	slot_panel.mouse_exited.connect(func():
		# Reset modulate
		slot_panel.modulate = base_modulate
		ItemTooltipManager.clear_market_context()
		ItemTooltipManager.hide_tooltip()
	)
	
	return slot_panel


func _format_recipe_needs(recipe: Dictionary, pending: Dictionary) -> String:
	"""Format a recipe's needs into a short display string"""
	var parts: Array[String] = []
	for input_id in recipe.keys():
		var needed = recipe[input_id]
		var have = pending.get(input_id, 0)
		var remaining = maxi(0, needed - have)
		
		if remaining > 0:
			var input_item: Item = _get_cached_item(input_id)
			var name = "?"
			if input_item:
				name = input_item.item_name
				if name.length() > 8:
					name = name.left(7) + "…"
			parts.append("%d %s" % [remaining, name])
	
	if parts.is_empty():
		return "Ready to craft"
	
	return "Need: %s" % ", ".join(parts)


func _get_trend_indicator(supply: float, is_sell: bool) -> Dictionary:
	"""Get price trend indicator"""
	# Calculate multiplier from supply
	var multiplier = pow(10.0, -supply)
	var percent_change = int((multiplier - 1.0) * 100)
	
	var trend_text: String = ""
	var trend_color: Color = Color.WHITE
	
	if absf(supply) < 0.05:
		trend_text = "→"
		trend_color = Color(0.8, 0.8, 0.8)
	elif supply < 0:
		# Scarce - prices high
		if is_sell:
			# Good for selling!
			trend_text = "↑%d%%" % abs(percent_change)
			trend_color = Color(0.4, 1.0, 0.4)  # Green = good for seller
		else:
			# Bad for buying
			trend_text = "↑%d%%" % abs(percent_change)
			trend_color = Color(1.0, 0.4, 0.4)  # Red = expensive
	else:
		# Surplus - prices low
		if is_sell:
			# Bad for selling
			trend_text = "↓%d%%" % abs(percent_change)
			trend_color = Color(1.0, 0.4, 0.4)  # Red = bad for seller
		else:
			# Good for buying!
			trend_text = "↓%d%%" % abs(percent_change)
			trend_color = Color(0.4, 1.0, 0.4)  # Green = cheap
	
	return {"text": trend_text, "color": trend_color}


func _on_action_button_pressed(item_id: int, price: int, item_name: String, is_sell_action: bool, max_stack: int) -> void:
	selected_item_id = item_id
	selected_item_price = price
	selected_item_name = item_name
	is_selling = is_sell_action
	
	transaction_dialog.title = "Sell Item" if is_selling else "Buy Item"
	item_label.text = item_name
	price_label.text = "%d gold each" % price
	
	# Calculate max quantity
	var max_qty = 99
	if is_selling:
		max_qty = max_stack
	else:
		# Limit by stock AND by gold
		max_qty = max_stack  # max_stack is the stock when buying
		if price > 0:
			var afford = current_gold / price
			max_qty = mini(max_qty, afford)
	
	max_qty = maxi(1, max_qty)
	quantity_spinbox.max_value = max_qty
	quantity_spinbox.value = 1
	
	_update_total_label()
	transaction_dialog.popup_centered()


func _on_quantity_changed(_value: float) -> void:
	_update_total_label()


func _on_max_button_pressed() -> void:
	quantity_spinbox.value = quantity_spinbox.max_value


func _update_total_label() -> void:
	var quantity = int(quantity_spinbox.value)
	var total = selected_item_price * quantity
	
	if is_selling:
		total_label.text = "You receive: %d gold" % total
		total_label.remove_theme_color_override("font_color")
	else:
		total_label.text = "Total cost: %d gold" % total
		if total > current_gold:
			total_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			total_label.remove_theme_color_override("font_color")


func _on_transaction_confirmed() -> void:
	if selected_item_id == -1:
		return
	
	var quantity = int(quantity_spinbox.value)
	
	if is_selling:
		InstanceClient.current.request_data(&"item.sell", _on_sell_response, {
			"item_id": selected_item_id,
			"quantity": quantity
		})
	else:
		var total = selected_item_price * quantity
		if total > current_gold:
			_show_notification("Not enough gold!", "Purchase Failed")
			return
		
		InstanceClient.current.request_data(&"item.buy", _on_buy_response, {
			"item_id": selected_item_id,
			"quantity": quantity
		})


func _on_buy_response(data: Dictionary) -> void:
	if data.has("error"):
		_show_notification(data.error, "Purchase Failed")
		return
	
	var msg = "Bought %dx %s for %d gold" % [
		data.get("bought_quantity", 1),
		data.get("item_name", "item"),
		data.get("total_price", 0)
	]
	_show_notification(msg, "Purchase Complete")


func _on_sell_response(data: Dictionary) -> void:
	if data.has("error"):
		_show_notification(data.error, "Sale Failed")
		return
	
	var msg = "Sold %dx %s for %d gold" % [
		data.get("sold_quantity", 1),
		data.get("item_name", "item"),
		data.get("total_price", 0)
	]
	_show_notification(msg, "Sale Complete")


func _on_search_changed(new_text: String) -> void:
	search_filter = new_text
	_refresh_buy_items()
	_refresh_sell_items()


func _on_tab_changed(_tab: int) -> void:
	# Refresh when switching tabs
	search_filter = ""
	if search_box:
		search_box.text = ""


func _on_gold_received(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()


func _on_gold_update(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()
	_refresh_buy_items()  # Update affordability


func _on_inventory_received(data: Dictionary) -> void:
	player_inventory = data.get("inventory", data)
	_refresh_sell_items()


func _on_inventory_update(data: Dictionary) -> void:
	player_inventory = data
	_refresh_sell_items()


func _on_vendor_price_update(data: Dictionary) -> void:
	"""Receive real-time price update for a single item"""
	var item_id = data.get("item_id", 0)
	if item_id <= 0:
		return
	
	# Update sell catalog entry
	for i in range(sell_catalog.size()):
		if sell_catalog[i].get("id", 0) == item_id:
			sell_catalog[i]["price"] = data.get("buy_price", sell_catalog[i].get("price", 0))
			sell_catalog[i]["supply"] = data.get("supply_level", 0.0)
			break
	
	# Update buy catalog entry
	for i in range(buy_catalog.size()):
		if buy_catalog[i].get("id", 0) == item_id:
			buy_catalog[i]["price"] = data.get("sell_price", buy_catalog[i].get("price", 0))
			buy_catalog[i]["supply"] = data.get("supply_level", 0.0)
			break
	
	# Refresh displays
	if visible:
		_refresh_buy_items()
		_refresh_sell_items()


func _on_vendor_catalog_update(data: Dictionary) -> void:
	"""Receive updated catalog with new stock levels"""
	var catalog_data = data.get("catalog", {})
	sell_catalog = catalog_data.get("sells", sell_catalog)
	buy_catalog = catalog_data.get("buys", buy_catalog)
	
	# Refresh displays
	if visible:
		_refresh_buy_items()
		_refresh_sell_items()
		print("[VendorUI] Catalog updated - stock levels refreshed")


func _on_market_event(data: Dictionary) -> void:
	"""Handle market event start/end"""
	if data.get("active", false):
		current_event = data
	else:
		current_event = null
	
	_update_event_banner()
	
	# Refresh catalog with new event pricing
	if visible:
		InstanceClient.current.request_data(&"market.catalog", _on_catalog_received)


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "%d Gold" % current_gold


func _on_close_button_pressed() -> void:
	visible = false
	sell_catalog.clear()
	buy_catalog.clear()
	_item_cache.clear()
	selected_item_id = -1
	ItemTooltipManager.clear_market_context()


func _get_cached_item(item_id: int) -> Item:
	"""Get item from cache, loading if necessary"""
	if not _item_cache.has(item_id):
		_item_cache[item_id] = ContentRegistryHub.load_by_id(&"items", item_id)
	return _item_cache[item_id]


func _show_notification(message: String, title: String) -> void:
	var hud = get_tree().get_root().find_child("HUD", true, false)
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message, title)


func _gui_input(event: InputEvent) -> void:
	"""Block scroll events from reaching the camera"""
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
