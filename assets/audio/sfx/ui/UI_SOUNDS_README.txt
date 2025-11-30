UI Sound Effects - Required Files
==================================

The UISoundManager expects the following audio files in this directory.
All files should be short, clean WAV files optimized for instant playback.

Required Files:
---------------

1. click.wav (~50ms)
   - Soft, satisfying button press
   - Light "tick" or "tap" sound
   - Not too clicky/mechanical

2. hover.wav (~30ms)
   - Very subtle hover feedback
   - Quiet, almost subliminal
   - Light tick or soft whoosh

3. open.wav (~150ms)
   - Menu/panel opening
   - Smooth whoosh or expansion sound
   - Rising pitch or expanding feel

4. close.wav (~100ms)
   - Menu/panel closing
   - Reverse of open, contracting feel
   - Falling pitch or soft close

5. success.wav (~200ms)
   - Positive confirmation
   - Pleasant chime or ding
   - Used for crafting success, trades, etc.

6. error.wav (~150ms)
   - Soft denial/error feedback
   - Not harsh or alarming
   - Subtle buzz or low tone

7. select.wav (~80ms)
   - Item/option selected
   - Similar to click but slightly different
   - Could have a slight "lock-in" feel

8. back.wav (~100ms)
   - Going back/cancel action
   - Soft reverse or retreat sound
   - Lighter than close

9. confirm.wav (~120ms)
   - Heavy confirmation (purchases, major actions)
   - More substantial than click
   - Satisfying "ka-chunk" or deep click

Design Guidelines (BOTW-inspired):
----------------------------------
- Clean, modern, minimal sounds
- Not 8-bit/retro - smooth and refined
- Soft attack, quick decay
- Avoid harsh frequencies
- Consistent volume levels across all files
- No reverb/echo (kept dry for flexibility)

Suggested Sources:
------------------
- Freesound.org (CC0/Public Domain)
- BFXR (https://sfxr.me/) - For procedural generation
- SFXR - Classic sound generator
- Soundsnap (commercial)
- Your own recordings/synthesis

Technical Specs:
----------------
- Format: WAV (16-bit or 24-bit)
- Sample Rate: 44100 Hz or 48000 Hz
- Channels: Mono (stereo is OK but wastes space)
- Normalization: -3dB to -6dB peak
- No trailing silence

The system gracefully handles missing files - no errors or crashes,
just no sound will play for that action.

