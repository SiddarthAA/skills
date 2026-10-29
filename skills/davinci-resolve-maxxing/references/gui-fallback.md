# GUI fallback (Linux/X11, xdotool)

Use the GUI only for what the API can't do: starting the bridge, dismissing dialogs, crash recovery, and the few
Fairlight/Inspector jobs with no API (ducking, EQ, subtitle styling, adding a Media Storage location).

## Rules
- **Screenshot Resolve's window, not the screen.** The user may be working in other apps:
  `import -window "$(xdotool search --onlyvisible --name '^DaVinci Resolve - ' | head -1)" shot.png`
- **Never type into the main window.** Letters are shortcuts there (`(` = Shift+9 opens Project Settings). Only type into a verified console or a dialog's text field (`rcon` enforces this).
- Look before you click: list windows first, act on the one you expect, then screenshot to confirm.
- Never click "Send" on a crash report, "Download" on update prompts, or anything that uploads or purchases.
- Prefer the API whenever it exists: `resolve:OpenPage("edit")`, `R.save()`, `R.render()`, `tl:AddMarker()`.

## Window titles (`xdotool search --onlyvisible --class resolve`, then `getwindowname`)
| Title | What | Action |
|---|---|---|
| `DaVinci Resolve - <project>` | Main window (1854x1048 on this box) | Target for F6 / menus |
| `resolve` (about 640x484) | Lua Console | Click its bottom input line, type, Return |
| `Project Manager` | Shown at launch | Double-click a tile. First tile after New Project = most recent, at (414,176) relative |
| `Create New Project` | After New Project | Name field is focused: Ctrl+A, type the name, Return |
| `Project Settings` / `Preferences` | Modal | Escape cancels without saving |
| `Message` | e.g. "Render Path Inaccessible" | Read it (`import -window <id>`), fix the cause, Return/Escape |
| `Problem Report for DaVinci Resolve` | After a crash | Click **Ignore** at (365,341) relative. Never Send |
| `Software Update` | Update nag at launch | Click Skip; never Download without the user's OK |

## Coordinates (relative to the main window, default layout)
| Target | Offset |
|---|---|
| Workspace menu | (647, 9) |
| Workspace > Console item | (658, 454) |
| Deliver page: "Add to Render Queue" | Needed only if `AddRenderJob` fails. Screenshot first; the button is bottom-left of Render Settings |

Coordinates drift with layout and resolution. Treat them as a starting point, take a screenshot, and verify.

## Shortcuts (Linux/Windows; on Mac, Ctrl becomes Cmd)
| Action | Keys |
|---|---|
| Pages Media/Cut/Edit/Fusion/Color/Fairlight/Deliver | Shift+2 ... Shift+8 (Shift+1 Project Manager, Shift+9 Project Settings) |
| Console | F6 on this box (not documented as a default; menu Workspace > Console always works) |
| Play/stop, shuttle | Space, J/K/L |
| Blade / ripple delete / lift | B or Ctrl+\ / Delete or Shift+Backspace / Backspace |
| Marker, mark in/out | M, I/O (Alt+X clears) |
| Zoom timeline to fit | Shift+Z |
| Undo / redo / save | Ctrl+Z / Ctrl+Shift+Z / Ctrl+S |
| Preferences | Ctrl+, |

## Recovery
```bash
resolve-up <project>        # handles crash report, relaunch, Project Manager, modals, bridge start
# by hand:
xdotool search --onlyvisible --class resolve | while read w; do echo "$w $(xdotool getwindowname $w)"; done
tail -50 ~/.local/share/DaVinciResolve/logs/ResolveDebug.txt          # or logs/LogArchive/ResolveDebug_C1.txt after a crash
```
If `rv` times out: the bridge isn't running (Resolve restarted), a long call is still working (raise `RV_TIMEOUT`),
or a modal dialog is open. List the windows before doing anything else.

## No-API jobs, by hand
- **Add Media Storage location:** Ctrl+, > System > Media Storage > Add, then restart Resolve. Or simply render into an existing one (`R.storage()`).
- **Ducking / EQ / compressor:** Fairlight page. Scriptable alternative: process the WAVs with ffmpeg before import (recipes.md C.5).
- **Subtitle track styling:** GUI only. Prefer `finish.py --subs` burn-in or `R.title` captions.
