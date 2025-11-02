# Setting Up Head Sprites for Composite System

## The Problem

The head sprites need **SpriteFrames** resources with the same animations as the base body, even though the head itself doesn't animate much. This ensures frame-by-frame synchronization.

## Quick Setup Guide

### Step 1: Create Head SpriteFrames

For each head variant (`head_a`, `head_b`, `head_c`, `head_d`), you need to create a `.tres` file at:

```
source/common/gameplay/characters/sprite_frames/composite/{class}/head/{head_id}.tres
```

### Step 2: Define Required Animations

Each head SpriteFrames must have these animations:
- `idle`
- `run`
- `harvest`
- `sit`

**Important:** Even if your head is a static image, you still need to create all 4 animations!

### Step 3: How to Set It Up in Godot Editor

#### Option A: Create from Scratch

1. In FileSystem, navigate to `source/common/gameplay/characters/sprite_frames/composite/miner/head/`
2. Right-click → Create New → Resource
3. Search for and select **SpriteFrames**
4. Save as `head_a.tres`
5. Double-click the resource to edit it
6. In the SpriteFrames editor:
   - Click "Add Animation" 4 times
   - Rename them to: `idle`, `run`, `harvest`, `sit`
   - For each animation:
     - Click it
     - Drag your head PNG into the frames area
     - If the head doesn't move during that animation, just add 1 frame
     - If it does move, add multiple frames
   - Set FPS to match base animations (usually 8-12 FPS)

#### Option B: Duplicate Base and Modify (Faster!)

1. Find the base character SpriteFrames: `source/common/gameplay/characters/sprite_frames/composite/miner/base/miner.tres`
2. Right-click → Duplicate
3. Move it to `source/common/gameplay/characters/sprite_frames/composite/miner/head/head_a.tres`
4. Open it in the editor
5. For each animation (`idle`, `run`, `harvest`, `sit`):
   - Delete all the existing body frames
   - Add your head image frame(s)
   - If the head doesn't move much, you can use just 1 frame repeated

### Step 4: Frame Synchronization Tips

For best results:
- **Same frame count as body:** If the body's `idle` has 4 frames, the head's `idle` should have 4 frames too
- **Static heads:** If your head doesn't animate, just repeat the same head PNG for all frames
- **Bobbing heads:** If you want the head to bob with the body, create slight variations in Y position

### Example: Simple Static Head Setup

For a head that doesn't move at all:

1. Create `head_a.tres` with 4 animations
2. For `idle` animation (body has 4 frames):
   - Add the same head PNG 4 times
3. For `run` animation (body has 8 frames):
   - Add the same head PNG 8 times
4. Repeat for `harvest` and `sit`

### Step 5: Verify Setup

Run the game. You should see:
- Character body animating
- Head rendering on top
- No error messages about missing animations
- Head staying synchronized with body movement

## Quick Checklist

- [ ] Created folder: `sprite_frames/composite/miner/head/`
- [ ] Created `head_a.tres`, `head_b.tres`, `head_c.tres`, `head_d.tres`
- [ ] Each .tres has animations: `idle`, `run`, `harvest`, `sit`
- [ ] Each animation has at least 1 frame
- [ ] Frame count matches base sprite (or is at least 1)
- [ ] FPS is set (8-12 typically)

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| "There is no animation with name 'idle'" | SpriteFrames missing animation | Add all 4 animations to the .tres file |
| "Head sprite frames not found" | File in wrong location or wrong name | Check path exactly matches: `sprite_frames/composite/{class}/head/{id}.tres` |
| "character_class is empty" | Character not initialized | Fixed in latest code update |
| Head not visible | No frames in animation | Add at least 1 frame to each animation |

## Base Sprite Setup

Don't forget you also need:
```
source/common/gameplay/characters/sprite_frames/composite/miner/base/miner.tres
```

This should contain the full body animations. You might already have this from your existing character sprites - just copy/move it to the new location!

