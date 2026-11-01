# macOS (UNTESTED: documented from Blackmagic docs, needs a teammate run)

Same bridge, same Lua, same `R` helpers. Differences:

| What | Linux (tested) | macOS |
|---|---|---|
| H.264/HEVC/AAC | Not decodable or encodable on free: transcode to ProRes, encode with ffmpeg | **Supported on free.** `prep.py transcode` is only needed for reframing; Resolve can render H.264 directly (`R.render({format="mp4", codec="H264"})`; check codec IDs with `p:GetRenderCodecs("mp4")`) |
| Master LUT folder (SetLUT) | `/opt/resolve/LUT` | `/Library/Application Support/Blackmagic Design/DaVinci Resolve/LUT/` (install with `RESOLVE_LUT_DIR=... install.sh`, may need sudo) |
| Support / logs | `~/.local/share/DaVinciResolve/` | `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/` |
| Fairlight presets (fl_eq.py `--out`, install.sh step 5) | `~/.local/share/DaVinciResolve/configs/Fairlight/Presets/{EQ,DYN}` | probably `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/configs/Fairlight/Presets/{EQ,DYN}`: confirm by saving an EQ preset in the GUI and finding the file |
| Built-in Fusion templates (R.templates) | `/opt/resolve/Fusion/Templates/Templates.drfx` | inside the app bundle; `find /Applications/DaVinci\ Resolve -name Templates.drfx`, unzip to `~/resolve-bridge/templates` |
| GUI driver | `scripts/gui` (xdotool) | not ported: use osascript/cliclick with the same techniques (`references/gui.md`) |
| Fonts Fusion sees | `/usr/share/fonts` only (bridge runs `ScanDir`) | System font folders; user fonts probably visible. Still check `R.has_font` |
| Media Storage default | `~/Videos` here | Usually `~/Movies`. `rv 'return R.storage()'` |
| Launch binary | `/opt/resolve/bin/resolve` | `open -a "DaVinci Resolve"` |
| Console | Workspace > Console (F6 here) | Workspace > Console; F-keys may need Fn |
| GUI automation | xdotool, ImageMagick `import` | `osascript` (System Events), `cliclick`, `screencapture`. Grant Accessibility + Screen Recording to the terminal |

## Starting the bridge on Mac (replaces rcon/resolve-up)
```sh
mkdir -p ~/resolve-bridge && ln -sf "$SKILL/scripts/bridge.lua" ~/resolve-bridge/ && ln -sf "$SKILL/scripts/lib.lua" ~/resolve-bridge/
open -a "DaVinci Resolve"            # open a project by hand, then Workspace > Console, Lua tab
printf '%s' 'dofile(os.getenv("HOME").."/resolve-bridge/bridge.lua")' | pbcopy
osascript -e 'tell application "DaVinci Resolve" to activate' \
          -e 'tell application "System Events" to keystroke "v" using command down' \
          -e 'tell application "System Events" to key code 36'     # paste + Return into the focused console
"$SKILL/scripts/rv" 'return resolve:GetVersionString()'
```
Pasting is safer than typing Lua through System Events. On Retina displays, screenshots are in pixels but clicks are in points (divide by 2).

## Teammate verification checklist (report results back into this file)
1. `rv 'return resolve:GetVersionString() .. " " .. tostring(resolve:IsStudio())'`
2. `rv 'return R.storage()'` and `rv 'return R.has_font("Helvetica")'`
3. `prep.py carriers 1920x1080 --fps 30 --out ~/resolve-bridge/assets`, then build a timeline with `R.place` + `R.title` + `R.motion` (recipes.md A excerpt). Grab `R.still` frames and confirm the text and zoom render.
4. Does ffi + libc work (the bridge answering at all proves it)? Does `bmd.wait` keep the UI responsive?
5. `R.lut` after installing LUTs into the Mac LUT folder.
6. `R.render` to ProRes, plus a direct H.264 render. Note the codec IDs.
7. Import a phone H.264/HEVC clip directly: does it decode (Resolution property set)?
8. `R.fx(item, "ofx.com.blackmagicdesign.resolvefx.Glow")` and a template `.setting`: do they render (R.still)? Studio-only pieces watermark on free.
9. Fairlight: save an EQ preset in the GUI, note the folder, then point `fl_eq.py --out` at it.
