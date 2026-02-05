# nigMenu Changelog

## v1.1.0 - Modular Rewrite

### 🏗️ Architecture Overhaul
- **Complete modular rewrite** - Script split into organized modules for easier maintenance and development
  - `core/` - Config, utilities, UI framework, settings
  - `features/` - Individual feature modules (raids, swords, generals, etc.)
  - `tabs/` - UI tab builders
- **Lazy loading system** - Modules load dependencies at runtime, preventing circular dependency issues
- **Single entry point** - Just execute `loader.lua` to load everything

### 🔄 Single Instance Management
- **Auto-cleanup on reinject** - Reinjecting the script now automatically terminates the previous instance
- All background loops properly stop when a new instance starts
- No more duplicate features running or UI stacking

### ⚡ Performance & UX Improvements
- **Improved Upgrades tab loading** - Content now loads with a spinner indicator
- **Better error handling** - "No data found" messages display when MetaService data isn't available
- **Debug output** - Console messages help diagnose loading issues

### 🐛 Bug Fixes
- Fixed tab switching not triggering content population
- Fixed sword enchants not finding sword data (now uses same path as splitter)
- Fixed modules failing to load due to early binding of global references

### 📁 New File Structure
```
nigMenu/
├── loader.lua          # Execute this
├── core/
│   ├── config.lua      # Theme, constants, state
│   ├── utils.lua       # Helper functions
│   ├── ui.lua          # Main window & navigation
│   └── settings.lua    # Save/load settings
├── features/
│   ├── raids.lua
│   ├── autoroll.lua
│   ├── generals.lua
│   ├── swords.lua
│   ├── splitter.lua
│   ├── accessories.lua
│   ├── merger.lua
│   ├── utilities.lua
│   └── autobuy.lua
└── tabs/
    ├── auto_tab.lua
    ├── upgrades_tab.lua
    ├── items_tab.lua
    ├── merger_tab.lua
    ├── utils_tab.lua
    └── config_tab.lua
```

---

## v1.0.0 - Initial Release
- Original single-file implementation
- Raid automation
- Auto-roll system
- Sword enchanting & splitting
- General upgrades
- Accessory rolling
- Pet merger
- Utility toggles
- Settings persistence
