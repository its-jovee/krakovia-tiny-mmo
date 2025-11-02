# Cosmetic Equipment System - Migration Guide

**Status**: Future Enhancement  
**Current System**: Free appearance customization with stored IDs  
**Target System**: Equippable cosmetic items

---

## Overview

This document outlines the migration path from the current appearance ID system to a full cosmetic equipment system. The current implementation stores appearance as simple string IDs (`appearance_face_id`, `appearance_hair_id`, `appearance_accessory_id`). The future system will treat these as equippable items with their own properties, rarity, and trade value.

---

## Current System (Phase 1)

### Data Storage
- **PlayerResource** stores appearance as strings:
  - `appearance_face_id: String` - Face variant (e.g., "0", "1", "2")
  - `appearance_hair_id: String` - Hair style (currently "none", future: "long", "short")
  - `appearance_accessory_id: String` - Accessory (currently "none", future: "eyepatch", "bandana")

### Network Sync
- `:appearance_face` synced via `PathRegistry`
- Applied on character spawn via `StateSynchronizer`

### UI
- Character creation: Face selection with Next/Previous buttons
- No in-game appearance menu initially

---

## Target System (Phase 2)

### Cosmetic Item Types

Create new item types that extend `Item` base class:

```gdscript
class_name CosmeticItem
extends Item

enum CosmeticSlot {
	FACE,
	HAIR,
	ACCESSORY,
	BODY_ARMOR,  # Future
	CAPE,        # Future
	HELMET       # Future
}

@export var cosmetic_slot: CosmeticSlot
@export var appearance_id: String  # Links to CompositePartRegistry
@export var class_restriction: String = ""  # Empty = all classes, or "miner", "forager", etc.
```

### Equipment Component Extension

Extend `EquipmentComponent` to support cosmetic slots:

```gdscript
# In EquipmentComponent
var cosmetic_slots: Dictionary = {
	CosmeticItem.CosmeticSlot.FACE: null,
	CosmeticItem.CosmeticSlot.HAIR: null,
	CosmeticItem.CosmeticSlot.ACCESSORY: null,
}

func equip_cosmetic(item: CosmeticItem) -> bool:
	if item.class_restriction and item.class_restriction != character.character_class:
		return false  # Can't equip this cosmetic on this class
	
	cosmetic_slots[item.cosmetic_slot] = item
	_update_character_appearance()
	return true
```

### Data Migration Strategy

#### Step 1: Create Cosmetic Items
Create item resources for each appearance variant:
- `face_0.tres`, `face_1.tres`, `face_2.tres`, etc.
- Each has `appearance_id` matching the current string IDs
- Add to ItemRegistry

#### Step 2: Migration Script
Convert existing player appearance data to equipped items:

```gdscript
func migrate_appearance_to_items(player_resource: PlayerResource) -> void:
	# Face migration
	if player_resource.appearance_face_id != "none":
		var face_item_id = "cosmetic_face_" + player_resource.appearance_face_id
		var face_item = ContentRegistryHub.load_by_id(&"items", face_item_id)
		if face_item:
			# Add to inventory if not already present
			if not player_resource.inventory.has(face_item_id):
				player_resource.inventory[face_item_id] = 1
	
	# Hair migration (when enabled)
	# Accessory migration (when enabled)
```

#### Step 3: Update Character Initialization
On character spawn, automatically equip cosmetic items based on stored IDs:

```gdscript
func _initialize_appearance_from_items(player_resource: PlayerResource) -> void:
	# Check equipped cosmetic slots
	for slot in equipment_component.cosmetic_slots:
		var item = equipment_component.cosmetic_slots[slot]
		if item:
			composite_sprite.set_layer(slot, item.appearance_id)
```

### Cosmetic Item Properties

Cosmetics can have additional properties for game economy:

```gdscript
@export var rarity: Item.Rarity = Item.Rarity.COMMON
@export var tradeable: bool = true
@export var purchase_price: int = 100  # Gold cost in shops
@export var dye_slots: int = 0  # Future: color customization
```

---

## Migration Timeline

### Phase 1 (Current Implementation)
- ✅ CompositeSprite system with layers
- ✅ Face selection during character creation
- ✅ Appearance stored in PlayerResource as strings
- ✅ Network synchronization via PathRegistry

### Phase 2 (Equipment Integration)
- [ ] Create CosmeticItem class
- [ ] Extend EquipmentComponent with cosmetic slots
- [ ] Create cosmetic item resources for all existing variants
- [ ] Implement in-game cosmetic menu to equip/unequip
- [ ] Add cosmetic items to shops/loot drops

### Phase 3 (Advanced Features)
- [ ] Hair layer implementation (animated)
- [ ] Accessory layer implementation (static)
- [ ] More cosmetic slots (capes, helmets, body armor)
- [ ] Dye system for color customization
- [ ] Cosmetic crafting/combining
- [ ] Seasonal/event-exclusive cosmetics

---

## Backward Compatibility

The migration preserves existing player appearances:

1. **Existing Characters**: Appearance IDs remain in PlayerResource
2. **Automatic Conversion**: On first login after migration, convert IDs to equipped items
3. **Fallback**: If item missing, use appearance ID directly (graceful degradation)

```gdscript
func get_appearance_for_layer(layer: CompositePartRegistry.Layer) -> String:
	# Try equipped item first
	var item = equipment_component.get_cosmetic_for_layer(layer)
	if item:
		return item.appearance_id
	
	# Fallback to stored ID
	match layer:
		CompositePartRegistry.Layer.FACE:
			return player_resource.appearance_face_id
		CompositePartRegistry.Layer.HAIR:
			return player_resource.appearance_hair_id
		CompositePartRegistry.Layer.ACCESSORY:
			return player_resource.appearance_accessory_id
	
	return "none"
```

---

## Testing Plan

### Pre-Migration Tests
1. Create characters with different face selections
2. Verify appearance persists across sessions
3. Verify appearance syncs to other clients

### Post-Migration Tests
1. Old characters load with correct appearance
2. Can equip/unequip cosmetic items
3. Class restrictions work correctly
4. Cosmetic items appear in inventory
5. Appearance syncs after equipment change

---

## Notes

- Keep `appearance_*_id` fields in PlayerResource for backward compatibility
- Update fields when cosmetic items are equipped (for save compat)
- Consider cosmetic items as "account-bound" vs "character-bound"
- Plan for cosmetic trading/marketplace features

---

**Last Updated**: 2025-11-01  
**Contact**: Development Team

