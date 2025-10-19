extends Control

## Game Guide Modal with free navigation between pages

var current_page: int = 0
var total_pages: int = 6

# Page data structure
var pages: Array[Dictionary] = [
	{
		"title": "Welcome & Basic Controls",
		"gif": "res://assets/guides/welcome.gif",
		"content": """[b]Welcome to Krakovia Kraft![/b]

This is a multiplayer crafting and trading MMO where you harvest resources, craft items, and trade with other players.

[b]Basic Controls:[/b]
• [b]WASD[/b] - Move your character
• [b]Left Click[/b] - Interact with nodes, NPCs, UI
• [b]Right Click[/b] - Open trade with players
• [b]I[/b] - Open Inventory
• [b]C[/b] - Open Crafting
• [b]Enter[/b] - Chat
• [b]ESC[/b] - Close menus

[b]Your Goal:[/b]
Harvest resources, craft valuable items, trade with players, and build your wealth!"""
	},
	{
		"title": "Harvesting System",
		"gif": "res://assets/guides/harvesting.gif",
		"content": """[b]How to Harvest:[/b]

1. Find a harvesting node (rocks, plants, hunting areas)
2. Walk up to the node and click on it
3. Stand still while the progress bar fills
4. Collect items when they drop!

[b]Node Tiers:[/b]
• [b]Tier 1-2[/b]: Beginner nodes, anyone can harvest
• [b]Tier 3-4[/b]: Intermediate nodes, level requirement
• [b]Tier 5-6[/b]: Advanced nodes, higher level required

[b]Multiplayer Bonus:[/b]
Harvesting with other players gives a [b]multiplier bonus[/b]!
• 2 players: 1.1x yield
• 3 players: 1.2x yield
• 4+ players: 1.3x yield

[b]Energy Cost:[/b]
Harvesting consumes energy. If you run out, you can't harvest until it regenerates!"""
	},
	{
		"title": "Crafting System",
		"gif": "res://assets/guides/crafting.gif",
		"content": """[b]How to Craft:[/b]

1. Press [b]C[/b] or click the Crafting button in the HUD
2. Browse available recipes in the left panel
3. Select a recipe to see requirements
4. Click [b]Craft[/b] if you have the materials
5. Items are added to your inventory!

[b]Recipe Types:[/b]
• [b]Processing[/b]: Turn raw materials into refined goods
• [b]Crafting[/b]: Combine materials into new items
• [b]Advanced[/b]: Complex recipes for valuable items

[b]Crafting Tips:[/b]
• Higher tier items sell for more gold
• Some recipes unlock at higher levels
• Crafted items can be traded with other players
• Check the marketplace to see what's in demand!"""
	},
	{
		"title": "Trading with Players",
		"gif": "res://assets/guides/trading.gif",
		"content": """[b]Trading Methods:[/b]

[b]1. Direct Player Trade:[/b]
• Walk up to another player
• [b]Right-click[/b] on them
• Select items and quantities to trade
• Both players must accept

[b]2. Chat Advertisements:[/b]
You can advertise in chat:
• [b]WTS[/b] (Want To Sell): "/wts Iron Ore x50"
• [b]WTB[/b] (Want To Buy): "/wtb Hide x30"
• [b]WTT[/b] (Want To Trade): "/wtt Sword for Armor"

[b]3. Player Shops:[/b]
Set up your own shop to sell items while you're offline!

[b]Trading Tips:[/b]
• Check item values before trading
• Be polite and fair with other players
• Use chat to find buyers/sellers
• Player shops are great for passive income"""
	},
	{
		"title": "Energy System & Minigames",
		"gif": "res://assets/guides/energy.gif",
		"content": """[b]Energy System:[/b]

Energy is consumed when:
• Harvesting resources
• Participating in minigames
• Crafting certain items

Energy regenerates slowly over time. Manage it wisely!

[b]Minigames:[/b]

Minigames are fun events that happen periodically:

[b]Hot Potato:[/b]
• Players pass a "potato" to each other
• Last player holding it when timer ends loses
• Winners get rewards!
• Enter the minigame zone when announced

[b]Minigame Tips:[/b]
• Server-wide announcements alert you when they start
• Minigames are optional but rewarding
• They're a great way to earn extra items
• Watch your energy before joining!"""
	},
	{
		"title": "Player Shops",
		"gif": "res://assets/guides/shops.gif",
		"content": """[b]Setting Up Your Shop:[/b]

1. Click the [b]Shop[/b] button in the HUD
2. Add items from your inventory
3. Set prices for each item
4. Toggle your shop [b]Open[/b]
5. Other players can buy while you're online or offline!

[b]Shopping at Other Player Shops:[/b]

• Look for the [b]🏪 shop indicator[/b] above players
• Click on them to browse their shop
• Buy items directly with gold
• Shops persist even when players log off

[b]Shop Strategy:[/b]
• Price competitively to attract buyers
• Sell high-demand items (check chat!)
• Restock regularly
• Advertise your shop in chat
• Position yourself in high-traffic areas

[b]Shop Tips:[/b]
• You earn gold even while offline!
• Popular items sell faster
• Watch market trends to adjust prices"""
	}
]

