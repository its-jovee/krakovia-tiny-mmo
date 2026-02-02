class_name HUD
extends CanvasLayer


var last_opened_interface: Control
var menus: Dictionary[StringName, Control]
var current_gold: int = 0
var in_market: bool = false
var current_level: int = 1
var current_exp: int = 0
var exp_required: int = 100
var has_opened_guide: bool = false  # Set to true when character is created (triggers guide auto-open)

# Harvest popup queue system
var _harvest_popup_queue: Array[Dictionary] = []
var _last_popup_time_ms: int = 0
const POPUP_MIN_INTERVAL_MS: int = 100  # Minimum 100ms between popups

@onready var menu_overlay: Control = $MenuOverlay
@onready var close_button: Button = $MenuOverlay/VBoxContainer/CloseButton
@onready var sub_menu: CanvasLayer = $SubMenu
@onready var gold_label: Label = $HBoxContainer2/VBoxContainer/GoldDisplay/Label
@onready var level_display: Panel = $HBoxContainer2/VBoxContainer/LevelDisplay
@onready var level_label: Label = $HBoxContainer2/VBoxContainer/LevelDisplay/VBoxContainer/LevelLabel
@onready var exp_progress_bar: ProgressBar = $HBoxContainer2/VBoxContainer/LevelDisplay/VBoxContainer/ExpProgressBar

# New HBoxContainer buttons
@onready var inventory_button: Button = $HBoxContainer/InventoryButton
@onready var crafting_button: Button = $HBoxContainer/CraftingButton
@onready var guild_button: Button = $HBoxContainer/GuildButton
@onready var shop_button: Button = $HBoxContainer/ShopButton
@onready var guide_button: Button = $HBoxContainer/GuideButton
@onready var titles_button: Button = $HBoxContainer/TitlesButton
@onready var guide_modal: Control = $GuideModal
@onready var character_creation_modal: Control = $CharacterCreationModal
@onready var character_portrait: Control = $HBoxContainer2/CharacterPortrait

# Menu overlay buttons
@onready var settings_button: Button = $MenuOverlay/VBoxContainer/SettingsButton
@onready var close_menu_button: Button = $MenuOverlay/VBoxContainer/CloseButton

# Time display
@onready var time_label: Label = $HBoxContainer2/VBoxContainer/TimeDisplay/TimeLabel

