# 🌍 Localization Files

This directory contains translation files for the Krakovia Tiny MMO game.

## 📁 Files

- **translations.csv** - Master translation file (CSV format)
  - Contains all translatable strings for the game
  - Supports: English (en), Portuguese Brazil (pt_BR)
  - Editable by translators without programming knowledge

- **translations.en.translation** - Compiled English translations (auto-generated)
- **translations.pt_BR.translation** - Compiled Portuguese translations (auto-generated)

## 🔧 How to Add New Translations

### 1. Add to CSV File

Edit `translations.csv` and add a new row:

```csv
translation_key,en,pt_BR
ui_new_button,Click Me,Clique em Mim
```

### 2. Use in Code

```gdscript
# Simple translation
button.text = tr("ui_new_button")

# Dynamic translation with formatting
var message = tr("minigame_winner").format({"player": player_name})

# Using TranslationManager helper
var text = TranslationManager.tr_dynamic("key_name", {"arg": value})
```

### 3. Import Translations

1. Open Godot Editor
2. Go to **Project → Project Settings → Localization → Translations**
3. Click "Reimport" or restart the editor
4. The `.translation` files will be auto-generated from the CSV

## 📝 Translation Key Naming Convention

```
[category]_[context]_[element]
```

**Examples:**
- `ui_inventory_title` - UI text for inventory title
- `error_login_failed_message` - Error message for failed login
- `item_copper_ore_name` - Item name for copper ore
- `minigame_winner_announcement` - Minigame announcement text

## 🌐 Supported Languages

| Language | Code | Status |
|----------|------|--------|
| English | `en` | ✅ Complete |
| Portuguese (Brazil) | `pt_BR` | ✅ Complete |

## 🎯 Translation Guidelines

### Portuguese (Brazil) Style

- **Formal "Você"** for system messages and UI
- **Informal** for flavor text and NPC dialogue
- **Direct and clear** for buttons and labels
- **Consistent terminology** across all text

### Common Terms

| English | Portuguese | Context |
|---------|-----------|---------|
| Handle | Identificador | User account handle |
| Character | Personagem | Game character |
| Inventory | Inventário | Player inventory |
| Crafting | Criação | Item crafting |
| Quest | Missão | Game quests |
| Guild | Guilda | Player guilds |

## 🔍 Finding Missing Translations

Run the validation script to find untranslated strings:

```bash
godot --script res://tools/validate_translations.gd
```

## 📊 Translation Progress

**Phase 1 - Error Messages**: ✅ Complete (180 strings)
- Handle validation errors
- Password validation errors
- Authentication errors
- Network errors
- Character creation errors
- Generic server errors

**Phase 2 - UI Elements**: 🚧 In Progress
- Common buttons and labels
- Menu titles
- Settings UI

**Phase 3 - Game Content**: ⏳ Pending
- Item names and descriptions (278 items)
- Quest text
- Minigame messages
- System messages

## 🤝 Contributing Translations

1. Edit `translations.csv` directly
2. Test translations in-game
3. Report any text overflow or UI issues
4. Maintain consistent terminology
5. Follow the style guidelines

## 🐛 Troubleshooting

**Translations not showing?**
- Ensure `.translation` files are imported by Godot
- Check `project.godot` has correct locale settings
- Verify translation keys match exactly (case-sensitive)

**Text too long for UI?**
- Report in issues with screenshot
- Consider abbreviations or shorter wording
- UI elements use auto-sizing where possible

**Special characters not displaying?**
- Ensure font supports Portuguese accents (á, ã, ç, etc.)
- Check font import settings in Godot

---

**Last Updated**: October 17, 2025  
**Total Strings**: ~180 (Phase 1 complete)  
**Target**: ~1,356 strings across all phases
