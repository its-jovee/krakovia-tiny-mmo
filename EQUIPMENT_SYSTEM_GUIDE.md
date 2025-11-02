# Equipment System Guide

## Overview

The equipment system allows creating cosmetic items that:
- Support **cross-class compatibility** (one item, multiple class-specific sprites)
- Have **level and class requirements**
- Can be **animated or static**
- **Sync with body animations** (breathing, squash/stretch, frame-by-frame)
- Support **future stat modifiers and effects**

## Creating a Cross-Class Equipment Item

### Example: Pumpkin Head

This guide shows how to create a "Pumpkin Head" accessory that works for all three classes (miner, forager, trapper), each with their own animated sprite.

### Step 1: Prepare the Sprite Assets

You already have:
```
source/common/gameplay/characters/sprite_frames/composite/miner/accessory/acc_pumpkin.tres
source/common/gameplay/characters/sprite_frames/composite/forager/accessory/acc_pumpkin.tres (create)
source/common/gameplay/characters/sprite_frames/composite/trapper/accessory/acc_pumpkin.tres (create)
```

Each `.tres` file should be a `SpriteFrames` resource with animations:
- `idle`
- `run`
- `harvest`
- `sit`

**Important:** Frame counts should match the base body animations for perfect sync.

### Step 2: Create the Equipment Resource

1. In Godot, navigate to `source/common/gameplay/items/equipment/`
2. Right-click → **New Resource**
3. Search for and select **EquipmentResource**
4. Save as `pumpkin_head.tres`

### Step 3: Configure the Equipment Resource

Open `pumpkin_head.tres` in the inspector and set:

#### Basic Info
- **Item Id:** `pumpkin_head`
- **Display Name:** `Pumpkin Head`
- **Description:** `A spooky pumpkin head for Halloween!`
- **Slot:** `ACCESSORY` (0)

#### Requirements
- **Required Classes:** Leave **empty** (or add ["miner", "forager", "trapper"]) - any class can equip
- **Required Level:** `1` (or higher if you want level gating)

#### Visual
- **Is Animated:** `true` ✅ (check this box!)
- **Sprite Frames By Class:** Click "Add Element" 3 times and configure:
  ```
  Key: "miner"    Value: [Load] acc_pumpkin.tres from miner/accessory/
  Key: "forager"  Value: [Load] acc_pumpkin.tres from forager/accessory/
  Key: "trapper"  Value: [Load] acc_pumpkin.tres from trapper/accessory/
  ```

#### Effects (Future)
- **Stat Modifiers:** Leave empty for now
- **Special Effects:** Leave empty for now

### Step 4: Test the Equipment

To test programmatically:

```gdscript
# Get the player's composite sprite
var composite_sprite: CompositeSprite = player.composite_sprite

# Load the equipment resource
var pumpkin_head: EquipmentResource = load("res://source/common/gameplay/items/equipment/pumpkin_head.tres")

# Equip it!
composite_sprite.equip_accessory(pumpkin_head)

# To unequip:
composite_sprite.unequip_accessory()
```

The system will automatically:
1. Check the player's class
2. Load the appropriate sprite frames
3. Sync animation with body movements
4. Apply breathing/squash-stretch shaders

## Creating Other Equipment Types

### Static (Non-Animated) Equipment

For items like eyepatches or simple overlays:

1. Set **Is Animated:** `false`
2. The system will use only the first frame of the "idle" animation
3. No frame synchronization needed

Example:
```gdscript
var eyepatch: EquipmentResource = EquipmentResource.new()
eyepatch.item_id = "eyepatch"
eyepatch.display_name = "Eyepatch"
eyepatch.slot = EquipmentResource.Slot.ACCESSORY
eyepatch.is_animated = false  # Static overlay
eyepatch.sprite_frames_by_class = {
    "miner": load("res://.../eyepatch_miner.tres"),
    "forager": load("res://.../eyepatch_forager.tres"),
    "trapper": load("res://.../eyepatch_trapper.tres")
}
```

### Class-Specific Equipment

To restrict equipment to specific classes:

```gdscript
var miner_helmet: EquipmentResource = EquipmentResource.new()
miner_helmet.required_classes = ["miner"]  # Only miners can equip
miner_helmet.sprite_frames_by_class = {
    "miner": load("res://.../miner_helmet.tres")
}
```

### Level-Gated Equipment

```gdscript
var legendary_crown: EquipmentResource = EquipmentResource.new()
legendary_crown.required_level = 30  # Must be level 30+
```

## Integration with Inventory/Shop System

### Equipping from Inventory

When a player equips an item from their inventory:

