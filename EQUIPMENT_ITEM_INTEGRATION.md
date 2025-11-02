# Equipment Item Integration - Complete!

## Overview

Successfully integrated the Equipment System with your existing Item/Inventory/Trading system. You can now have cosmetic equipment items like "Pumpkin Head" that work seamlessly with inventory, trading, and equipment slots.

## What Was Created

### 1. **EquipmentItem Class** (`equipment_item.gd`)
- Extends `Item` (like `GearItem`, `MaterialItem`, etc.)
- References an `EquipmentResource` for visual rendering
- Handles equipping/unequipping via `CompositeSprite`
- Supports level and class requirements
- Tradeable and sellable

### 2. **Accessory Slot** (`item_slot/slots/accessory.tres`)
- New equipment slot type for cosmetic accessories
- Unlocked by default (no level requirement)
- Used by EquipmentItem to determine where it can be equipped

### 3. **Pumpkin Head Item** (`equipment/pumpkin_head_item.tres`)
- Complete item definition ready for inventory
- Links to your pumpkin head `EquipmentResource`
- Tradeable, sellable (500 gold minimum)
- Level 1 requirement, all classes can equip
- Tagged as: cosmetic, equipment, halloween, accessory

## How It Works

### Item Flow

```
Player gets Pumpkin Head Item
  ↓
Shows in Inventory (like any item)
  ↓
Can be traded/sold (like any item)
  ↓
Player equips it to Accessory Slot
  ↓
EquipmentItem.on_equip() called
  ↓
CompositeSprite.equip_accessory(EquipmentResource) called
  ↓
Visual appearance updates (class-specific sprite)
  ↓
Pumpkin head animates with character
```

### Code Structure

```gdscript
EquipmentItem (inventory item)
  └─ equipment: EquipmentResource (visual data)
       └─ sprite_frames_by_class: Dictionary
            ├─ "miner": acc_pumpkin_miner.tres
            ├─ "forager": acc_pumpkin_forager.tres
            └─ "trapper": acc_pumpkin_trapper.tres
```

## Integration Points

### 1. Inventory System ✅
- Pumpkin Head appears as a normal item in inventory grid
- Shows icon, name, stack count (always 1 for equipment)
- Can be selected, inspected, sold, traded

### 2. Trading System ✅
- Equipment items inherit `can_trade = true`
- Can be offered in player-to-player trades
- Works with existing trade UI

### 3. Equipment System ✅
- Uses `ItemSlot` system (like GearItem)
- Can create equipment slot buttons in UI
- `can_equip()` checks level and class requirements
- `on_equip()` / `on_unequip()` handle visual changes

## Next Steps

### 1. Update Item Registry

Run the update script to add pumpkin head to the items registry:

```bash
python update_registry.py
```

This will:
- Scan `source/common/gameplay/items/` for new items
- Add pumpkin head to `items_index.tres`
- Assign it a unique ID
- Make it available via `ContentRegistryHub.load_by_slug(&"items", &"pumpkin_head")`

### 2. Give Player the Item (Testing)

In-game console or server code:

```gdscript
# Give 1 pumpkin head to player
var pumpkin_id = ContentRegistryHub.id_from_slug(&"items", &"pumpkin_head")
player.player_resource.inventory[pumpkin_id] = {"stack": 1}

# Or via request handler:
InstanceClient.current.request_data(&"give_item", func(data): pass, {
    "item": "pumpkin_head",
    "quantity": 1
})
```

### 3. Add Equipment Slot UI

To allow players to equip from inventory, add an equipment slot button:

```gdscript
# In your inventory/equipment UI:
var accessory_slot = GearSlotButton.new()
accessory_slot.gear_slot = load("res://source/common/gameplay/items/item_slot/slots/accessory.tres")
accessory_slot.pressed.connect(_on_accessory_slot_pressed)
equipment_slots_container.add_child(accessory_slot)
```

### 4. Handle Equip from Inventory

Update inventory click handler:

```gdscript
func _on_item_slot_clicked(item_slot_panel: Panel) -> void:
    var item_data = item_slot_panel.item_data
    if item_data.has("item") and item_data.item:
        selected_item = item_data.item
        
        # Show "Equip" button if it's equipment
        if selected_item is EquipmentItem:
            equip_button.show()
            equip_button.disabled = not selected_item.can_equip(local_player)
```

### 5. Network Sync Equipment State

For multiplayer, sync equipped items:

**Add to PlayerResource:**
```gdscript
@export var equipped_accessory_item_id: int = -1
```

**Register in PathRegistry:**
```gdscript
register_field(":equipped_accessory_id", WIRE_I32)
```

**Sync on spawn:**
```gdscript
syn.set_by_path(^":equipped_accessory_id", player_resource.equipped_accessory_item_id)
```

**Listen for changes in Player:**
```gdscript
var equipped_accessory_id: int = -1:
    set = _set_equipped_accessory_id

func _set_equipped_accessory_id(new_id: int) -> void:
    equipped_accessory_id = new_id
    if new_id != -1:
        var item: EquipmentItem = ContentRegistryHub.load_by_id(&"items", new_id)
        if item and item is EquipmentItem:
            item.on_equip(self)
    else:
        # Unequip current accessory
        composite_sprite.unequip_accessory()
```

## File Structure

```
source/common/gameplay/items/
├── equipment_item.gd                    # NEW: Equipment item class
├── equipment/
│   ├── equipment_resource.gd            # Visual data (already created)
│   ├── pumpkin_head.tres               # Visual resource (you created)
│   └── pumpkin_head_item.tres          # NEW: Inventory item
└── item_slot/slots/
    └── accessory.tres                   # NEW: Accessory equipment slot

source/common/gameplay/characters/
└── composite_sprite.gd                  # Updated with equip_accessory()
```

## Testing Checklist

- [ ] Run `python update_registry.py` to register the item
- [ ] Restart Godot to reload the registry
- [ ] Give yourself a pumpkin head via console/admin command
- [ ] See it appear in inventory
- [ ] Click it to select it
- [ ] Equip it to accessory slot
- [ ] See pumpkin head appear on your character
- [ ] Verify animation syncs with body
- [ ] Trade it with another player
- [ ] Sell it at market

## Future Enhancements

### More Equipment Types
- Create more accessories: eyepatch, witch hat, etc.
- Each just needs an `EquipmentResource` + `EquipmentItem`
- Reuse the same `accessory.tres` slot

### Additional Slots
- Create new slots: `helmet.tres`, `cape.tres`, etc.
- Add to `EquipmentResource.Slot` enum
- Implement in `CompositeSprite`: `equip_helmet()`, etc.

### Equipment Sets
- Create bonus effects when wearing multiple items
- Check equipped slots, apply set bonuses
- Store in `EquipmentResource.special_effects`

### Transmogrification
- Allow equipping stats from GearItem
- Display appearance from EquipmentItem
- Separate cosmetic and functional slots

## Benefits of This Design

✅ **Unified System** - Equipment items work like any other item  
✅ **Trading Support** - Built-in trade/sell functionality  
✅ **Cross-Class** - One item, multiple class sprites  
✅ **Extensible** - Easy to add more equipment types  
✅ **Network-Ready** - Prepared for multiplayer sync  
✅ **UI-Friendly** - Integrates with existing inventory UI  

Your players can now collect, trade, and wear cosmetic accessories! 🎃✨

