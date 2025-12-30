# KRAFTOVIA: Technical Guide

> **For developers joining the project. Covers architecture, codebase structure, and all implemented systems.**
> Last updated: December 2024

---

# PART 1: ARCHITECTURE OVERVIEW

## The 3-Tier Server Model

Kraftovia uses a custom 3-tier architecture for scalability and separation of concerns:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────────┐
│   GATEWAY   │────▶│   MASTER    │────▶│     WORLD SERVER        │
│   SERVER    │     │   SERVER    │     │  ┌─────────────────────┐│
│             │     │             │     │  │ ServerInstance #1   ││
│ HTTP/Auth   │     │ Accounts    │     │  │ (SubViewport)       ││
│ Sessions    │     │ Routing     │     │  └─────────────────────┘│
│             │     │             │     │  ┌─────────────────────┐│
│             │     │             │     │  │ ServerInstance #2   ││
│             │     │             │     │  │ (SubViewport)       ││
└─────────────┘     └─────────────┘     │  └─────────────────────┘│
                                        └─────────────────────────┘
```

### Gateway Server (`source/server/gateway/`)
- **Purpose:** HTTP entry point for authentication
- **Responsibilities:**
  - Account creation and login
  - Session token generation
  - Routing players to available World Servers
- **Key file:** `gateway_main.gd`

### Master Server (`source/server/master/`)
- **Purpose:** Central authority for accounts
- **Responsibilities:**
  - Account database (hashed passwords with per-account salts)
  - Account validation for World Servers
  - Legacy password migration
- **Key files:**
  - `master_main.gd` - Entry point
  - `components/database.gd` - Account persistence
  - `account_models/account.gd` - Account resource with password hashing

### World Server (`source/server/world/`)
- **Purpose:** Game world simulation
- **Responsibilities:**
  - Player data persistence
  - Game instances (multiple per server)
  - All gameplay systems
- **Key files:**
  - `world_main.gd` - Entry point, loads config, starts components
  - `components/instance_server.gd` - Core game instance logic
  - `components/world_database.gd` - Player data persistence

---

## Instance Model

Each World Server can run multiple **ServerInstance** nodes. Each instance is a Godot `SubViewport` containing:

- A loaded map
- Connected players
- All gameplay managers (TradeManager, ShopManager, QuestManager, etc.)
- A StateSynchronizerManager for delta sync

**Instance lifecycle:**
1. World Server loads map into new ServerInstance
2. Players warp into instance via warpers/teleporters
3. Instance manages AOI (Area of Interest) for efficient broadcasting
4. Players can warp between instances

---

## Connection Flow

```
1. Player opens game
2. Client connects to Gateway (HTTP)
3. Gateway validates credentials against Master
4. Gateway returns session token + World Server address
5. Client connects to World Server (WebSocket)
6. World Server validates session token
7. Player spawns into default instance
8. State sync begins (delta-based binary protocol)
```

---

## Key Architectural Decisions

| Decision | Rationale |
|----------|-----------|
| **Custom netcode** (no MultiplayerSynchronizer) | Full control over bandwidth, delta compression, AOI |
| **Resource-based persistence** (.tres files) | Godot-native, human-readable, easy debugging |
| **SubViewport instances** | Physics isolation, clean separation |
| **Binary wire codec** | Bandwidth efficiency for MMO scale |
| **Rate limiting** | 30 req/sec, 10 burst/100ms to prevent abuse |

---

## Server Configuration

World servers are configured via `data/config/world_config.cfg`:

```ini
[world-server]
name = "Kraftovia"
max_players = 200
hardcore = false
motd = "Welcome to Kraftovia!"
bonus_xp = 0.0
max_character = 5
pvp = true

[performance]
preload_resources = true
preload_items = true
preload_recipes = true

