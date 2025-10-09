# Admin Commands Guide

## Overview

This multiplayer game now includes a comprehensive admin command system with role-based permissions. Commands allow admins to manage players, items, and moderation tasks.

## How to Make Someone an Admin

Admins are configured via the database to prevent griefing. There are two methods:

### Method 1: Edit Database Files (Production)

Edit the player data resource file:
- `source/server/world/data/classic.tres` (main database)
- `source/server/world/data/hardcore.tres` (hardcore mode)

Find the player's resource and add the role to their `server_roles` field:

```gdscript
server_roles = {
    "senior_admin": {}
}
```

Or for moderator:

```gdscript
server_roles = {
    "moderator": {}
}
```

Save the file and restart the server.

### Method 2: Debug Mode (Development Only)

In debug/editor mode, any player can use `/selfadmin` to grant themselves senior_admin privileges. This command is automatically disabled in production builds.

## Available Commands

### Player Management Commands

#### `/give @handle item_slug quantity`
Give items to a player using item slugs (handles).

**Permission**: senior_admin  
**Examples**:
- `/give @john ore 10` - Give 10 ore to player @john
- `/give @alice copper_ore 5` - Give 5 copper ore to player @alice
- `/give @bob health_potion 3` - Give 3 health potions to player @bob

**Common item slugs**: `ore`, `copper_ore`, `iron_ore`, `coal`, `stone`, `clay`, `health_potion`, `bone`, `wooden_bow.item`, `copper_ring`, `thornmail`

#### `/setgold @handle amount`
Set a player's gold amount.

**Permission**: senior_admin  
**Examples**:
- `/setgold @john 1000` - Set @john's gold to 1000
- `/setgold @alice 500` - Set @alice's gold to 500

#### `/setlevel @handle level`
Set a player's level and award appropriate attribute points.

**Permission**: senior_admin  
**Examples**:
- `/setlevel @john 10` - Set @john to level 10
- `/setlevel @alice 5` - Set @alice to level 5

#### `/tp @target` or `/tp @player1 @player2`
Teleport players.

**Permission**: senior_admin  
**Examples**:
- `/tp @john` - Teleport yourself to @john
- `/tp @alice @bob` - Teleport @alice to @bob's location

### Moderation Commands

#### `/ban @handle [duration] [reason]`
Ban a player from the server.

**Permission**: senior_admin  
**Duration formats**: `30m`, `2h`, `7d`, `1w`, `permanent` (or omit for permanent)  
**Examples**:
- `/ban @griefer permanent Griefing` - Permanently ban @griefer
- `/ban @john 24h Spamming` - Ban @john for 24 hours
- `/ban @alice 7d Harassment` - Ban @alice for 7 days

#### `/mute @handle [duration] [reason]`
Mute a player in chat.

**Permission**: senior_admin, moderator  
**Duration formats**: `30m`, `2h`, `7d`, `1w`, `permanent` (or omit for permanent)  
**Examples**:
- `/mute @spammer 1h Spam` - Mute @spammer for 1 hour
- `/mute @toxic permanent Toxic behavior` - Permanently mute @toxic
- `/mute @john 30m Inappropriate language` - Mute @john for 30 minutes

### Utility Commands

#### `/heal` (existing)
Heal yourself to full health.

**Permission**: senior_admin, moderator

#### `/size` (existing)
Change your character size.

**Permission**: senior_admin, moderator

#### `/set` (existing)
Set arbitrary properties on players.

**Permission**: senior_admin

## Roles and Permissions

### senior_admin
Full access to all commands:
- `/heal`, `/size`, `/set`
- `/give`, `/setgold`, `/setlevel`
- `/ban`, `/mute`, `/tp`

### moderator
Limited moderation powers:
- `/heal`, `/size`
- `/mute`

### default
Regular player commands:
- `/help`, `/getid`, `/trade`

## How It Works

### Ban System
- Banned players are rejected during authentication
- Ban information includes: reason, expiry timestamp, admin who banned
- Bans can be temporary (with duration) or permanent
- Ban data is stored in `WorldPlayerData.banned_players`
- Expired bans are automatically removed on login attempt

### Mute System
- Muted players can connect but cannot send chat messages
- Mute information includes: reason, expiry timestamp, admin who muted
- Mutes can be temporary (with duration) or permanent
- Mute data is stored in `WorldPlayerData.muted_players`
- Expired mutes are automatically removed when trying to chat

### Duration Parsing
The system supports flexible duration formats:
- `30s` or `30sec` = 30 seconds
- `15m` or `15min` = 15 minutes
- `2h` or `2hr` = 2 hours
- `7d` or `7day` = 7 days
- `1w` or `1week` = 1 week
- `permanent` or `perm` or empty = permanent

## Technical Details

### Key Files

**Database**:
- `source/server/world/data/world_player_data.gd` - Ban/mute tracking

**Commands**:
- `source/server/world/components/chat_command/give_command.gd`
- `source/server/world/components/chat_command/setgold_command.gd`
- `source/server/world/components/chat_command/setlevel_command.gd`
- `source/server/world/components/chat_command/ban_command.gd`
- `source/server/world/components/chat_command/mute_command.gd`
- `source/server/world/components/chat_command/tp_command.gd`
- `source/server/world/components/chat_command/admin_utils.gd` - Helper utilities

**Permissions**:
- `source/server/world/components/instance_manager.gd` - Role configuration

**Enforcement**:
- `source/server/world/components/world_server.gd` - Ban check on auth
- `source/server/world/components/data_request_handlers/chat.message.send.gd` - Mute check

### Finding Players

All admin commands that target players use the `@handle` format, which refers to the player's account_name (not display_name). This ensures commands work consistently even if players change their display names.

Examples:
- `@guest1` - Targets the account with handle "guest1"
- `@john_doe` - Targets the account with handle "john_doe"

### Database Persistence

Ban and mute data is automatically saved to the database when applied. The database is also saved when players disconnect to prevent data loss.

## Security Notes

1. **Admin roles are database-only**: You cannot grant admin roles via chat commands (except `/selfadmin` in debug mode), preventing privilege escalation attacks.

2. **All admin actions are logged**: Ban and mute commands record which admin performed the action.

3. **Bans are checked at authentication**: Banned players cannot connect to the server at all.

4. **Mutes are checked per message**: Each chat message is validated against the mute list.

## Troubleshooting

### "Player not found" error
- Ensure you're using the correct @handle (account_name)
- Check that the player is currently online in the same instance
- Verify the player exists in the database

### "Account not found" error (for ban/mute)
- The account doesn't exist in the database
- Check spelling of the account handle
- Use `/getid` to verify player handles

### Ban/mute not persisting
- Ensure the database is being saved properly
- Check file permissions on the database files
- Verify the server has write access to the data directory

## Future Enhancements

Potential additions for the admin system:
- `/unban @handle` - Remove a ban
- `/unmute @handle` - Remove a mute
- `/kick @handle [reason]` - Disconnect player without banning
- `/listbans` - Show all active bans
- `/listmutes` - Show all active mutes
- `/warn @handle [message]` - Send a warning to a player
- Admin action logging to file
- Web-based admin panel

