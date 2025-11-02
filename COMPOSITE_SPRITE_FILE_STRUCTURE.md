# Composite Sprite File Structure

**Date**: November 1, 2025  
**Status**: Updated to match organized folder structure

---

## File Organization

### Your Organized Structure ✅

```
source/common/gameplay/characters/sprite_frames/composite/
  ├── miner/
  │   ├── base/
  │   │   └── miner.tres          # Base body animations
  │   ├── head/
  │   │   ├── 0.tres              # Head variant 0
  │   │   ├── 1.tres              # Head variant 1
  │   │   ├── 2.tres              # Head variant 2
  │   │   └── 3.tres              # Head variant 3
  │   ├── hair/                    # For future use
  │   └── accessory/               # For future use
  ├── forager/
  │   ├── base/
  │   │   └── forager.tres
  │   ├── head/
  │   │   ├── 0.tres
  │   │   ├── 1.tres
  │   │   ├── 2.tres
  │   │   └── 3.tres
  │   ├── hair/
  │   └── accessory/
  └── trapper/
      ├── base/
      │   └── trapper.tres
      ├── head/
      │   ├── 0.tres
      │   ├── 1.tres
      │   ├── 2.tres
      │   └── 3.tres
      ├── hair/
      └── accessory/
```

---

## How The System Loads Files

### Base Layer
```gdscript
Path: composite/{class}/base/{class}.tres
Example: composite/miner/base/miner.tres
```
- **Purpose**: Body animations (idle, run, harvest, sit)
- **Type**: SpriteFrames resource
- **Content**: Full character body sprite sheet

### Head Layer
```gdscript
Path: composite/{class}/head/{id}.tres
Example: composite/miner/head/0.tres
```
- **Purpose**: Head/face variations
- **Type**: SpriteFrames resource  
- **Content**: Head sprite sheet matching body animation frames
- **IDs**: "0", "1", "2", "3" (4 variants per class)

### Hair Layer (Future)
```gdscript
Path: composite/{class}/hair/{id}.tres
Example: composite/miner/hair/long.tres
```
- **Currently**: Disabled (empty folder)
- **Future**: Animated hair sprite sheets

### Accessory Layer (Future)
```gdscript
Path: composite/{class}/accessory/{id}.png
Example: composite/miner/accessory/eyepatch.png
```
- **Currently**: Disabled (empty folder)
- **Future**: Static PNG overlays

---

## What You Need to Create

For each class (miner, forager, trapper):

### 1. Base Sprite (Already Have This)
Just move/copy your existing sprite frames:
- `sprite_frames/miner.tres` → `sprite_frames/composite/miner/base/miner.tres`
- `sprite_frames/forager.tres` → `sprite_frames/composite/forager/base/forager.tres`
- `sprite_frames/trapper.tres` → `sprite_frames/composite/trapper/base/trapper.tres`

### 2. Head Sprites (Need to Create - 12 total)
Create 4 head SpriteFrames per class:
- `composite/miner/head/0.tres` through `3.tres`
- `composite/forager/head/0.tres` through `3.tres`
- `composite/trapper/head/0.tres` through `3.tres`

Each head SpriteFrames must contain:
- **idle** animation (X frames - match base)
- **run** animation (X frames - match base)
- **harvest** animation (X frames - match base)
- **sit** animation (X frames - match base)

---

## Quick Start

### Step 1: Move Base Sprites
1. Create the folder structure you showed in the screenshot (already done!)
2. Copy your existing sprite frames into the base folders:
   ```
   miner.tres → composite/miner/base/miner.tres
   forager.tres → composite/forager/base/forager.tres
   trapper.tres → composite/trapper/base/trapper.tres
   ```

### Step 2: Create Head Sprites
**Option A - Quick Test (Duplicate Base)**:
1. Duplicate `composite/miner/base/miner.tres` 4 times
2. Rename to: `composite/miner/head/0.tres`, `1.tres`, `2.tres`, `3.tres`
3. Repeat for forager and trapper

This will show the full character temporarily, but proves the system works!

**Option B - Proper Implementation**:
1. Extract head regions from your sprite sheets
2. Create head-only sprite sheets for each animation
3. Create SpriteFrames resources pointing to these
4. Make each variant unique (different expressions)

---

## Code References

The system automatically builds paths using `CompositePartRegistry`:

```gdscript
# Base: composite/{class}/base/{class}.tres
var base_path = CompositePartRegistry.get_animated_spriteframes_path(
    "miner",
    CompositePartRegistry.Layer.BASE,
    "default"
)
# Returns: "res://...sprite_frames/composite/miner/base/miner.tres"

# Head: composite/{class}/head/{id}.tres
var head_path = CompositePartRegistry.get_animated_spriteframes_path(
    "miner",
    CompositePartRegistry.Layer.HEAD,
    "0"
)
# Returns: "res://...sprite_frames/composite/miner/head/0.tres"
```

---

## Naming Convention Changes

All references updated from "face" to "head":
- ✅ `Layer.HEAD` (was `Layer.FACE`)
- ✅ `appearance_head_id` (was `appearance_face_id`)
- ✅ `:appearance_head` sync field (was `:appearance_face`)
- ✅ `head_sprite` variable (was `face_sprite`)
- ✅ `selected_head_index` (was `selected_face_index`)
- ✅ UI: "HeadSelection" (was "FaceSelection")

---

## Testing

Once you create the head sprites:

1. **Load Game** → Character Creation
2. **Select Class** (miner/forager/trapper)
3. **Click Previous/Next** to cycle through heads (0-3)
4. **Label shows**: "Head: 1" → "Head: 2" → "Head: 3" → "Head: 4"
5. **Create Character**
6. **In-game**: Character should display with selected head overlay

---

## File Paths Summary

| Layer | Location | Filename Pattern | Example |
|-------|----------|------------------|---------|
| Base | `composite/{class}/base/` | `{class}.tres` | `miner/base/miner.tres` |
| Head | `composite/{class}/head/` | `{id}.tres` | `miner/head/0.tres` |
| Hair | `composite/{class}/hair/` | `{id}.tres` | `miner/hair/long.tres` |
| Accessory | `composite/{class}/accessory/` | `{id}.png` | `miner/accessory/eye patch.png` |

---

**Next Step**: Create the 12 head SpriteFrames resources and test!