[network]
rate_limit_enabled = true
rate_limit_max_per_second = 30
rate_limit_burst_max = 10
rate_limit_burst_window_ms = 100
```

Physics tick rate is set to 10 ticks/second in `world_main.gd` (comparable to EVE Online's 1 tick/sec, Albion Online's ~2 ticks/sec).

---

# PART 2: CODEBASE STRUCTURE

## High-Level Overview

The codebase is split into three main directories:

| Directory | Purpose | Runs On |
|-----------|---------|---------|
| `source/client/` | UI, input, rendering, client networking | Client only |
| `source/server/` | Game logic, persistence, server networking | Server only |
| `source/common/` | Shared classes, items, characters, sync | Both |

**Total: ~275 GDScript files**

---

## Detailed Folder Structure

### `source/client/` — Client-Only Code (68 files)

```
source/client/
├── client_main.gd              # Client entry point
│
├── autoload/                   # Global singletons (added to Project Settings)
│   ├── events.gd               # Global event bus for UI communication
│   ├── ui_icons.gd             # Centralized icon loading/caching
│   ├── ui_sounds.gd            # Audio playback for UI
│   └── ui_animations.gd        # Shared tween configurations
│
├── gateway/                    # Login/account creation screens
│   ├── gateway.gd              # Gateway connection logic
│   └── ui/                     # Login UI components
│       ├── popup_panel.gd
│       ├── handle_validation_indicator.gd
│       ├── password_strength_indicator.gd
│       └── stylebox_gradient.gd
│
├── local_player/               # Player-controlled character
│   ├── local_player.gd         # Input handling, camera, movement
│   ├── mouse_component.gd      # Mouse input and click detection
│   └── potato_indicator.gd     # Hot potato minigame indicator
│
├── network/                    # Client networking
│   ├── world_client.gd         # Connection to world server
│   ├── instance_client.gd      # Instance-level networking, subscriptions
│   └── instance_manager.gd     # Multi-instance management
│
├── shaders/                    # Visual effects
│   └── character_animation*.gdshader  # Breathing, squash/stretch
│
├── ui/                         # All UI components (50+ files)
│   ├── ui.gd                   # Root UI manager
│   ├── hud/                    # Always-visible HUD
│   │   ├── hud.gd              # Main HUD controller
│   │   ├── health_bar/         # Health display
│   │   ├── energy_bar/         # Energy display
│   │   ├── character_portrait/ # Player portrait
│   │   ├── item_slots.gd       # Hotbar
│   │   ├── harvesting/         # Harvesting progress panel
│   │   │   ├── HarvestingPanel.gd
│   │   │   └── DamagePopup.gd
│   │   ├── harvest_popup.gd    # Item received popup
│   │   ├── level_up_popup.gd   # Level up notification
│   │   ├── craft_xp_popup.gd   # Crafting XP notification
│   │   ├── character_creation_modal.gd
│   │   └── menu_overlay.gd
│   ├── inventory/              # Inventory & equipment
│   │   ├── inventory_menu.gd   # Main inventory UI
│   │   ├── item_slot.gd        # Inventory slot display
│   │   ├── item_slot_button.gd # Clickable slot
│   │   ├── equipment_slot.gd   # Equipment slot
│   │   ├── gear_slot.gd        # Gear display
│   │   ├── drag_drop_world.gd  # Drag-and-drop handling
│   │   ├── trade_request_modal.gd
│   │   └── crafting_test.gd    # Crafting UI
│   ├── shop/                   # Player shop system
│   │   ├── shop_browse_ui.gd   # Browsing other players' shops
│   │   ├── shop_setup_ui.gd    # Setting up your shop
│   │   └── shop_indicator.gd   # Shop open indicator above players
│   ├── market/                 # NPC vendor market
│   │   └── market_browse_ui.gd
│   ├── guild/                  # Guild management
│   │   ├── guild_menu.gd
│   │   ├── guild_panel.gd
│   │   ├── guild_display.gd
│   │   ├── create_guild_menu.gd
│   │   ├── search_guild_menu.gd
│   │   └── no_guild_menu.gd
│   ├── quest_board/            # Quest system UI
│   │   └── quest_board_menu.gd
│   ├── minigame/               # Minigame UIs
│   │   ├── invitation_popup.gd
│   │   ├── announcement_popup.gd
│   │   ├── hot_potato_ui.gd
│   │   └── horse_racing_ui.gd
│   ├── chat/                   # Chat system
│   │   └── chat_menu.gd
│   ├── leaderboard/
│   │   └── leaderboard_menu.gd
│   ├── storage/                # Bank/storage
│   │   └── storage_menu.gd
│   ├── titles/                 # Title selection
│   │   └── titles_menu.gd
│   ├── worker/                 # Hired NPC workers
│   │   └── worker_hire_ui.gd
│   ├── player_profile/
│   │   └── player_profile.gd
│   ├── settings/
│   │   ├── settings.gd
│   │   └── language_selector.gd
│   ├── tooltips/               # Item tooltips
│   │   ├── item_tooltip.gd
│   │   └── item_tooltip_manager.gd
│   ├── guide/                  # In-game tutorial
│   │   └── guide_modal.gd
│   ├── components/             # Reusable UI components
│   │   ├── animated_button.gd
│   │   └── icon_label.gd
│   └── shared/
│       └── sub_panel.gd
│
├── utils/
│   ├── button_utils.gd
│   └── event_subscriber.gd     # Helper for event cleanup
│
└── world/                      # Client-side world features
    └── day_night_cycle.gd      # Time-based lighting
