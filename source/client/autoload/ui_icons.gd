extends Node
## UIIcons - Centralized icon registry for UI elements
## Maps semantic icon names to their actual resource paths.
## Provides helpers for getting icon textures and BBCode image tags.


# =============================================================================
# ICON PATHS - Using existing Raven Fantasy Icons (32x32)
# =============================================================================

const ICON_BASE := "res://assets/Raven Fantasy Icons/Separated Files/32x32/"

# Icon mappings: semantic_name -> filename
# These use existing icons from the Raven Fantasy pack
const ICONS := {
	# -------------------------------------------------------------------------
	# ACTIONS
	# -------------------------------------------------------------------------
	"checkmark": "fb1094.png",      # Green checkmark
	"check": "fb1094.png",          # Alias
	"close": "fb1093.png",          # Red X / close
	"x": "fb1093.png",              # Alias
	"arrow_left": "fb1089.png",     # Left arrow
	"arrow_right": "fb1090.png",    # Right arrow
	"arrow_up": "fb1087.png",       # Up arrow
	"arrow_down": "fb1088.png",     # Down arrow
	"back": "fb1089.png",           # Back arrow
	
	# -------------------------------------------------------------------------
	# ECONOMY / TRADING
	# -------------------------------------------------------------------------
	"gold": "coroa.png",            # Gold coin/crown
	"coin": "coroa.png",            # Alias
	"money": "coroa.png",           # Alias
	"shop": "fb44.png",             # Shop/store icon
	"store": "fb44.png",            # Alias
	"stock": "barrel.png",          # Barrel for stock
	"box": "fb34.png",              # Box/crate
	"package": "fb34.png",          # Alias
	"trade": "fb1103.png",          # Trade/exchange
	"buy": "fb1101.png",            # Buy/purchase
	"sell": "fb1102.png",           # Sell
	
	# -------------------------------------------------------------------------
	# TRENDS / INDICATORS
	# -------------------------------------------------------------------------
	"trending_up": "fb1087.png",    # Up arrow (green context)
	"trending_down": "fb1088.png",  # Down arrow (red context)
	"increase": "fb1087.png",       # Alias
	"decrease": "fb1088.png",       # Alias
	
	# -------------------------------------------------------------------------
	# STATUS / FEEDBACK
	# -------------------------------------------------------------------------
	"fire": "fb83.png",             # Fire/flame (streak, burnout)
	"flame": "fb83.png",            # Alias
	"streak": "fb83.png",           # Alias
	"burnout": "fb83.png",          # Alias
	"lightning": "fb81.png",        # Lightning bolt (sync)
	"bolt": "fb81.png",             # Alias
	"sync": "fb81.png",             # Alias
	"star": "fb130.png",            # Star (perfect, rating)
	"perfect": "fb130.png",         # Alias
	"star_filled": "fb130.png",     # Alias
	"star_empty": "fb131.png",      # Empty star
	"timer": "fb1098.png",          # Timer/clock
	"clock": "fb1098.png",          # Alias
	"time": "fb1098.png",           # Alias
	"hourglass": "fb1097.png",      # Hourglass
	"wait": "fb1097.png",           # Alias
	"sparkle": "fb82.png",          # Sparkle/magic
	"magic": "fb82.png",            # Alias
	"ready": "fb1094.png",          # Ready checkmark
	"warning": "fb1096.png",        # Warning/alert
	"alert": "fb1096.png",          # Alias
	"info": "fb1095.png",           # Info circle
	"question": "fb1095.png",       # Alias
	
	# -------------------------------------------------------------------------
	# MINIGAMES
	# -------------------------------------------------------------------------
	"potato": "fb1171.png",         # Potato (hot potato game)
	"hot_potato": "fb1171.png",     # Alias  
	"horse": "fb1155.png",          # Horse (racing)
	"race": "fb1155.png",           # Alias
	"trophy": "fb129.png",          # Trophy/cup (winner)
	"winner": "fb129.png",          # Alias
	"crown": "coroa.png",           # Crown
	"gift": "fb35.png",             # Gift box
	"present": "fb35.png",          # Alias
	"reward": "fb35.png",           # Alias
	"gamepad": "fb1186.png",        # Game controller
	"game": "fb1186.png",           # Alias
	"dice": "fb1185.png",           # Dice (random/luck)
	"random": "fb1185.png",         # Alias
	"celebration": "fb130.png",     # Star for celebration
	
	# -------------------------------------------------------------------------
	# CRAFTING / PRODUCTION
	# -------------------------------------------------------------------------
	"hammer": "fb22.png",           # Hammer (crafting)
	"craft": "fb22.png",            # Alias
	"anvil": "fb23.png",            # Anvil
	"forge": "fb23.png",            # Alias
	"production": "fb22.png",       # Alias
	"gear": "fb1104.png",           # Gear/cog (settings)
	"settings": "fb1104.png",       # Alias
	"cog": "fb1104.png",            # Alias
	"pickaxe": "fb20.png",          # Pickaxe (mining)
	"mine": "fb20.png",             # Alias
	"axe": "fb21.png",              # Axe (foraging)
	"chop": "fb21.png",             # Alias
	"tool": "fb22.png",             # Generic tool
	
	# -------------------------------------------------------------------------
	# VENDORS / NPCs
	# -------------------------------------------------------------------------
	"vendor": "fb44.png",           # General vendor/merchant
	"merchant": "fb44.png",         # Alias
	"blacksmith": "fb23.png",       # Anvil/blacksmith
	"herbalist": "fb19.png",        # Herbs/plants (herbalist)
	"grocer": "fb18.png",           # Grain/food (grocer/farmer)
	"farmer": "fb18.png",           # Alias
	"jeweler": "fb24.png",          # Gem/jewel (jeweler)
	"carpenter": "fb21.png",        # Axe/wood (carpenter/builder)
	"builder": "fb21.png",          # Alias
	
	# -------------------------------------------------------------------------
	# NAVIGATION / MISC
	# -------------------------------------------------------------------------
	"search": "fb1091.png",         # Magnifying glass
	"find": "fb1091.png",           # Alias
	"scroll": "fb36.png",           # Scroll (guide/document)
	"document": "fb36.png",         # Alias
	"guide": "fb36.png",            # Alias
	"book": "fb37.png",             # Book
	"menu": "fb1099.png",           # Menu lines
	"list": "fb1099.png",           # Alias
	"home": "fb1100.png",           # Home
	"refresh": "fb1092.png",        # Refresh/reload
	"reload": "fb1092.png",         # Alias
	"lock": "fb1105.png",           # Lock
	"locked": "fb1105.png",         # Alias
	"unlock": "fb1106.png",         # Unlock
	"unlocked": "fb1106.png",       # Alias
	"eye": "fb1107.png",            # Eye (visible)
	"visible": "fb1107.png",        # Alias
	"eye_off": "fb1108.png",        # Eye off (hidden)
	"hidden": "fb1108.png",         # Alias
	
	# -------------------------------------------------------------------------
	# PLAYER / SOCIAL
	# -------------------------------------------------------------------------
	"player": "fb1150.png",         # Player silhouette
	"person": "fb1150.png",         # Alias
	"user": "fb1150.png",           # Alias
	"players": "fb1151.png",        # Multiple players
	"group": "fb1151.png",          # Alias
	"party": "fb1151.png",          # Alias
	"chat": "fb1152.png",           # Chat bubble
	"message": "fb1152.png",        # Alias
	"heart": "fb1.png",             # Heart (health, love)
	"health": "fb1.png",            # Alias
	"energy": "fb81.png",           # Energy bolt
	"mana": "fb2.png",              # Mana drop
}


