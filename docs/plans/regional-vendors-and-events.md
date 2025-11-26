# Regional Vendors & Market Events System

## Overview

Transform the market system from a global pricing model to a regional vendor-based economy with periodic market events.

---

## Phase 1: Price Decay System

**Goal:** Prices gradually return to equilibrium over time.

### Implementation

1. **Add decay timer to WorldServer**
   - Call `market_data.apply_decay()` every 5 minutes (configurable)
   - Decay is already implemented, just needs to be triggered

2. **Configuration in MarketData**
   - `decay_rate_per_hour: float = 0.1` (already exists)
   - At 0.1/hour, a maxed-out price (±1.0 supply) returns to normal in ~10 hours

### Files to modify
- `source/server/world/world_server.gd` - Add decay timer

---

## Phase 2: Vendor Refactor (Regional Pricing)

**Goal:** Each vendor has their own inventory and local supply/demand.

### Data Model

```gdscript
# vendor_data.gd - Per-vendor persistent data
class_name VendorData
extends Resource

@export var vendor_id: String = ""  # Unique ID like "town_blacksmith"
@export var vendor_name: String = "Merchant"

# What this vendor deals in (item IDs)
@export var item_catalog: Array[int] = []

# Local supply levels (only for items in catalog)
@export var local_supply: Dictionary = {}  # {item_id: supply_level}

# Vendor personality/specialization affects base prices
@export var buy_multiplier: float = 0.7   # What they pay when buying FROM player
@export var sell_multiplier: float = 1.3  # What they charge when selling TO player
```

### Vendor Types (Examples)

| Vendor | Location | Specializes In | Notes |
|--------|----------|----------------|-------|
| Town Blacksmith | Town Square | Weapons, Tools, Ore | Pays well for ore |
| General Store | Town Square | Common items, Food | Jack of all trades |
| Herbalist | Forest Edge | Herbs, Potions | Only vendor for rare herbs |
| Fishing Merchant | Docks | Fish, Bait, Nets | Best fish prices |
| Luxury Trader | Castle | Gems, Rare items | High prices both ways |

### UI Changes

- When interacting with vendor, show THEIR inventory (not all items)
- Show both BUY and SELL tabs
- Prices reflect THIS vendor's local supply

### Files to create/modify
- `source/server/world/data/vendor_data.gd` - NEW: Per-vendor data
- `source/common/gameplay/maps/components/interaction_areas/vendor/vendor_area.gd` - Add vendor_data reference
- `source/server/world/components/world_database.gd` - Load/save vendor data
- `source/client/ui/market/market_browse_ui.gd` - Show buy AND sell in one UI

---

## Phase 3: Market Events System

**Goal:** Periodic server-wide events that affect demand for specific items.

### Event Structure

```gdscript
# market_event.gd
class_name MarketEvent
extends Resource

@export var event_id: String = ""
@export var title: String = ""           # "Goblin Invasion!"
@export var description: String = ""     # "Swords and shields in high demand!"
@export var icon: String = "⚔️"

# Which items are affected and how
@export var affected_items: Dictionary = {}  # {item_id: demand_modifier}
# demand_modifier: positive = high demand (prices UP), negative = surplus (prices DOWN)

# Duration
@export var duration_minutes: int = 30

# Optional: Which vendor types are most affected
@export var vendor_type_multipliers: Dictionary = {}  # {"blacksmith": 1.5, "general": 1.0}
```

### Example Events

```gdscript
# goblin_invasion.tres
event_id = "goblin_invasion"
title = "Goblin Invasion!"
description = "The militia needs weapons! Swords and shields in high demand."
icon = "⚔️"
affected_items = {
    101: 0.5,   # Iron Sword: +50% demand (prices up)
    102: 0.5,   # Steel Sword: +50% demand
    110: 0.3,   # Wooden Shield: +30% demand
    50: -0.2,   # Fish: -20% (nobody's fishing during invasion)
}
duration_minutes = 30

# harsh_winter.tres
event_id = "harsh_winter"
title = "Harsh Winter Approaching"
description = "Stock up on food and firewood!"
icon = "❄️"
affected_items = {
    201: 0.6,   # Firewood: +60% demand
    202: 0.4,   # Coal: +40% demand
    50: 0.3,    # Cooked Fish: +30% demand
    51: 0.3,    # Bread: +30% demand
}
duration_minutes = 45

# merchant_caravan.tres
event_id = "merchant_caravan"
title = "Merchant Caravan Arrives"
description = "Traders from afar bring exotic goods at low prices!"
icon = "🐪"
affected_items = {
    301: -0.4,  # Silk: -40% demand (surplus, prices down)
    302: -0.4,  # Spices: -40% demand
    303: -0.3,  # Exotic Gems: -30% demand
}
duration_minutes = 20

# mining_boom.tres
event_id = "mining_boom"
title = "Mining Boom!"
description = "New ore veins discovered! Miners flood the market."
icon = "⛏️"
affected_items = {
    10: -0.5,   # Iron Ore: -50% demand (surplus)
    11: -0.5,   # Copper Ore: -50% demand
    12: -0.3,   # Gold Ore: -30% demand
    20: 0.3,    # Pickaxes: +30% demand
}
duration_minutes = 30

# festival.tres
event_id = "summer_festival"
title = "Summer Festival!"
description = "The town celebrates! Decorations and treats wanted."
icon = "🎉"
affected_items = {
    401: 0.5,   # Flowers: +50% demand
    402: 0.4,   # Honey: +40% demand
    403: 0.4,   # Sweet Berries: +40% demand
    404: 0.3,   # Ribbons: +30% demand
}
duration_minutes = 25
```

