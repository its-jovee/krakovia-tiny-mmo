class_name HUD
extends CanvasLayer


var last_opened_interface: Control
var menus: Dictionary[StringName, Control]
var current_gold: int = 0
var in_market: bool = false

@onready var menu_overlay: Control = $MenuOverlay
@onready var close_button: Button = $MenuOverlay/VBoxContainer/CloseButton
@onready var sub_menu: CanvasLayer = $SubMenu
@onready var gold_label: Label = $GoldDisplay/Label

func _ready() -> void:
	for button: Button in $MenuOverlay/VBoxContainer.get_children():
		if button.text.containsn("CLOSE"):
			button.pressed.connect(_on_overlay_menu_close_button_pressed)
			continue
		button.pressed.connect(display_menu.bind(button.text.to_lower()))
	
	# Add trade request modal
	var trade_request_modal = preload("res://source/client/ui/inventory/trade_request_modal.tscn").instantiate()
	sub_menu.add_child(trade_request_modal)
	menus["trade_request"] = trade_request_modal
	InstanceClient.subscribe(&"trade.open", _on_trade_open)
	
	# Subscribe to gold updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	
	# Subscribe to market status updates
	InstanceClient.subscribe(&"market.status", _on_market_status_update)
	
	# Subscribe to harvest item notifications
	InstanceClient.subscribe(&"harvest.item_received", _on_harvest_item_received)
	
	# Request initial gold amount
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)

func _on_gold_received(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _on_gold_update(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % current_gold

func _on_market_status_update(data: Dictionary) -> void:
	var in_market_area = data.get("in_market", false)
	print("HUD received market status: ", in_market_area)
	set_market_status(in_market_area)

func set_market_status(in_market_area: bool) -> void:
	in_market = in_market_area
	# Update UI to show market status if needed
	if gold_label:
		if in_market:
			gold_label.modulate = Color.GREEN
		else:
			gold_label.modulate = Color.WHITE

func get_market_status() -> bool:
	return in_market

func _on_overlay_menu_close_button_pressed() -> void:
	menu_overlay.hide()


func open_player_profile(player_id: int) -> void:
	display_menu(&"player_profile")
	menus[&"player_profile"].open_player_profile(player_id)


func _on_submenu_visiblity_changed(menu: Control) -> void:
	if menu.visible:
		hide()
		# Special handling for inventory menu to sync market status
		if menu.name == "Inventory" and menu.has_method("_sync_market_status_from_hud"):
			print("HUD: Calling inventory market status sync")
			menu._sync_market_status_from_hud()
	else:
		show()


func display_menu(menu_name: StringName) -> void:
	if not menus.has(menu_name):
		var path: String = "res://source/client/ui/" + menu_name + "/" + menu_name + "_menu.tscn"
		if not ResourceLoader.exists(path):
			return
		var new_menu: Control = load(path).instantiate()
		new_menu.visibility_changed.connect(_on_submenu_visiblity_changed.bind(new_menu))
		sub_menu.add_child(new_menu)
		menus[menu_name] = new_menu
	menus[menu_name].show()


func _on_overlay_menu_button_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(menu_overlay, ^"position:x", menu_overlay.position.x + menu_overlay.size.x, 0.0)
	tween.tween_callback(menu_overlay.show)
	tween.tween_property(menu_overlay, ^"position:x", 815.0, 0.3)

func _on_trade_open(data: Dictionary):
	# Open inventory menu to ensure it's loaded and ready for trade
	display_menu(&"inventory")

# temporary
var attributes: Dictionary
var available_points: int:
	set(value):
		$LevelupButton/Control/VBoxContainer/Label.text = "Available points: %d" % value
		available_points = value

func _on_levelup_button_pressed() -> void:
	print_debug(attributes)
	if not attributes:
		InstanceClient.current.request_data(
			&"attribute.get",
			_on_attribute_received,
		)
	else:
		$LevelupButton/Control.visible = not $LevelupButton/Control.visible


func _on_attribute_received(data: Dictionary) -> void:
	attributes = data
	available_points = data.get("points", 0)
	$LevelupButton/Control/Label.text = "Debug:\n" + str(data)
	$LevelupButton/Control.show()


func _on_vit_button_pressed() -> void:
	if available_points:
		available_points -= 1
		InstanceClient.current.request_data(
			&"attribute.spend",
			Callable(),
			{"attr": "vitality"}
		)


func _on_button_str_pressed() -> void:
	if available_points:
		available_points -= 1
		InstanceClient.current.request_data(
			&"attribute.spend",
			Callable(),
			{"attr": "strenght"}
		)


func _on_harvest_item_received(data: Dictionary) -> void:
	"""Handle harvest item notifications and show popup"""
	var items: Array = data.get("items", [])
	for item_dict in items:
		var slug: StringName = item_dict.get("slug", &"")
		var amount: int = int(item_dict.get("amount", 0))
		
		# Get item details from registry
		var item: Item = ContentRegistryHub.load_by_slug(&"items", slug)
		if item and amount > 0:
			_show_harvest_popup(item.item_name, item.item_icon, amount)


func _show_harvest_popup(item_name: String, icon: Texture2D, amount: int) -> void:
	"""Create and display a harvest notification popup"""
	# Load the popup scene
	var popup_scene = preload("res://source/client/ui/hud/harvest_popup.tscn")
	if not popup_scene:
		# Fallback: print to console if scene doesn't exist yet
		print("[Harvest] +%d %s" % [amount, item_name])
		return
	
	var popup: Control = popup_scene.instantiate()
	add_child(popup)
	
	# Position popup at bottom-center of screen, stacking vertically if multiple exist
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var base_y: float = viewport_size.y - 150.0
	
	# Count existing popups to stack them
	var existing_popups: int = 0
	for child in get_children():
		if child.name.begins_with("HarvestPopup"):
			existing_popups += 1
	
	popup.position = Vector2(viewport_size.x / 2.0 - 100.0, base_y - (existing_popups * 50.0))
	
	# Setup the popup
	if popup.has_method("setup"):
		popup.setup(item_name, icon, amount)