func _ready() -> void:
	# Wire up character portrait with character creation modal
	if character_portrait and character_creation_modal:
		character_portrait.set_character_creation_modal(character_creation_modal)
	
	# Connect the new HBoxContainer buttons
	if inventory_button:
		inventory_button.pressed.connect(_on_inventory_button_pressed)
	if crafting_button:
		crafting_button.pressed.connect(_on_crafting_button_pressed)
	if titles_button:
		titles_button.pressed.connect(_on_titles_button_pressed)
	if guild_button:
		guild_button.pressed.connect(_on_guild_button_pressed)
	if shop_button:
		shop_button.pressed.connect(_on_shop_button_pressed)
	if guide_button:
		guide_button.pressed.connect(_on_guide_button_pressed)
	
	# Connect MenuOverlay buttons
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
	
	# Add shop setup menu
	var shop_setup_menu = preload("res://source/client/ui/shop/shop_setup_ui.tscn").instantiate()
	sub_menu.add_child(shop_setup_menu)
	menus["shop_setup"] = shop_setup_menu
	
	# Add shop browse menu
	var shop_browse_menu = preload("res://source/client/ui/shop/shop_browse_ui.tscn").instantiate()
	sub_menu.add_child(shop_browse_menu)
	menus["shop_browse"] = shop_browse_menu
	
	# Add titles menu
	var titles_menu = preload("res://source/client/ui/titles/titles_menu.tscn").instantiate()
	sub_menu.add_child(titles_menu)
	menus["titles"] = titles_menu
	
	# Add storage menu
	var storage_menu = preload("res://source/client/ui/storage/storage_menu.tscn").instantiate()
	sub_menu.add_child(storage_menu)
	menus["storage"] = storage_menu
	
	# Add leaderboard menu
	var leaderboard_menu = preload("res://source/client/ui/leaderboard/leaderboard_menu.tscn").instantiate()
	sub_menu.add_child(leaderboard_menu)
	menus["leaderboard"] = leaderboard_menu
	
	# Add market browse UI (for buying from NPCs)
	var market_browse_menu = preload("res://source/client/ui/market/market_browse_ui.tscn").instantiate()
	market_browse_menu.visibility_changed.connect(_on_submenu_visiblity_changed.bind(market_browse_menu))
	sub_menu.add_child(market_browse_menu)
	menus[&"market_browse"] = market_browse_menu
	
	# Add worker hire menu
	var worker_hire_menu = preload("res://source/client/ui/worker/worker_hire_ui.tscn").instantiate()
	worker_hire_menu.visibility_changed.connect(_on_submenu_visiblity_changed.bind(worker_hire_menu))
	sub_menu.add_child(worker_hire_menu)
	menus[&"worker_hire"] = worker_hire_menu
	
	# Subscribe to gold updates
	InstanceClient.subscribe(&"gold.update", _on_gold_update)
	
	# Subscribe to market status updates
	InstanceClient.subscribe(&"market.status", _on_market_status_update)
	
	# Subscribe to vendor status updates (for NPC vendor interaction)
	InstanceClient.subscribe(&"vendor.status", _on_vendor_status_update)
	
	# Subscribe to worker area status updates (for hired worker NPCs)
	InstanceClient.subscribe(&"worker.area.status", _on_worker_area_status_update)
	
	# Subscribe to worker item collection notifications (shows popups like harvest)
	InstanceClient.subscribe(&"worker.items_received", _on_worker_items_received)
	
	# Subscribe to storage chest status updates
	InstanceClient.subscribe(&"storage_chest.status", _on_storage_chest_status_update)
	
	# Subscribe to harvest item notifications
	InstanceClient.subscribe(&"harvest.item_received", _on_harvest_item_received)
	
	# Subscribe to exp updates
	InstanceClient.subscribe(&"exp.update", _on_exp_update)
	
	# Request initial gold amount
	InstanceClient.current.request_data(&"gold.get", _on_gold_received)
	
	# Request initial level/exp data
	InstanceClient.current.request_data(&"level.get", _on_level_received)
	
	# Connect to language change events
	EventBus.language_changed.connect(_update_ui_text)
	_update_ui_text()
	
	# Check if this is a newly created character
	print("[Guide] HUD ready - checking just_created_character flag: ", EventBus.just_created_character)
	if EventBus.just_created_character:
		print("[Guide] Detected newly created character - will auto-open guide in 2 seconds")
		EventBus.just_created_character = false  # Reset flag
		_delayed_guide_open.call_deferred()
	else:
		print("[Guide] Not a newly created character, skipping auto-open")


func _process(_delta: float) -> void:
	# Process the harvest popup queue
	_process_popup_queue()
	
	# Update time display
	_update_time_display()


func _update_ui_text() -> void:
	# Update gold display
	_update_gold_display()
	
	# Update level display
	_update_level_display()
	
	# Update menu overlay buttons
	if settings_button:
		settings_button.text = TranslationServer.translate("hud_settings")
	if close_menu_button:
		close_menu_button.text = TranslationServer.translate("hud_close")
	
	# Update guide tooltip
	if guide_button:
		guide_button.tooltip_text = TranslationServer.translate("hud_tooltip_guide")

func _on_gold_received(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _on_gold_update(data: Dictionary) -> void:
	current_gold = data.get("gold", 0)
	_update_gold_display()

func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = TranslationServer.translate("hud_gold").format({"amount": current_gold})


func _update_time_display() -> void:
	if not time_label:
		return
	
	var day_night = InstanceClient.day_night_cycle
	if not day_night:
		time_label.text = "..."
		return
	
	var phase = day_night.get_phase_name()
	
	# Set color based on phase
	match phase:
		"Dawn":
			time_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
		"Day":
			time_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		"Dusk":
			time_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		"Evening":
			time_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.85))
		"Night", "Late Night":
			time_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		_:
			time_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	
	time_label.text = phase


