# Class-Exclusive Harvesting System

## Overview

The harvesting system implements class-exclusive, tier-based resource gathering for three classes:
- **Miner**: Ores, stone, gems (6 tiers)
- **Forager**: Wood, plants, herbs, food (6 tiers)
- **Trapper**: Hides, meat, bones, fur (4+ tiers)

All nodes use a unified loot table system where each harvest rolls weighted chances to determine which items drop.

## System Components

### 1. HarvestLootTable Resource (`harvest_loot_table.gd`)

Defines weighted loot tables for harvest nodes.

**Fields:**
- `loot_entries`: Array of dictionaries with:
  - `item_slug`: StringName - the item to drop
  - `weight`: float - drop chance percentage (e.g., 40.0 = 40%)
  - `quantity_min`: int - minimum quantity
  - `quantity_max`: int - maximum quantity
- `rare_bonus_entries`: Array of dictionaries with:
  - `item_slug`: StringName
  - `chance`: float - independent roll (0.0-1.0, e.g., 0.02 = 2%)
  - `quantity`: int

### 2. HarvestNode Script (`harvest_node.gd`)

Extended with class/level restrictions:

**New Fields:**
- `required_class`: StringName - &"miner", &"forager", or &"trapper"
- `required_level`: int - minimum level required
- `tier`: int - tier number (1-6)
- `loot_table`: HarvestLootTable - the loot table to use

**Validation:**
- Players must match the required class
- Players must meet the minimum level
- Errors returned: `wrong_class`, `level_too_low`, `node_depleted`, `out_of_range`

### 3. Client UI (`HarvestingPanel.gd`)

Updated to display:
- Tier badge (T1-T6)
- Class requirement
- Level requirement
- Error messages for failed harvest attempts

## Creating New Tiers

### Tier Configuration

**Level Requirements:**
- T1: Levels 1-5
- T2: Levels 6-10
- T3: Levels 11-15
- T4: Levels 16-20
- T5: Levels 21-25
- T6: Levels 26-30

**Harvest Rates (base_yield_per_sec):**
- Miner: 1.0 (T1), 1.2 (T2), 1.5 (T3), 1.8 (T4), 2.0 (T5), 2.5 (T6)
- Forager: 0.833 (T1), 1.0 (T2), 1.111 (T3), 1.25 (T4), 1.429 (T5), 1.667 (T6)
  - *(Adjusted for 12s, 10s, 9s, 8s, 7s, 6s harvest intervals)*
- Trapper: 1.0 (T1-T4+)

**Resource Pool:**
- T1: 100-120
- T2: 120-140
- T3: 150-170
- T4+: 180-200

**Cooldown:**
- T1: 300s (5 min)
- T2: 360s (6 min)
- T3: 420s (7 min)
- T4+: 480s+ (8+ min)

### Step-by-Step: Creating a New Tier

#### Step 1: Create Loot Table Resource

Create `loot_tables/<class>_t<tier>_loot_table.tres`:

```gdscript
[gd_resource type="Resource" script_class="HarvestLootTable" load_steps=2 format=3]

[ext_resource type="Script" path="res://source/server/world/components/harvesting/harvest_loot_table.gd" id="1"]

[resource]
script = ExtResource("1")
loot_entries = Array[Dictionary]([{
"item_slug": &"item_name",
"quantity_max": 2,
"quantity_min": 1,
"weight": 40.0
}])
rare_bonus_entries = Array[Dictionary]([{
"chance": 0.02,
"item_slug": &"rare_item",
"quantity": 1
}])
```

**Weight Guidelines:**
- Total weights don't need to sum to 100 (each is independent)
- Common items: 30-40%
- Uncommon items: 15-25%
- Rare items: 5-10%
- Very rare items: 1-3%

**Rare Bonus Chances:**
- T1 Forager: 2% (0.02)
- T2 Forager: 1.5% (0.015)
- T3 Forager: 1% (0.01)
- T4 Forager: 0.5% (0.005)
- T5-T6 Forager: None
- Trapper: 1-5% for special drops

#### Step 2: Create Node Scene

Create `nodes/<class>_node_t<tier>.tscn`:

