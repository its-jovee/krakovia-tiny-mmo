Harvest Game Audio Files
========================

The harvest game system expects the following audio files in this directory:

1. beat_tick.wav - Metronome-like tick sound for rhythm beats
   - Short, punchy sound
   - Plays on each beat/window event
   
2. hit_perfect.wav - Satisfying success sound for perfect timing
   - Positive, rewarding sound
   - Should feel impactful
   
3. hit_good.wav - Lighter success sound for good (but not perfect) timing
   - Less impactful than perfect
   - Still positive feedback
   
4. hit_miss.wav - Subtle negative sound for missed timing
   - Not too harsh (players will miss often)
   - Quick, low-key feedback
   
5. sync_bonus.wav - Exciting sound when multiple players hit together
   - More impactful than individual hits
   - Should feel rewarding and special

Notes:
- All files should be .wav format
- Keep files short (under 1 second typically)
- The system gracefully handles missing files (no crash, just no sound)
- Consider adding slight variations for variety

Suggested sources:
- Freesound.org (Creative Commons sounds)
- BFXR (procedural sound generator)
- SFXR (8-bit sound generator)