func _on_market_status_update(data: Dictionary) -> void:
	var in_market_area = data.get("in_market", false)
	print("HUD received market status: ", in_market_area)
	set_market_status(in_market_area)


func _on_vendor_status_update(data: Dictionary) -> void:
	var in_vendor = data.get("in_vendor", false)
	var vendor_info = data.get("vendor", {})
	var vendor_name = vendor_info.get("name", "Vendor")
	var vendor_id = vendor_info.get("id", "")
	
	# Translate vendor name on client side
	if not vendor_id.is_empty():
		var translated_name = TranslationServer.translate("npc_%s_name" % vendor_id)
		if translated_name != ("npc_%s_name" % vendor_id):  # Check if translation exists
			vendor_name = translated_name
	
	print("[HUD] Vendor status: in_vendor=%s, vendor=%s" % [in_vendor, vendor_name])
	
	if in_vendor:
		# Auto-open the vendor UI when entering a vendor area
		open_vendor_ui()
	else:
		# Close vendor UI when leaving vendor area
		if menus.has(&"market_browse"):
			menus[&"market_browse"].visible = false


func _on_worker_area_status_update(data: Dictionary) -> void:
	var in_worker_area = data.get("in_worker_area", false)
	var worker_type = data.get("worker_type", "")
	var worker_name = data.get("worker_name", "Worker")
	var worker_id = data.get("worker_id", "")
	
	# Translate worker name on client side
	if not worker_id.is_empty():
		var translated_name = TranslationServer.translate("npc_%s_name" % worker_id)
		if translated_name != ("npc_%s_name" % worker_id):  # Check if translation exists
			worker_name = translated_name
	
	print("[HUD] Worker area status: in_area=%s, type=%s, name=%s" % [in_worker_area, worker_type, worker_name])
	
	if in_worker_area and worker_type != "":
		# Auto-open the worker hire UI when entering a worker area
		open_worker_ui(worker_type)
	else:
		# Close worker UI when leaving worker area
		if menus.has(&"worker_hire"):
			menus[&"worker_hire"].visible = false


func open_worker_ui(worker_type: String) -> void:
	"""Open the worker hire UI for a specific worker type"""
	if menus.has(&"worker_hire"):
		var worker_menu = menus[&"worker_hire"]
		if worker_menu.has_method("open_worker"):
			worker_menu.open_worker(worker_type)


func set_market_status(in_market_area: bool) -> void:
	in_market = in_market_area
	# Update UI to show market status if needed
	if gold_label:
		if in_market:
			gold_label.modulate = Color.GREEN
		else:
			gold_label.modulate = Color.WHITE
	
	# Auto-open market browse when entering market (optional behavior)
	# Uncomment the line below to enable auto-open:
	# if in_market:
	# 	open_market_browse()

func get_market_status() -> bool:
	return in_market


func open_market_browse() -> void:
	"""Legacy - redirects to open_vendor_ui"""
	open_vendor_ui()


func open_vendor_ui() -> void:
	"""Open vendor UI for buying/selling items"""
	if menus.has(&"market_browse"):
		var vendor_menu = menus[&"market_browse"]
		if vendor_menu.has_method("open_vendor"):
			vendor_menu.open_vendor()
		elif vendor_menu.has_method("open_market"):
			vendor_menu.open_market()  # Fallback for old method name

func _on_storage_chest_status_update(data: Dictionary) -> void:
	var in_storage_area = data.get("in_storage_area", false)
	print("HUD received storage chest status: ", in_storage_area)
	if in_storage_area:
		# Auto-open storage menu when entering area
		if menus.has(&"storage"):
			var storage_menu = menus[&"storage"]
			if storage_menu.has_method("show_menu"):
				storage_menu.show_menu()
			else:
				# Animate open if show_menu not available
				if has_node("/root/UIAnimations"):
					get_node("/root/UIAnimations").animate_panel_open(storage_menu)
				else:
					storage_menu.visible = true
	else:
		# Auto-close storage menu when leaving area
		if menus.has(&"storage"):
			var storage_menu = menus[&"storage"]
			if has_node("/root/UIAnimations"):
				get_node("/root/UIAnimations").animate_panel_close(storage_menu)
			else:
				storage_menu.visible = false

