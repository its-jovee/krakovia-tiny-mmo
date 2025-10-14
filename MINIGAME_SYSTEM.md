# Minigame System - Horse Racing

## Overview
The minigame system allows players to participate in server-wide mini-games. The first implemented game is **Horse Racing**, a betting game where players wager gold on horses and winners receive proportional payouts.

## Features

### Horse Racing Game
- **Max Players**: 12 players per game
- **Betting Phase**: 60 seconds to place bets and get ready
- **Race Duration**: 30 seconds with smooth animation
- **Prize Distribution**: 
  - 70% of total pot goes to 1st place winners (proportional to bet amount)
  - 30% of total pot goes to 2nd place winners (proportional to bet amount)
  - Losers forfeit their bets

### Game Flow
1. **Invitation**: Every 15 minutes, server broadcasts a game invitation to all players
2. **Join**: Players can join using `/join` command or clicking "Join Game" button in popup
3. **Betting**: Players select a horse (1-5) and enter bet amount
4. **Ready**: Players click "Ready" when satisfied with their bet
5. **Race**: After timer expires or all ready, race begins (30 seconds)
6. **Results**: Winners receive proportional gold from the pot

## Commands

### Player Commands
- `/join` - Join the most recent active minigame

### Admin Commands
- `/startgame [game_type]` - Manually trigger a game invitation (default: horse_racing)

## Testing

### Quick Test Setup
1. Start the server with admin privileges (use `/selfadmin` in debug mode)
2. Use `/startgame` to trigger an immediate game invitation
3. Use `/join` to join the game
4. Use `/setgold @yourname 1000` to give yourself testing gold
5. Select a horse and place a bet
6. Click "Ready" to start the race

### Multi-Player Testing
1. Connect multiple clients
2. Admin uses `/startgame` to trigger invitation
3. All test players use `/join`
4. Each player bets on different horses
5. Test various scenarios:
   - All players ready early
   - Some players leave during betting
   - Players disconnect during race (bet is forfeit)
   - Multiple players bet on same winning horse

## Technical Details

### Server Components
- `MinigameManager` - Manages game sessions and invitations
- `HorseRacingGame` - Handles horse racing game logic
- Data Request Handlers:
  - `minigame.join.gd` - Join game session
  - `minigame.bet.gd` - Place bet
  - `minigame.ready.gd` - Toggle ready status
  - `minigame.leave.gd` - Leave game session

### Client Components
- `InvitationPopup` - Shows game invitation with join/dismiss buttons
- `HorseRacingUI` - Main game interface with three phases:
  - Betting Phase: Select horse, enter bet, ready up
  - Racing Phase: Watch animated race progress
  - Results Phase: View winners and earnings

### Network Events
- `minigame.invitation` - Server broadcasts invitation to all players
- `minigame.state` - Updates game state (participants, bets, timer)
- `minigame.race_update` - Sends horse positions during race
- `minigame.results` - Final results and winnings distribution

## Configuration

### Timing Settings (in `minigame_manager.gd`)
```gdscript
const INVITATION_INTERVAL: float = 900.0  # 15 minutes
const INVITATION_DURATION: float = 30.0   # Join window
```

### Game Settings (in `horse_racing_game.gd`)
```gdscript
const MAX_PLAYERS: int = 12
const BETTING_DURATION: float = 60.0
const RACE_DURATION: float = 30.0
const NUM_HORSES: int = 5
```

## Future Extensions

The system is designed to support additional minigames:
- Hot Potato
- Wheel of Fortune
- Dice Games
- Card Games

To add a new game:
1. Create game class extending Node in `source/server/world/components/minigames/`
2. Add game type to `available_games` array in MinigameManager
3. Update `create_game_session()` to handle new game type
4. Create corresponding UI in `source/client/ui/minigame/`
5. Add data request handlers as needed

## Known Limitations
- Only one game session can be active at a time per game type
- Player must have sufficient gold before betting
- Disconnected players automatically forfeit their bets
- Race outcome is purely random (not skill-based)

## Troubleshooting

### Game invitation not appearing
- Check MinigameManager is loaded: Server console should show "[MinigameManager] Started with 15 minute invitation interval"
- Verify timer is running correctly
- Use `/startgame` to manually trigger

### Cannot join game
- Check max player limit (12)
- Verify game is still in betting phase
- Ensure no previous join attempt is pending

### Bet not accepted
- Verify player has sufficient gold
- Check bet amount is valid (> 0)
- Ensure horse_id is valid (0-4)

### UI not showing
- Verify UI nodes are properly added to scene tree
- Check InstanceClient subscriptions are active
- Look for errors in client console

