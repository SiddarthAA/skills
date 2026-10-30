# Projects, settings, preferences, keyboard and layouts

**[L]** = verified on free 21.1.1 Linux. Guardrail: only create, rename or delete projects, bins and presets the agent made (prefix them `agent-`).

## Projects [L]
```lua
local pm = R.pm()
pm:CreateProject("agent-x")          -- becomes current; pm:LoadProject(name); pm:SaveProject(); pm:CloseProject(p) leaves "Untitled Project"
pm:GetProjectListInCurrentFolder(); pm:CreateFolder("agent-f"); pm:OpenFolder("agent-f"); pm:GotoParentFolder(); pm:GotoRootFolder(); pm:DeleteFolder("agent-f")
pm:ExportProject("name", "/abs/path.drp", false)   -- the backup that works (.drp = zip of XML)
pm:ImportProject("/abs/path.drp", "agent-copy")    -- import under a new name
pm:DeleteProject("agent-x")                         -- only your own, never the loaded one
pm:GetCurrentDatabase()                             -- {DbType = "Disk", DbName = "Local Database"}
```
- `ArchiveProject(name, path.dra, false, false, false)` returns false (no file, no crash), even inside ~/Videos. With media flags it was reported to SIGSEGV. Use ExportProject.
- Projects live in SQLite: `~/.local/share/DaVinciResolve/Resolve Project Library/Resolve Projects/Users/guest/Projects/<name>/Project.db`.
  Read-only inspection is fine; never write to it while Resolve runs.
- `.drp` and `.drt` are zip files of XML (`project.xml`, `SeqContainer/<uuid>.xml`, `MediaPool/Master/MpFolder.xml`); most state sits in hex FieldsBlobs.
  Good for diffing and backups; not a practical authoring format. Author timelines as FCPXML instead.

## Project and timeline settings [L]
- `p:GetSetting()` = 158 keys (strings); `p:SetSetting(k, v)`; `p:GetSettings()` / `p:SetSettings(table)`. Timeline: `tl:GetSetting(k)`, `tl:GetSettings()` (69), `tl:SetSettings`.
- Useful keys: `timelineFrameRate` (only before the first timeline), `timelineResolutionWidth/Height`, `timelineInputResMismatchBehavior`
  (scaleToFit/scaleToCrop/centerCrop/stretch), `colorScienceMode` (davinciYRGB...), `superScale`, `videoMonitorFormat`, `timelineSampleRate`.
  `SetSetting("timelinePlaybackFrameRate", ...)` returns false.
- Per-timeline resolution: `tl:SetSetting("useCustomSettings", "1")` then width/height (R.timeline does it).
- Settings presets: `p:SaveCurrentProjectSettingsAsNewPreset(name)`, `SetProjectSettingsPreset`, `UpdateProjectSettingsPreset`, `DeleteProjectSettingsPreset`,
  `ExportProjectSettingsPreset(name, path)` / `ImportProjectSettingsPreset(path)`; list: `p:GetProjectSettingsPresetList()` ({Name, Width, Height}).
  Exporting "Current Project" returns false: save it as a named preset first.

## App-wide presets [L]
| Kind | Calls | File format |
|---|---|---|
| Keyboard | `resolve:GetKeyboardPresetList()` (DaVinci Resolve, Premiere, FCPX, Avid, Pro Tools), `GetCurrentKeyboardPreset`, `LoadKeyboardPreset`, `ExportKeyboardPreset(name, path)`, `ImportKeyboardPreset(path)` (named after the file), `DeleteKeyboardPreset` | **Text**: `action := Key \| Key2` with sections (506 actions). Grep it to find a shortcut |
| Layout (panels) | `SaveLayoutPreset`, `LoadLayoutPreset`, `UpdateLayoutPreset`, `ExportLayoutPreset(name, path)`, `ImportLayoutPreset(path, name)`, `DeleteLayoutPreset`, `GetLayoutPresetList` | opaque (130 KB) |
| User preferences | `SaveUserPreferencesPreset`, `LoadUserPreferencesPreset`, `ExportUserPreferencesPreset(name, path)`, `ImportUserPreferencesPreset(path, name)`, `DeleteUserPreferencesPreset` | XML `SM_UserPrefs` |
| Render | `pages/deliver.md` | XML |
| Fairlight EQ/Dynamics/plugin/config | `pages/fairlight.md` | XML / binary |
| Burn-in | `GetBurnInPresetList` (empty here), `Import/Export/DeleteBurnInPreset`, `p:LoadBurnInPreset` | |
- **Before GUI driving check the keyboard preset**: `resolve:GetCurrentKeyboardPreset() == "DaVinci Resolve"`, otherwise `LoadKeyboardPreset("DaVinci Resolve")`.
  The shortcuts in this skill assume it. A teammate on Premiere keys would break every key press.
- Other app calls: `resolve:GetVersion()` -> {21,1,1,10,""}, `GetVersionString()`, `GetProductName()`, `IsStudio()` (false), `GetCurrentPage()`,
  `OpenPage(name)` (media, cut, edit, fusion, color, fairlight, deliver), `SetKeyframeMode`, `DisableBackgroundTasksForCurrentResolveSession()`,
  `ValidateDCTL(path)` (compiler messages), `Quit()`.

## Config files (Linux: `~/.local/share/DaVinciResolve/configs/`)
`config.user.xml` (preferences, readable XML), `keyboard.preset.xml`, `UI.preset` (layout), `Fairlight/Presets/*`, `OFXPluginCacheV2.xml`. Fusion user
data: `~/.local/share/DaVinciResolve/Fusion/` (Templates, Macros, Fuses, Config). Logs: `~/.local/share/DaVinciResolve/logs/ResolveDebug.txt`.