func _on_overlay_menu_close_button_pressed() -> void:
	menu_overlay.hide()


func _on_inventory_button_pressed() -> void:
	"""Open inventory menu showing equipment view"""
	display_menu(&"inventory")
	# Ensure we're on the equipment tab (tab index 0)
	if menus.has(&"inventory") and menus[&"inventory"].has_method("show_tab"):
		menus[&"inventory"].show_tab(0)


func _on_crafting_button_pressed() -> void:
	"""Open inventory menu and switch to crafting tab"""
	display_menu(&"inventory")
	# Switch to crafting tab (tab index 4)
	if menus.has(&"inventory") and menus[&"inventory"].has_method("show_tab"):
		menus[&"inventory"].show_tab(4)


func _on_guild_button_pressed() -> void:
	"""Open guild menu"""
	display_menu(&"guild")


func _on_shop_button_pressed() -> void:
	"""Open shop setup menu"""
	# Make player sit down immediately when opening shop UI
	InstanceClient.current.request_data(&"state.sit", Callable(), {"on": true})
	
	if menus.has(&"shop_setup"):
		var shop_menu = menus[&"shop_setup"]
		if shop_menu.has_method("show_menu"):
			shop_menu.show_menu()
		shop_menu.visible = true
	else:
		# Fallback: try to display it
		display_menu(&"shop_setup")


func open_player_shop(seller_peer_id: int) -> void:
	"""Open shop browse UI for a specific seller"""
	if menus.has(&"shop_browse"):
		var browse_menu = menus[&"shop_browse"]
		if browse_menu.has_method("open_shop"):
			browse_menu.open_shop(seller_peer_id)


func _on_titles_button_pressed() -> void:
	"""Open titles menu"""
	display_menu(&"titles")


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
	
	# Play open sound
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_open()
	
	# Animate menu open
	var menu = menus[menu_name]
	if has_node("/root/UIAnimations"):
		get_node("/root/UIAnimations").animate_panel_open(menu)
	else:
		menu.show()
	
	menu_overlay.hide()  # Close the menu overlay after opening a menu


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
		$LevelupButton/Control/VBoxContainer/Label.text = TranslationServer.translate("hud_available_points").format({"points": value})
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


func _on_worker_items_received(data: Dictionary) -> void:
	"""Handle worker collection notifications and show popup (like harvest)"""
	var items: Array = data.get("items", [])
	
	# Queue each item for display (no EXP for worker collection)
	for item_dict in items:
		var slug: StringName = item_dict.get("slug", &"")
		var amount: int = int(item_dict.get("amount", 0))
		
		# Get item details from registry
		var item: Item = ContentRegistryHub.load_by_slug(&"items", slug)
		if item and amount > 0:
			var translated_name = ItemTooltipManager._get_translated_item_name(item)
			_queue_harvest_popup(translated_name, item.item_icon, amount, 0)


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
	
	# Queue each item for display
	for item_dict in items:
		var slug: StringName = item_dict.get("slug", &"")
		var amount: int = int(item_dict.get("amount", 0))
		
		# Get item details from registry
		var item: Item = ContentRegistryHub.load_by_slug(&"items", slug)
		if item and amount > 0:
			var item_exp: int = exp_per_item * amount
			var translated_name = ItemTooltipManager._get_translated_item_name(item)
			_queue_harvest_popup(translated_name, item.item_icon, amount, item_exp)


func _queue_harvest_popup(item_name: String, icon: Texture2D, amount: int, exp_amount: int) -> void:
	"""Add a popup to the queue for display"""
	_harvest_popup_queue.append({
		"name": item_name,
		"icon": icon,
		"amount": amount,
		"exp": exp_amount
	})


