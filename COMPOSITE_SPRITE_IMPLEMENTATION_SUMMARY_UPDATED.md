# Composite Sprite System - Implementation Summary (UPDATED)

**Date**: November 1, 2025  
**Status**: ✅ Core System Implemented - **Face SpriteFrames Assets Required**

---

## IMPORTANT UPDATE

**Faces are now ANIMATED sprite sheets, not static PNG overlays!**

The system has been updated to use `AnimatedSprite2D` for faces instead of static `Sprite2D` to ensure faces move correctly with body animations (head bobbing during walk, position changes, etc.).

---

## What's Been Implemented

### 1. Core Composite Sprite System ✅

**File**: `source/common/gameplay/characters/composite_sprite.gd`
- CompositeSprite component with 4 sprite layers (Base, Hair, Face, Accessory)
- **Base layer**: Existing animated SpriteFrames (idle/run/harvest/sit)
- **Face layer**: **Animated SpriteFrames** synced frame-by-frame with body
- Hair layer: Prepared but disabled initially
- Accessory layer: Static overlay, prepared but disabled
- Shader support for all layers
- Frame-perfect animation synchronization

### 2. Sprite Registry System ✅

**File**: `source/common/registry/composite_part_registry.gd`
- Static registry cataloging available parts per class
- Current face options: 0, 1, 2, 3 (4 faces per class)
- **Updated**: Face layer now uses `get_animated_spriteframes_path()` instead of `get_static_texture_path()`
- Validation for part IDs and class compatibility

### 3. Data Persistence ✅

**Modified**: `source/common/gameplay/characters/player/player_resource.gd`
- Added `appearance_face_id: String = "0"`
- Added `appearance_hair_id: String = "none"` (disabled)
- Added `appearance_accessory_id: String = "none"` (disabled)
- Network synced on player spawn

### 4. Character System Integration ✅

**Modified**: `source/common/gameplay/characters/character.gd`
- Integrated CompositeSprite with null-safe reference
- Updated animation system to sync face with body
- Backward compatibility maintained

### 5. Character Creation UI ✅

**Modified**: `source/client/gateway/gateway.gd` & `.tscn`
- Face selection with Previous/Next buttons
- Sends face ID with character creation

---

## What's Needed Next

### Required Assets: Face SpriteFrames

You need to create **12 SpriteFrames resources** (not PNG files):

```
source/common/gameplay/characters/sprite_frames/composite/
  ├── miner_face_0.tres    (SpriteFrames with idle/run/harvest/sit)
  ├── miner_face_1.tres    (SpriteFrames with idle/run/harvest/sit)
  ├── miner_face_2.tres    (SpriteFrames with idle/run/harvest/sit)
  ├── miner_face_3.tres    (SpriteFrames with idle/run/harvest/sit)
  ├── forager_face_0.tres  (SpriteFrames with idle/run/harvest/sit)
  ├── forager_face_1.tres  (and so on...)
  ├── forager_face_2.tres
  ├── forager_face_3.tres
  ├── trapper_face_0.tres
  ├── trapper_face_1.tres
  ├── trapper_face_2.tres
  └── trapper_face_3.tres
```

Each SpriteFrames resource must contain:
- **"idle" animation**: X frames (match body idle frame count)
- **"run" animation**: X frames (match body run frame count)
- **"harvest" animation**: X frames (match body harvest frame count)
- **"sit" animation**: X frames (match body sit frame count)

### Why Frame-by-Frame Matters

Looking at your attached sprites, when the character walks:
- Frame 1: Head at position Y=-30
- Frame 2: Head at position Y=-28 (body moves up/down)

A static face overlay at Y=-30 would float incorrectly in frame 2!

**Solution**: Face sprite sheet must have the same frame-by-frame position changes as the body.

---

## Quick Start: Simplest Approach

### Option 1: Duplicate Existing SpriteFrames (Fastest)

1. In Godot File System, find `sprite_frames/miner.tres`
2. **Duplicate** it (Ctrl+D or right-click > Duplicate)
3. **Rename** to `sprite_frames/composite/miner_face_0.tres`
4. Save
5. Repeat for all 12 variants

This reuses your existing animations! The face layer will show the full character (temporarily) until you replace with face-only sprites later.

### Option 2: Create Face-Only Sprite Sheets

See `COMPOSITE_SPRITE_ASSET_GUIDE_UPDATED.md` for detailed instructions on:
- Extracting face regions from body sprites
- Creating frame-matched sprite sheets
- Setting up SpriteFrames resources

---

## How The System Works

### Character Creation Flow

1. Player selects class → `selected_skin` = "miner"
2. Player clicks Previous/Next → `selected_face_index` cycles 0-3
3. Player creates character → Server receives `{"face": "0", "class": "miner"}`
4. Server creates PlayerResource with `appearance_face_id = "0"`

### In-Game Rendering

1. Character spawns with CompositeSprite node
2. CompositeSprite loads:
   - **Base sprite**: `sprite_frames/miner.tres` (existing body animations)
   - **Face sprite**: `sprite_frames/composite/miner_face_0.tres` (NEW - must create)
3. Both layers play "idle" animation, synced
4. When player walks:
   - Base plays "run" animation
   - Face plays "run" animation **at the same time**
   - Both layers stay aligned frame-by-frame
5. Face flips horizontally with character direction

---

## Testing Checklist

### Before Creating Face Assets ⚠️
- [x] Code compiles without errors
- [x] "Could not resolve class Player" error FIXED
- [ ] Create at least one face SpriteFrames (e.g., `miner_face_0.tres`)

### After Creating Face Assets ✅
- [ ] Face sprite sheet loads correctly
- [ ] Face animates with body (idle → run → harvest → sit)
- [ ] Face stays attached during all animations
- [ ] Face flips correctly with character
- [ ] Selected face persists after logout/login
- [ ] Other players see your face

---

## Current Architecture

```
CompositeSprite Node2D
├── BaseSprite (AnimatedSprite2D)      ← Plays miner.tres
├── FaceSprite (AnimatedSprite2D)      ← Plays miner_face_0.tres (NEW)
├── HairSprite (AnimatedSprite2D)      ← Disabled
└── AccessorySprite (Sprite2D)         ← Disabled
```

All `AnimatedSprite2D` layers:
- Share the same `offset = Vector2(0, -30)`
- Share the same `scale = Vector2(0.8, 0.8)`
- Play the same animation name ("idle", "run", etc.)
- Flip together (`flip_h` synced)

---

## Files Modified in This Update

- ✅ `composite_sprite.gd`: Changed face from Sprite2D to AnimatedSprite2D
- ✅ `composite_part_registry.gd`: Updated to handle face as animated layer
- ✅ `character.gd`: Made composite_sprite reference null-safe (fixes class resolution error)

---

## Next Steps

1. **Create Face SpriteFrames** (Priority 1)
   - Option A: Duplicate existing SpriteFrames as placeholder
   - Option B: Create proper face-only sprite sheets
   
2. **Test With One Face** (Priority 2)
   - Create just `miner_face_0.tres`
   - Copy same to `1.tres`, `2.tres`, `3.tres` for testing
   - Verify system works
   
3. **Create All Face Variants** (Priority 3)
   - Make unique faces for each variant
   - Test face selection in character creation

---

**Implementation Status**: Core system ready, waiting for animated face assets ✅  
**Assets Required**: 12 SpriteFrames resources (3 classes × 4 faces each)  
**Each SpriteFrames**: Must contain idle/run/harvest/sit animations matching body  
**Next Action**: Create or duplicate SpriteFrames resources for faces

