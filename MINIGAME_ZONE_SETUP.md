# Minigame Zone Setup Guide

## Overview
Minigame invitations now use a location-based system. Only players inside designated **Minigame Zones** receive the popup invitation. Other players see a chat announcement directing them to the zone.

## How It Works

### Timeline
1. **T-1 minute**: Server-wide announcement: *"🎮 Horse Racing starting in 1 minute at the Game Arena! Hurry over to join!"*
2. **T-0**: Game starts
   - Players **inside the zone** receive a popup with the "Join" button
   - All players see: *"🎮 Horse Racing has begun! Players in the Game Arena can /join now!"*
   - Players outside the zone can type `/join` if they reach the zone in time

### Benefits
- Creates a physical gathering point for social interaction
- Encourages exploration of the map
- Makes minigames feel like in-world events
- Players can choose to travel to participate

## Adding a Minigame Zone to Your Map

### Option 1: Instance the Scene (Recommended)
1. Open your map scene (e.g., `source/server/world/maps/overworld.tscn`)
2. Right-click in the Scene tree → **Instance Child Scene**
3. Select `source/server/world/components/minigames/minigame_zone.tscn`
4. Position it where you want players to gather
5. Adjust the `CollisionShape2D` size to fit your desired area

### Option 2: Create Manually
1. Add an `Area2D` node to your map
2. Attach the script: `res://source/server/world/components/minigames/minigame_zone.gd`
3. Add a `CollisionShape2D` child (use `RectangleShape2D` or `CircleShape2D`)
4. Configure the Area2D:
   - **Collision Layer**: 0 (no layer)
   - **Collision Mask**: 1 (player layer)

### Configuration
In the Inspector, you can set:
- **Zone Name**: Display name for the zone (e.g., "Game Arena", "Casino", "Colosseum")
- **Minigame Manager Path**: (Optional) Leave empty for auto-detection

## Multiple Zones
You can have multiple minigame zones across different maps. Players in **any** registered zone will receive the popup. This allows you to:
- Place zones in multiple towns
- Create themed areas for specific games
- Distribute gathering points across the world

## Player Detection
The zone automatically:
- Tracks players entering/exiting via `body_entered`/`body_exited` signals
- Registers itself with the `MinigameManager` on `_ready()`
- Reports which players are inside when invitations are sent

## Testing
To test the zone:
1. Add a `MinigameZone` to a map
2. Start the server
3. Position your player **outside** the zone
4. Run `/startgame` command
5. You should see only the chat message, not the popup
6. Walk into the zone
7. Run `/startgame` again
8. You should now see the popup invitation

## Technical Details

### Server-Side Flow
```gdscript
# When invitation timer fires
MinigameManager.send_game_invitation("horse_racing")
  ├─> Sends chat announcement to ALL players
  ├─> Waits 60 seconds (PRE_START_DELAY)
  ├─> Gets list of players in registered zones
  ├─> Sends popup RPC ONLY to those players
  └─> Sends final chat message to ALL players
```

### Zone Registration
```gdscript
# On zone ready
MinigameZone._ready()
  └─> minigame_manager.register_minigame_zone(self)

# On zone removal
MinigameZone._exit_tree()
  └─> minigame_manager.unregister_minigame_zone(self)
```

## Future Enhancements
- Different zones for different game types
- Zone capacity limits
- Visual indicators (particles, lights) when a game is starting
- Teleport option for VIP players
- Zone-specific leaderboards