# UI References
@onready var close_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleBar/CloseButton
@onready var page_title: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/PageTitle
@onready var content_text: RichTextLabel = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/ScrollContainer/ContentVBox/ContentText
@onready var gif_texture: TextureRect = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/PageContent/ScrollContainer/ContentVBox/GIFContainer/GIFTexture
@onready var page_indicator: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/PageIndicator
@onready var prev_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/PrevButton
@onready var next_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/BottomBar/NextButton
@onready var overlay: ColorRect = $Overlay

# Sidebar page buttons
@onready var page_buttons: Array = [
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page0Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page1Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page2Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page3Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page4Button,
	$CenterContainer/MainPanel/MarginContainer/VBoxContainer/ContentArea/Sidebar/PageButtons/Page5Button,
]


func _ready() -> void:
	# Connect signals
	close_button.pressed.connect(_on_close_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# Connect sidebar buttons
	for i in range(page_buttons.size()):
		if page_buttons[i]:
			page_buttons[i].pressed.connect(_on_page_button_pressed.bind(i))
	
	# Start hidden
	hide()
	
	# Load first page
	_load_page(0)


func open_guide(start_page: int = 0) -> void:
	"""Open the guide modal"""
	print("[GuideModal] open_guide called with start_page: ", start_page)
	current_page = start_page
	_load_page(current_page)
	show()
	print("[GuideModal] Guide modal is now visible: ", visible)


func close_guide() -> void:
	"""Close the guide modal"""
	hide()


func _load_page(page_index: int) -> void:
	"""Load and display a specific page"""
	if page_index < 0 or page_index >= pages.size():
		return
	
	current_page = page_index
	var page_data: Dictionary = pages[page_index]
	
	# Update title
	page_title.text = page_data["title"]
	
	# Update content
	content_text.text = page_data["content"]
	
	# Load GIF (if exists)
	var gif_path: String = page_data["gif"]
	if ResourceLoader.exists(gif_path):
		var gif_texture_res = load(gif_path)
		if gif_texture_res:
			gif_texture.texture = gif_texture_res
	else:
		# Placeholder if GIF doesn't exist yet
		gif_texture.texture = null
	
	# Update page indicator
	page_indicator.text = TranslationServer.translate("guide_page_indicator").format({
		"current": current_page + 1,
		"total": total_pages
	})
	
	# Update button states
	prev_button.disabled = (current_page == 0)
	next_button.disabled = (current_page == total_pages - 1)
	
	# Highlight active page button
	_update_sidebar_buttons()


func _update_sidebar_buttons() -> void:
	"""Highlight the current page button"""
	for i in range(page_buttons.size()):
		if page_buttons[i]:
			if i == current_page:
				page_buttons[i].add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold highlight
			else:
				page_buttons[i].remove_theme_color_override("font_color")


func _on_close_pressed() -> void:
	close_guide()


func _on_prev_pressed() -> void:
	if current_page > 0:
		_load_page(current_page - 1)


func _on_next_pressed() -> void:
	if current_page < total_pages - 1:
		_load_page(current_page + 1)


func _on_page_button_pressed(page_index: int) -> void:
	"""Direct navigation from sidebar"""
	_load_page(page_index)


func _on_overlay_clicked(event: InputEvent) -> void:
	"""Close guide when clicking outside the panel"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_guide()


func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts"""
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC key
		close_guide()
		accept_event()
