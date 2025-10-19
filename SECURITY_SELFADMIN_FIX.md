# 🚨 CRITICAL: /selfadmin Security Vulnerability Fixed

## The Vulnerability

**Any player could use `/selfadmin` to grant themselves senior admin privileges on the production server!**

### Root Cause

The export configuration had:
```
dedicated_server=false
custom_features=""
```

This caused the server to be exported in a mode where the "debug" check passed, enabling the `/selfadmin` command for all players.

## The Fix

### 1. Export Configuration Updated (`export_presets.cfg`)

**Before:**
```properties
dedicated_server=false
custom_features=""
```

**After:**
```properties
dedicated_server=true
custom_features="production"
```

### 2. Code Hardening (`instance_manager.gd`)

Added explicit production check and warning:

```gdscript
# SECURITY: Only enable /selfadmin in development (editor/debug mode), never in production
if (OS.has_feature("debug") or OS.has_feature("editor")) and not OS.has_feature("production"):
    ServerInstance.global_chat_commands["/selfadmin"] = load("res://source/server/world/components/chat_command/selfadmin_command.gd").new()
    ServerInstance.global_role_definitions["default"]["commands"].append("/selfadmin")
    print("[SECURITY WARNING] /selfadmin command is ENABLED - this should only happen in development!")
```

## Deployment Steps (URGENT)

### Step 1: Re-export the Server

In Godot Editor:
1. Open project
2. Go to **Project → Export**
3. Select "Server-Linux" preset
4. Verify settings:
   - ✅ `dedicated_server = true`
   - ✅ `custom_features = "production"`
5. Click **Export Project** (use RELEASE mode, not debug)
6. Export to: `builds/server/kraftovia.server.0.4.x86_64`

### Step 2: Deploy to Linux VM

```bash
# 1. Stop the current server
sudo systemctl stop krakovia-server  # or kill the process

# 2. Backup the current binary
cp kraftovia.server.0.4.x86_64 kraftovia.server.0.4.x86_64.BACKUP

# 3. Upload the new binary from builds/server/
scp builds/server/kraftovia.server.0.4.x86_64 user@your-vm:/path/to/server/

# 4. Set permissions
chmod +x kraftovia.server.0.4.x86_64

# 5. Restart the server
sudo systemctl start krakovia-server

# 6. Verify /selfadmin is disabled
# Try typing /selfadmin in-game - it should say "Unknown command"
```

### Step 3: Verify the Fix

**Test 1: Check server logs**
```bash
# Look for this line - it should NOT appear:
grep "SECURITY WARNING.*selfadmin" server.log

# If you see the warning, something went wrong!
```

**Test 2: In-game test**
```
1. Login as a regular player
2. Type: /selfadmin
3. Expected result: "Unknown command" or similar error
4. If it says "Yes admin" - THE FIX FAILED!
```

**Test 3: Check features**
```bash
# Add this temporary debug line to your server startup
# to verify features:
./kraftovia.server.0.4.x86_64 --features

# Should NOT see: "debug" or "editor"
# Should see: "production"
```

## Additional Security Measures

### 1. Revoke All Existing Admin Privileges

If players used `/selfadmin` before the fix, they still have admin powers! Clean them:

```bash
# Option A: Reset the database (see database cleaning guide)
rm classic.tres
rm hardcore.tres

# Option B: Manual edit (remove server_roles from player data)
nano classic.tres
# Find and remove lines like: server_roles = { "senior_admin": {} }
```

### 2. Monitor for Suspicious Admin Activity

Check server logs for admin command usage:
```bash
grep -E "/ban|/kick|/setgold|/setlevel" server.log
```

### 3. Change Database Security (Future)

Consider adding password protection to admin accounts in the database so even if someone modifies the file, they need credentials.

## How to Properly Grant Admin Privileges

Since `/selfadmin` is now disabled in production, use **database editing**:

```bash
# 1. Stop server
sudo systemctl stop krakovia-server

# 2. Edit database
nano classic.tres

# 3. Find the player's entry and add:
[sub_resource type="PlayerResource" id="PlayerResource_xyz"]
account_name = "player_handle"
display_name = "Player Name"
server_roles = {
    "senior_admin": {}
}

# 4. Save and restart
sudo systemctl start krakovia-server
```

## Testing in Development

To test admin commands during development:

**Local/Editor Mode:**
- `/selfadmin` works automatically ✅

**Testing Production Build Locally:**
```bash
# Export without "production" feature temporarily
# Or manually grant admin via database edit
```

## Summary

✅ **Fixed:** Export configuration now explicitly sets production mode
✅ **Hardened:** Code now checks for "production" feature and logs warnings
⚠️ **Action Required:** Re-export and redeploy server IMMEDIATELY
⚠️ **Database Cleanup:** Revoke admin from players who used `/selfadmin`

## Questions?

- **Q: Can I keep debug mode for easier admin management?**
  - A: **NO!** This is a critical security vulnerability. Use database editing for admins.

- **Q: How do I know if players already used /selfadmin?**
  - A: Check your database file (`classic.tres`) for `server_roles = { "senior_admin": {} }` entries.

- **Q: What if I need quick admin access on production?**
  - A: Stop the server, edit the database, add admin role, restart. It takes 30 seconds.

---

**Date Fixed:** October 18, 2025
**Severity:** CRITICAL
**Status:** PATCH READY - REQUIRES DEPLOYMENT