```

---

### `source/server/` — Server-Only Code (95 files)

```
source/server/
├── gateway/                    # Gateway Server
│   ├── gateway_main.gd         # Entry point
│   ├── http_server.gd          # HTTP server for auth
│   ├── player_gateway_server/  # Player session management
│   │   └── expiration_timer/   # Session timeout
│   └── master_gateway_client/  # Connection to master server
│
├── master/                     # Master Server
│   ├── master_main.gd          # Entry point
│   ├── components/
│   │   ├── database.gd         # Account persistence
│   │   ├── master_gateway_server/  # Listens for gateway connections
│   │   └── master_world_server/    # Listens for world connections
│   └── account_models/
│       ├── account.gd          # Account resource (password hashing)
│       └── account_collection.gd
│
└── world/                      # World Server (most files here)
    ├── world_main.gd           # Entry point, config loading
    │
    ├── components/             # Core gameplay systems
    │   ├── world_server.gd     # WebSocket server
    │   ├── instance_server.gd  # Game instance (845 lines!)
    │   ├── instance_manager.gd # Multi-instance management
    │   ├── world_database.gd   # Player data persistence
    │   ├── world_manager_client.gd  # Connection to master
    │   ├── game_time_manager.gd     # In-game time
    │   ├── performance_monitor.gd   # FPS/memory tracking
    │   ├── console.gd          # Debug console
    │   │
    │   ├── trade_manager.gd    # Player-to-player trading
    │   ├── shop_manager.gd     # Player shops
    │   ├── quest_manager.gd    # Quest generation/completion
    │   ├── minigame_manager.gd # Minigame orchestration
    │   ├── leaderboard_manager.gd  # Rankings
    │   ├── title_progress_tracker.gd  # Achievement tracking
    │   │
    │   ├── harvesting/         # Harvesting system
    │   │   ├── harvest_manager.gd   # Node registry, spatial grid
    │   │   ├── harvest_node.gd      # Individual harvest node
    │   │   └── harvest_loot_table.gd
    │   │
    │   ├── minigames/          # Minigame implementations
    │   │   ├── hot_potato_game.gd
    │   │   ├── horse_racing_game.gd
    │   │   └── minigame_zone.gd
    │   │
    │   ├── monsters/           # NPC enemies (seasonal)
    │   │   └── halloween_monster.gd
    │   │
    │   ├── chat_command/       # Admin/chat commands (14 commands)
    │   │   ├── chat_command.gd      # Base class
    │   │   ├── admin_utils.gd       # Permission checking
    │   │   ├── give_command.gd      # /give
    │   │   ├── setgold_command.gd   # /setgold
    │   │   ├── setlevel_command.gd  # /setlevel
    │   │   ├── tp_command.gd        # /tp (teleport)
    │   │   ├── heal_command.gd      # /heal
    │   │   ├── mute_command.gd      # /mute
    │   │   ├── ban_command.gd       # /ban
    │   │   ├── size_command.gd      # /size
    │   │   ├── set_command.gd       # /set
    │   │   ├── getid_command.gd     # /getid
    │   │   ├── help_command.gd      # /help
    │   │   ├── trade_command.gd     # /trade
    │   │   ├── join_command.gd      # /join (minigame)
    │   │   ├── startgame_command.gd # /startgame
    │   │   ├── toogle_role_command.gd
    │   │   └── selfadmin_command.gd # /selfadmin (dev only)
    │   │
    │   └── data_request_handlers/  # RPC handlers (42 handlers!)
    │       ├── data_request_handler.gd  # Base class
    │       │
    │       │ # Inventory & Items
    │       ├── inventory.get.gd
    │       ├── item.buy.gd
    │       ├── item.sell.gd
    │       ├── item.equip.gd
    │       ├── item.equip_cosmetic.gd
    │       ├── item.unequip_cosmetic.gd
    │       │
    │       │ # Crafting
    │       ├── craft.get_recipes.gd
    │       ├── craft.execute.gd
    │       │
    │       │ # Trading
    │       ├── trade.respond.gd
    │       ├── trade.update.gd
    │       ├── trade.confirm.gd
    │       ├── trade.cancel.gd
    │       │
    │       │ # Player Shops
    │       ├── shop.open.gd
    │       ├── shop.close.gd
    │       ├── shop.browse.gd
    │       ├── shop.add_item.gd
    │       ├── shop.remove_item.gd
    │       ├── shop.purchase.gd
    │       │
    │       │ # Quests
    │       ├── quest.fetch.gd
    │       ├── quest.complete.gd
    │       ├── quest.pin.gd
    │       │
    │       │ # Harvesting
    │       ├── harvest.join.gd
    │       ├── harvest.leave.gd
    │       ├── harvest.game_input.gd
    │       │
    │       │ # Minigames
    │       ├── minigame.join.gd
    │       ├── minigame.leave.gd
    │       ├── minigame.ready.gd
    │       ├── minigame.bet.gd
    │       │
    │       │ # Guild
    │       ├── guild.create.gd
    │       ├── guild.search.gd
    │       ├── guild.get.gd
    │       ├── guild.self.gd
    │       ├── guild.quit.gd
    │       │
    │       │ # Storage
    │       ├── storage.get.gd
    │       ├── storage.info.gd
    │       ├── storage.deposit.gd
    │       ├── storage.withdraw.gd
    │       │
    │       │ # Characters
    │       ├── character.list.gd
    │       ├── character.create.gd
    │       ├── character.switch.gd
    │       │
    │       │ # Other
    │       ├── gold.get.gd
    │       ├── level.get.gd
    │       ├── profile.get.gd
    │       ├── attribute.get.gd
    │       ├── attribute.spend.gd
    │       ├── titles.get.gd
    │       ├── titles.select.gd
    │       ├── leaderboard.fetch.gd
    │       ├── market.catalog.gd
    │       ├── worker.hire.gd
    │       ├── worker.status.gd
    │       ├── worker.collect.gd
    │       ├── state.sit.gd
    │       ├── action.perform.gd
    │       ├── resource.consume.gd
    │       └── chat.message.send.gd
    │
    ├── data/                   # World persistence
    │   ├── guild.gd            # Guild data structure
    │   ├── classic.tres        # Main world data
    │   └── hardcore.tres       # Hardcore mode data
    │
    └── events/                 # Market events
        ├── market_event.gd
        └── events/             # Event definitions
