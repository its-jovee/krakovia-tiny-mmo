# Immediate Trickle Distribution System

## Overview

The harvesting system has been upgraded from **batch distribution** to **immediate trickle distribution** for better player feedback and engagement.

## What Changed

### Old System (Batch Distribution)
- Resources accumulated in a shared pool
- Items distributed only when player left or node depleted
- Players saw "projected total" but didn't get items until done
- Confusing UX with abstract pool amounts

### New System (Immediate Trickle Distribution)
- Items distributed **immediately** every harvest tick
- Pop-up notifications show exactly what you got
- Visual feedback with item icon + name + quantity
- Multiple players = faster ticks (same multiplier system)

## Implementation Details

### Server-Side Changes (`harvest_node.gd`)

#### 1. Immediate Distribution in Harvest Tick
```gdscript
# Each player has a harvest_pool that accumulates fractional amounts
var harvest_pool: float = float(h.get("harvest_pool", 0.0)) + produce

# When pool >= 1.0, immediately distribute
if harvest_pool >= 1.0:
    var harvest_count: int = int(floor(harvest_pool))
    harvest_pool -= float(harvest_count)
    
    # Roll loot table for each harvest
    # Give items immediately
    # Send notification via harvest.item_received
```

**Key Features:**
- Fractional accumulation prevents loss of partial progress
- Rolls loot table for each completed harvest
- Sends `harvest.item_received` RPC with items array
- Updates `earned_total` for UI tracking

#### 2. Simplified Distribution Logic
- `_distribute()` function deprecated (kept for compatibility)
- `player_leave()` no longer calls distribution
- `_on_depleted()` no longer distributes pool
- Pool amount reset immediately

### Client-Side Changes

#### 1. HUD Subscription (`hud.gd`)
```gdscript
# Subscribe to harvest notifications
InstanceClient.subscribe(&"harvest.item_received", _on_harvest_item_received)

func _on_harvest_item_received(data: Dictionary) -> void:
    var items: Array = data.get("items", [])
    for item_dict in items:
        var slug: StringName = item_dict.get("slug", &"")
        var amount: int = int(item_dict.get("amount", 0))
        
        var item: Item = ContentRegistryHub.load_by_slug(&"items", slug)
        if item:
            _show_harvest_popup(item.item_name, item.item_icon, amount)
```

#### 2. Harvest Popup Component

**Files Created:**
- `source/client/ui/hud/harvest_popup.gd` - Logic
- `source/client/ui/hud/harvest_popup.tscn` - Visual scene

**Features:**
- Displays item icon + "+X Item Name"
- Fades in with scale pop animation
- Floats upward
- Fades out after 2.5 seconds
- Auto-stacks vertically when multiple items arrive
- Auto-cleanup with `queue_free()`

## Benefits

### ✅ Immediate Gratification
- Players see items **instantly** as they harvest
- Clear cause-and-effect relationship
- More satisfying gameplay loop

### ✅ Better Visual Feedback
- Pop-up shows exactly what you got
- Item icon for quick recognition
- Quantity clearly displayed

### ✅ Multiplayer Still Works
- Multiplier makes ticks faster
- Groups harvest more items per second
- Each player gets their own drops

### ✅ Simpler Code
- No complex pool allocation math
- No time-based distribution calculations
- Immediate = easier to understand and maintain

### ✅ Better Solo Experience
- Solo players don't wait for pool to fill
- Get items every ~1 second
- More engaging for solo gameplay

## How It Works in Practice

### Solo Harvesting (1x multiplier)
1. Player stands at node
2. Every 1 second: harvest tick
3. Roll loot table (e.g., 40% Copper, 30% Stone)
4. Items added to inventory
5. Pop-up shows "+2 Copper Ore"
6. Pop-up floats up and fades

### Group Harvesting (1.5x multiplier with 5+ players)
1. Players stand at node
2. Every 1 second: harvest tick
3. Base rate × 1.5 multiplier = 1.5 harvests/second
4. Each player accumulates in their pool
5. When pool >= 1.0, distribute immediately
6. Result: Faster item acquisition

## Examples

