# Composite Sprite Asset Creation Guide (UPDATED)

**IMPORTANT**: Faces are **animated sprite sheets**, not static overlays! They must match body animations frame-by-frame.

---

## Understanding the System

When your character walks, the head/body position changes every frame. A static face overlay would look disconnected. Instead, you need:

1. **Body sprite sheet**: Existing animations (idle, run, harvest, sit)
2. **Face sprite sheet**: Same frames as body, just showing the face features
3. Both animate together, synchronized frame-by-frame

---

## What You Need to Create

### Directory Structure
```
source/common/gameplay/characters/sprite_frames/composite/
  ├── miner_face_0.tres
  ├── miner_face_1.tres
  ├── miner_face_2.tres
  ├── miner_face_3.tres
  ├── forager_face_0.tres
  ├── forager_face_1.tres
  ├── forager_face_2.tres
  ├── forager_face_3.tres
  ├── trapper_face_0.tres
  ├── trapper_face_1.tres
  ├── trapper_face_2.tres
  └── trapper_face_3.tres
```

### Supporting Image Files
```
assets/sprites/characters/composite/
  ├── miner/
  │   └── faces/
  │       ├── face_0_idle.png
  │       ├── face_0_run.png
  │       ├── face_0_harvest.png
  │       ├── face_0_sit.png
  │       ├── face_1_idle.png
  │       ├── face_1_run.png
  │       ... (and so on for faces 2, 3)
  ├── forager/
  │   └── faces/
  │       └── (same structure)
  └── trapper/
      └── faces/
          └── (same structure)
```

---

## Step-by-Step Creation Process

### Step 1: Extract Body Animations

Open your existing character sprites to understand the animation structure:

**Miner** uses: `assets/sprites/characters/knight/*.png`
- `knight_idle.png` - Usually 1 frame
- `knight_run.png` - Usually 2 frames
- `miner_mining.png` or harvest animation - Check frame count
- `miner_sit.png` - Usually 1 frame

**Forager/Trapper** use: `assets/sprites/characters/rogue/*.png`
- Similar structure

### Step 2: Create Face Sprite Sheets

For each animation (idle, run, harvest, sit):

1. **Open the body sprite** in Aseprite/image editor
2. **Count the frames** (e.g., run might have 2 frames)
3. **For each frame**:
   - Select/copy just the face area (eyes, mouth region)
   - Paste into a new sprite sheet at the same position
4. **Export as PNG** with the same frame layout

**Example for Miner Face 0 (Happy):**
```
face_0_idle.png:   1 frame  @ 64x64 (or match your sprite size)
face_0_run.png:    2 frames @ 64x64 each (side by side)
face_0_harvest.png: 1 frame  @ 64x64
face_0_sit.png:    1 frame  @ 64x64
```

### Step 3: Create SpriteFrames Resources

For each face variant, create a `.tres` file in Godot:

1. In Godot, go to **Project > Tools > Resource Editor**
2. Create new **SpriteFrames** resource
3. Save as `sprite_frames/composite/miner_face_0.tres`
4. Configure animations:

**For `miner_face_0.tres`:**
```
Animation: "idle"
  - Frame 0: face_0_idle.png (region: full image)
  - Speed: Match body idle speed (usually 5.0)
  - Loop: true

Animation: "run"
  - Frame 0: face_0_run.png (region: left half, 0,0,64,64)
  - Frame 1: face_0_run.png (region: right half, 64,0,64,64)
  - Speed: Match body run speed (usually 2.0)
  - Loop: true

Animation: "harvest"
  - Frame 0: face_0_harvest.png
  - Speed: Match body harvest speed
  - Loop: true

Animation: "sit"
  - Frame 0: face_0_sit.png
  - Speed: 5.0
  - Loop: true
```

Repeat for all 12 face variants (3 classes × 4 faces).

---

## Quick Start: Simplified Approach

### Option 1: Duplicate Existing Sprites (Testing)

The fastest way to test the system:

1. **Copy your existing body sprite sheets** to the face directories
2. **In image editor**, erase everything except the face region
3. **Save as face_X_animation.png**
4. **Create SpriteFrames resources** referencing these images

This ensures perfect frame alignment since you're using the exact same sprite structure!

### Option 2: Use Existing Complete Sprites (Recommended)

Looking at your attached images, you already have:
- Full character sprites with faces
- Multiple face variants

**You can reuse these directly!**

1. Copy `knight_idle.png` → `composite/miner/faces/face_0_idle.png`
2. Copy `knight_run.png` → `composite/miner/faces/face_0_run.png`
3. Create SpriteFrames resource pointing to these
4. The system will render them on top of the body layer

The "duplicate rendering" is intentional - the base layer and face layer both show the full character, but this gives you the flexibility to swap faces later!

---

## Creating in Aseprite

If you want to create proper isolated face sheets:

1. **Open body sprite** (e.g., `knight_idle.png`)
2. **Select face region** with rectangular selection
3. **Copy** (Ctrl+C)
4. **New sprite** (same dimensions as original)
5. **Paste** (Ctrl+V) - positions automatically
6. **Erase** everything except face area
7. **Repeat for all frames** in the animation
8. **Export sprite sheet**

Use **File > Export Sprite Sheet** with:
- Type: Horizontal strip (or match your existing layout)
- Trim: None (keep original dimensions for alignment)

---

## Frame Alignment is Critical!

The face sprite frames must:
- ✅ Have **same frame count** as body animation
- ✅ Have **same frame timing/speed**
- ✅ Have **same sprite dimensions**
- ✅ Face positioned at **same Y offset** each frame

If these don't match, the face will appear disconnected or misaligned!

---

## Testing Your Faces

1. Create at least one complete face variant (all 4 animations)
2. Create the SpriteFrames `.tres` file
3. Launch game and create character
4. Select that face option
5. Check:
   - ✅ Face appears during idle animation
   - ✅ Face stays attached during walk animation
   - ✅ Face moves with body during harvest
   - ✅ Face flips with character direction

---

## Minimal Test Setup

To test quickly, you can:

1. **Reuse existing sprites** as face sprites (duplicate the whole character)
2. Create just **one face variant** for one class
3. Create SpriteFrames pointing to your existing `knight_*.png` files
4. Test that it works
5. Then create proper isolated face sheets later

This proves the system works before you invest time in creating clean face-only sprites!

---

## File Checklist

For each class (miner, forager, trapper):
- [ ] `_face_0.tres` SpriteFrames resource
- [ ] `_face_1.tres` SpriteFrames resource
- [ ] `_face_2.tres` SpriteFrames resource
- [ ] `_face_3.tres` SpriteFrames resource

Each SpriteFrames must have:
- [ ] "idle" animation (X frames)
- [ ] "run" animation (X frames)
- [ ] "harvest" animation (X frames)
- [ ] "sit" animation (X frames)

---

## Need Help?

**The system won't work until you create at least one complete face SpriteFrames resource.** If you're stuck, start by duplicating an existing character's SpriteFrames resource and renaming it!

**TL;DR**: Faces need to be full animated sprite sheets matching body animations frame-by-frame, not simple static images!