```

---

### `source/common/` — Shared Code (60 files)

```
source/common/
├── main.gd                     # Shared entry point logic
│
├── gameplay/                   # All gameplay systems
│   │
│   ├── characters/             # Entity hierarchy
│   │   ├── entity.gd           # Base: health, position
│   │   ├── character.gd        # Animation, sprites, movement
│   │   ├── composite_sprite.gd # Layered rendering for cosmetics
│   │   │
│   │   ├── player/             # Player-specific
│   │   │   ├── player.gd       # Player character node
│   │   │   ├── player_resource.gd  # Player data (271 lines)
│   │   │   ├── display_name_label.gd
│   │   │   └── speech_bubble.gd
│   │   │
│   │   ├── classes/            # Character classes
│   │   │   ├── character_resource.gd  # Class definition
│   │   │   └── character_collection/
│   │   │       ├── miner.tres
│   │   │       ├── forager.tres
│   │   │       └── trapper.tres
│   │   │
│   │   └── components/
│   │       └── hand/           # Weapon holding
│   │           └── hand.gd
│   │
│   ├── items/                  # Item system
│   │   ├── item.gd             # Base item class
│   │   ├── gear_item.gd        # Equipment with stats
│   │   ├── weapon_item.gd      # Weapons
│   │   ├── equipment_item.gd   # Wearables
│   │   ├── material_item.gd    # Crafting materials
│   │   ├── consumable_item.gd  # Potions, food
│   │   ├── quest_item.gd       # Quest items
│   │   │
│   │   ├── item_slot/          # Equipment slots
│   │   │   ├── item_slot.gd
│   │   │   ├── item_slot_unlock_rule.gd
│   │   │   └── slots/          # Slot definitions
│   │   │
│   │   ├── equipment/
│   │   │   └── equipment_resource.gd
│   │   │
│   │   └── [categories]/       # Item definitions by type
│   │       ├── equipment/
│   │       ├── weapons/
│   │       ├── tools/
│   │       ├── materials/
│   │       ├── consumables/
│   │       ├── food/
│   │       ├── luxury/
│   │       └── etc.
│   │
│   ├── crafting/               # Crafting system
│   │   ├── crafting_recipe.gd  # Recipe resource
│   │   └── recipes/            # 100+ recipes
│   │       ├── blacksmith/
│   │       ├── forager/
│   │       ├── miner/
│   │       ├── trapper/
│   │       ├── culinarian/
│   │       ├── guild/
│   │       ├── tier1/
│   │       └── interdependent/
│   │
│   ├── maps/                   # World/instance definitions
│   │   ├── map.gd              # Base map class
│   │   ├── instance/
│   │   │   ├── instance_resource.gd
│   │   │   └── instance_collection/
│   │   │
│   │   ├── components/
│   │   │   └── interaction_areas/  # Trigger zones
│   │   │       ├── interaction_area.gd  # Base class
│   │   │       ├── warper/warper.gd     # Instance transitions
│   │   │       ├── teleporter/teleporter.gd  # In-instance teleport
│   │   │       ├── quest_board/quest_board_area.gd
│   │   │       ├── storage_chest/storage_chest_area.gd
│   │   │       ├── leaderboard/leaderboard_area.gd
│   │   │       ├── vendor/vendor_area.gd
│   │   │       ├── worker/worker_area.gd
│   │   │       └── market/market_area.gd
│   │   │
│   │   ├── props/              # Interactive objects
│   │   │   ├── collectibles/coin.gd
│   │   │   ├── doors/activable_door/
│   │   │   └── ground_button/
│   │   │
│   │   └── [map_folders]/      # Actual maps
│   │       ├── overworld/
│   │       ├── dungeon/
│   │       ├── mining_cave/
│   │       ├── guild_house/
│   │       └── etc.
│   │
│   ├── quests/
│   │   └── quest.gd            # Quest resource
│   │
│   ├── titles/                 # Achievement titles
│   │   └── title_resource.gd
│   │
│   └── combat/                 # LEGACY - Not actively developed
│       ├── ability/
│       │   ├── ability.gd
│       │   └── ability_collection/
│       ├── attack/attack.gd
│       ├── attributes/
│       │   ├── stats_catalog.gd
│       │   ├── attributes_map.gd
│       │   └── stat_growth/
│       ├── components/
│       │   ├── ability_system_component.gd
│       │   ├── attributes_mirror.gd
│       │   └── equipment_component.gd
│       ├── gameplay_effect/
│       │   ├── gameplay_effect.gd
│       │   └── resources/      # burn, heal, etc.
│       ├── gameplay_resource/
│       │   ├── gameplay_resource.gd
│       │   ├── health_cost_resource.gd
│       │   ├── mana_resource.gd
│       │   ├── fury_resource.gd
│       │   └── energy_resource.gd
│       ├── damage_model/
│       ├── team/team_component.gd
│       ├── effect_spec.gd
│       └── gameplay_event.gd
│
├── network/                    # Networking
│   ├── base_server.gd          # WebSocket server base class
│   ├── base_client.gd          # WebSocket client base class
│   │
│   └── sync/                   # State synchronization
│       ├── wire_codec.gd       # Binary encoding/decoding
│       ├── state_synchronizer.gd        # Server-side sync
│       ├── state_synchronizer_manager.gd
│       └── props_access.gd     # Property path system
│
├── registry/                   # Content loading
│   ├── content_registry_hub.gd # Central loader
│   ├── content_registry.gd     # Type-specific registry
│   ├── content_index.gd        # Slug-to-ID mapping
│   ├── path_registry.gd        # Property paths for sync
│   ├── event_registry.gd       # Event definitions
│   ├── scene_registry.gd       # Preloaded scenes
│   └── composite_part_registry.gd  # Cosmetic parts
│
└── utils/                      # Utilities
    ├── logger.gd               # Centralized logging
    ├── anim_utils.gd           # Animation helpers
    ├── file_utils.gd           # File I/O
    ├── cmdline_utils.gd        # Command-line parsing
    ├── credentials_utils.gd    # Password hashing
    ├── tls_options_utils.gd    # TLS configuration
    ├── recipe_item_validator.gd
    ├── run_recipe_validation.gd
    └── editor_scripts/         # Editor tools
```

---

## Key Files Deep Dive

### Most Important Files (by line count and criticality)

| File | Lines | Role |
|------|-------|------|
| `instance_server.gd` | 845 | Core game instance - player spawn/despawn, AOI, rate limiting |
| `player_resource.gd` | 271 | Player data schema - inventory, level, quests, workers |
| `instance_client.gd` | 336 | Client networking - subscriptions, data requests |
| `wire_codec.gd` | 368 | Binary protocol for state sync |
| `quest_manager.gd` | ~300 | Quest generation and completion |
| `harvest_node.gd` | ~250 | Harvesting mechanics |
| `trade_manager.gd` | ~200 | Trading state machine |
| `hud.gd` | ~400 | Main HUD controller |

---

## System Interconnections

```
┌─────────────────────────────────────────────────────────────────┐
│                      ServerInstance                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │TradeManager  │  │ ShopManager  │  │QuestManager  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │HarvestManager│  │MinigameManager│ │LeaderboardMgr│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────────────────────────────────────────┐          │
│  │        StateSynchronizerManager                   │          │
│  └──────────────────────────────────────────────────┘          │
│                           │                                      │
│                    ┌──────▼──────┐                              │
│                    │ WireCodec   │                              │
│                    └──────┬──────┘                              │
└───────────────────────────┼─────────────────────────────────────┘
                            │ (Binary over WebSocket)
┌───────────────────────────┼─────────────────────────────────────┐
│                    ┌──────▼──────┐                              │
│                    │InstanceClient│                             │
│  ┌──────────────────────────────────────────────────┐          │
│  │        StateSynchronizerManagerClient             │          │
│  └──────────────────────────────────────────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  LocalPlayer │  │     HUD      │  │   UI Menus   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                         Client                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Finding What You Need

### "I want to add a new..."

| Task | Look Here |
|------|-----------|
| New item type | `source/common/gameplay/items/` - create .tres resource |
| New recipe | `source/common/gameplay/crafting/recipes/` |
| New admin command | `source/server/world/components/chat_command/` |
| New RPC handler | `source/server/world/components/data_request_handlers/` |
| New UI panel | `source/client/ui/` |
| New interaction area | `source/common/gameplay/maps/components/interaction_areas/` |
| New minigame | `source/server/world/components/minigames/` |

### "I want to modify..."

