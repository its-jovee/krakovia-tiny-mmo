# 🌍 Internationalization (i18n) Project Scope
## Brazilian Portuguese Translation Implementation

**Project**: Krakovia Tiny MMO  
**Target Language**: Portuguese (Brazil) - `pt_BR`  
**Status**: Planning Phase  
**Created**: October 17, 2025  
**Estimated Timeline**: 2-3 weeks (development + translation)

---

## 📊 Executive Summary

This document outlines a comprehensive plan to add Brazilian Portuguese localization to the Krakovia Tiny MMO game. The implementation will use Godot's native Translation system with minimal architectural changes, leveraging existing centralized patterns like `ErrorMessages`.

### Key Objectives
1. ✅ Full Brazilian Portuguese translation of all game text
2. ✅ Language toggle in UI (English ⟷ Portuguese)
3. ✅ Persistent language preference (saved to user settings)
4. ✅ Scalable architecture for future languages
5. ✅ Zero runtime performance impact

---

## 🎯 Scope Breakdown

### Phase 1: Infrastructure Setup ⏱️ 2-3 Days

#### 1.1 Translation System Core
**Files to Create:**
- `source/common/utils/translation_manager.gd` - Central translation management
- `source/common/utils/event_bus.gd` - Event system for language changes (if doesn't exist)
- `localization/translations_base.csv` - Master translation file
- `localization/translations.en.translation` - English translation binary
- `localization/translations.pt_BR.translation` - Portuguese translation binary

**Tasks:**
- [ ] Create `TranslationManager` singleton
- [ ] Implement language switching logic
- [ ] Add persistent settings storage (`user://settings.cfg`)
- [ ] Setup translation CSV structure
- [ ] Configure `project.godot` internationalization settings
- [ ] Create EventBus for `language_changed` signal

**Complexity**: Medium  
**Priority**: Critical Path

---

#### 1.2 Project Configuration
**Files to Modify:**
- `project.godot` - Add internationalization settings

**Configuration:**
```ini
[internationalization]
locale/translations=PackedStringArray(
    "res://localization/translations.en.translation",
    "res://localization/translations.pt_BR.translation"
)
locale/translations_pot_files=PackedStringArray()
locale/test="pt_BR"
```

**Tasks:**
- [ ] Update project settings
- [ ] Register translation files
- [ ] Set default locale to English

**Complexity**: Low  
**Priority**: Critical Path

---

### Phase 2: Error Messages Migration ⏱️ 1-2 Days

#### 2.1 Refactor ErrorMessages System
**Files to Modify:**
- `source/common/utils/error_messages.gd` (298 lines)

**Current Structure:**
```gdscript
const ERROR_MESSAGES: Dictionary = {
    "handle_empty": {
        "title": "Handle Required",
        "message": "Please enter a player handle.",
        "suggestion": "Choose a unique handle..."
    }
}
```

**New Structure:**
```gdscript
static func get_error_message(error_key: String) -> Dictionary:
    return {
        "title": tr("error_" + error_key + "_title"),
        "message": tr("error_" + error_key + "_message"),
        "suggestion": tr("error_" + error_key + "_suggestion")
    }
```

**Estimated Error Messages**: ~60 error types × 3 strings = **~180 translation keys**

**Tasks:**
- [ ] Replace hardcoded strings with `tr()` calls
- [ ] Create CSV entries for all error messages
- [ ] Translate all error messages to Portuguese
- [ ] Test all error scenarios
- [ ] Update `format_error_message()` to use `tr("ui_tip")`

**Complexity**: Medium  
**Priority**: High (Proof of Concept)

---

### Phase 3: UI Components Translation ⏱️ 3-4 Days

#### 3.1 Gateway/Login System
**Files to Modify:**
- `source/client/gateway/gateway.gd` (647 lines)
- `source/client/gateway/gateway.tscn`

**Text Categories:**
- Login/Create Account buttons
- Input field labels (Handle, Password)
- Remember Me checkbox
- Error popups
- Character creation screen
- Validation messages

**Estimated Strings**: ~40 UI elements

**Tasks:**
- [ ] Extract all hardcoded UI text
- [ ] Replace with translation keys
- [ ] Add `_on_language_changed()` handler
- [ ] Implement dynamic UI refresh
- [ ] Test language switching

**Complexity**: Medium  
**Priority**: High

---

#### 3.2 Inventory & Equipment System
**Files to Modify:**
- `source/client/ui/inventory/inventory_menu.gd`
- `source/client/ui/inventory/inventory_menu.tscn`
- `source/client/ui/inventory/item_slot.gd`
- `source/client/ui/inventory/trade_request_modal.tscn`

**Text Categories:**
- Tab labels (Inventory, Equipment, Crafting, Trading)
- Button text (Ready, Cancel, Accept, Reject)
- Status messages
- Tooltips
- Trade UI text

**Estimated Strings**: ~50 UI elements

**Tasks:**
- [ ] Extract UI text from scenes
- [ ] Update GDScript to use `tr()`
- [ ] Create tooltip translation system
- [ ] Test inventory interactions

**Complexity**: Medium  
**Priority**: High

---

#### 3.3 Chat & Social Systems
**Files to Modify:**
- `source/client/ui/chat/chat_menu.gd`
- `source/client/ui/chat/chat_menu.tscn`
- `source/client/ui/guild/guild_menu.tscn`
- `source/client/ui/player_profile/player_profile_menu.tscn`

**Text Categories:**
- Channel names (Global, Local, Guild, Party)
- System messages
- Guild UI labels
- Player profile labels

**Estimated Strings**: ~35 UI elements

**Tasks:**
- [ ] Translate channel names
- [ ] Update system message format
- [ ] Create translation keys for guild UI
- [ ] Test chat functionality

**Complexity**: Medium  
**Priority**: Medium

---

#### 3.4 HUD & Overlays
**Files to Modify:**
- `source/client/ui/hud/hud.gd`
- `source/client/ui/hud/hud.tscn`
- `source/client/ui/hud/level_up_popup.tscn`
- `source/client/ui/hud/harvest_popup.tscn`
- `source/client/ui/tooltips/item_tooltip_manager.gd`
- `source/client/ui/tooltips/item_tooltip.tscn`

**Text Categories:**
- Health/Energy bars
- Level up notifications
- Harvesting progress
- Item tooltips
- Status effects

**Estimated Strings**: ~30 UI elements

**Tasks:**
- [ ] Extract HUD text
- [ ] Create tooltip translation format
- [ ] Update popup messages
- [ ] Test all HUD elements

**Complexity**: Low-Medium  
**Priority**: Medium

---

#### 3.5 Minigame Systems
**Files to Modify:**
- `source/client/ui/minigame/horse_racing_ui.gd`
- `source/client/ui/minigame/hot_potato_ui.gd`
- `source/client/ui/minigame/announcement_popup.gd`
- `source/client/ui/minigame/invitation_popup.gd`

**Current Hardcoded Examples:**
```gdscript
"🏆 Winner: " + winner_name
"💀 You were eliminated from Hot Potato!"
"Bet failed: " + response["error"]
```

**New Format:**
```gdscript
tr("minigame_winner").format({"name": winner_name})
tr("minigame_hot_potato_eliminated")
tr("minigame_bet_failed").format({"error": response["error"]})
```

**Estimated Strings**: ~45 UI elements + system messages

**Tasks:**
- [ ] Extract all minigame text
- [ ] Implement dynamic string formatting
- [ ] Update announcement system
- [ ] Test all minigame flows

**Complexity**: Medium  
**Priority**: Medium

---

#### 3.6 Shop & Trading Systems
**Files to Modify:**
- `source/client/ui/shop/shop_setup_ui.gd`
- `source/client/ui/shop/shop_browse_ui.gd`
- `source/client/ui/shop/shop_indicator.gd`
- `source/server/world/components/shop_manager.gd`
- `source/server/world/components/trade_manager.gd`

**Text Categories:**
- Shop UI labels
- Trade status messages
- Shop indicators
- Price formatting

**Estimated Strings**: ~25 UI elements

**Tasks:**
- [ ] Extract shop UI text
- [ ] Update trade messages
- [ ] Test shop interactions
- [ ] Verify price displays

**Complexity**: Low-Medium  
**Priority**: Medium

---

#### 3.7 Quest Board System
**Files to Modify:**
- `source/client/ui/quest_board/quest_board_menu.tscn`
- `source/server/world/components/quest_manager.gd`

**Text Categories:**
- Quest board UI
- Quest status labels
- Completion messages

**Estimated Strings**: ~20 UI elements

**Tasks:**
- [ ] Extract quest UI text
- [ ] Create quest translation keys
- [ ] Test quest board

**Complexity**: Low  
**Priority**: Low

---

### Phase 4: Game Content Translation ⏱️ 5-7 Days

#### 4.1 Item System
**Files to Modify/Create:**
- `source/common/gameplay/items/item_metadata.json` → Split into:
  - `source/common/gameplay/items/item_metadata_en.json`
  - `source/common/gameplay/items/item_metadata_pt_BR.json`
- `source/common/gameplay/items/item.gd`
- `source/common/gameplay/items/item_metadata_manager.gd`

**Current Item Count**: **278 unique items** (estimated from JSON structure)

**Per Item Translation Needed:**
- Item name
- Item description
- Flavor text (if any)
- Category/type labels

**Total Estimated Strings**: 278 items × 2-3 strings = **~600-800 strings**

**Sample Structure:**
```json
{
  "copper_ore": {
    "name": "Minério de Cobre",
    "description": "Minério de cobre bruto. Pode ser fundido em lingotes.",
    "harvest_sources": [...],
    "crafted_by": [...]
  }
}
```

**Tasks:**
- [ ] Create separate metadata files per language
- [ ] Update `ItemMetadataManager` to load language-specific files
- [ ] Translate all 278 item names
- [ ] Translate all 278 item descriptions
- [ ] Update `Item` class to use localized metadata
- [ ] Test item tooltips
- [ ] Verify crafting UI displays correct names

**Complexity**: High (Volume)  
**Priority**: High (Core Content)

---

#### 4.2 Recipe System
**Files to Reference:**
- `source/common/gameplay/items/recipes/` (directory structure)
- Recipe index files

**Estimated Recipe Count**: ~150-200 recipes (based on tier system and item count)

**Translation Needed:**
- Recipe names
- Class requirements (already keywords)
- Crafting station names

**Note**: Recipes use item references, so translating items automatically translates most recipe text.

**Additional Strings**: ~30 crafting-related UI elements

**Tasks:**
- [ ] Extract crafting station names
- [ ] Translate class requirement labels
- [ ] Update recipe UI to use translations
- [ ] Test crafting interface

**Complexity**: Low-Medium  
**Priority**: Medium

---

#### 4.3 Quest Content
**Current Status**: No quest `.tres` files found in search

**Investigation Needed:**
- [ ] Locate quest data storage
- [ ] Determine quest text structure
- [ ] Estimate quest count

**Estimated Strings**: ~50-100 (assuming 20-30 quests × 2-3 strings each)

**Tasks:**
- [ ] Find quest data files
- [ ] Create quest translation structure
- [ ] Translate all quest text
- [ ] Test quest display

**Complexity**: Medium  
**Priority**: Medium

---

#### 4.4 Harvesting System
**Files to Modify:**
- `source/server/world/components/harvesting/harvest_node.gd`

**Text to Translate:**
- Node type names (ore, wood, plants, etc.)
- Harvesting status messages
- Encouragement messages

**Estimated Strings**: ~25 system messages

**Tasks:**
- [ ] Extract harvesting messages
- [ ] Translate node types
- [ ] Update harvest popup
- [ ] Test harvesting flow

**Complexity**: Low  
**Priority**: Low

---

### Phase 5: Server-Side Messages ⏱️ 2-3 Days

#### 5.1 System Messages Architecture

**Problem**: Server doesn't know client language preference  
**Solution**: Send translation keys + arguments instead of formatted strings

**Current Pattern:**
```gdscript
// Server
broadcast_to_all_players("Player X won the race!")

// Client
chat_panel.add_system_message(message)
```

**New Pattern:**
```gdscript
// Server
broadcast_to_all_players({
    "key": "minigame_winner",
    "args": {"player": player_name, "game": game_name}
})

// Client
var message = tr(data["key"]).format(data["args"])
chat_panel.add_system_message(message)
```

**Files to Modify:**
- `source/server/world/components/world_server.gd`
- `source/server/world/components/minigame_manager.gd`
- `source/server/world/components/minigames/horse_racing_game.gd`
- `source/server/world/components/minigames/hot_potato_game.gd`
- `source/client/ui/chat/chat_menu.gd`

**Estimated Messages**: ~80-100 server system messages

**Tasks:**
- [ ] Refactor server broadcast system
- [ ] Update all server messages to use key+args
- [ ] Update client message handlers
- [ ] Test all system messages
- [ ] Verify multiplayer scenarios

**Complexity**: High (Architecture Change)  
**Priority**: High (Core Functionality)

---

### Phase 6: Language Toggle UI ⏱️ 1 Day

#### 6.1 Settings Menu Integration
**Files to Modify:**
- `source/client/ui/settings/settings_menu.tscn`
- `source/client/ui/settings/settings_menu.gd` (if exists)

**UI Component:**
```gdscript
extends OptionButton

func _ready() -> void:
    clear()
    add_item("English", 0)
    add_item("Português (BR)", 1)
    
    # Set current selection
    selected = TranslationManager.get_language()
    
    item_selected.connect(_on_language_selected)

func _on_language_selected(index: int) -> void:
    TranslationManager.set_language(index)
```

**Tasks:**
- [ ] Add language selector to settings menu
- [ ] Create visual language indicator
- [ ] Test language switching
- [ ] Verify settings persistence

**Complexity**: Low  
**Priority**: Medium

---

#### 6.2 Gateway Language Selector
**Files to Modify:**
- `source/client/gateway/gateway.tscn`
- `source/client/gateway/gateway.gd`

**Location**: Top-right corner of login screen (non-intrusive)

**Tasks:**
- [ ] Add language dropdown to gateway
- [ ] Position UI element
- [ ] Style to match theme
- [ ] Test on both themes (desert/navy)

**Complexity**: Low  
**Priority**: High (First Contact Point)

---

### Phase 7: Testing & Validation ⏱️ 2-3 Days

#### 7.1 Automated Testing
**Create Test Scripts:**
- `tools/validate_translations.gd` - Check for missing translations
- `tools/test_language_switching.gd` - Automated UI tests

**Tasks:**
- [ ] Verify all translation keys exist in both languages
- [ ] Check for untranslated strings
- [ ] Test language switching in all menus
- [ ] Verify formatting strings work correctly
- [ ] Test special characters (Portuguese accents)

**Complexity**: Medium  
**Priority**: High

---

#### 7.2 Manual Testing Checklist
- [ ] Login/account creation flow
- [ ] Character creation
- [ ] Inventory management
- [ ] Trading system
- [ ] Chat messages
- [ ] Minigames (all types)
- [ ] Shop system
- [ ] Quest board
- [ ] Harvesting
- [ ] Guild UI
- [ ] Error messages
- [ ] Tooltips
- [ ] HUD elements
- [ ] Settings persistence

**Complexity**: Low  
**Priority**: Critical

---

## 📈 Translation Volume Estimate

| Category | Estimated Count | Priority |
|----------|----------------|----------|
| **Error Messages** | 180 strings | Critical |
| **UI Labels & Buttons** | 250 strings | Critical |
| **Item Names** | 278 strings | High |
| **Item Descriptions** | 278 strings | High |
| **System Messages** | 100 strings | High |
| **Minigame Text** | 45 strings | Medium |
| **Quest Text** | 75 strings | Medium |
| **Tooltips** | 50 strings | Medium |
| **Miscellaneous** | 100 strings | Low |
| **TOTAL** | **~1,356 strings** | - |

---

## 🗂️ File Structure

```
krakovia-tiny-mmo/
├── localization/
│   ├── README.md
│   ├── translations_base.csv (Master file)
│   ├── translations.en.translation (Generated)
│   ├── translations.pt_BR.translation (Generated)
│   ├── items_en.csv
│   ├── items_pt_BR.csv
│   └── progress_tracker.md
│
├── source/
│   ├── common/
│   │   ├── utils/
│   │   │   ├── translation_manager.gd ✨ NEW
│   │   │   ├── error_messages.gd 🔧 MODIFIED
│   │   │   └── event_bus.gd ✨ NEW (if needed)
│   │   └── gameplay/
│   │       └── items/
│   │           ├── item_metadata_en.json ✨ NEW
│   │           ├── item_metadata_pt_BR.json ✨ NEW
│   │           └── item_metadata_manager.gd 🔧 MODIFIED
│   │
│   ├── client/
│   │   ├── gateway/
│   │   │   └── gateway.gd 🔧 MODIFIED
│   │   └── ui/
│   │       ├── settings/
│   │       │   └── language_selector.gd ✨ NEW
│   │       ├── inventory/
│   │       │   └── inventory_menu.gd 🔧 MODIFIED
│   │       ├── chat/
│   │       │   └── chat_menu.gd 🔧 MODIFIED
│   │       └── minigame/
│   │           ├── horse_racing_ui.gd 🔧 MODIFIED
│   │           └── hot_potato_ui.gd 🔧 MODIFIED
│   │
│   └── server/
│       └── world/
│           └── components/
│               ├── world_server.gd 🔧 MODIFIED
│               └── minigame_manager.gd 🔧 MODIFIED
│
├── tools/
│   ├── extract_translatable_text.gd ✨ NEW
│   ├── validate_translations.gd ✨ NEW
│   └── translation_progress.gd ✨ NEW
│
└── project.godot 🔧 MODIFIED
```

**Legend:**
- ✨ NEW - File to be created
- 🔧 MODIFIED - Existing file to be modified

---

## 🚀 Implementation Order (Recommended)

### Sprint 1: Foundation (Week 1)
1. ✅ Phase 1.1 - Translation system core
2. ✅ Phase 1.2 - Project configuration
3. ✅ Phase 2.1 - Error messages migration (POC)
4. ✅ Phase 6.2 - Gateway language selector

**Deliverable**: Working language toggle with error messages translated

---

### Sprint 2: UI Translation (Week 2)
5. ✅ Phase 3.1 - Gateway/Login system
6. ✅ Phase 3.2 - Inventory & Equipment
7. ✅ Phase 3.3 - Chat & Social
8. ✅ Phase 3.4 - HUD & Overlays
9. ✅ Phase 6.1 - Settings menu integration

**Deliverable**: All UI elements translatable

---

### Sprint 3: Content & Server (Week 3)
10. ✅ Phase 4.1 - Item system (high volume)
11. ✅ Phase 4.2 - Recipe system
12. ✅ Phase 5.1 - Server-side messages
13. ✅ Phase 3.5 - Minigame systems
14. ✅ Phase 4.3 - Quest content

**Deliverable**: All game content translated

---

### Sprint 4: Polish & Testing (Week 4)
15. ✅ Phase 4.4 - Harvesting system
16. ✅ Phase 3.6 - Shop & Trading
17. ✅ Phase 3.7 - Quest Board
18. ✅ Phase 7.1 - Automated testing
19. ✅ Phase 7.2 - Manual testing
20. ✅ Final polish and bug fixes

**Deliverable**: Production-ready i18n system

---

## 🔧 Technical Implementation Details

### Translation Key Naming Convention

```
[category]_[context]_[element]
```

**Examples:**
```
ui_inventory_title
ui_button_confirm
ui_button_cancel
error_login_invalid_credentials_title
error_login_invalid_credentials_message
item_copper_ore_name
item_copper_ore_description
minigame_winner_announcement
system_player_joined_server
```

### String Formatting Pattern

**Static Strings:**
```gdscript
button.text = tr("ui_button_confirm")
```

**Dynamic Strings:**
```gdscript
# CSV: minigame_winner = "🏆 Winner: {player}"
var message = tr("minigame_winner").format({"player": player_name})
```

**Pluralization (future):**
```gdscript
# Use conditional logic for now
var key = "item_count_single" if count == 1 else "item_count_plural"
label.text = tr(key).format({"count": count})
```

---

## 🎯 Success Criteria

### Functional Requirements
- ✅ All UI text displays in selected language
- ✅ Language preference persists across sessions
- ✅ No untranslated strings (fallback to English)
- ✅ Smooth language switching without restart
- ✅ All error messages translated
- ✅ All item names and descriptions translated
- ✅ Server messages display in client language

### Non-Functional Requirements
- ✅ Zero runtime performance impact
- ✅ No gameplay functionality broken
- ✅ Clean, maintainable code
- ✅ Easy to add more languages in future
- ✅ Translation files can be edited by non-programmers

### Quality Assurance
- ✅ Brazilian Portuguese uses proper grammar
- ✅ Game terminology is consistent
- ✅ Accents and special characters render correctly
- ✅ Text fits in UI elements (no overflow)
- ✅ Formal vs informal tone is consistent

---

## 🌐 Portuguese Translation Guidelines

### Tone & Style
- **Formal "Você"** for system messages
- **Informal** for flavor text and NPC dialogue
- **Direct and clear** for UI labels and buttons
- **Game-specific terminology** should be consistent

### Common Translations

| English | Portuguese | Notes |
|---------|-----------|-------|
| Inventory | Inventário | Standard |
| Equipment | Equipamento | Not "Armadura" |
| Crafting | Criação / Fabricação | Context-dependent |
| Quest | Missão | Not "Busca" |
| Guild | Guilda | Not "Clã" |
| Shop | Loja | Standard |
| Trade | Comércio / Troca | Context-dependent |
| Level | Nível | Standard |
| Experience | Experiência | Standard |
| Health | Vida / Saúde | "Vida" for games |
| Energy | Energia | Standard |
| Minigame | Minijogo | Standard |
| Player | Jogador(a) | Gender-neutral when possible |
| Server | Servidor | Standard |
| Account | Conta | Standard |
| Character | Personagem | Not "Caractere" |

### Item Naming
- Keep fantasy item names in English or adapt phonetically
- Use Portuguese for common items (wood → madeira, stone → pedra)
- Maintain consistency across similar items

---

## 🐛 Known Challenges & Mitigations

### Challenge 1: Scene File Text
**Issue**: `.tscn` files may have hardcoded text  
**Mitigation**: Use scene editor or script-based text updates in `_ready()`

### Challenge 2: Dynamic UI Sizing
**Issue**: Portuguese text may be longer than English  
**Mitigation**: Use auto-sizing containers, test all UI elements

### Challenge 3: Server Message Synchronization
**Issue**: Multiplayer messages need to work for players with different languages  
**Mitigation**: Send translation keys + args instead of formatted strings

### Challenge 4: Translation Quality
**Issue**: Machine translation may be poor quality  
**Mitigation**: Review all translations, consider community translation contributions

### Challenge 5: Maintenance
**Issue**: New features add new strings  
**Mitigation**: Create tool to detect missing translations, document workflow

---

## 📝 Progress Tracking

### Phase Completion Checklist
- [x] Phase 1: Infrastructure Setup ✅ COMPLETE
- [ ] Phase 2: Error Messages Migration
- [ ] Phase 3: UI Components Translation
- [ ] Phase 4: Game Content Translation
- [ ] Phase 5: Server-Side Messages
- [ ] Phase 6: Language Toggle UI
- [ ] Phase 7: Testing & Validation

### Translation Completion
- [x] Error Messages (180 strings) ✅ COMPLETE
- [x] Common UI Elements (15 strings) ✅ COMPLETE
- [ ] UI Labels (235 strings remaining)
- [ ] Item Names (278 strings)
- [ ] Item Descriptions (278 strings)
- [ ] System Messages (100 strings)
- [ ] Minigame Text (45 strings)
- [ ] Quest Text (75 strings)
- [ ] Tooltips (50 strings)
- [ ] Miscellaneous (100 strings)

**Total Progress**: 198 / 1,356 strings (14.6%)

---

## 📚 Resources & References

### Godot Documentation
- [Internationalizing Games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)
- [Locales](https://docs.godotengine.org/en/stable/tutorials/i18n/locales.html)
- [TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html)

### Translation Tools
- [Godot CSV Translation Editor](https://github.com/godotengine/godot-proposals/issues/2830)
- [POEditor](https://poeditor.com/) - Collaborative translation platform
- [Weblate](https://weblate.org/) - Open source translation tool

### Portuguese Resources
- [Brazilian Portuguese Style Guide](https://github.com/github/choosealicense.com/blob/gh-pages/CONTRIBUTING-pt_BR.md)
- [Game Translation Best Practices](https://www.gamedeveloper.com/business/localization-best-practices-for-game-developers)

---

## 🎬 Next Steps

### Immediate Actions (Completed ✅)
1. ✅ Review and approve this scope document
2. ✅ Create `TranslationManager` singleton
3. ✅ Setup CSV translation file structure
4. ✅ Implement error messages migration (POC)

### Short-term Goals (Next Session)
1. ⏳ Open Godot Editor and import translations
2. ⏳ Test language switching functionality
3. ⏳ Add language selector UI to gateway scene
4. ⏳ Begin UI component translation (login/gateway)

### Long-term Goals
1. ⏳ Complete all translations
2. ⏳ Community testing
3. ⏳ Consider adding more languages (Spanish, German, etc.)

---

## 🤝 Contribution Workflow

### For Developers
1. Always use `tr()` for user-facing text
2. Add new keys to `localization/translations_base.csv`
3. Provide English translation immediately
4. Mark Portuguese as `[TODO]` for translation team
5. Run validation script before committing

### For Translators
1. Edit CSV files directly (or use translation tool)
2. Maintain consistent terminology
3. Test translations in-game
4. Report any text overflow issues
5. Suggest improvements to English source text

---

## 📊 Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Translation quality poor | High | Medium | Review process, native speaker testing |
| UI text overflow | Medium | High | Auto-sizing, early testing |
| Performance impact | Low | Low | Use compiled translations, cache lookups |
| Incomplete translation | Medium | Medium | Fallback to English, validation tools |
| Maintenance burden | Medium | Medium | Clear documentation, automated tools |
| Breaking existing features | High | Low | Comprehensive testing, gradual rollout |

---

## 💡 Future Enhancements

### Potential Features
- 🌍 Additional languages (Spanish, German, French, etc.)
- 🗣️ Voice-over localization
- 📝 Community translation contributions
- 🔧 In-game translation editor for admins
- 📊 Analytics on language usage
- 🌐 Regional variants (pt_PT vs pt_BR)

### Scalability Considerations
- CSV format is human-readable and git-friendly
- Translation keys are centralized and searchable
- Architecture supports unlimited languages
- Community can contribute via pull requests
- Tools can auto-detect missing translations

---

**Document Version**: 1.0  
**Last Updated**: October 17, 2025  
**Author**: GitHub Copilot + João Vitor  
**Status**: Ready for Implementation 🚀