```gdscript
[gd_scene load_steps=3 format=3 uid="uid://<class>_t<tier>_node"]

[ext_resource type="Script" path="res://source/server/world/components/harvesting/harvest_node.gd" id="1"]
[ext_resource type="Resource" path="res://source/server/world/components/harvesting/loot_tables/<class>_t<tier>_loot_table.tres" id="2"]

[node name="<Class>NodeT<Tier>" type="Node2D"]
script = ExtResource("1")
node_type = &"<class>_t<tier>"
radius = 64.0
base_yield_per_sec = <rate>
max_amount = <pool>
cooldown_seconds = <cooldown>
max_move_during_tick = 1.0
energy_cost_per_sec = <cost>
required_class = &"<class>"
required_level = <level>
tier = <tier>
loot_table = ExtResource("2")

[node name="Sprite2D" type="Sprite2D" parent="."]
modulate = Color(<r>, <g>, <b>, 1)
scale = Vector2(32, 32)
```

## Item Distribution by Class

### Miner Items (30 total)

**T1 (Lvl 1-5):** Copper Ore, Stone, Coal, Clay, Sand
**T2 (Lvl 6-10):** Iron Ore, Tin Ore, Limestone, Sandstone, Gravel, Salt
**T3 (Lvl 11-15):** Silver Ore, Granite, Marble, Slate, Sulfur, Saltpeter, Emerald, Ruby, Sapphire, Topaz, Amethyst, Quartz Crystal
**T4 (Lvl 16-20):** Gold Ore, Obsidian, Lodestone, Mica
**T5 (Lvl 21-25):** Malachite, Diamond
**T6 (Lvl 26-30):** Adamantine Ore

### Forager Items (40 total)

**T1 (Lvl 1-5):** Oak Wood, Berries, Wheat, Plant Fiber, Herbs Common, Mushrooms Common
**T2 (Lvl 6-10):** Pine Wood, Birch Wood, Apples, Pears, Olives, Rye, Barley, Oats, Carrots, Onions, Cabbage, Turnips, Flax, Hemp, Beeswax, Honey, Tree Sap, Cork
**T3 (Lvl 11-15):** Maple Wood, Ash Wood, Grapes, Cotton, Silk, Herbs Rare, Exotic Flowers, Animal Feces, Rare Spices, Resin, Bamboo
**T4 (Lvl 16-20):** Cedar Wood, Willow Wood, Pumpkins, Gourds, Walnuts, Almonds, Indigo Plant, Woad Plant, Madder Root, Rare Seeds
**T5 (Lvl 21-25):** Fire Herbs, Special Mushrooms
**T6 (Lvl 26-30):** Ironwood

### Trapper Items (30 total)

**T1 (Lvl 1-5):** Rabbit Hide, Rabbit Meat, Feathers, Sinew
**T2 (Lvl 6-10):** Deer Hide, Deer Meat, Bones, Animal Fat, Fox Fur
**T3 (Lvl 11-15):** Boar Hide, Boar Meat, Wolf Pelt, Bear Fur, Blood Vials, Claws, Teeth, Horns
**T4+ (Special/Rare):** Musk Glands, Bile Sacs, Trophy Antlers, Exotic Hides, Pristine Pelts

## Existing Tiers

### Completed - ALL TIERS CREATED! ✅
- ✅ Miner T1, T2, T3, T4, T5, T6 (COMPLETE)
- ✅ Forager T1, T2, T3, T4, T5, T6 (COMPLETE)
- ✅ Trapper T1, T2, T3, T4 (COMPLETE)

All 16 loot tables and 16 node scenes have been created and are ready to use!

## Testing

1. **Class Restriction:** Try harvesting with wrong class → should show "Requires [Class] class"
2. **Level Restriction:** Try harvesting below required level → should show "Requires level X"
3. **Loot Table:** Harvest multiple times → should receive varied items based on weights
4. **Rare Bonuses:** Harvest many times → should occasionally get rare bonus items
5. **Tier Progression:** Higher tier nodes should give better/rarer items

## Placing Nodes in World

Nodes can be placed directly in instance maps:

1. Open an instance scene (e.g., `source/server/world/instances/overworld.tscn`)
2. Add node scene as child: `nodes/miner_node_t1.tscn`
3. Position in appropriate location
4. Repeat for other tiers/classes

**Distribution Guidelines:**
- T1 nodes: Starter areas, easily accessible
- T2-T3 nodes: Mid-level areas
- T4-T6 nodes: Dangerous/remote areas
- Cluster by class type: mines for miners, forests for foragers, wilderness for trappers