| System | Start Here |
|--------|-----------|
| Player spawning | `instance_server.gd:spawn_player()` |
| Inventory logic | `data_request_handlers/inventory.get.gd` |
| Trading flow | `trade_manager.gd` |
| Quest generation | `quest_manager.gd` |
| Harvesting yields | `harvest_node.gd`, `harvest_loot_table.gd` |
| Level/XP curve | `player_resource.gd:get_exp_for_level()` |
| Chat messages | `data_request_handlers/chat.message.send.gd` |

### "I want to debug..."

| Problem | Check These |
|---------|-------------|
| Player not syncing | `state_synchronizer.gd`, `wire_codec.gd` |
| Items not appearing | `inventory.get.gd`, item slug registration |
| Network errors | `instance_server.gd:data_request()` logs |
| Performance issues | `performance_monitor.gd`, AOI settings |

---

## File Naming Conventions

| Pattern | Meaning | Example |
|---------|---------|---------|
| `*_manager.gd` | Server-side system orchestrator | `trade_manager.gd` |
| `*_resource.gd` | Godot Resource (data container) | `player_resource.gd` |
| `*_client.gd` | Client-side networking | `instance_client.gd` |
| `*_server.gd` | Server-side networking | `world_server.gd` |
| `*.tres` | Resource instance (data file) | `miner.tres` |
| `*_area.gd` | Interaction trigger zone | `vendor_area.gd` |
| `*_menu.gd` | UI panel/menu | `inventory_menu.gd` |
| `*_ui.gd` | UI component | `shop_browse_ui.gd` |
| `*_command.gd` | Chat/admin command | `give_command.gd` |
| `category.action.gd` | RPC request handler | `trade.respond.gd` |

---

## Data Request Handler Naming

Handlers follow `category.action.gd` naming:

```
inventory.get.gd      → Get inventory contents
craft.execute.gd      → Execute a craft
trade.respond.gd      → Respond to trade request
shop.purchase.gd      → Purchase from shop
quest.complete.gd     → Submit completed quest
harvest.join.gd       → Join a harvest node
guild.create.gd       → Create a guild
character.switch.gd   → Switch character
```

The handler is loaded dynamically based on the request type:
```gdscript
request_data(&"trade.respond", callback, {accepted: true})
// Server loads: data_request_handlers/trade.respond.gd
```

---

# PART 3: NETWORKING & PROTOCOL

## Overview

Kraftovia uses **WebSocket-based multiplayer** with a **custom binary protocol**. We do NOT use Godot's built-in MultiplayerSynchronizer.

**Why custom:**
- Full control over what gets synced and when
- Delta compression (only send changed values)
- AOI (Area of Interest) filtering
- Binary encoding for bandwidth efficiency

---

## Wire Codec (`source/common/network/sync/wire_codec.gd`)

The wire codec handles binary encoding/decoding of game state.

### Supported Types

| Wire Type | Bytes | GDScript |
|-----------|-------|----------|
| `WIRE_BOOL` | 1 | bool |
| `WIRE_I32` | 4 | int |
| `WIRE_F32` | 4 | float |
| `WIRE_VEC2_F32` | 8 | Vector2 |
| (fallback) | varies | Variant |

### Message Types

**Delta** - Incremental state updates:
```
[u16: block_count]
  [u32: entity_id]
  [u16: pair_count]
    [u16: property_id]
    [value: encoded by wire type]
  ...
...
```

**Bootstrap** - Initial state for new entities:
```
[u16: map_updates_count]
  [u16: property_id]
  [utf8_string: path]
  [u8: wire_type]
...
[u16: objects_count]
  [u32: entity_id]
  [u16: pair_count]
    [u16: property_id]
    [value]
  ...
...
```

---

## Data Request/Response Pattern

Client requests use a request-response pattern:

**Client side (`instance_client.gd`):**
```gdscript
# Request data from server
func request_data(type: StringName, handler: Callable, args: Dictionary = {}) -> int:
    var request_id: int = _next_data_request_id
    _next_data_request_id += 1
    _pending_data_requests[request_id] = handler
    data_request.rpc_id(1, request_id, type, args)
    return request_id

# Example usage:
request_data(&"inventory.get", func(data): print(data))
```

**Server side (`instance_server.gd`):**
```gdscript
@rpc("any_peer", "call_remote", "reliable", 1)
func data_request(request_id: int, type: StringName, args: Dictionary) -> void:
    var peer_id: int = multiplayer.get_remote_sender_id()

    # Rate limiting
    if not _rate_ok(peer_id):
        data_response.rpc_id(peer_id, request_id, type, {"error": "Rate limit exceeded"})
        return

    # Load handler dynamically
    var handler: DataRequestHandler = _get_or_load_handler(type)
    var response = handler.data_request_handler(peer_id, self, args)
    data_response.rpc_id(peer_id, request_id, type, response)
```

---

## Request Handlers

Handlers live in `source/server/world/components/data_request_handlers/`.

Naming convention: `<category>.<action>.gd`

Examples:
- `inventory.get.gd` - Get player inventory
- `craft.execute.gd` - Execute a craft
- `trade.respond.gd` - Respond to trade request
- `shop.purchase.gd` - Purchase from player shop

Handler template:
```gdscript
extends DataRequestHandler

func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
    # Validate args
    # Perform action
    # Return response dictionary
    return {"success": true, "data": ...}
```

---

## Subscription System (Push Events)

Server can push events to clients without a request:

**Server:**
```gdscript
data_push.rpc_id(peer_id, &"harvest.event", {"type": "joined", "node": node_name})
```

**Client:**
```gdscript
# Subscribe in _ready()
InstanceClient.subscribe(&"harvest.event", func(data):
    if data.get("type") == &"joined":
        show_harvesting_ui()
)
```

Common push events:
- `chat.message` - Chat messages
- `harvest.event` - Harvesting join/leave
- `harvest.status` - Harvesting progress
- `shop.status` - Shop opened/closed
- `market.status` - Entered/left market area
- `vendor.status` - Entered/left vendor area

---

## Rate Limiting

Configured per-instance to prevent abuse:

