# Fusion page + effects (applying any effect to a clip)

Fusion is fully scriptable from the console (`comp:AddTool`, inputs, keyframes, expressions, macros), so for agents this is the effects
engine for every page. **[L]** = verified on free 21.1.1 Linux.

## Apply ANY effect: `R.fx(item, id, params)` [L]
```lua
R.fx(item, "ofx.com.blackmagicdesign.resolvefx.Glow", {brightness = 0.6})  -- any of the 53 ResolveFX on free
R.fx(item, "FilmGrain", {MasterStrength = 0.15})                          -- any Fusion tool (about 500 in the registry)
R.fx(item, R.templates .. "Edit/Effects/CCTV.setting")  -- any macro/template .setting: built-in (unpacked by install.sh), Reactor, your own
local carrier = R.place(tl, R.carrier(tl), {track = 2, at = 120, len = 60, media = "video"})[1]  -- transparent clip for overlays
local _, comp = R.fx(carrier, R.templates .. "Edit/Titles/Headline.setting")       -- title/generator templates go on a carrier
comp:FindToolByID("TextPlus"):SetInput("StyledText", "hacktober")
R.fx(item, "Transform", {Size = {{0, 1.2}, {8, 1.0}}})                     -- {{frame, value}, ...} = keyframes
print(R.inputs(tool))   -- the tool's own params with current values (skips the common Settings page)
```
- Repeat calls chain the effects (each one is spliced just before MediaOut1). Returns `tool, comp`.
- Param IDs: `references/effects-catalog.tsv` (every ResolveFX on free with params and defaults) or `R.inputs(tool)`. **`SetInput` on a wrong
  ID is silently ignored**; R.fx asserts the ID exists.
- Proof: always `R.still()` before and after, because a broken chain renders BLACK, not an error. Measure from the shell:
  `compare -metric MAE before.png after.png null: 2>&1` (the number in brackets is 0..1; above about 0.01 means a visible change).

### Why R.fx is built the way it is (each one cost a black or wrong frame)
| Trap | Fix in R.fx |
|---|---|
| **ResolveFX take the image on `Source`, not `Input`**: wiring `t.Input` leaves them unconnected, so the frame is black | `tool:FindMainInput(1)` (Source, Input, Background or MainInput1) |
| Macros/groups output on `MainOutput1`; `mo.Input = t.Output` connects nothing, so the frame is black | `mo.Input:ConnectTo(tool:FindMainOutput(1))` |
| **`comp:Paste(settings)` returns false unless that comp is open in the Fusion page** | seek the playhead onto the clip (SetCurrentTimecode is ignored ON the Fusion page, so seek first), `OpenPage("fusion")`, wait until `fusion:GetCurrentComp() == comp`, paste, go back |
| `bmd.readstring(s, extra)` returns nil (`assert()` passes 2 values!), and **`Paste(nil)` pastes the CLIPBOARD**: the previous template, silently | read into a local first, call readstring with one argument, check `.Tools` |
| No `bmd.readfile`/`io` in the console | `R.readfile(path)` (ffi + libc) |
| Templates paste several top-level tools, and Fusion may auto-connect them to MediaOut | the output tool = the pasted tool that no OTHER pasted tool reads from |
| Generators/titles have no main input | their output simply replaces the picture (use a carrier clip for overlays) |

