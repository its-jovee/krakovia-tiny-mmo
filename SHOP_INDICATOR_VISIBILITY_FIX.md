# Shop Indicator Visibility Fix

**Date**: October 17, 2025  
**Status**: ✅ **FIXED** - peer_id initialization added + debug logging

---

## Problem Description

Other players cannot see shop indicators when someone opens a shop. The shop opens successfully for the seller, but other players in the area don't see the indicator above the seller's character.

---

## Root Cause

The `Player.peer_id` property was not being initialized when players spawn on the client. This caused the shop indicator system to fail because:

1. Server broadcasts `shop.status` with `seller_peer_id`
2. Client finds the player in `players_by_peer_id` dictionary
3. Client sets `player.has_shop_open = true` and `player.shop_name = "Shop Name"`
4. Player's `_update_shop_indicator()` is called
5. Shop indicator is created and `shop_indicator.peer_id = peer_id` is set
6. **BUT** `peer_id` was `-1` (default value), not the actual peer ID!

---

## Fix Applied ✅

### 1. Set peer_id When Spawning Players

**File**: `source/client/network/instance_client.gd`

```gdscript
@rpc("authority", "call_remote", "reliable", 0)
func spawn_player(player_id: int) -> void:
    # ... player instantiation code ...
    
    new_player.name = str(player_id)
    # CRITICAL: Set the peer_id so shop indicators work correctly
    new_player.peer_id = player_id  # ✅ NEW!
    print("Set player.peer_id to: ", new_player.peer_id)
    
    players_by_peer_id[player_id] = new_player
    # ... rest of spawn code ...
```

### 2. Added Comprehensive Debug Logging

**Files Modified**:
- `source/client/network/instance_client.gd` - `_on_shop_status()` function
- `source/common/gameplay/characters/player/player.gd` - `_update_shop_indicator()` function

These debug logs will help diagnose any remaining issues:

```
=== CLIENT: Received shop.status ===
Data: {status: opened, seller_peer_id: 123, shop_name: "My Shop"}
Seller peer ID: 123
Available players: [1, 123, 456]
Found player: true
Player name: 123
Shop opened - has_shop_open: true, shop_name: My Shop

=== PLAYER: _update_shop_indicator called ===
Player name: 123
peer_id: 123
has_shop_open: true
shop_name: My Shop
Should show shop indicator!
Creating new shop indicator...
Shop indicator created and added!
Shop indicator should now be visible!
```

---

## How It Works Now

### When Player A Opens a Shop:

1. **Player A** clicks "Open Shop"
2. **Server** creates shop session via `ShopManager.open_shop()`
3. **Server** broadcasts to ALL players:
   ```gdscript
   data_push.rpc_id(peer_id, &"shop.status", {
       status: "opened",
       seller_peer_id: player_a_id,
       seller_name: "Player A",
       shop_name: "Cool Shop"
   })
   ```

### On Player B's Client:

4. **Client** receives `shop.status` event
5. **Client** finds Player A in `players_by_peer_id[player_a_id]`
6. **Client** sets:
   - `player_a.has_shop_open = true`
   - `player_a.shop_name = "Cool Shop"`
   - `player_a.peer_id = player_a_id` (already set at spawn)
7. **Player A's setter** triggers `_update_shop_indicator()`
8. **Shop indicator** instantiated and positioned above Player A
9. **Shop indicator** becomes visible to Player B! ✨

---

## Testing Instructions

### Test 1: Two Players in Same Area

1. **Player A** opens a shop
2. Check **Player A's console** for:
   ```
   Shop opened - has_shop_open: true, shop_name: My Shop
   ```
3. Check **Player B's console** for:
   ```
   === CLIENT: Received shop.status ===
   Seller peer ID: [Player A's ID]
   Found player: true
   Should show shop indicator!
   Shop indicator should now be visible!
   ```
4. **Player B** should see a shop indicator (🛒) above **Player A**

### Test 2: Multiple Shops

1. **Player A** opens a shop named "Shop A"
2. **Player C** opens a shop named "Shop C"
3. **Player B** should see indicators above both Player A and Player C
4. Each indicator should show the correct shop name

### Test 3: Shop Close

1. **Player A** opens a shop
2. **Player B** sees the indicator
3. **Player A** closes the shop
4. **Player B** should see the indicator disappear
5. Check console for "Shop closed" message

---

## Debug Checklist

If shop indicators still don't appear, check the console for:

### On the Seller's Client:
- [ ] `Shop opened - has_shop_open: true`
- [ ] `Should show shop indicator!`
- [ ] `Shop indicator created and added!`

### On Other Clients:
- [ ] `=== CLIENT: Received shop.status ===`
- [ ] `Found player: true` (if false, player not spawned yet)
- [ ] `=== PLAYER: _update_shop_indicator called ===`
- [ ] `peer_id: [actual number, not -1]`
- [ ] `Should show shop indicator!`

### Common Issues:
- **"Found player: false"**: Player hasn't spawned yet on that client
- **"peer_id: -1"**: Player spawn didn't set peer_id (our fix should prevent this)
- **"Node not ready yet"**: Player not fully initialized (should retry automatically)

---

## Files Modified

1. **`source/client/network/instance_client.gd`**
   - Set `peer_id` when spawning players
   - Added debug logging to `_on_shop_status()`

2. **`source/common/gameplay/characters/player/player.gd`**
   - Added debug logging to `_update_shop_indicator()`

---

## Prevention

To prevent similar issues in the future:

1. ✅ **Always initialize peer_id** when spawning network entities
2. ✅ **Add debug logging** for multiplayer synchronization
3. ✅ **Test with multiple clients** before considering a feature complete
4. ✅ **Use print statements** to trace network event propagation

---

## Additional Notes

### Why This Wasn't Caught Earlier?

The seller (opening their own shop) doesn't see this bug because:
- They directly set their own `has_shop_open` and `shop_name`
- Their `peer_id` is set through other mechanisms (local player)
- The indicator appears correctly for them

But **other players** rely on the network broadcast and proper `peer_id` initialization, which was missing.

### Network Architecture

The shop system uses a **broadcast pattern**:
- Server maintains authoritative shop state
- Server broadcasts changes to ALL connected peers
- Each client updates their local representation
- This ensures all players see consistent shop states

---

## Status

✅ **Fix Applied** - peer_id now initialized + extensive debug logging

Test with two players to confirm shop indicators are now visible to all players in the area!

---

## Cleanup (Optional)

After confirming the fix works, you can **remove the debug print statements** to reduce console spam. Keep the structural changes (peer_id initialization) as they're essential.
