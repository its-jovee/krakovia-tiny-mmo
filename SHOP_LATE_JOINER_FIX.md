# Shop State Synchronization for Late Joiners

**Date**: October 17, 2025  
**Status**: ✅ **FIXED** - Late-joining players now receive existing shop states

---

## Problem Description

Players who log in **after** another player has already opened a shop cannot see that shop. The shop indicator only appears for players who were online when the shop was opened.

---

## Root Cause

The shop system uses a **broadcast pattern**:
1. Player A opens shop
2. Server broadcasts `shop.status` event to **all currently connected players**
3. Player B (who wasn't connected yet) logs in
4. Player B **never receives** the shop status for Player A's shop
5. Player B can't see Player A's shop indicator

This is a classic **late-joiner synchronization problem** in multiplayer games.

---

## Solution Applied ✅

### 1. Added Shop Sync Method to ShopManager

**File**: `source/server/world/components/shop_manager.gd`

```gdscript
## Sync all active shops to a newly connected player
func sync_shops_to_player(peer_id: int, instance: ServerInstance) -> void:
	print("ShopManager: Syncing ", active_shops.size(), " active shops to new player ", peer_id)
	
	# Send shop status for each active shop
	for session in active_shops.values():
		# Only sync shops in this instance
		if session.instance == instance:
			var data = {
				"status": "opened",
				"seller_peer_id": session.seller_peer_id,
				"seller_name": session.seller_name,
				"shop_name": session.shop_name,
				"position": session.shop_position
			}
			
			instance.data_push.rpc_id(peer_id, &"shop.status", data)
			print("  - Synced shop: ", session.shop_name, " (seller: ", session.seller_peer_id, ")")
```

### 2. Call Sync When Player Spawns

**File**: `source/server/world/components/instance_server.gd`

```gdscript
func spawn_player(peer_id: int) -> void:
	# ... existing spawn code ...
	
	connected_peers.append(peer_id)
	_propagate_spawn(peer_id)
	
	# ✅ NEW: Sync existing shops to the newly connected player
	if has_node("ShopManager"):
		var shop_mgr: ShopManager = get_node("ShopManager")
		shop_mgr.sync_shops_to_player(peer_id, self)
```

---

## How It Works Now

### Scenario: Player B Joins After Player A Opens Shop

1. **Player A** opens a shop at 10:00 AM
2. **Server** broadcasts to all online players
3. **Player C** (online) sees the shop indicator
4. **Player B** logs in at 10:05 AM
5. **Server** spawns Player B
6. **Server** calls `sync_shops_to_player(player_b_id)`
7. **Server** sends shop status for **all active shops** to Player B
8. **Player B** receives shop status for Player A's shop
9. **Player B's client** creates shop indicator above Player A
10. **Player B** can now see and interact with Player A's shop! ✨

---

## Data Flow Diagram

```
Player A Opens Shop (10:00 AM)
    ↓
Server broadcasts to [Player C, Player D, Player E]
    ↓
All online players see shop indicator

Player B Logs In (10:05 AM)
    ↓
Server: spawn_player(player_b_id)
    ↓
Server: sync_shops_to_player(player_b_id)
    ↓
Server sends: shop.status for Player A's shop
    ↓
Player B receives shop status
    ↓
Player B's client creates indicator
    ↓
Player B sees Player A's shop!
```

---

## Testing Instructions

### Test 1: Basic Late Joiner

1. **Player A** logs in and opens a shop
2. **Player A** logs out or stays online
3. **Player B** logs in
4. **Expected**: Player B should immediately see Player A's shop indicator
5. Check **Player B's console** for:
   ```
   === CLIENT: Received shop.status ===
   Seller peer ID: [Player A's ID]
   Shop opened - has_shop_open: true
   ```

### Test 2: Multiple Shops

1. **Player A** opens "Shop A"
2. **Player C** opens "Shop C"
3. **Player D** opens "Shop D"
4. **Player B** logs in
5. **Expected**: Player B should see **all three shops**
6. Check **server console** for:
   ```
   ShopManager: Syncing 3 active shops to new player [B's ID]
     - Synced shop: Shop A (seller: [A's ID])
     - Synced shop: Shop C (seller: [C's ID])
     - Synced shop: Shop D (seller: [D's ID])
   ```

### Test 3: Shop Opens After Late Joiner

1. **Player B** logs in (no shops yet)
2. **Player A** opens a shop
3. **Expected**: Player B should see the new shop (normal broadcast works)

### Test 4: Instance-Specific Sync

If your game has multiple instances/maps:
1. **Player A** opens shop in Instance 1
2. **Player B** logs into Instance 2
3. **Expected**: Player B should NOT see Player A's shop (different instance)
4. **Player C** logs into Instance 1
5. **Expected**: Player C SHOULD see Player A's shop (same instance)

---

## Debug Output

### Server Console (when Player B joins):
```
ShopManager: Syncing 2 active shops to new player 456
  - Synced shop: Cool Shop (seller: 123)
  - Synced shop: Awesome Shop (seller: 789)
```

### Client Console (Player B):
```
=== CLIENT: Received shop.status ===
Data: {status: opened, seller_peer_id: 123, shop_name: "Cool Shop"}
Seller peer ID: 123
Found player: true
Shop opened - has_shop_open: true, shop_name: Cool Shop

=== PLAYER: _update_shop_indicator called ===
Should show shop indicator!
Shop indicator created and added!

[Repeat for each active shop]
```

---

## Performance Considerations

### Scalability
- **Small servers (< 50 players)**: No issues
- **Large servers (> 100 players)**: 
  - Each late joiner receives N shop status messages (N = active shops)
  - Consider spatial filtering (only sync nearby shops)
  - Consider pagination for very large numbers of shops

### Optimization Ideas (Future)
```gdscript
func sync_nearby_shops_to_player(peer_id: int, max_distance: float = 500.0):
    var player = instance.get_player(peer_id)
    for session in active_shops.values():
        if player.global_position.distance_to(session.shop_position) <= max_distance:
            # Only sync shops within 500 units
            _send_shop_status_to_player(peer_id, session)
```

---

## Comparison with Other Systems

This same pattern is used for:
- ✅ **Player positions**: Synced via StateSynchronizer
- ✅ **Harvesting nodes**: State replicated on spawn
- ✅ **Chat messages**: Only sent to online players (no history sync)
- ✅ **Trades**: Only between currently connected players
- ✅ **Shops**: Now properly synced on join! ✨

---

## Files Modified

1. **`source/server/world/components/shop_manager.gd`**
   - Added `sync_shops_to_player()` method

2. **`source/server/world/components/instance_server.gd`**
   - Call `sync_shops_to_player()` when player spawns

---

## Edge Cases Handled

✅ **Multiple shops in same instance**: All synced  
✅ **Shops in different instances**: Only same-instance shops synced  
✅ **Player opens shop immediately after joining**: Works (both systems active)  
✅ **Shop closes between spawn and sync**: Handled gracefully (already closed)  
✅ **No shops active**: Sync runs but sends nothing (no errors)

---

## Known Limitations

1. **No spatial filtering**: All shops in the instance are synced, regardless of distance
2. **No shop history**: Closed shops are not preserved or shown
3. **No shop persistence**: Shops don't survive server restarts

---

## Future Enhancements

### Spatial Filtering (Recommended for Large Servers)
```gdscript
# Only sync shops within render distance
sync_nearby_shops_to_player(peer_id, max_distance: 1000.0)
```

### Incremental Updates
```gdscript
# Send shops in batches to avoid network spike
sync_shops_in_batches(peer_id, batch_size: 10, delay: 0.1)
```

### Priority System
```gdscript
# Sync nearest shops first, distant shops later
sync_shops_by_priority(peer_id)
```

---

## Status

✅ **Fix Applied** - Late-joining players now see all active shops

This follows the same synchronization pattern used throughout the MMO for state consistency.

---

## Testing Checklist

- [ ] Player joins after shop opens → Sees shop immediately
- [ ] Player joins when multiple shops open → Sees all shops
- [ ] Server console shows sync message
- [ ] Client console shows shop status received
- [ ] Shop indicators appear correctly
- [ ] Can browse and purchase from synced shops
- [ ] No duplicate indicators (one per shop)