func _process_popup_queue() -> void:
	"""Process the popup queue - called from _process"""
	if _harvest_popup_queue.is_empty():
		return
	
	var now_ms: int = Time.get_ticks_msec()
	
	# Check if enough time has passed since last popup
	if now_ms - _last_popup_time_ms >= POPUP_MIN_INTERVAL_MS:
		var popup_data: Dictionary = _harvest_popup_queue.pop_front()
		_show_harvest_popup(popup_data["name"], popup_data["icon"], popup_data["amount"], popup_data["exp"])
		_last_popup_time_ms = now_ms


func _show_harvest_popup(item_name: String, icon: Texture2D, amount: int, exp_amount: int = 0) -> void:
	"""Create and display a harvest notification popup in top-right corner"""
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
	
	# Position popup at top-right of screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_width: float = 240.0
	var popup_height: float = 50.0
	var base_x: float = viewport_size.x - popup_width - 20.0  # 20px from right edge
	var base_y: float = 100.0  # Start from top
	
	# Push existing popups down to make room for the new one
	for child in get_children():
		if child.name.begins_with("HarvestPopup_") and child != popup:
			var tween = create_tween()
			tween.tween_property(child, "position:y", child.position.y + popup_height + 8.0, 0.12).set_ease(Tween.EASE_OUT)
	
	# New popup appears at the top (most recent first)
	popup.position = Vector2(base_x, base_y)
	
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
		level_label.text = TranslationServer.translate("hud_level").format({"level": current_level})
	if exp_progress_bar:
		exp_progress_bar.max_value = exp_required
		# Animate progress bar value change
		if has_node("/root/UIAnimations"):
			var anim = get_node("/root/UIAnimations")
			anim.animate_bar_fill(exp_progress_bar, current_exp)
		else:
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
	
	# Play success sound and animate
	if has_node("/root/UISounds"):
		get_node("/root/UISounds").play_success()
	if has_node("/root/UIAnimations"):
		get_node("/root/UIAnimations").animate_popup_in(popup)


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
	
	# Load the content index to get all recipe entries
	var recipes_index: ContentIndex = load("res://source/common/registry/indexes/recipes_index.tres")
	if not recipes_index:
		return unlocked
	
	# Iterate through all entries in the registry
	for entry in recipes_index.entries:
		var recipe_id: int = entry.get(&"id", 0)
		if recipe_id == 0:
			continue
		var recipe: CraftingRecipe = ContentRegistryHub.load_by_id(&"recipes", recipe_id)
		if recipe and recipe.required_level == level:
			# If we have player class, filter by it. Otherwise show all.
			if player_class == "" or recipe.required_class == player_class:
				unlocked.append(String(recipe.recipe_name))
	
	return unlocked


## Show a simple notification message using AcceptDialog
func show_notification(message: String, title: String = "Notification") -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = title
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dialog.ok_button_text = "OK"
	
	# Add to scene
	add_child(dialog)
	
	# Show popup
	dialog.popup_centered()
	
	# Auto-close after confirmed or timeout
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	
	# Auto-close after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(dialog):
		dialog.queue_free()


func _on_guide_button_pressed() -> void:
	"""Open the game guide modal"""
	if guide_modal:
		guide_modal.open_guide()


func open_guide_for_new_player() -> void:
	"""Manually open the guide (called by guide button)"""
	if guide_modal:
		guide_modal.open_guide()


func _delayed_guide_open() -> void:
	"""Delayed guide open with async support"""
	print("[Guide] _delayed_guide_open called, waiting 2 seconds...")
	await get_tree().create_timer(2.0).timeout
	print("[Guide] Delay complete, checking guide_modal: ", guide_modal != null, " is_valid: ", is_instance_valid(guide_modal) if guide_modal else false)
	if guide_modal and is_instance_valid(guide_modal):
		print("[Guide] Opening guide modal now!")
		guide_modal.open_guide()
		print("[Guide] Guide modal opened successfully!")
	else:
		print("[Guide] ERROR: guide_modal is null or invalid!")