| Setting | Default | Description |
|---------|---------|-------------|
| `rate_limit_max_per_second` | 30 | Max requests per second per peer |
| `rate_limit_burst_max` | 10 | Max requests in burst window |
| `rate_limit_burst_window_ms` | 100 | Burst window duration |

Implementation in `instance_server.gd:_rate_ok()`.

---

## AOI (Area of Interest)

Players only receive updates for nearby entities.

**Configuration:**
- `AOI_CHECK_INTERVAL = 0.5` seconds
- Grid-based spatial partitioning

**Flow:**
1. `StateSynchronizerManager` tracks entity positions
2. Every 0.5s, check for entities entering/leaving each peer's AOI
3. Send spawn/despawn RPCs as needed
4. Delta updates only go to peers who have that entity in view

---

# PART 4: DATA PERSISTENCE

## Overview

Kraftovia uses **Godot Resources** (.tres files) for persistence:

| Data | Location | Format |
|------|----------|--------|
| Accounts | Master Server | `account_collection.tres` |
| Player data | World Server | `world_player_data.tres` |
| World data | World Server | `classic.tres`, `hardcore.tres` |
| Guilds | World Server | Inside world data |

---

## PlayerResource Schema

`source/common/gameplay/characters/player/player_resource.gd`

```gdscript
class_name PlayerResource
extends Resource

# Identity
@export var player_id: int
@export var account_name: String
@export var display_name: String = "Player"
@export var character_class: String = "miner"  # miner, forager, trapper

# Appearance
@export var appearance_head_id: String = "head_a"  # head_a, head_b, head_c, head_d
@export var equipped_accessory_id: int = -1

# Economy
@export var golds: int
@export var inventory: Dictionary  # {item_id: {"stack": count}}

# Progression
@export var level: int = 1
@export var experience: int = 0
@export var attributes: Dictionary  # LEGACY: {vitality, strength, agility}
@export var available_attributes_points: int

# State
@export var current_energy: float = -1.0  # Persisted between sessions
@export var last_logout_time: float = 0.0
@export var last_position: Vector2 = Vector2.ZERO

# Social
@export var guild: Guild
@export var server_roles: Dictionary  # Admin roles

# Quests & Titles
@export var quest_stats: Dictionary
@export var selected_title_slug: String = ""

# Workers (hired NPC system)
@export var worker_jobs: Array[Dictionary]
@export var worker_burnout: Dictionary
```

---

## Account Schema

`source/server/master/account_models/account.gd`

```gdscript
class_name Account
extends Resource

@export var handle: String        # Unique username
@export var password_hash: String # Hashed password
@export var salt: String          # Per-account salt
```

Password hashing uses Godot's built-in `String.sha256_text()` with per-account salts.

---

## Backup System

World data is automatically backed up with timestamps:

```
classic.tres
classic.tres.backup.2025-12-25T23-55-24
classic.tres.backup.2025-12-25T23-58-13
classic.tres.backup.2025-12-26T00-02-50
```

Backups are created on:
- Regular save intervals
- Server shutdown
- Major operations

---

# PART 5: GAMEPLAY SYSTEMS

## 5.1 Character Creation & Classes

### Overview
Players choose one of three classes at character creation. Each class has exclusive access to certain harvest nodes and recipes.

### Classes

| Class | Role | Exclusive Resources |
|-------|------|---------------------|
| **Miner** | Metal/stone | Ore veins, gems, stone |
| **Forager** | Plants/herbs | Trees, bushes, herbs |
| **Trapper** | Animals/leather | Animal traps, hides, meat |

### Key Files
- `source/common/gameplay/characters/classes/character_resource.gd` - Class definition
- `source/common/gameplay/characters/classes/character_collection/` - Class instances (miner.tres, forager.tres, trapper.tres)

### Character Creation Flow
1. Client sends character creation request
2. Server creates new `PlayerResource`
3. Server assigns class-specific starting inventory
4. Player spawns with default appearance (head variant, no accessories)

### Appearance System
- 4 head variants: `head_a`, `head_b`, `head_c`, `head_d`
- Cosmetic accessories (equipped separately)
- Composite sprite system layers: body → head → accessory

---

## 5.2 Character & Entity System

### Hierarchy

```
Node2D
└── Entity (base: health, position)
    └── Character (animation, sprite, movement)
        └── Player (player-specific data)
            └── LocalPlayer (input handling, camera)
```

### Key Files
- `source/common/gameplay/characters/entity.gd`
- `source/common/gameplay/characters/character.gd`
- `source/common/gameplay/characters/player/player.gd`
- `source/client/local_player/local_player.gd`

### Animation States
- `IDLE` - Standing still
- `RUN` - Moving
- `HARVEST` - Harvesting a node
- `SIT` - Sitting (for shops)

### Composite Sprite System
Layered rendering for cosmetic items:
1. Base body sprite (by class)
2. Head variant overlay
3. Equipped accessory overlay

---

## 5.3 Harvesting System (Core Gameplay Loop)

### Overview
Harvesting is the primary resource gathering mechanic. Players approach harvest nodes matching their class, and items trickle into their inventory over time.

### Key Files
- `source/server/world/components/harvesting/harvest_manager.gd` - Manages all nodes
- `source/server/world/components/harvesting/harvest_node.gd` - Individual node
- `source/server/world/components/harvesting/harvest_loot_table.gd` - Drop tables

### Mechanics

**Spatial Grid (O(1) lookups):**
```gdscript
const GRID_SIZE: int = 500  # pixels
var _spatial_grid: Dictionary = {}  # Vector2i -> [HarvestNode]
```

**Class Exclusivity:**
Each node is tagged for a specific class. Only matching class can harvest.

**6-Tier Progression:**

| Tier | Level Req | XP Multiplier |
|------|-----------|---------------|
| T1 | 1 | 1.0x |
| T2 | 5 | 1.5x |
| T3 | 10 | 2.0x |
| T4 | 15 | 2.5x |
| T5 | 20 | 3.0x |
| T6 | 25 | 4.0x |

**Trickle Distribution:**
Items appear immediately in inventory as harvested (no waiting for completion).

