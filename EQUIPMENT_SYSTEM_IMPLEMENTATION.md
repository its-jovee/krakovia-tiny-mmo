# Equipment System Implementation Summary

## Overview

Implemented a flexible equipment system for cosmetic accessories that supports **cross-class compatibility**. One item can have different sprites per class, automatically selecting the correct one based on the player's class.

## Key Features

### ✅ Cross-Class Support
- Single "Pumpkin Head" item works for miner, forager, and trapper
- Each class gets its own animated sprite
- Automatic sprite selection based on `character_class`

### ✅ Requirements System
- **Level requirements:** Minimum level to equip
- **Class restrictions:** Optional whitelist of allowed classes
- Empty `required_classes` = all classes can equip

### ✅ Animation Support
- **Animated accessories:** Full frame-by-frame sync with body animations
- **Static accessories:** Single frame overlays
- Automatic shader application (breathing, squash/stretch)

### ✅ Extensible Design
- Future slots: HELMET, CAPE, BODY_ARMOR, etc.
- Future effects: Stat modifiers, particle emitters, special abilities
- Equipment sets with bonuses

## Architecture

### EquipmentResource (`equipment_resource.gd`)

```gdscript
class_name EquipmentResource extends Resource

enum Slot { ACCESSORY }

@export var item_id: String
@export var display_name: String
@export var slot: Slot
@export var required_classes: Array[String] = []  # Empty = all classes
@export var required_level: int = 1
@export var sprite_frames_by_class: Dictionary = {}  # {"miner": SpriteFrames, ...}
@export var is_animated: bool = false

func get_sprite_frames_for_class(char_class: String) -> SpriteFrames
func can_equip(char_class: String, level: int) -> bool
```

### CompositeSprite Integration

**New Methods:**
- `equip_accessory(equipment: EquipmentResource)` - Equips cross-class item
- `unequip_accessory()` - Removes equipped accessory

**Features:**
- Automatically selects correct sprite for player's class
- Handles animated and static accessories
- Syncs animated accessories with body movement
- Applies shaders to all layers

## How Cross-Class Items Work

### Example: Pumpkin Head

1. **Create Equipment Resource** (`pumpkin_head.tres`):
   ```
   item_id: "pumpkin_head"
   display_name: "Pumpkin Head"
   is_animated: true
   required_classes: []  # All classes
   sprite_frames_by_class:
     "miner": acc_pumpkin_miner.tres
     "forager": acc_pumpkin_forager.tres
     "trapper": acc_pumpkin_trapper.tres
   ```

2. **Equip on Character:**
   ```gdscript
   var pumpkin = load("res://.../pumpkin_head.tres")
   player.composite_sprite.equip_accessory(pumpkin)
   ```

3. **System Automatically:**
   - Checks `player.character_class` (e.g., "miner")
   - Loads `sprite_frames_by_class["miner"]`
   - Applies to accessory layer
   - Syncs animations with body

### Benefits

✅ **One item definition** instead of three separate items  
✅ **Simpler inventory** - "Pumpkin Head" not "Pumpkin Head (Miner)"  
✅ **Class switching** - If player changes class, sprite updates automatically  
✅ **Easier balancing** - Change stats/requirements in one place  
✅ **Less code duplication** - Shared logic for all classes

## File Structure

```
source/common/gameplay/items/equipment/
├── equipment_resource.gd           # Base class
└── [equipment_items].tres          # Individual equipment (pumpkin_head.tres, etc.)

source/common/gameplay/characters/
├── composite_sprite.gd             # Updated with equip_accessory() method
└── sprite_frames/composite/
    ├── miner/accessory/
    │   └── acc_pumpkin.tres
    ├── forager/accessory/
    │   └── acc_pumpkin.tres
    └── trapper/accessory/
        └── acc_pumpkin.tres
```

## Usage Example

### Creating Pumpkin Head Equipment

```gdscript
# In Godot Editor:
# 1. Create new EquipmentResource
# 2. Save as: source/common/gameplay/items/equipment/pumpkin_head.tres
# 3. Set in Inspector:
#    - item_id: "pumpkin_head"
#    - display_name: "Pumpkin Head"
#    - is_animated: true
#    - sprite_frames_by_class:
#        Key: "miner"    → Load miner/accessory/acc_pumpkin.tres
#        Key: "forager"  → Load forager/accessory/acc_pumpkin.tres
#        Key: "trapper"  → Load trapper/accessory/acc_pumpkin.tres
```

### Equipping in Code

```gdscript
# Load equipment resource
var pumpkin_head: EquipmentResource = load("res://source/common/gameplay/items/equipment/pumpkin_head.tres")

# Check if player can equip
if pumpkin_head.can_equip(player.character_class, player.level):
    # Equip via composite sprite
    player.composite_sprite.equip_accessory(pumpkin_head)
else:
    show_error("You don't meet the requirements!")

# To unequip:
player.composite_sprite.unequip_accessory()
```

## Animation Sync

Animated accessories automatically sync with body animations:

- **Frame-by-frame sync:** Accessory frame matches body frame exactly
- **Animation changes:** When body plays "run", accessory plays "run"
- **Shader effects:** Breathing and squash/stretch applied to all layers
- **Flip state:** Accessories flip with character direction

## Future Network Sync

To sync equipment across clients (future work):

1. Add to `PlayerResource`:
   ```gdscript
   @export var equipped_accessory_id: String = "none"
   ```

2. Register in `PathRegistry`:
   ```gdscript
   register_field(":equipped_accessory_id", WIRE_VARIANT)
   ```

3. Sync on spawn:
   ```gdscript
   syn.set_by_path(^":equipped_accessory_id", player_resource.equipped_accessory_id)
   ```

4. Add setter in `Character`:
   ```gdscript
   var equipped_accessory_id: String = "none":
       set = _set_equipped_accessory_id
   
   func _set_equipped_accessory_id(new_id: String) -> void:
       equipped_accessory_id = new_id
       if new_id != "none":
           var equipment = load("res://.../equipment/%s.tres" % new_id)
           composite_sprite.equip_accessory(equipment)
       else:
           composite_sprite.unequip_accessory()
   ```

## Next Steps

1. **Create Sprite Assets:**
   - Create SpriteFrames for `acc_pumpkin.tres` for each class
   - Ensure all 4 animations exist: idle, run, harvest, sit
   - Match frame counts with base body animations

2. **Create Equipment Resource:**
   - Follow guide in `EQUIPMENT_SYSTEM_GUIDE.md`
   - Test with one class first
   - Add remaining classes once working

3. **Integrate with Inventory:**
   - Add equip button to inventory UI
   - Load equipment resource when equipping
   - Save equipped_accessory_id to PlayerResource

4. **Network Sync:**
   - Follow network sync steps above
   - Test late joiners see correct equipment
   - Test equipment persists across sessions

## Benefits of This Design

✨ **Flexible:** Easy to add new equipment types (helmets, capes, etc.)  
✨ **Scalable:** Cross-class support reduces asset duplication  
✨ **Maintainable:** Centralized equipment definitions  
✨ **Extensible:** Ready for stat modifiers and special effects  
✨ **Performance:** Efficient animation sync, minimal overhead  
✨ **User-Friendly:** One item works for all classes automatically  

## Questions?

See `EQUIPMENT_SYSTEM_GUIDE.md` for detailed setup instructions and troubleshooting!

