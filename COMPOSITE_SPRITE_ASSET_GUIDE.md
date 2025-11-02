# Composite Sprite Asset Creation Guide

Quick guide for creating face overlay assets for the Composite Sprite System.

---

## Directory Structure to Create

```
assets/sprites/characters/composite/
  ├── miner/
  │   └── face/
  ├── forager/
  │   └── face/
  └── trapper/
      └── face/
```

**PowerShell commands (run from project root):**
```powershell
New-Item -ItemType Directory -Force -Path "assets\sprites\characters\composite\miner\face"
New-Item -ItemType Directory -Force -Path "assets\sprites\characters\composite\forager\face"
New-Item -ItemType Directory -Force -Path "assets\sprites\characters\composite\trapper\face"
```

---

## Face Asset Specifications

### File Requirements
- **Files needed**: 12 total (4 per class)
  - `miner/face/0.png`, `miner/face/1.png`, `miner/face/2.png`, `miner/face/3.png`
  - `forager/face/0.png`, `forager/face/1.png`, `forager/face/2.png`, `forager/face/3.png`
  - `trapper/face/0.png`, `trapper/face/1.png`, `trapper/face/2.png`, `trapper/face/3.png`

### Image Specifications
- **Size**: 64x64 pixels
- **Format**: PNG with alpha transparency
- **Content**: Just the facial features (eyes, mouth, nose, etc.)
- **Background**: Transparent
- **Positioning**: Centered on canvas

### Face Variations
Suggested variations for each class (customize as desired):
1. **Face 0**: Neutral expression
2. **Face 1**: Happy/smiling
3. **Face 2**: Serious/determined
4. **Face 3**: Surprised/excited

---

## Creating Faces from Existing Sprites

### Option 1: Extract from Existing Character Sprites

Your current character sprites are located in:
- `assets/sprites/characters/knight/*.png` (used for miner)
- `assets/sprites/characters/rogue/*.png` (used for forager/trapper)

**Steps in Aseprite (or similar)**:
1. Open the character sprite (e.g., `knight_idle.png`)
2. Identify the face region (typically top portion of character)
3. Select the face area with the rectangular selection tool
4. Copy the selection (Ctrl+C)
5. Create new 64x64 canvas
6. Paste (Ctrl+V) and position centrally
7. Export as PNG
8. Create variations by:
   - Changing mouth shape (smile, frown, neutral)
   - Adjusting eye expressions
   - Adding/removing details

### Option 2: Draw New Faces

If you prefer custom faces:
1. Create a new 64x64 canvas in your image editor
2. Draw simple facial features:
   - Eyes (2-3 pixels high, 6-8 pixels apart)
   - Mouth (3-5 pixels wide)
   - Optional: nose, eyebrows, facial marks
3. Keep it simple and pixelated to match your art style
4. Export as PNG with transparency

### Option 3: Placeholder Faces

For quick testing, you can create simple placeholder faces:
1. Create 64x64 canvas
2. Draw a simple emoji-style face:
   - Face 0: `:)` (two dots for eyes, curved line for mouth)
   - Face 1: `:D` (two dots for eyes, open smile)
   - Face 2: `:|` (two dots for eyes, straight line mouth)
   - Face 3: `:O` (two dots for eyes, open circle mouth)
3. Use bright contrasting colors for visibility

---

## Face Positioning Technical Details

The face sprite will be overlaid on the character using these transform settings:
```gdscript
face_sprite.position = Vector2(0, -30)  # Offset upward
face_sprite.scale = Vector2(0.8, 0.8)   # Match body sprite scale
```

- Position `(0, -30)` places the face sprite 30 pixels above the character origin
- Scale `0.8` matches the body sprite scaling
- The face will flip horizontally when the character flips

**Design Tip**: Create the face assuming it will be displayed at the character's head position. The system will automatically position it correctly.

---

## Testing Your Faces

### In-Game Testing
1. Launch the game
2. Create a new character
3. Select a class (miner/forager/trapper)
4. Click "Previous" / "Next" buttons to cycle faces
5. Create the character
6. Check that the face appears correctly overlaid on the character

### What to Look For
- ✅ Face positioned on character's head
- ✅ Face scales appropriately
- ✅ Face flips with character direction
- ✅ Face doesn't obstruct other features
- ✅ Face is visible against different backgrounds

### Common Issues
- **Face too low/high**: Currently hardcoded at `position.y = -30`, may need adjustment per class
- **Face too large/small**: Currently scaled to `0.8`, adjust face sprite size (64x64) or scale
- **Face not visible**: Check that PNG has non-transparent pixels
- **Wrong face showing**: Verify files are named 0.png, 1.png, 2.png, 3.png (not face0.png, etc.)

---

## Quick Start: Minimal Implementation

To get the system running quickly, you only need **one face per class** initially:

1. Create just `0.png` for each class (3 files total)
2. Copy the same face to `1.png`, `2.png`, `3.png`
3. Test that the system works
4. Replace with unique faces later

**Fastest Method**: Use a colored circle
```
miner/face/0.png    - Red circle with dots for eyes
forager/face/0.png  - Green circle with dots for eyes  
trapper/face/0.png  - Blue circle with dots for eyes
```
Duplicate each as 1.png, 2.png, 3.png.

---

## Example Face Templates

### Simple Pixel Face (Text-Based Guide)
```
. . . . . . . . . .    (64x64 canvas)
. . # # . . # # . .    (# = dark pixel for eyes)
. . # # . . # # . .
. . . . . . . . . .
. . . . . . . . . .    
. . . # # # # . . .    (# = dark pixel for mouth)
. . # . . . . # . .    (curved smile)
. . . . . . . . . .
```

### Aseprite Tips
- Use the **Circle tool** (Shift+Z) for round eyes
- Use the **Curve tool** for mouth shapes
- Use **Onion Skin** to maintain consistency across face variants
- **Palette**: Use your existing character palette for consistency

---

## After Creating Assets

1. **Import to Godot**: Place PNG files in the correct directories
2. **Godot will auto-import**: Wait for import to complete
3. **Test in editor**: Can preview textures in FileSystem panel
4. **Test in game**: Create character and verify face appears

---

## Need Help?

- Faces not appearing? Check `COMPOSITE_SPRITE_IMPLEMENTATION_SUMMARY.md` troubleshooting section
- Want to change face position? Modify `face_sprite.position` in `composite_sprite.gd`
- Want different face options? Update `CompositePartRegistry._initialize()` face arrays

---

**TL;DR**: Create 12 PNG files (64x64, transparent) with simple face drawings, place in `composite/{class}/face/{0-3}.png`, test in game!