## Speed ramps (verified frame-exact) [L]
```lua
-- SourceTime = which source frame (relative to the clip's source IN) to show at each item frame; Fusion splines between keys
R.fx(item, "TimeStretcher", {SourceTime = {{0, 0}, {30, 15}, {60, 22}, {89, 80}}})   -- normal -> slow-mo -> hold-ish -> fast
```
Matched against source frames: item frames 30/60/89 showed source +15/+22/+80 exactly. Source frames beyond the item's own range are
available (the comp's global range spans the whole source clip), but keep them inside the media. Frames between keys are blended
(`InterpolateBetweenFrames`); for true slow motion from 30p, shoot high frame rate or accept the blend.
**Don't use TimeSpeed for ramps**: its Speed is integrated from the comp's GLOBAL start (whole-source range), so timeline frame 0 showed
source +100 instead of +0 [L].

## What's available on free [L]
- **53 OFX** (52 ResolveFX + Color Generator). Pixel test at defaults: 41 visibly change the frame; 12 are identity until set (keyers,
  Dead Pixel Fixer, Transform, CST, Gamut, Stop Motion, Despill). Burn Away is a transition (SourceFrom/SourceTo). List: `effects-catalog.tsv`.
  Categories: Blur (Box, Directional, Gaussian, Mosaic, Radial, Zoom), Color (ACES, CST, Chromatic Adaptation, Color Compressor, Gamut
  Mapping/Limiter, Invert, Despill), Film Emulation (Camera Shake, Film Damage, Flicker Addition), Generate (Color Palette, Grid), Key
  (3D/HSL/Luma Keyer, Shrink and Grow), Light (Glow, Light Rays), Revival (Dead Pixel Fixer, Deband), Stylize (Abstraction, Blanking Fill,
  Drop Shadow, Edge Detect, Emboss, Mirrors, Prism Blur, Scanlines, Watercolor, Burn Away), Temporal (Stop Motion), Texture (JPEG Damage),
  Transform (Transform, Picture In Picture, Video Collage), Warp (Dent, Ripples, Vortex, Waviness).
  Studio-only ResolveFX (Lens Flare, Film Look Creator, Noise Reduction, Face Refinement...) don't exist on free.
- **About 500 Fusion tools**: `resolve:Fusion():GetRegList(1)` (attrs REGS_ID/REGS_Name/REGS_Category). 142 Krokodove tools, particles (pEmitter...),
  3D, Text+, Merge, Transform, Glow/SoftGlow, FilmGrain/Grain, Shake/CameraShake, DirectionalBlur, VectorMotionBlur, Defocus, Displace,
  FastNoise, TimeSpeed/TimeStretcher (speed ramps: the comp sees the whole source range), Tracker/PlanarTracker, masks (Ellipse, Rectangle,
  Polygon, BSpline), keyers (ChromaKeyer, DeltaKeyer, UltraKeyer).
- **417 templates** in `/opt/resolve/Fusion/Templates/Templates.drfx` (a zip; install.sh unpacks it to `~/resolve-bridge/templates/` = `R.templates`): Edit/Effects (Binoculars,
  CCTV, DSLR, DVE, Repeat, Slice, Watermark), Edit/Titles (25: Headline, Pow!!, Glass, Candy, Lift...), Edit/Transitions (16 Fusion transitions),
  Edit/Generators (Contours, Honeycomb, Paper, Squares, Starfield), Fusion/{Backgrounds, Particles, Shaders, Looks}. Verified: CCTV, Watermark,
  Binoculars, DVE, Headline (custom text).
- OGraf HTML title templates (21.x) need WebKit/CEF: macOS/Windows only per the developer docs; not on Linux.

## Raw Fusion API [L]
| Call | Notes |
|---|---|
| `item:AddFusionComp()`, `GetFusionCompByIndex(1)`, `GetFusionCompCount()`, `GetFusionCompNameList()`, `GetFusionCompByName`, `RenameFusionCompByName`, `DeleteFusionCompByName` | A comp starts with `MediaIn1` and `MediaOut1`; comp frame 0 = the item's first frame |
| `comp:AddTool(id)`, `comp:FindTool(name)`, `comp:FindToolByID(id)`, `comp:GetToolList(selectedOnly)`, `tool:Delete()` | |
| Connect: `merge.Background = mi.Output`, `input:ConnectTo(output)`; read: `input:GetConnectedOutput()`, `output:GetConnectedInputs()` | |
| `tool:SetInput(id, v)`, `tool:GetInput(id, frame)`, `tool[id][frame] = v` | Text+: `StyledText`, `Font`, `Style`, `Size`, `Center` {x,y} 0..1 **y up**, `Red1/Green1/Blue1`, `CharacterSpacing`, `Enabled2..8` shading elements |
| Keyframes: `tool:AddModifier("Size", "BezierSpline"); tool.Size[0] = 2; tool.Size[8] = 1` (XYPath for Center) | `R.key(tool, input, {{f, v}, ...})` |
| Expressions: `tool.MasterStrength:SetExpression("0.3 + 0.2*sin(time/3)")`, `GetExpression()` | [L] |
| `tool:SaveSettings(path.setting)` / `tool:LoadSettings(path)`; `comp:Paste(bmd.readstring(text))` (Fusion page only) | Turn anything built in Fusion into a reusable template |
| `item:ExportFusionComp(path, 1)` / `item:ImportFusionComp(path)` | Whole comp as .comp (R.template uses it) |
| `tool:FindMainInput(1)`, `tool:FindMainOutput(1)` | Use these instead of guessing names |
| Input attrs: `INPS_ID`, `INPS_Name`, `INPS_DataType` (Image/Mask/Number/Point/Text...), `INPS_ICS_ControlPage` ("Common" = shared Settings page) | |
| `resolve:Fusion().FontManager:ScanDir(dir)` / `GetFontList()` | Fusion only scans /usr/share/fonts; the bridge rescans ~/.local/share/fonts |
- **Never `comp:Lock()`**: values read back fine but nothing renders.
- A comp only renders on the timeline/Deliver: grab with `R.still` (Edit page). `ExportCurrentFrameAsStill` fails on the Fusion page.

## Transitions (Edit-page API, includes Fusion transitions) [L]
`item:AddTransition({type, category, position = "start"|"end", alignment = "left"|"center"|"right", duration})`:
- simple (30): "Cross Dissolve", "Additive Dissolve", "Blur Dissolve", "Dip To Color Dissolve", "Non-Additive Dissolve", "Smooth Cut",
  "Arrow Iris", "Cross Iris", "Diamond Iris", "Eye Iris", "Hexagon Iris", "Oval Iris", "Pentagon Iris", "Square Iris", "Triangle Iris",
  "Barn Door", "Push", "Slide", "Split", "Box", "Heart", "Star", "Band Wipe", "Center Wipe", "Clock Wipe", "Edge Wipe", "Radial Wipe",
  "Spiral Wipe", "Venetian Blind Wipe", "X Wipe".
- fusion (18): Circles, Cube, Disarrange, Edgy, Fold, Glitch, Glow, Mosaic, Perspective, Posterize, Radial, Rotate, Shash, Shatter, Spin, Warp, Zoom In, Brightness Flash.
- ofx (1): Burn Away. A wrong category returns nil. **Center alignment needs source handles on both clips** (nil otherwise).

## Tracking in Fusion
The Tracker tool adds fine by script (`R.fx(item, "Tracker")`; inputs PatternCenter1/Width1/Height1, outputs Position1, SteadyPosition...), but
**`SetInput("TrackForward", 1)` does nothing**, even with the comp open in the Fusion page: no keyframes, TrackedCenter1 stays at its default [L].
In the Fusion page GUI (Inspector > Trackers tab, Tracking buttons at about (1620-1760, 222-250)) the buttons stayed greyed out and both viewers
black in our session (unverified route). Working routes: the Color page tracker for window grades (`pages/color.md`, verified); or track outside
Resolve (e.g. OpenCV in a uv script) and write the path as keyframes with `R.key(tool, "Center", {{f, {x, y}}, ...})` (untested idea).

## Fusion page GUI (rarely needed)
Shift+5 or `resolve:OpenPage("fusion")` shows the comp of the clip under the playhead (seek BEFORE switching). Nodes, Inspector and keyframes
are all reachable by script, so use the GUI only to look: `gui shot`.
