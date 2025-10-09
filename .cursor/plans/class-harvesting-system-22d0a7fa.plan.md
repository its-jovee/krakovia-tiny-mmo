<!-- 22d0a7fa-eca9-4ad4-b17a-99f126fac5b7 3c3c463e-9a95-423b-bb21-06e2452e2242 -->
# Class-Exclusive Harvesting System Implementation

## Overview

Implement unified harvesting system for three classes with weighted loot tables:

- **Miner**: 30 items across 6 tiers (ores, stone, gems)
- **Forager**: 40 items across 6 tiers (wood, plants, herbs, food)
- **Trapper**: 30 items across 4+ tiers (hides, meat, bones, fur)

All nodes are class-exclusive with level requirements (T1: 1-5, T2: 6-10, T3: 11-15, T4: 16-20, T5: 21-25, T6: 26-30). All three classes use the same loot table system - each harvest rolls on weighted chances to determine which items drop.

## Implementation Steps

### 1. Create Unified Loot Table System

Create `source/server/world/components/harvesting/harvest_loot_table.gd`:

- Resource class to define weighted loot tables for all node types
- Fields: `loot_entries: Array[Dictionary]` with structure:
- `item_slug: StringName` - the item to drop
- `weight: float` - drop chance weight (e.g., 40.0 = 40%)
- `quantity_min: int` - minimum quantity to drop
- `quantity_max: int` - maximum quantity to drop
- Field: `rare_bonus_entries: Array[Dictionary]` for special rare drops:
- `item_slug: StringName`
- `chance: float` - independent roll chance (e.g., 0.02 = 2%)
- `quantity: int` - how many to drop
- Method: `roll_loot() -> Dictionary` that:
- Rolls each loot entry independently based on weight
- Rolls rare bonuses separately
- Returns dictionary of item_slug: quantity pairs
- Example return: `{"copper_ore": 3, "stone": 1, "coal": 2}`

### 2. Extend HarvestNode with Class/Level Restrictions and Loot Tables

Modify `source/server/world/components/harvesting/harvest_node.gd`:

- Add `@export var required_class: StringName` (empty = any, or &"miner"/&"forager"/&"trapper")
- Add `@export var required_level: int` (minimum level to harvest)
- Add `@export var tier: int` (1-6 for organization/display)
- Add `@export var loot_table: HarvestLootTable` (loot table for this node)
- Add `@export var harvest_interval: float` (seconds between harvests, varies by tier)

Update `player_join()`:

- Validate player class matches `required_class`
- Validate player level >= `required_level`
- Return appropriate error codes: `&"wrong_class"`, `&"level_too_low"`, etc.

Update harvesting tick logic in `_process()`:

- When awarding resources, call `loot_table.roll_loot()` to get items
- Award all items from the roll to the harvester
- Update pool_amount and distribution logic accordingly

### 3. Update Data Request Handlers

Modify `source/server/world/components/data_request_handlers/harvest.join.gd`:

- Return class/level requirement errors with specific messages
- Include node tier and requirements in response for client UI

### 4. Create Node Resources/Scenes

Create tier-specific node scene variants:

- `source/server/world/components/harvesting/nodes/miner_node_t1.tscn` through `t6.tscn`
- `source/server/world/components/harvesting/nodes/forager_node_t1.tscn` through `t6.tscn`
- `source/server/world/components/harvesting/nodes/trapper_node_t1.tscn` through `t4.tscn`

Configure each with appropriate:

- Node type, class requirement, level requirement, tier
- Visual sprites (reuse/differentiate by tier)
- For Miner: Direct drops matching the specification
- For Forager: Loot tables with weighted drops and rare bonuses
- For Trapper: Direct drops with trap-specific yields

### 5. Update Client UI

Modify `source/client/ui/hud/harvesting/HarvestingPanel.gd`:

- Display class requirement (e.g., "Requires: Miner")
- Display level requirement (e.g., "Level 11+ Required")
- Display tier badge (T1-T6)
- For foragers: Show possible loot table items
- Show error messages for class/level restrictions

### 6. Place Nodes in World Maps

Add harvesting nodes to instance maps:

- Distribute T1 nodes in starter areas
- Place higher tier nodes in progressively dangerous/distant areas
- Cluster nodes by class type in thematic regions (mines for miners, forests for foragers, wilderness for trappers)
- Ensure balanced access for all three classes

### Key Files Referenced

**Existing:**

- `source/server/world/components/harvesting/harvest_node.gd` - Core node logic
- `source/server/world/components/harvesting/harvest_manager.gd` - Node registration
- `source/server/world/components/data_request_handlers/harvest.join.gd` - Join validation
- `source/client/ui/hud/harvesting/HarvestingPanel.gd` - Client UI
- `source/common/gameplay/items/materials/*.tres` - All 100+ material items already exist

**Item Registry Paths:**

- Miner items: Tagged with "miner" (copper_ore, stone, coal, etc.)
- Forager items: Tagged with "forager" (wood, berries, herbs, etc.)  
- Trapper items: Tagged with "trapper" (rabbit_hide, deer_meat, bones, etc.)

## Notes

- All items are already created and registered in the game
- Forager bundles drop every 6-12 seconds based on tier
- Trapper uses same passive harvest as Miner (no timer-based trap placement needed for now)
- Rare bonuses for Forager: T1 (2%), T2 (1.5%), T3 (1%), T4 (0.5%), T5-T6 (none)

### To-dos

- [ ] Create HarvestLootTable resource class with weighted roll logic
- [ ] Add class/level restrictions and bundle/direct harvest modes to HarvestNode
- [ ] Update harvest.join.gd to validate class and level requirements
- [ ] Create tier-specific node scene variants for all three classes (18+ scenes)
- [ ] Configure direct drops for Miner/Trapper and loot tables for Forager on all nodes
- [ ] Update HarvestingPanel to show class, level, and tier requirements
- [ ] Place harvesting nodes in world maps with appropriate tier distribution