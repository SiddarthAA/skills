# Driving Resolve's GUI (Linux/X11)

Use the GUI only where neither the API nor a template file reaches (`capability-matrix.md`). The usual GUI jobs: building a template
once (a Fairlight mix, a DRX grade), the Ducker, buses, subtitle styling, an Effects Library drag, and dismissing dialogs. Resolve has no
accessibility tree (its bundled Qt has no AT-SPI bridge), so the GUI means screenshots, keys, clicks and number fields.

## Rules
- **Screenshot before you click, and after to confirm.** Shoot Resolve's windows only (`gui shot`), never the whole screen: the user may be working.
- **Letters typed into the main window are shortcuts.** `gui type` refuses letters there; numbers (`-0-9.:`) are allowed for number fields. For a
  real text box (e.g. the Effects search), screenshot to confirm it's focused, then `GUI_TEXT_FIELD=1 gui type ...`.
- Check the keyboard preset first: `resolve:GetCurrentKeyboardPreset() == "DaVinci Resolve"` (else `LoadKeyboardPreset("DaVinci Resolve")`).
- Never click Send (crash reports), Buy Now (upsell), Download/Update, or anything that uploads or pays.
- Coordinates in this skill are for a 1920x1080 screen with the main window maximized (1854x1048 at 66,32) on the default layout. They are hints:
  confirm with a screenshot. Crop screenshots (`gui shot f.png x y w h`) to save tokens.

## The `gui` helper (scripts/gui)
`gui` and `rv`'s dialog check default to `DISPLAY=:1` (this machine). Export `DISPLAY` to point elsewhere.
| Command | Does |
|---|---|
| `gui wins` | Visible Resolve windows: id, title, x y w h |
| `gui shot out.png [x y w h]` | Screenshot the main window (or a crop of it) |
| `gui key ctrl+s [...]` | Activate the window, press keys (xdotool names: `alt+s`, `shift+4`, `Escape`, `Return`, `Up`) |
| `gui click X Y [right\|double]` | Click at window-relative coordinates |
| `gui field X Y VALUE` | Double-click a number field, Ctrl+A, type, Return |
| `gui drag X1 Y1 X2 Y2` | Qt-friendly drag (press, small move, gradual moves, release): Effects Library onto clips |
| `gui scroll X Y up\|down [n]` | Mouse wheel |
| `gui type 'text'` | Type into the focused field (numbers only in the main window unless `GUI_TEXT_FIELD=1`) |
| `GUI_WIN='^Message$'` or `GUI_WIN=<id>` | Retarget any command at another window (by title regex or id) |

## How Resolve's UI behaves [L]
| Behaviour | What to do |
|---|---|
| **Top-level windows are reused and titles go stale** (the Dynamics panel was titled "Patch Input/Output") | Find the new window with `gui wins` (by size), screenshot it, target it by id |
| Menus, dropdowns and submenus are separate popup windows titled `resolve` | `gui wins` shows their geometry; submenus open on click, not hover |
| **Clicking an item in a popup list sometimes doesn't register** | Open the dropdown, then **keyboard**: Up/Down/Home/End + Return. Down from a blank selection can skip the first item: use Up/Home |
| Number fields | Double-click, Ctrl+A, type, Return (`gui field`). **Type in the display format**: `4.0:1` not `4`; `-500.0`; `80` |
| Drag and drop needs gradual motion | `gui drag` (a plain press-move-release does nothing) |
| Name/confirm dialogs | `Message` (e.g. "Create New" at (407,161)), `Input` (name field (207,87), Return to OK) |
| **Studio upsell modal** "You have reached a limitation" after a Studio-only API call | `GUI_WIN='^Message$' gui key Escape` (= Not Yet). While it is open, API create calls silently return nil. `rv` warns |
| Page switch races | The first `SetCurrentTimecode` after `OpenPage` can be dropped; `SetCurrentTimecode` is ignored ON the Fusion page. `R.seek` retries |

## Pages and global keys (DaVinci Resolve keymap, 21.1)
Media Shift+1, Photo Shift+2, Cut Shift+3, Edit Shift+4, Fusion Shift+5, Color Shift+6, Fairlight Shift+7, Deliver Shift+8,
Project Manager Shift+0, Project Settings Shift+9, Preferences Ctrl+, , Keyboard Customization Ctrl+Alt+K, Console F6, save Ctrl+S, undo Ctrl+Z.
Prefer `resolve:OpenPage("color")`. The full action->key list: `resolve:ExportKeyboardPreset("DaVinci Resolve", path)`, then grep (e.g. `sessionTrackForward := Ctrl+T`).
Menu bar (y=9): DaVinci Resolve 50, File 118, Edit 152, Trim 190, Timeline 241, Clip 290, Mark 329, View 371, Playback 423, Fusion 481,
Color 528, Fairlight 580, Workspace 647, Help 706.

## Per-page coordinates
In the page references: `pages/fairlight.md` (mixer strips, EQ/Dynamics windows, Presets Library, Ducker, Bus Format), `pages/color.md`
(palettes, primaries fields, windows, tracker, node keys), `pages/edit.md` (top bar, Effects Library, Inspector), `pages/deliver.md`.

## Window titles
| Title | What | Action |
|---|---|---|
| `DaVinci Resolve - <project>` | Main window | Target for keys/clicks |
| `resolve` (640x480) | Lua Console | Only `rcon` types here |
| `resolve` (small) | A popup menu/dropdown | Keyboard to pick |
| `Message` | Confirmations, errors, the Studio upsell, "Render Path Inaccessible" | Read it (screenshot), then Escape or the right button |
| `Input` | Name a preset | Click (207,87), type, Return |
| `Presets Library`, `Bus Format`, `Dialog`, `Plugin UI Panel`, `Patch Input/Output` | Fairlight windows (titles may be stale) | Screenshot to identify |
| `Project Manager`, `Create New Project` | Launch | `resolve-up` handles them |
| `Problem Report for DaVinci Resolve` | After a crash | Click **Ignore** at (365,341). Never Send |
| `Software Update` | Update nag | Skip; never Download |

## Recovery
```bash
resolve-up <project>   # crash report -> Ignore, launch, Project Manager, modals, bridge start, open/create project
gui wins               # what's open?
tail -50 ~/.local/share/DaVinciResolve/logs/ResolveDebug.txt     # after a crash: logs/LogArchive/ResolveDebug_C1.txt
```
- **"Unsupported GPU Processing Mode" at launch** (log: GPUDetect "No matched GPUs found") usually means CUDA died after a laptop suspend
  (`python3 -c "import ctypes; print(ctypes.CDLL('libcuda.so.1').cuInit(0))"` prints 999). Fix: `sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm` with
  Resolve closed. That needs the user (sudo).
- If `rv` times out: the bridge isn't running (Resolve restarted), a long call is still working (raise `RV_TIMEOUT`), or a modal is open (`gui wins`).