### Miner at T1 Node (Solo)
- **Loot Table**: Copper (40%), Stone (30%), Coal (15%), Clay (10%), Sand (5%)
- **Every second**:
  - Roll: 40% chance for 1-2 Copper Ore
  - Roll: 30% chance for 1-2 Stone
  - Roll: 15% chance for 1 Coal
  - etc.
- **Typical results**: Every 2-3 seconds player gets 1-3 items

### Forager at T1 Node (Solo)
- **Loot Table**: Oak Wood (40%), Berries (25%), Wheat (20%), etc.
- **Rare Bonus**: 2% chance for Silk
- **Every 1.2 seconds** (0.833 rate):
  - Accumulates in pool
  - At 1.2s, pool = 1.0, distribute
  - Roll loot table
  - Occasionally get rare Silk!

### Trapper at T2 Node (Group of 3)
- **Loot Table**: Deer Hide (35%), Deer Meat (30%), Bones (20%), etc.
- **Multiplier**: 1.2x (3 players)
- **Every second**: Each player gets 1.2 progress
- **Result**: Items every ~0.8 seconds per player

## Network Considerations

### RPC Traffic
- **Old system**: Large batches on leave/deplete
- **New system**: Small frequent messages (1-3 items each)
- **Impact**: More frequent but smaller payloads
- **Mitigation**: Items bundled per tick, not per item

### Data Format
```gdscript
# harvest.item_received payload
{
    "node": "Node_path",
    "items": [
        {"slug": "copper_ore", "amount": 2},
        {"slug": "stone", "amount": 1}
    ]
}
```

## UI/UX Design

### Pop-up Behavior
- **Lifetime**: 2.5 seconds total
- **Fade In**: 0.3 seconds
- **Visible**: 1.5 seconds
- **Fade Out**: 1.0 second
- **Float Speed**: 30 pixels/second upward
- **Stacking**: Vertical offset of 50 pixels per popup

### Visual Style
- Panel background for readability
- Item icon (32x32) on left
- Text on right: "+X Item Name"
- Font size: 16pt
- Centered in HBoxContainer

## Testing Checklist

- [ ] Solo harvesting shows immediate popups
- [ ] Multiple players get their own popups
- [ ] Popups stack vertically when many items come quickly
- [ ] Fractional amounts accumulate correctly
- [ ] Rare bonuses appear in popups
- [ ] Popups auto-cleanup after lifetime
- [ ] Item icons display correctly
- [ ] Item names display correctly
- [ ] Quantities display correctly
- [ ] Works with all three classes (miner, forager, trapper)
- [ ] Works across all tiers (T1-T6)
- [ ] No memory leaks from popups

## Future Enhancements

### Possible Improvements
1. **Sound Effects**: Play satisfying "ding" on item received
2. **Rarity Colors**: Gold text for rare items, white for common
3. **Combo System**: "3x Combo!" when getting same item multiple times
4. **Summary**: Show total harvested when leaving node
5. **Floating Numbers**: Items float from node to player
6. **Particle Effects**: Sparkles when receiving rare items
7. **Settings**: Option to disable/reduce popup frequency

### Configuration Options
Could add to settings:
- Popup duration
- Float speed
- Stack spacing
- Font size
- Show/hide icons
- Combine duplicate items

## Troubleshooting

### Popups Not Appearing
1. Check HUD has subscribed to `harvest.item_received`
2. Verify `harvest_popup.tscn` exists and loads correctly
3. Check console for "[Harvest] +X Item" fallback messages
4. Ensure ContentRegistryHub can load items by slug

### Items Not Being Given
1. Check `instance.give_item()` returns true
2. Verify item slugs match registry
3. Check inventory has space
4. Look for server errors in console

### Performance Issues
1. Limit popup lifetime to prevent accumulation
2. Ensure old popups are cleaned up via `queue_free()`
3. Consider pooling popup instances if needed
4. Monitor RPC frequency (should be ~1-2 per second per player)

## Summary

The immediate trickle distribution system provides **instant feedback** and **better engagement** while maintaining the same multiplayer benefits. Players see exactly what they're getting in real-time, making harvesting more rewarding and transparent.

**Key takeaway**: Harvesting now feels like opening loot boxes in real-time! 🎁