# =============================================================================
# STATE
# =============================================================================

var _texture_cache: Dictionary = {}


# =============================================================================
# PUBLIC API - GET ICONS
# =============================================================================

## Get icon texture by key name
func get_icon(key: String) -> Texture2D:
	# Check cache first
	if _texture_cache.has(key):
		return _texture_cache[key]
	
	# Get path
	var path := get_icon_path(key)
	if path.is_empty():
		return null
	
	# Load and cache
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		_texture_cache[key] = texture
		return texture
	
	return null


## Get full path to icon resource
func get_icon_path(key: String) -> String:
	if not ICONS.has(key):
		push_warning("UIIcons: Unknown icon key '%s'" % key)
		return ""
	return ICON_BASE + ICONS[key]


## Check if an icon key exists
func has_icon(key: String) -> bool:
	return ICONS.has(key)


## Get all available icon keys
func get_all_keys() -> Array:
	return ICONS.keys()


# =============================================================================
# BBCODE HELPERS - For RichTextLabel
# =============================================================================

## Get BBCode image tag for icon
func bbcode(key: String, width: int = 16, height: int = 16) -> String:
	var path := get_icon_path(key)
	if path.is_empty():
		return ""
	return "[img=%dx%d]%s[/img]" % [width, height, path]


## Get BBCode with icon and text
func bbcode_with_text(key: String, text: String, width: int = 16, height: int = 16) -> String:
	var icon_tag := bbcode(key, width, height)
	if icon_tag.is_empty():
		return text
	return "%s %s" % [icon_tag, text]


