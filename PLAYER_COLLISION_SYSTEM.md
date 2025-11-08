# Player Collision System - Hybrid Approach

## Overview

This system implements a hybrid approach to player-to-player collision:
- **Default**: Players can walk through each other (no collision)
- **Minigames**: Body blocking enabled for strategic gameplay

## Problem Solved

Fixed a bug where players could "drag" each other by colliding. This happened because:
1. Local player uses `move_and_slide()` which pushes colliding bodies
2. Remote player positions are authority-synced from server, not physics-driven
3. This created a tug-of-war effect where the local player pushed, but the server kept resetting the remote player's position

## Solution

### Default Behavior (No Collision)
Remote players are configured to be non-solid:
- `collision_layer = 0` - Not on any collision layer
- `collision_mask = 6` - Still collide with world objects/walls, not players
- `velocity = Vector2.ZERO` - Always locked to zero in `_physics_process()`
- `move_and_slide()` - Still called to participate in physics, but with zero velocity
- `is_remote_player = true` - Flag to ensure velocity stays zero

Local player needs to detect remote players when collision is enabled:
- `collision_layer = 1` - On player layer
- `collision_mask = 7` - Can detect players, objects, and walls

**Benefits:**
- ✅ Prevents griefing (blocking doorways, harvest nodes, etc.)
- ✅ Smooth movement in crowded areas (spawns, shops, quest boards)
- ✅ No harvesting interruption when bumped
- ✅ No network latency jank from collision resolution

### Minigame Override (Enable Collision)
For strategic gameplay like Hot Potato, collision can be enabled:

```gdscript
# Enable collision
server_instance.broadcast_player_collision_mode(true)

# Disable collision
server_instance.broadcast_player_collision_mode(false)
```

When enabled:
- `collision_layer = 1` - On player layer
- `collision_mask = 7` - Collides with players, objects, and walls
- Players become solid obstacles for body blocking

## Implementation Files

### Client Side
**`source/client/network/instance_client.gd`**
- Lines 195-203: Configure remote players with no collision by default
- Lines 234-241: RPC handler to toggle collision for all remote players

**`source/client/local_player/local_player.tscn`**
- Line 23: Local player `collision_mask = 7` to detect other players when collision enabled

**`source/common/gameplay/characters/player/player.gd`**
- Lines 34: `is_remote_player` flag for remote players
- Lines 51-56: `_physics_process()` keeps remote player velocity at zero
- Lines 208-224: `set_player_collision_enabled()` method to toggle collision per player

### Server Side
**`source/server/world/components/instance_server.gd`**
- Lines 345-355: Broadcast collision mode to all clients

**`source/server/world/components/minigames/hot_potato_game.gd`**
- Lines 61-65: Enable collision when game starts
- Lines 247-251: Disable collision when game ends
- Lines 439-445: Helper to get ServerInstance reference

## Usage in Minigames

To enable player collision in a minigame:

```gdscript
# In your minigame start logic
var server_instance = _get_server_instance()
if server_instance:
    server_instance.broadcast_player_collision_mode(true)

# In your minigame end logic
if server_instance:
    server_instance.broadcast_player_collision_mode(false)
```

## Collision Layer Reference

- **Layer 1**: Players
- **Layer 2**: Objects (harvest nodes, etc.)
- **Layer 4**: Walls/terrain

**Masks:**
- `6` (binary `110`): Collide with objects + walls
- `7` (binary `111`): Collide with players + objects + walls

## Testing Checklist

- [ ] Players can walk through each other during normal gameplay
- [ ] Players still collide with walls and objects
- [ ] Harvesting is not interrupted by other players walking into you
- [ ] Hot Potato game enables collision when starting
- [ ] Players can body block each other during Hot Potato
- [ ] Collision is disabled when Hot Potato ends
- [ ] No "dragging" effect when players collide

