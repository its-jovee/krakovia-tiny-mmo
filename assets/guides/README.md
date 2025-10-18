# Guide GIFs Directory

This directory contains animated GIF files for the in-game guide system.

## Required GIF Files

Place the following GIF files in this directory:

1. **welcome.gif** - Shows basic movement controls (WASD), clicking nodes, opening menus
2. **harvesting.gif** - Shows player clicking harvest node, progress bar filling, items dropping
3. **crafting.gif** - Shows opening crafting menu, selecting recipe, crafting items
4. **trading.gif** - Shows right-clicking player to open trade, adding items, accepting trade
5. **energy.gif** - Shows energy bar depleting during harvesting, minigame participation
6. **shops.gif** - Shows opening shop UI, adding items, toggling shop open, shop indicator above player

## GIF Guidelines

- **Resolution**: 400x200 pixels recommended
- **File Format**: Animated GIF
- **Frame Rate**: 10-15 FPS (keeps file size small)
- **Duration**: 3-5 seconds loop
- **File Size**: Under 2MB per GIF recommended

## Placeholder Behavior

If a GIF file doesn't exist yet, the guide will still work - it just won't display the animation for that page. The text content will still be visible.

## Godot Import Settings

Godot will automatically detect GIF files. Make sure the import settings are:
- **Compress**: Lossless
- **Filter**: Enabled
- **Mipmaps**: Disabled (not needed for UI)
- **Repeat**: Enabled (for looping)