**Multiplayer:**
Multiple players can harvest the same node. Each gets individual loot rolls.

### Events
- `harvest.event` - Player joined/left node
- `harvest.status` - Progress update
- `harvest.tick` - Harvest attempt occurred
- `harvest.distribution` - Items received

---

## 5.4 Crafting System

### Overview
100+ recipes organized by profession. Many require materials from different classes, encouraging trade.

### Key Files
- `source/common/gameplay/crafting/crafting_recipe.gd` - Recipe resource
- `source/common/gameplay/crafting/recipes/` - All recipe definitions
- `source/server/world/components/data_request_handlers/craft.execute.gd`

### Recipe Structure
```gdscript
class_name CraftingRecipe
extends Resource

@export var slug: StringName
@export var recipe_name: StringName
@export var required_class: String  # miner, forager, trapper, blacksmith...
@export var required_level: int

@export var gold_cost: int
@export var energy_cost: float

# Inputs (up to 3)
@export var input_1_slug: StringName
@export var input_1_quantity: int
# ... input_2, input_3

# Outputs (up to 2)
@export var output_1_slug: StringName
@export var output_1_quantity: int
# ... output_2
```

### Interdependence
Key design: Many recipes require materials from OTHER classes.

Example:
- Miner gathers iron ore
- Forager gathers wood
- Iron tools require BOTH iron + wood
- Forces trading between players

---

## 5.5 Trading System

### Overview
Direct player-to-player trading with bidirectional item/gold exchange.

### Key Files
- `source/server/world/components/trade_manager.gd`
- `source/server/world/components/data_request_handlers/trade.*.gd`

### Trade Flow
1. Player A sends trade request to Player B
2. Player B accepts/rejects
3. Both players add items and gold
4. Both players confirm
5. Items and gold swap atomically

### TradeSession State
```gdscript
class TradeSession:
    var peer_a: int
    var peer_b: int
    var items_a: Dictionary  # {item_id: quantity}
    var items_b: Dictionary
    var gold_a: int
    var gold_b: int
    var confirmed_a: bool
    var confirmed_b: bool
    var locked: bool
```

### Delta Tracking
Only changed fields are sent to save bandwidth.

---

## 5.6 Shop System

### Overview
Players can open consignment shops to sell items while AFK.

### Key Files
- `source/server/world/components/shop_manager.gd`
- `source/server/world/components/data_request_handlers/shop.*.gd`
- `source/client/ui/shop/`

### Mechanics
- Player sits down to open shop
- Sets shop name and lists items with prices
- Other players can browse and purchase
- Shop auto-closes when owner stands up
- Visual indicator shows shop is open

### ShopSession State
```gdscript
class ShopSession:
    var seller_peer_id: int
    var shop_name: String
    var items: Dictionary  # {item_id: {quantity, price}}
    var position: Vector2
    var opened_time: int
```

### Events
- `shop.status` - Shop opened/closed
- `shop.update` - Inventory changed
- `shop.item_sold` - Item was purchased
- `shop.purchase_complete` - Purchase confirmation

---

## 5.7 Quest System

### Overview
Daily rotating quests from 18 adventurer types. Each type prefers different items.

### Key Files
- `source/server/world/components/quest_manager.gd`
- `source/server/world/components/data_request_handlers/quest.*.gd`

### Mechanics

**Quest Generation:**
- 10 quests per player
- Rotates every 24 hours
- Each adventurer type has preferred item pools

**Adventurer Types (18):**
Swordsman, Mage, Scholar, Ranger, Cleric, Rogue, Knight, Bard, Merchant, Alchemist, Chef, Smith, Tailor, Jeweler, Carpenter, Farmer, Hunter, Fisher

**Rewards:**
- Gold (scales with item value)
- XP (scales with difficulty)

**Pinned Quests:**
Players can pin quests for easy tracking.

### Data Handlers
- `quest.fetch.gd` - Get available quests
- `quest.complete.gd` - Submit completed quest
- `quest.pin.gd` - Pin/unpin quest

---

## 5.8 Minigame System

### Overview
Periodic minigames for gold rewards and social interaction.

### Key Files
- `source/server/world/components/minigame_manager.gd`
- `source/server/world/components/minigame_manager/hot_potato_game.gd`
- `source/server/world/components/minigame_manager/horse_racing_game.gd`

### Games

**Hot Potato:**
- Pass the "potato" before timer expires
- Last holder loses
- Click other players to pass

**Horse Racing:**
- Bet on horses
- Watch race unfold
- Win multiplied bet if horse wins

### Mechanics
- 15-minute invitation cycle
- Players opt-in via minigame zones
- Betting system for horse racing
- Gold prizes for winners

### Events
- Invitation popup
- Game start announcement
- Results announcement

---

## 5.9 Guild System

### Overview
Player organizations with shared identity.

### Key Files
- `source/server/world/data/guild.gd`
- `source/server/world/components/data_request_handlers/guild.*.gd`

### Features
- Guild creation (name, description)
- Member management
- Guild search
- Guild perks (planned)

### Data Handlers
- `guild.create.gd` - Create new guild
- `guild.search.gd` - Search guilds
- `guild.get.gd` - Get guild info
- `guild.self.gd` - Get player's guild
- `guild.quit.gd` - Leave guild

---

## 5.10 Titles/Achievements

### Overview
Unlockable titles displayed under player names.

### Key Files
- `source/common/gameplay/titles/title_resource.gd`
- `source/server/world/components/title_progress_tracker.gd`

### Mechanics
- Various unlock conditions (level, quests completed, events)
- Player selects active title
- Title displays with rarity color

### Example Titles
- "Alpha Tester" - Played during alpha
- "Quest Master" - Complete X quests
- "Master Miner" - Reach level 30 as miner

---

## 5.11 Leaderboards

### Overview
Competitive rankings updated every 60 seconds.

### Key Files
- `source/server/world/components/leaderboard_manager.gd`

### Score Formula
```gdscript
score = (krak_weight * 10000) + (gold * 0.1) + (level * 100)
```

### Boards
- Global (all players)
- Per-class (miner, forager, trapper)

