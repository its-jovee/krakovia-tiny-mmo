# Harvesting Progress Bar Fix

## Problem
The harvesting progress bar was tracking item distribution (when items were actually received) instead of tracking harvest attempts (the completion of each harvest cycle). This meant:
- Progress bar only filled once and never reset
- Players didn't see visual feedback for failed harvest attempts (RNG misses)
- Progress bar duration didn't match the actual harvest cycle time

## Solution

### 1. Server-Side Changes (`harvest_node.gd`)
Added `harvest.tick` event that fires **for each individual RNG roll attempt**:

```gdscript
for _i in range(harvest_count):
    # Send harvest.tick for EACH individual roll attempt
    if instance_tick != null:
        instance_tick.data_push.rpc_id(pid, &"harvest.tick", {
            "node": String(get_path()),
        })
    
    var rolled_loot: Dictionary
    if loot_table != null:
        rolled_loot = loot_table.roll_loot()
```

**Key Fix**: Previously sent one tick per `harvest_pool >= 1.0`, but if multiple harvests accumulated (e.g., `harvest_count = 3`), only one progress bar cycle would show for three RNG rolls. Now sends one tick per roll.

### 2. Client-Side Changes

#### `instance_client.gd`
- Added subscription to `harvest.tick` event
- Removed progress bar reset from `harvest.distribution` (items received)
- Now resets on `harvest.tick` (harvest attempt completed)

#### `HarvestingPanel.gd`
- Renamed `on_item_drop()` → `on_harvest_tick()` to better reflect purpose
- Changed from fixed duration to **adaptive timing learned from server**
- Progress bar duration is measured from actual time between `harvest.tick` events
- Uses exponential moving average to smooth out network jitter

**How Adaptive Timing Works:**
```gdscript
func on_harvest_tick():
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Learn duration from time between ticks
    if harvest_last_tick_time > 0.0:
        var measured_duration = current_time - harvest_last_tick_time
        harvest_tick_duration = lerp(harvest_tick_duration, measured_duration, 0.3)
    
    harvest_start_time = current_time
    harvest_last_tick_time = current_time
```

**Benefits:**
- No need to know server's `base_yield_per_sec` configuration
- Automatically adapts to any node type (T1-T6)
- Handles multiplier changes smoothly
- Compensates for network latency variations

### 3. How It Works Now

**Harvest Cycle:**
1. Every second (server tick), players accumulate harvest_pool based on `base_yield_per_sec * multiplier`
2. When `harvest_pool >= 1.0`, server sends `harvest.tick` to client
3. Client resets progress bar to 0% and starts filling again
4. Server rolls loot (weighted RNG) - may or may not give items
5. If items are received, popup notification shows
6. Progress bar continues filling regardless of item success/failure

**Visual Feedback:**
- ✅ Progress bar fills = harvest attempt in progress
- ✅ Progress bar completes = harvest attempt finished (loot rolled)
- ✅ Popup appears = items successfully received from RNG
- ✅ No popup = RNG miss (but progress bar still resets)

**Multiplier Impact:**
- More players = faster progress bar (higher multiplier)
- Fewer players = slower progress bar (lower multiplier)
- Progress bar duration dynamically adjusts as players join/leave

## Benefits
- Players now see consistent feedback for every harvest cycle
- Progress bar resets properly on every attempt (not just successes)
- Duration accurately reflects current multiplier
- Clear distinction between "harvest attempt" and "item received"
- Better understanding of weighted loot system (not every attempt gives items)

## T5/T6 Node Fix (Multiple Rolls Issue)

### Problem Discovered
On higher tier nodes with slower yield rates, the `harvest_pool` could accumulate multiple harvests (e.g., 2.5 → harvest_count = 2) before draining. This caused:
- Server performs 2 RNG rolls
- Client only sees 1 progress bar cycle
- Player sees bar fill once, gets nothing (roll 1 failed), then gets item (roll 2 succeeded)
- Feels "laggy" or "desynced"

### Solution
Moved `harvest.tick` event **inside the roll loop** so it fires once per individual RNG attempt:
```gdscript
for _i in range(harvest_count):  // Could be 1, 2, 3+ rolls
    send harvest.tick  // ← One tick per roll!
    roll_loot()
```

Now if 3 harvests accumulated, player sees 3 fast progress bar cycles (even if yield rate is slow), maintaining the "fast RNG attempt" visual feedback.

## Testing Checklist
- [ ] Progress bar fills smoothly over calculated duration
- [ ] Progress bar resets when harvest attempt completes
- [ ] Progress bar resets even when no items are received (RNG miss)
- [ ] Duration changes when players join/leave (multiplier changes)
- [ ] **T5/T6 nodes**: Multiple fast cycles when harvest_pool > 1.0
- [ ] **T5/T6 nodes**: Each RNG roll gets its own progress bar cycle
- [ ] Popup notifications still appear when items are received
- [ ] No popup when RNG fails (as expected)