### Event Scheduler

```gdscript
# market_event_manager.gd
class_name MarketEventManager
extends Node

signal event_started(event: MarketEvent)
signal event_ended(event: MarketEvent)

@export var event_interval_minutes: int = 30
@export var event_pool: Array[MarketEvent] = []

var current_event: MarketEvent = null
var event_end_time: int = 0
var next_event_time: int = 0

func _ready():
    # Schedule first event
    next_event_time = Time.get_unix_time_from_system() + (event_interval_minutes * 60)

func _process(_delta):
    var now = Time.get_unix_time_from_system()
    
    # Check if current event ended
    if current_event and now >= event_end_time:
        _end_current_event()
    
    # Check if time for new event
    if not current_event and now >= next_event_time:
        _start_random_event()

func _start_random_event():
    if event_pool.is_empty():
        return
    
    current_event = event_pool.pick_random()
    event_end_time = Time.get_unix_time_from_system() + (current_event.duration_minutes * 60)
    next_event_time = event_end_time + (event_interval_minutes * 60)
    
    event_started.emit(current_event)
    _broadcast_event_to_all_players()

func _end_current_event():
    var ended = current_event
    current_event = null
    event_ended.emit(ended)
    _broadcast_event_ended_to_all_players()
```

### Price Calculation with Events

```gdscript
func get_final_price_multiplier(item_id: int, vendor: VendorData) -> float:
    # Base: vendor's local supply/demand
    var local_mult = vendor.get_price_multiplier(item_id)
    
    # Event modifier (if any)
    var event_mult = 1.0
    if MarketEventManager.current_event:
        var event = MarketEventManager.current_event
        if event.affected_items.has(item_id):
            var demand_mod = event.affected_items[item_id]
            # Convert demand modifier to price multiplier
            # +0.5 demand = 1.5x price, -0.5 demand = 0.67x price
            event_mult = 1.0 + demand_mod
    
    return local_mult * event_mult
```

### Files to create
- `source/server/world/events/market_event.gd` - Event resource
- `source/server/world/events/market_event_manager.gd` - Scheduler
- `source/server/world/events/definitions/` - Event .tres files
- `source/client/ui/events/event_banner_ui.gd` - Shows current event

---

## Phase 4: Client UI Updates

### Event Banner
- Persistent banner at top of screen during events
- Shows event icon, title, and time remaining
- Clicking shows affected items

### Vendor UI Redesign
- Single UI for buy AND sell
- Two tabs: "Buy from [Vendor]" and "Sell to [Vendor]"
- Shows only items this vendor deals in
- Prices clearly show event modifiers (if any)

### Price Display
```
Iron Sword
Base: 50g
Vendor: 65g (+30% markup)
Event: 97g (+50% demand) ⚔️
─────────────────
YOU PAY: 97g
```

---

## Implementation Order

1. **Phase 1: Decay** (30 min)
   - Hook up decay timer
   - Test prices returning to normal

2. **Phase 2: Vendor Refactor** (2-3 hours)
   - Create VendorData resource
   - Migrate from global to per-vendor pricing
   - Update buy/sell handlers
   - Update UI to show vendor-specific inventory

3. **Phase 3: Events** (2 hours)
   - Create event system
   - Define 5-6 starter events
   - Broadcast to clients
   - Apply to price calculations

4. **Phase 4: Polish** (1 hour)
   - Event banner UI
   - Price breakdown in tooltips
   - Testing & balancing

---

## Future Considerations

- **Player shops** could also be affected by events (optional modifier)
- **Regional events** - Some events only affect certain areas
- **Player-triggered events** - Guild actions cause market shifts
- **Seasonal cycles** - Different base prices by in-game season
- **Supply chains** - Crafting materials affect finished goods prices