### Caching
- Top 50 per board
- Refreshes every 60 seconds

---

## 5.12 Item System

### Overview
All items are Godot Resources with a class hierarchy.

### Key Files
- `source/common/gameplay/items/` - Item definitions
- `source/common/gameplay/items/gear_item.gd`
- `source/common/gameplay/items/weapon_item.gd`
- `source/common/gameplay/items/material_item.gd`
- `source/common/gameplay/items/consumable_item.gd`

### Item Hierarchy
```
Item (base)
├── GearItem (equipment with stats)
│   └── WeaponItem (damage stats)
├── MaterialItem (crafting materials)
├── ConsumableItem (potions, food)
└── QuestItem (quest-specific)
```

### Equipment Slots
- Head
- Body
- Weapon (right hand)
- Accessory

Slots have unlock rules (level requirements).

---

## 5.13 Combat & Abilities (LEGACY)

> **Note:** This system exists but is NOT core to Kraftovia's vision. The game is a crafting/economy MMO, not a combat game. Documented for reference only.

### Key Files
- `source/common/gameplay/combat/components/ability_system_component.gd`
- `source/common/gameplay/combat/attributes/`
- `source/common/gameplay/combat/gameplay_effect/`

### Attributes (Legacy)
- Health, Mana, Fury, Energy
- AD, AP, Armor, MR
- Attack Speed, Move Speed

### Gameplay Effects
Buff/debuff system with:
- Duration
- Stat modifiers
- Periodic effects (DoT, HoT)

**Status:** Partially implemented, not being actively developed.

---

# PART 6: CLIENT SYSTEMS

## UI Architecture

```
CanvasLayer (UI)
├── HUD
│   ├── HealthBar
│   ├── EnergyBar
│   ├── CharacterPortrait
│   ├── ItemSlots
│   └── ChatBox
├── Inventory (toggle)
├── CraftingMenu (toggle)
├── QuestBoard (context)
├── ShopUI (context)
└── Modals (overlays)
```

### Key Files
- `source/client/ui/hud/hud.gd` - Main HUD
- `source/client/ui/inventory/inventory_menu.gd`
- `source/client/autoload/events.gd` - Global event bus

---

## Input Handling

**LocalPlayer** handles input in `source/client/local_player/local_player.gd`:
- WASD / Arrow keys for movement
- Click to interact
- Keyboard shortcuts for UI

**Mouse Component** handles:
- Click detection
- Hover states
- Drag-and-drop

---

## Event Subscriptions

Client subscribes to server events via `InstanceClient.subscribe()`:

```gdscript
func _ready():
    InstanceClient.subscribe(&"chat.message", _on_chat_message)
    InstanceClient.subscribe(&"harvest.event", _on_harvest_event)
```

Always unsubscribe in `_exit_tree()` to prevent memory leaks.

---

## Autoload Systems

| Singleton | Purpose |
|-----------|---------|
| `Events` | Global event bus |
| `UIIcons` | Centralized icon loading |
| `UISounds` | Audio management |
| `UIAnimations` | Shared animation definitions |

---

# PART 7: DEVELOPMENT WORKFLOW

## Running Locally

### Prerequisites
- Godot 4.4+
- Three terminal windows

### Start Servers
```bash
# Terminal 1: Gateway
godot --headless --path . -- --server=gateway

# Terminal 2: Master
godot --headless --path . -- --server=master

# Terminal 3: World
godot --headless --path . -- --server=world
```

Or use the editor with feature tags:
- `server_gateway`
- `server_master`
- `server_world`
- `client`

### Testing with Multiple Clients
Run multiple instances of the client (different windows).

---

## Adding New Features

### New Item
1. Create resource in `source/common/gameplay/items/<category>/`
2. Set slug, name, icon, stats
3. Register in content index (automatic via folder)

### New Recipe
1. Create resource in `source/common/gameplay/crafting/recipes/<profession>/`
2. Set inputs, outputs, requirements
3. Validate with `run_recipe_validation.gd`

### New Data Request Handler
1. Create `<category>.<action>.gd` in `data_request_handlers/`
2. Extend `DataRequestHandler`
3. Implement `data_request_handler(peer_id, instance, args) -> Dictionary`

### New Push Event
1. Server: `data_push.rpc_id(peer_id, &"event.name", data)`
2. Client: `InstanceClient.subscribe(&"event.name", handler)`

---

## Debug Commands

See `docs/ADMIN_COMMANDS.md` for full list.

Quick reference:
- `/give <item_slug> <amount>` - Give item
- `/setgold <amount>` - Set gold
- `/setlevel <level>` - Set level
- `/tp <x> <y>` - Teleport
- `/heal` - Full heal

---

## Content Registry

Items, recipes, and handlers are loaded via `ContentRegistryHub`:

```gdscript
# Load item by slug
var item: Item = ContentRegistryHub.load_by_slug(&"items", &"iron_ore")

# Load item by ID
var item: Item = ContentRegistryHub.load_by_id(&"items", 42)

# Get ID from slug
var id: int = ContentRegistryHub.id_from_slug(&"items", &"iron_ore")
```

Content is auto-indexed from folder structure.

---

# APPENDIX: Quick Reference

## RPC Channels
| Channel | Usage |
|---------|-------|
| 0 | Unreliable (position updates) |
| 1 | Reliable (data requests, state changes) |

## Key Signals
| Signal | Source | Purpose |
|--------|--------|---------|
| `player_entered_warper` | ServerInstance | Player touched warper |
| `peer_disconnected` | MultiplayerAPI | Player disconnected |

## Common Patterns

**Server-authoritative action:**
```gdscript
# Client requests
request_data(&"action.do", callback, {args})

# Server validates and executes
func data_request_handler(...):
    if not validate(args):
        return {"error": "Invalid"}
    perform_action()
    return {"success": true}
```

**State sync:**
```gdscript
# Server sets value
player.syn.set_by_path(^":position", new_pos)

# Automatically synced to relevant clients via delta
```

---

*This document covers all implemented systems as of December 2024. For design vision, see GDD.md. For production schedule, see ROADMAP.md.*
