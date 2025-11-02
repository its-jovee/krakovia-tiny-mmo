# Equipment System - Server Authority Implementation Guide

## Critical Issue Identified

The current `EquipmentItem` system is **client-only**, which is wrong. Equipped cosmetic items MUST be:
- ✅ Server-authoritative (like `GearItem`)
- ✅ Persistent (saved to database)
- ✅ Synced to all clients (visible to everyone)
- ✅ Validated by server (can't cheat requirements)

## Current Architecture (WRONG)

```
Client: Click "Equip" → EquipmentItem.on_equip() → CompositeSprite.equip_accessory()
        ↓
        No server involvement
        ↓
        Other players don't see it
        Not saved
```

## Correct Architecture (TO IMPLEMENT)

```
Client: Click "Equip" → Send request to server
        ↓
Server: Validate requirements → Update PlayerResource → Broadcast to all
        ↓
All Clients: Receive sync → Update CompositeSprite
```

---

## Implementation Plan

### Phase 1: Server-Side Storage

**File:** `source/common/gameplay/characters/player/player_resource.gd`

Add:
```gdscript
## Equipped cosmetic items (item IDs, not EquipmentResource)
@export var equipped_accessory_id: int = -1  # -1 = nothing equipped
# Future:
# @export var equipped_helmet_id: int = -1
# @export var equipped_cape_id: int = -1
```

### Phase 2: Network Synchronization

**File:** `source/common/registry/path_registry.gd`

Add:
```gdscript
register_field(":equipped_accessory_id", WIRE_VARIANT)
```

**File:** `source/server/world/components/instance_server.gd`

In `_spawn_player()`, add:
```gdscript
syn.set_by_path(^":equipped_accessory_id", new_player.player_resource.equipped_accessory_id)
```

### Phase 3: Server Request Handler

**File:** `source/server/world/components/data_request_handlers/item.equip_cosmetic.gd` (NEW)

```gdscript
extends DataRequestHandler

func handle(player: Player, data: Dictionary) -> Dictionary:
	var item_id: int = data.get("item_id", -1)
	var slot_type: String = data.get("slot", "accessory")  # "accessory", "helmet", etc.
	
	# Validate item exists in inventory
	if not player.player_resource.inventory.has(item_id):
		return {"ok": false, "error": "Item not in inventory"}
	
	# Load item and validate it's an EquipmentItem
	var item: Item = ContentRegistryHub.load_by_id(&"items", item_id)
	if not item or not item is EquipmentItem:
		return {"ok": false, "error": "Invalid equipment item"}
	
	var equipment_item := item as EquipmentItem
	
	# Validate requirements
	if not equipment_item.can_equip(player):
		return {"ok": false, "error": "Requirements not met"}
	
	# Equip item (server-side)
	match slot_type:
		"accessory":
			player.player_resource.equipped_accessory_id = item_id
			player.state_synchronizer.set_by_path(^":equipped_accessory_id", item_id)
	
	# Save to database
	player.save_player_data()
	
	return {"ok": true, "equipped_id": item_id, "slot": slot_type}
```

**File:** `source/server/world/components/data_request_handlers/item.unequip_cosmetic.gd` (NEW)

```gdscript
extends DataRequestHandler

func handle(player: Player, data: Dictionary) -> Dictionary:
	var slot_type: String = data.get("slot", "accessory")
	
	match slot_type:
		"accessory":
			player.player_resource.equipped_accessory_id = -1
			player.state_synchronizer.set_by_path(^":equipped_accessory_id", -1)
	
	player.save_player_data()
	
	return {"ok": true, "slot": slot_type}
```

### Phase 4: Client Request (Instead of Direct Equip)

**File:** `source/client/ui/inventory/inventory_menu.gd`

Replace `equipment_item.on_equip(local_player)` with:
```gdscript
# Send equip request to server
InstanceClient.current.request_data(
	&"item.equip_cosmetic",
	func(response: Dictionary):
		if response.get("ok", false):
			print("✅ Equipped %s!" % equipment_item.item_name)
		else:
			print("❌ Failed to equip: %s" % response.get("error", "Unknown error"))
	,
	{
		"item_id": selected_item_id,
		"slot": "accessory"
	}
)
```

### Phase 5: Client Sync Handler

**File:** `source/common/gameplay/characters/character.gd`

Add a property listener:
```gdscript
var equipped_accessory_id: int = -1:
	set = _set_equipped_accessory

func _set_equipped_accessory(new_id: int) -> void:
	equipped_accessory_id = new_id
	
	if composite_sprite:
		if new_id == -1:
			# Unequip
			composite_sprite.unequip_accessory()
		else:
			# Equip
			var item: Item = ContentRegistryHub.load_by_id(&"items", new_id)
			if item and item is EquipmentItem:
				var equipment_item := item as EquipmentItem
				composite_sprite.equip_accessory(equipment_item.equipment)
```

---

## Naming Clarification

You're right that the naming is confusing. Here's the structure:

### Current Structure (Correct, but confusing)
```
pumpkin_head.tres (EquipmentResource)
├── Cross-class sprite frames (miner/forager/trapper)
├── Display info
└── Requirements

pumpkin_head_item.tres (EquipmentItem extends Item)
├── References pumpkin_head.tres
├── Inventory properties (icon, price, stack limit)
├── Can be traded, sold, moved in inventory
└── Registry slug: "pumpkin_head"
```

### Why This Way?
- **EquipmentResource** = The "definition" of the equipment (visuals, stats, effects)
- **EquipmentItem** = The "inventory item" that holds the equipment (tradeable, sellable)

This mirrors the existing pattern:
- `GearResource` defines the gear
- `GearItem` is the inventory item that references it

### Better Naming (Optional Refactor)
```
pumpkin_head_equipment.tres (EquipmentResource)
pumpkin_head.tres (EquipmentItem)
```

This would make it clearer that the item is what players interact with, and the equipment is the data.

---

## Debug: Why Clicking Does Nothing

**Immediate Test (Add to inventory_menu.gd `_on_equip_button_pressed()`):**

```gdscript
func _on_equip_button_pressed() -> void:
	print("=" * 60)
	print("EQUIP BUTTON PRESSED!")
	print("Selected item: %s" % (selected_item.item_name if selected_item else "NULL"))
	print("Is EquipmentItem: %s" % (selected_item is EquipmentItem if selected_item else false))
	print("=" * 60)
	
	# ... rest of function
```

If this doesn't print when you click, then:
1. The button isn't connected (scene file issue)
2. The button you're clicking isn't the one we think it is
3. The HBoxContainer is invisible (parent visibility blocks clicks)

**Diagnostic:**
After selecting the Pumpkin Head, check console for:
```
[Inventory] EquipmentItem detected! Showing equip button...
  → HBox visible: true
  → Connected Equip button pressed signal
  → Button visible: true, disabled: false, text: 'Equip'
  → Button global visible: true  ← CRITICAL: Must be true
```

If "Button global visible" is **false**, the parent HBoxContainer or its ancestors are invisible.

---

## Summary: What Needs to Happen

### Immediate (Debug Click Issue)
1. Reload project
2. Select Pumpkin Head
3. Check console for visibility debug
4. Click Equip
5. If still no "EQUIP BUTTON PRESSED!", the button isn't wired correctly

### Short-term (Server Authority)
1. Add `equipped_accessory_id` to PlayerResource
2. Add PathRegistry field
3. Create server request handlers
4. Update client to send requests instead of direct equip
5. Add sync handler in Character

### Long-term (Full System)
1. Multiple equipment slots (helmet, cape, etc.)
2. Equipment preview in character creation
3. Equipment trading/marketplace
4. Equipment effects/stats (if desired)
5. Equipment collections/achievements

---

## Next Steps

**Priority 1:** Fix the clicking issue first (diagnostic above)
**Priority 2:** Implement server authority (Phase 1-5)
**Priority 3:** Clean up naming if desired

The server authority changes are essential for a multiplayer game. The current client-only approach won't work for your use case where players need to see each other's cosmetics.

