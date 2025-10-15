class_name HUD
extends CanvasLayer


var last_opened_interface: Control
var menus: Dictionary[StringName, Control]
var current_gold: int = 0
var in_market: bool = false
var current_level: int = 1
var current_exp: int = 0
var exp_required: int = 100

@onready var menu_overlay: Control = $MenuOverlay
@onready var close_button: Button = $MenuOverlay/VBoxContainer/CloseButton
@onready var sub_menu: CanvasLayer = $SubMenu
@onready var gold_label: Label = $GoldDisplay/Label
@onready var level_display: Panel = $LevelDisplay
@onready var level_label: Label = $LevelDisplay/VBoxContainer/LevelLabel
@onready var exp_progress_bar: ProgressBar = $LevelDisplay/VBoxContainer/ExpProgressBar

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
	
	# Add quest board menu
	var quest_board_menu = preload("res://source/client/ui/quest_board/quest_board_menu.tscn").instantiate()
	sub_menu.add_child(quest_board_menu)
	menus["quest_board"] = quest_board_menu
	
	# Subscribe to gold updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	
	# Subscribe to market status updates
	InstanceClient.subscribe(&"market.status", _on_market_status_update)
	
	# Subscribe to harvest item notifications
	InstanceClient.subscribe(&"harvest.item_received", _on_harvest_item_received)
	
	# Subscribe to exp updates
	InstanceClient.subscribe(&"exp.update", _on_exp_update)
	
	# Request initial gold amount
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	
	# Request initial level/exp data
	InstanceClient.current.request_data(&"level.get", _on_level_received)

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
	var exp_gained: int = data.get("exp_gained", 0)
	
	# Calculate EXP per item (divide total exp by total items)
	var total_items: int = 0
	for item_dict in items:
		total_items += int(item_dict.get("amount", 0))
	
	var exp_per_item: int = 0
	if total_items > 0 and exp_gained > 0:
		exp_per_item = int(float(exp_gained) / float(total_items))
	
	for item_dict in items:
		var slug: StringName = item_dict.get("slug", &"")
		var amount: int = int(item_dict.get("amount", 0))
		
		# Get item details from registry
		var item: Item = ContentRegistryHub.load_by_slug(&"items", slug)
		if item and amount > 0:
			var item_exp: int = exp_per_item * amount
			_show_harvest_popup(item.item_name, item.item_icon, amount, item_exp)


func _show_harvest_popup(item_name: String, icon: Texture2D, amount: int, exp_amount: int = 0) -> void:
	"""Create and display a harvest notification popup"""
	# Load the popup scene
	var popup_scene = preload("res://source/client/ui/hud/harvest_popup.tscn")
	if not popup_scene:
		# Fallback: print to console if scene doesn't exist yet
		print("[Harvest] +%d %s" % [amount, item_name])
		return
	
	var popup: Control = popup_scene.instantiate()
	
	# Give it a unique name for tracking
	popup.name = "HarvestPopup_" + str(Time.get_ticks_msec())
	add_child(popup)
	
	# Position popup at bottom-center of screen, stacking vertically if multiple exist
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var base_y: float = viewport_size.y - 100.0
	
	# Count existing popups to stack them
	var existing_popups: int = 0
	for child in get_children():
		if child.name.begins_with("HarvestPopup_"):
			existing_popups += 1
	
	popup.position = Vector2(viewport_size.x / 2.0 - 120.0, base_y - (existing_popups * 50.0))
	
	# Setup the popup
	if popup.has_method("setup"):
		popup.setup(item_name, icon, amount, exp_amount)


func _on_level_received(data: Dictionary) -> void:
	current_level = data.get("level", 1)
	current_exp = data.get("experience", 0)
	exp_required = data.get("exp_required", 100)
	_update_level_display()


func _on_exp_update(data: Dictionary) -> void:
	var old_level = current_level
	current_level = data.get("level", current_level)
	current_exp = data.get("exp", current_exp)
	exp_required = data.get("exp_required", 100)
	var leveled_up = data.get("leveled_up", false)
	
	_update_level_display()
	
	if leveled_up and current_level > old_level:
		_show_level_up_popup(current_level)


func _update_level_display() -> void:
	if level_label:
		level_label.text = "Level %d" % current_level
	if exp_progress_bar:
		exp_progress_bar.max_value = exp_required
		exp_progress_bar.value = current_exp


func _show_level_up_popup(new_level: int) -> void:
	var popup_scene = preload("res://source/client/ui/hud/level_up_popup.tscn")
	var popup: Control = popup_scene.instantiate()
	add_child(popup)
	
	# Position at center of screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	popup.position = Vector2(viewport_size.x / 2.0 - 200.0, viewport_size.y / 2.0 - 150.0)
	
	# Get unlocked recipes for this level
	var unlocked_recipes = _get_unlocked_recipes_for_level(new_level)
	
	if popup.has_method("setup"):
		popup.setup(new_level, unlocked_recipes)


func _get_unlocked_recipes_for_level(level: int) -> Array[String]:
	"""Get all recipes that are unlocked at this specific level for the player's class"""
	var unlocked: Array[String] = []
	
	# Get player class from local player
	var player_class: String = ""
	if InstanceClient.local_player:
		player_class = InstanceClient.local_player.character_class
	
	# Load all recipes from registry
	var registry = ContentRegistryHub.registry_of(&"recipes")
	if not registry:
		return unlocked
	
	# Check all recipe IDs (1-145 based on what I saw in inventory_menu.gd)
	for recipe_id in range(1, 146):
		var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
		if recipe and recipe.required_level == level:
			# If we have player class, filter by it. Otherwise show all.
			if player_class == "" or recipe.required_class == player_class:
				unlocked.append(String(recipe.recipe_name))
	
	return unlocked
