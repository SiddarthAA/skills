# R helpers (scripts/lib.lua) and scripting basics

Code runs inside Resolve's Lua Console (LuaJIT = Lua 5.1: no `//` operator, use `math.floor`; arrays are 1-based).
Globals inside a request: `resolve`, `R` (scripts/lib.lua), `print`, `reload()`, `stop()`, plus `bmd`, `ffi`.
Ground truth for signatures: `/opt/resolve/Developer/Scripting/DaVinciResolveScript.pyi` (Python stub, same names).
**[L]** verified in our lab on free 21.1.1 Linux; **[R]** reported, not re-tested.

## R helpers (scripts/lib.lua)

Frames are relative to the timeline start (0 = first frame).

| Helper | Does |
|---|---|
| `R.project()`, `R.mp()`, `R.tl()`, `R.pm()`, `R.save()` | Handles; save the project |
| `R.find(name, folder)` | Media-pool clip by exact name, searching every bin (or one `folder`); prefers file-backed clips. Same-named clips in different bins are ambiguous: keep the MediaPoolItems you imported, or pass the folder |
| `R.find_path(path)` | The clip of this exact file, any bin |
| `R.bin(name)` | Top-level bin, created if missing |
| `R.import(paths, bin)` | Import into a bin (created if missing). **Reuses a clip of the same FILE PATH wherever it is (it is not moved into `bin`)**, so give a changed file (e.g. a re-made SRT) a new name. Warns on undecodable media |
| `R.frames(clip)` | Clip length in frames (audio-only clips have no "Frames" property; uses Duration) |
| `R.timeline(name, {w, h, fps, crop, video, audio})` | New timeline with a unique name. `w`/`h` set a per-timeline resolution (vertical inside a 16:9 project). `crop = true` makes other-aspect sources fill (scaleToCrop) so `R.frame` can pick what shows. `fps` only works before the project's first timeline |
| `R.open(name)` | Make an existing timeline current |
| `R.tracks(tl, kind, n)` | Ensure n tracks of "video" / "audio" / "subtitle" |
| `R.carrier(tl)` | Transparent ProRes 4444 "carrier" clip matching the timeline size/fps (from install.sh; lives in the skill's own `_carriers` bin). Place it on an upper track, then put titles/generators on it with `R.title` or `R.fx` |
| `R.place(tl, clip, {track, at, from, len, media, atrack})` | Exact placement (exclusive end handled). Asserts the source range is inside the clip and that it landed where asked (else deletes the stray item and errors). `media` = "video" or "audio" (only that part) or nil (both, linked); `atrack` = audio track when it differs from `track`. Returns `{video, linked audio...}` |
| `R.frame(item, x, zoom)` | Frame a subject in a wider source (crop timeline): x = position as a fraction of source width. Sets `Pan = (0.5 - x) * timeline_width * zoom` (pixel-verified), clamped against black edges |
| `R.keep(tl, clip, ranges, {track, at, media})` | Lay `{{in,out},...}` source ranges back to back (silence cuts, selects; `out` exclusive). Returns items and the end frame |
| `R.items(tl, kind, track)`, `R.dump(tl)` | List items; a readable map of every track |
| `R.tc(tl, rel)`, `R.fps(tl)` | Relative frame to timecode; integer fps |
| `R.has_font(family)`, `R.default_font()` | Is the family visible to Fusion (rescans ~/.local/share/fonts); first available of Open Sans / Inter / DejaVu Sans / Helvetica Neue / Arial |
| `R.title(tl, {text, at, len, track=2, font, style, size, color, center, anim, speed, word_at, tracking, outline})` | Title on a carrier clip with Text+. `anim` = "pop" (default) / "fade" / "type" (typewriter) / "words" (word by word) / "rise" (letters rise in turn) / "slide" / "none"; `speed` = frames per line/word/letter. Returns `item, comp, textTool`. `size` is a fraction of the frame WIDTH: on 9:16 a full-width 5-letter headline is about 0.55, a 15-character line 0.2 (16:9: 0.16 / 0.08). |
| `R.template(tl, comp_path, {at, len, track, text})` | Reuse a saved `.comp` title, retargeting its Text+ |
| **`R.fx(item, id, params)`** | **Apply any effect**: ResolveFX (`ofx.com.blackmagicdesign.resolvefx.<Name>`), any Fusion tool ID, or a `.setting` file: a preset (`R.effects .. "glitch.setting"`), a template (`R.templates .. "Edit/Effects/CCTV.setting"`) or a chain saved by `R.save_fx`. Chains; params may be keyframes `{{f, v}, ..., ease = "out"}` (keyed ResolveFX are re-pasted so they animate); asserts param IDs exist. Returns `tool, comp`. `pages/fusion.md`, `effects.md` |
| `R.inputs(tool)` | ONE string `ID(Display name)=value ...` of a tool's own params (display names for macro `InputN`), to find IDs for R.fx: `return R.inputs(t)`, not `pairs` |
| `R.templates` | `~/resolve-bridge/templates/`: Resolve's 417 built-in Fusion templates as .setting files (install.sh) |
| `R.effects` | `~/resolve-bridge/fx/` = the skill's `assets/fx`: 18 verified effect presets (zoom-punch, glitch, vhs, film-look, light-leak, lower-third...) and `build.lua` (their builders, `FX.b[name](item)`). `effects.md` |
| `R.save_fx(tools, path)` | Save tools (a chain, with keys and modifiers) as a .setting that `R.fx(item, path)` re-applies to any clip. `R.writefile(path, s)` writes any file |
| `R.readfile(path)` | Read a file inside the console (no io there): ffi + libc |
| `R.motion(item, {punch={from,to,frames}, push={from,to}, shake={amp,frames}, blur})` | Keyframed Fusion Transform on a clip. Named keys, Transform Size units (1 = 100%), frames from the item's first frame: `R.motion(it, {punch = {from = 1.3, to = 1.0, frames = 8}})` zooms 130% to 100% over 8 frames; `push = {from = 1, to = 1.08}` over the whole clip; `shake = {amp = 0.015, frames = 10}` (fraction of frame). Returns the Transform tool |
| `R.zoom(item, {target={x,y} top-left fractions, scale=2, at, frames=15, ease="inout", hold})` | Demo zoom onto a point; `hold` = absolute frame where it zooms back out (omit: stays in). Pixel-verified maths |
| `R.callout(tl, {at, len, label, pill={x,y}, boxes={{x1,y1,x2,y2,ax,ay}}, track, size, font, drift})` | After `dofile(R.effects .. "callout.lua")`: box + leader line + label pill on a carrier, in timeline px |
| `R.key(tool, input, {{frame, value}, ..., ease = "out"})` | Keyframe any Fusion input (BezierSpline; XYPath for points). `ease` (or a 4th arg): `linear` (default), `smooth`, `inout`, `in`, `out`, `snap`, `back` (overshoot), `hold` (steps) or a CSS cubic-bezier `{x1, y1, x2, y2}`; `R.EASE` lists them. Frames from the item's first frame |
| `R.track(item, tool, input, file, {offset, size, stabilize, on})` | Key a point input to a `track.py` track (OpenCV): follow an object, `size` = also key a mask's Width/Height (face blur), `stabilize` = hold the object still, `on` = the carrier holding the tool when it isn't the tracked clip. `effects.md` §6 |
| `R.qualify(item, {r,g,b}, ccParams, {tol=0.08, soft=0.05, window=maskTool})` | Secondary by script: a ColorCorrector on pixels near one colour (sampled off a still), optionally inside a window. Returns cc, mask |
| `R.curve(item, {{in, out}, ...}, "rgb")` | Curves by script (Fusion ColorCurves, LUTBezier keys): S-curves, per-channel. Chains like `R.fx`. Per-range wheels: `R.fx(item, "ColorCorrector", {ShadowsBlueGain = 1.2, ...})` (`pages/color.md`) |
| `R.lut(items, "agent/moody.cube")` | LUT on node 1 (runs BEFORE later nodes). The path is relative to the master LUT folder. Custom curves: `prep.py lut curve --points ...` |
| `R.cdl(item, {slope={r,g,b}, offset, power, sat})` | ASC CDL on node 1 |
| `R.group(name, items, lut)` | Color group with a pre-clip LUT: one look for many clips |
| `R.volume(item, db)`, `R.fade(item, in, out)` | Clip gain (dB), fades (frames), audio or video |
| `R.normalize(tl, items, mode, target)` | Clip-gain loudness normalize ("EBU R128" -23, "YouTube", "True Peak"...) |
| `R.sync(cam, mic)` | Waveform-sync an external recorder to a camera clip |
| `R.markers(tl, frames, color, name)` | Beat / cue markers |
| `R.still` notes | Stills do NOT include the subtitle track (check captions in a render). The folder must already exist (the console can't mkdir; R.still errors otherwise). PNGs are uncompressed (about 6 MB at 1080p). Compare two stills from the shell: `compare -metric MAE a.png b.png null: 2>&1` prints `<abs> (<0..1>)`; average colour/luminance: `convert a.png -resize 1x1! -format '%[fx:luminance]' info:` |
| `R.seek(tl, rel)` | Move the playhead, retrying (the first move after a page switch can be dropped) |
| `R.still(tl, rel, png)`, `R.stills(tl, frames, dir, prefix)` | **The agent's eyes:** full timeline composite PNGs at timeline resolution (Edit page) |
| `R.storage()` | Media Storage roots (the only places renders may go) |
| `R.render({dir, name, format, codec, range, audio, preset, settings})` | Blocking render. Returns status, seconds, path. Default ProRes 422 HQ .mov. `settings` = any SetRenderSettings keys (e.g. subtitle burn-in) |
| `R.ser(v)`, `R.dump(tl)` | Readable dump of any API return / of a timeline. Lua tables can't hold nil, so `R.ser({a, nil, c})` silently drops the nil: check suspicious values one by one |
| `reload()` (bridge global) | Re-reads lib.lua into `R`. Call it after editing lib.lua (resolve-up does it when the bridge is already up) |

## Raw API

Per page, with what's verified on free: `pages/media.md`, `pages/edit.md` (timeline, Inspector properties, transitions, subtitles,
multicam), `pages/fusion.md` (Fusion + effects), `pages/color.md`, `pages/fairlight.md`, `pages/deliver.md`, `project-and-prefs.md`.
What works by API vs template vs GUI vs not at all: `capability-matrix.md`.

Tips:
- Wrap probes: `local ok, v = pcall(function() return {call()} end)`. Some calls return nothing at all (FlattenMulticam), and `tostring()` of nothing errors in LuaJIT.
- A method referenced without calling it (`x:Method and ...`) is a Lua syntax error: use `x.Method` to test that it exists.
- Enumerations are constants on `resolve` (`resolve.EXPORT_FCPXML_1_10`, `resolve.COMPOSITE_OVERLAY`, `resolve.MULTICAM_ANGLE_SYNC_IN`...).
  The .pyi stub lists them all.