## Convert emoji in text to icon BBCode
func replace_emoji(text: String) -> String:
	var result := text
	
	# Common emoji replacements
	var emoji_map := {
		# Economy
		"💰": bbcode("gold"),
		"🪙": bbcode("coin"),
		"🏪": bbcode("shop"),
		"📦": bbcode("box"),
		
		# Trends
		"📈": bbcode("trending_up"),
		"📉": bbcode("trending_down"),
		"↑": bbcode("arrow_up"),
		"↓": bbcode("arrow_down"),
		"→": bbcode("arrow_right"),
		"←": bbcode("arrow_left"),
		
		# Status
		"🔥": bbcode("fire"),
		"⚡": bbcode("lightning"),
		"★": bbcode("star"),
		"⭐": bbcode("star"),
		"✨": bbcode("sparkle"),
		"⏱️": bbcode("timer"),
		"⏳": bbcode("hourglass"),
		"⏰": bbcode("clock"),
		
		# Feedback
		"✓": bbcode("checkmark"),
		"✔": bbcode("checkmark"),
		"✔️": bbcode("checkmark"),
		"✅": bbcode("checkmark"),
		"✕": bbcode("close"),
		"✗": bbcode("close"),
		"✖": bbcode("close"),
		"❌": bbcode("close"),
		"⚠️": bbcode("warning"),
		
		# Minigames
		"🥔": bbcode("potato"),
		"🐎": bbcode("horse"),
		"🏆": bbcode("trophy"),
		"🎁": bbcode("gift"),
		"🎮": bbcode("gamepad"),
		"🎉": bbcode("celebration"),
		
		# Crafting
		"⚒️": bbcode("blacksmith"),
		"🔨": bbcode("hammer"),
		"⛏️": bbcode("pickaxe"),
		"🪓": bbcode("axe"),
		"⚙️": bbcode("gear"),
		
		# Vendors
		" ": bbcode("vendor"),
		"🌿": bbcode("herbalist"),
		"🌾": bbcode("grocer"),
		"💎": bbcode("jeweler"),
		"🪵": bbcode("carpenter"),
		
		# Misc
		"🔍": bbcode("search"),
		"📖": bbcode("book"),
		"📋": bbcode("scroll"),
		"❤️": bbcode("heart"),
		"💤": bbcode("hourglass"),
	}
	
	for emoji in emoji_map:
		result = result.replace(emoji, emoji_map[emoji])
	
	return result


# =============================================================================
# UTILITY
# =============================================================================

## Create a TextureRect with the specified icon
func create_icon_rect(key: String, size: Vector2 = Vector2(16, 16)) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = get_icon(key)
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


## Preload commonly used icons (call during loading screen if needed)
func preload_common() -> void:
	var common := ["gold", "checkmark", "close", "star", "fire", "lightning", "timer"]
	for key in common:
		get_icon(key)
