# 🚀 Quick Start Guide - Internationalization System

**For developers working on the i18n implementation**

---

## 🎯 What We Built (Phase 1)

A complete translation infrastructure supporting **English** and **Brazilian Portuguese** with:
- ✅ Translation management system
- ✅ Event-driven UI updates
- ✅ 198 translated strings (error messages + UI elements)
- ✅ Persistent language preferences
- ✅ Reusable language selector component

---

## 📂 Key Files You'll Use

| File | Purpose |
|------|---------|
| `localization/translations.csv` | **Main translation file** - Add all translatable strings here |
| `source/common/utils/translation_manager.gd` | Singleton for language management |
| `source/common/utils/event_bus.gd` | Global events (language_changed) |
| `source/client/ui/settings/language_selector.gd` | Reusable language selector UI component |

---

## ✍️ How to Add Translations

### 1. Add to CSV File

Open `localization/translations.csv` and add your string:

```csv
keys,en,pt_BR
ui_my_button,Click Here,Clique Aqui
ui_welcome_message,Welcome {player}!,Bem-vindo(a) {player}!
```

### 2. Use in Your Code

**Simple text:**
```gdscript
button.text = tr("ui_my_button")
```

**With formatting:**
```gdscript
label.text = tr("ui_welcome_message").format({"player": player_name})
```

**Using TranslationManager helper:**
```gdscript
var text = TranslationManager.tr_dynamic("ui_welcome_message", {"player": player_name})
```

### 3. Import in Godot

1. Open Godot Editor
2. Project automatically detects CSV changes
3. Translation files regenerate on import

---

## 🔧 Common Tasks

### Change Language Programmatically
```gdscript
TranslationManager.set_language(TranslationManager.Language.PT_BR)
```

### Get Current Language
```gdscript
var current_lang = TranslationManager.get_language()
# Returns: TranslationManager.Language.EN or TranslationManager.Language.PT_BR
```

### Listen to Language Changes
```gdscript
func _ready():
    EventBus.language_changed.connect(_on_language_changed)

func _on_language_changed():
    # Refresh your UI text here
    my_label.text = tr("ui_my_label")
```

### Add Language Selector to UI
```gdscript
# In your scene, add an OptionButton node
# Attach the language_selector.gd script to it
# It automatically populates and handles language switching!
```

---

## 📝 Translation Key Naming Convention

Follow this pattern: `[category]_[context]_[element]`

### Examples:
```csv
# UI Elements
ui_inventory_title
ui_button_confirm
ui_settings_audio_volume

# Error Messages
error_login_failed_title
error_login_failed_message
error_network_timeout_suggestion

# Game Content
item_copper_ore_name
item_copper_ore_description
minigame_horse_racing_winner

# System Messages
system_player_joined_server
system_guild_created
system_trade_completed
```

---

## 🎨 Working with Error Messages

Error messages are **already fully translated**! Just use them:

```gdscript
# Get translated error message
var error_data = ErrorMessages.get_error_message("login_invalid_credentials")

# Returns dictionary with:
# {
#   "title": "Login Failed" or "Falha no Login",
#   "message": "Invalid handle or password..." (translated),
#   "suggestion": "Make sure your handle..." (translated)
# }

# Format for display
var formatted = ErrorMessages.format_error_message(error_data)
popup_label.text = formatted
```

---

## 🧪 Testing Your Translations

### Quick Test in Code
```gdscript
# Test switching languages
TranslationManager.set_language(TranslationManager.Language.EN)
print(tr("ui_button_confirm"))  # Should print "Confirm"

TranslationManager.set_language(TranslationManager.Language.PT_BR)
print(tr("ui_button_confirm"))  # Should print "Confirmar"
```

### Test a Specific Key
```gdscript
TranslationManager.test_translation("error_login_invalid_credentials_title")
# Prints the key in all languages
```

---

## 🐛 Troubleshooting

### Translation not showing?
```gdscript
# Check if translation exists
if TranslationServer.has_translation("your_key_here"):
    print("Translation exists!")
else:
    print("Missing translation key!")
```

### Fallback to English
If a Portuguese translation is missing, the system automatically falls back to English.

### Force Reload Translations
Restart the Godot Editor or reimport the CSV file.

---

## 📊 Next Phase Preview (Phase 2)

You'll be translating:
1. Gateway/Login UI (buttons, labels, messages)
2. Character creation screen
3. Inventory menus
4. Chat interface
5. HUD elements

**Approach:**
1. Find hardcoded strings in `.gd` files
2. Add translation keys to CSV
3. Replace strings with `tr()` calls
4. Test in both languages

---

## 💡 Pro Tips

### 1. Batch Operations
Add multiple related strings at once:
```csv
ui_inventory_title,Inventory,Inventário
ui_inventory_empty,No items,Nenhum item
ui_inventory_full,Inventory full,Inventário cheio
ui_inventory_sort,Sort,Ordenar
```

### 2. Keep Keys Organized
Group by category using comments in CSV:
```csv
# ===== INVENTORY SYSTEM =====
ui_inventory_title,Inventory,Inventário

# ===== CRAFTING SYSTEM =====
ui_crafting_title,Crafting,Criação
```

### 3. Dynamic Content
Use placeholders for variable content:
```csv
system_player_joined,{player} joined the server,{player} entrou no servidor
system_level_up,You reached level {level}!,Você alcançou o nível {level}!
```

---

## 📚 Reference Links

- **Project Scope**: `I18N_PROJECT_SCOPE.md`
- **Phase 1 Summary**: `I18N_PHASE1_COMPLETE.md`
- **Localization Guide**: `localization/README.md`
- **Godot i18n Docs**: https://docs.godotengine.org/en/stable/tutorials/i18n/

---

## ✅ Quick Checklist for New Features

When adding new UI or content:

- [ ] Identify all user-facing text
- [ ] Add translation keys to `localization/translations.csv`
- [ ] Provide English translation
- [ ] Provide Portuguese translation (or mark `[TODO]`)
- [ ] Replace hardcoded strings with `tr()` calls
- [ ] Test in both languages
- [ ] Verify text fits in UI elements

---

**Happy Translating! 🌍**

_Last Updated: October 17, 2025_
