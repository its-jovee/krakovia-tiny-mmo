# Animation Parameter Adjustments

## Changes Made

Updated shader animation parameters based on user feedback to create more expressive breathing and more subtle squash & stretch effects.

### Breathing Animation (Idle & Sitting)
**Previous Values:**
- Intensity: 0.3 (30%)
- Speed: 1.5 Hz (idle), 1.0 Hz (sitting)
- Scale factor: 0.02
- Horizontal compensation: 0.5x

**New Values:**
- Intensity: **0.6 (60%)** - Doubled for more expression
- Speed: **2.5 Hz (idle), 1.8 Hz (sitting)** - Much more frequent
- Scale factor: **0.035** - 75% increase in movement
- Horizontal compensation: **0.3x** - Less horizontal, more vertical focus

**Visual Impact:**
- Characters now breathe **noticeably** even from a distance
- More frequent breathing creates livelier feel
- Vertical emphasis better suits top-down perspective
- Sitting still shows relaxed state (slightly slower)

### Squash & Stretch (Running/Harvesting)
**Previous Values:**
- Intensity: 0.15 (15%)
- Speed: 6.0 Hz
- Vertical range: -15% to +7.5%
- Horizontal range: +15% to -7.5%

**New Values:**
- Intensity: **0.08 (8%)** - Nearly half as intense
- Speed: **5.0 Hz** - Slightly slower, more natural
- Vertical range: **-8% to +2.4%** - More subtle bounce
- Horizontal range: **+1.6% to -1.6%** - Minimal horizontal change

**Visual Impact:**
- Bounce effect is now **fun but not distracting**
- Vertical focus matches top-down/isometric perspective
- Less horizontal deformation = cleaner sprite readability
- Maintains "game feel" without being cartoony

## Parameter Summary Table

| Parameter | Old Value | New Value | Change |
|-----------|-----------|-----------|--------|
| **Breathing Intensity** | 0.3 | 0.6 | +100% |
| **Breathing Speed (Idle)** | 1.5 Hz | 2.5 Hz | +67% |
| **Breathing Speed (Sit)** | 1.0 Hz | 1.8 Hz | +80% |
| **Breathing Scale Factor** | 0.02 | 0.035 | +75% |
| **Breathing H. Compensation** | 0.5x | 0.3x | -40% |
| **Squash Intensity** | 0.15 | 0.08 | -47% |
| **Squash Speed (Run)** | 6.0 Hz | 5.0 Hz | -17% |
| **Squash Vertical Range** | ±15% | ±8% | -47% |
| **Squash Horizontal Range** | ±15% | ±1.6% | -89% |

## Files Updated

1. **character_animation.gdshader**
   - Updated default uniform values
   - Adjusted vertex shader calculations
   - Reduced horizontal deformation in both modes

2. **character_animation_outline.gdshader**
   - Mirrored all changes from base shader
   - Maintains consistency with hover outline

3. **character.gd**
   - Updated `_setup_animation_shader()` default parameters
   - Adjusted breathing speeds in `_update_animation_shader_state()`
   - Sitting: 2.5 → 1.8 Hz (more noticeable difference)

4. **player.gd**
   - Updated `_apply_combined_shader()` parameter copying
   - Ensures hover transitions preserve new values

## Visual Comparison

### Breathing (Idle)
```
OLD: subtle chest rise      (barely noticeable)
NEW: pronounced breathing   (clearly visible)

    ___         _____         ___
   /   \       /     \       /   \
  | o o |  →  |  o o  |  →  | o o |
  |_____|     |_______|     |_____|
    |  |         | |          |  |
  (small)     (bigger)     (small)
```

### Squash & Stretch (Walking)
```
OLD: bouncy, cartoony      (distracting)
NEW: subtle, fun           (polished)

   ___        _____        ___
  /   \      |     |      /   \
 | o o |  →  | o o |  →  | o o |
 |_____|     |_____|     |_____|
   | |         |||         | |
 (tall)     (squash)     (tall)
```

## Design Rationale

### Why More Expressive Breathing?
1. **Readability**: Characters are small on screen in MMO view
2. **Life**: Needs to be visible to convey "aliveness"
3. **Frequency**: Faster = more engaging to watch
4. **Verticality**: Matches game perspective better

### Why More Subtle Squash/Stretch?
1. **Distraction**: Too bouncy pulls focus from gameplay
2. **Realism**: Characters aren't rubber balls
3. **Perspective**: Top-down view emphasizes vertical
4. **Polish**: Subtle = professional, exaggerated = amateur

### Top-Down Perspective Considerations
In isometric/top-down games:
- **Vertical changes** are clearly visible (height changes)
- **Horizontal changes** can distort sprite readability
- **Breathing** should be vertical (chest/shoulders)
- **Bounce** should be vertical (feet contact, height)

## Testing Recommendations

1. **Stand idle near crowd**
   - All characters should breathe visibly
   - Different timing (not synchronized)
   - More noticeable than before

2. **Walk around map**
   - Subtle vertical bounce
   - Doesn't distract from gameplay
   - Feels smooth and polished

3. **Sit down**
   - Breathing slows noticeably
   - Still frequent enough to see
   - Conveys relaxed state

4. **Compare with other players**
   - Hover outline still works perfectly
   - Animations continue during hover
   - No visual glitches or stuttering

## User Feedback Applied

✅ **"Breaths more frequent and expressive"**
- Doubled intensity (0.3 → 0.6)
- Increased speed by 67% (1.5 → 2.5 Hz)
- Enhanced scale factor (0.02 → 0.035)

✅ **"Squash & stretch more subtle"**
- Halved intensity (0.15 → 0.08)
- Reduced bounce effect significantly
- Made it fun but not distracting

✅ **"More vertical than horizontal"**
- Reduced horizontal breathing compensation (0.5x → 0.3x)
- Minimized horizontal squash (±15% → ±1.6%)
- Emphasized vertical deformation

## Performance Impact

**None.** These are just parameter tweaks - no additional computation.

All effects remain GPU-based with zero CPU overhead.

## Future Fine-Tuning

If further adjustments are needed, these are the key values to modify:

**Make breathing MORE expressive:**
```gdscript
breathing_intensity = 0.8  # Even more vertical movement
breathing_speed = 3.0      # Even faster breathing
```

**Make breathing LESS expressive:**
```gdscript
breathing_intensity = 0.4  # Reduce movement
breathing_speed = 2.0      # Slower breathing
```

**Make squash MORE bouncy:**
```gdscript
squash_stretch_intensity = 0.12  # More bounce
squash_stretch_speed = 6.0       # Faster bounce
```

**Make squash LESS visible:**
```gdscript
squash_stretch_intensity = 0.05  # Barely noticeable
squash_stretch_speed = 4.0       # Slower bounce
```

All changes are in real-time - no restarts needed!