```gdscript
func on_equip_button_pressed(item_id: String) -> void:
    # Load the equipment resource
    var equipment_path := "res://source/common/gameplay/items/equipment/%s.tres" % item_id
    var equipment: EquipmentResource = load(equipment_path)
    
    # Check if player can equip
    if not equipment.can_equip(player.character_class, player.level):
        show_error("You don't meet the requirements!")
        return
    
    # Equip via composite sprite
    player.composite_sprite.equip_accessory(equipment)
    
    # Save equipped item to PlayerResource
    player.player_resource.equipped_accessory_id = item_id
    
    # Sync over network (future work)
    # ...
```

### Network Synchronization (Future Work)

To sync equipment across clients:

1. Add to `PlayerResource`:
   ```gdscript
   @export var equipped_accessory_id: String = "none"
   ```

2. Register in `PathRegistry`:
   ```gdscript
   register_field(":equipped_accessory_id", WIRE_VARIANT)
   ```

3. Sync when player spawns:
   ```gdscript
   syn.set_by_path(^":equipped_accessory_id", player_resource.equipped_accessory_id)
   ```

4. Listen for changes in `Character`:
   ```gdscript
   var equipped_accessory_id: String = "none":
       set = _set_equipped_accessory_id
   
   func _set_equipped_accessory_id(new_id: String) -> void:
       equipped_accessory_id = new_id
       if new_id == "none":
           composite_sprite.unequip_accessory()
       else:
           var equipment: EquipmentResource = load("res://.../equipment/%s.tres" % new_id)
           composite_sprite.equip_accessory(equipment)
   ```

## File Structure

```
source/common/gameplay/items/equipment/
├── equipment_resource.gd         # Base class
├── pumpkin_head.tres             # Example equipment
├── eyepatch.tres
└── ...

source/common/gameplay/characters/sprite_frames/composite/
├── miner/accessory/
│   ├── acc_pumpkin.tres
│   └── acc_eyepatch.tres
├── forager/accessory/
│   ├── acc_pumpkin.tres
│   └── acc_eyepatch.tres
└── trapper/accessory/
    ├── acc_pumpkin.tres
    └── acc_eyepatch.tres
```

## Animation Requirements

For **animated accessories** that sync with body movement:

### Required Animations
- `idle` - matches body idle animation
- `run` - matches body run animation
- `harvest` - matches body harvest animation
- `sit` - matches body sit animation

### Frame Counts
Frame counts should match the base body:
- **Idle:** Usually 1 frame (static) or 2-4 frames (breathing)
- **Run:** Usually 2-8 frames
- **Harvest:** Usually 2-4 frames
- **Sit:** Usually 1 frame

### Frame Rate
Match the base body FPS (usually 5-8 FPS).

## Future Enhancements

### Stat Modifiers
```gdscript
equipment.stat_modifiers = {
    "armor": 5.0,
    "move_speed": -0.1  # -10% movement speed
}
```

### Special Effects
```gdscript
var glow_effect: EquipmentEffect = EquipmentEffect.new()
glow_effect.type = EquipmentEffect.Type.PARTICLE_EMITTER
glow_effect.particle_scene = preload("res://.../glow_particles.tscn")

equipment.special_effects.append(glow_effect)
```

### Equipment Sets
```gdscript
var halloween_set: EquipmentSet = EquipmentSet.new()
halloween_set.required_items = ["pumpkin_head", "witch_cape", "ghost_boots"]
halloween_set.set_bonus = {
    "spooky_aura": true,
    "candy_drop_rate": 2.0
}
```

## Tips

1. **Always create SpriteFrames resources first** before creating EquipmentResource
2. **Test with one class** before adding all three
3. **Check frame counts match** between body and accessory for smooth sync
4. **Use empty arrays** for `required_classes` to allow all classes
5. **Start with `is_animated = false`** for simpler items, then upgrade to animated
6. **Reuse sprite sheets** across classes when possible (just different rects)

## Troubleshooting

**Problem:** Accessory doesn't appear
- Check that `sprite_frames_by_class` has an entry for the player's class
- Verify the SpriteFrames resource path is correct
- Make sure `is_animated` matches your setup

**Problem:** Accessory animation is out of sync
- Verify frame counts match between body and accessory
- Check that all 4 animations exist (idle, run, harvest, sit)
- Ensure FPS matches

**Problem:** "Cannot equip" error
- Check `required_level` and `required_classes`
- Use `equipment.can_equip(class, level)` to debug

**Problem:** Wrong sprite shows for class
- Verify dictionary keys are exact: "miner", "forager", "trapper" (lowercase)
- Check that each SpriteFrames resource loads correctly

