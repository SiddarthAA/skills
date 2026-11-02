# Effects cookbook: how to make the usual edit effects in free Resolve (all verified)

Every recipe here was built by script, rendered and checked on stills (before/after MAE) on free 21.1.1 Linux. **[L]** = verified.
Mechanics of `R.fx` (wiring, templates, ResolveFX inputs): `pages/fusion.md`. Helpers: `references/api.md`.

## 0. Pick the route
| You want | Use |
|---|---|
| A ready-made look/move on a clip (glitch, VHS, punch zoom...) | **A preset**: `R.fx(item, R.effects .. "<name>.setting")` (§1). Keys start at the clip's first frame |
| A transition between two clips | `outgoing:AddTransition({type = "<name>", category = "fusion"/"simple", ...})`: **98 by API** (§3) |
| A styled title / lower third | `R.title(tl, {..., anim = ...})` (§4) or one of the ~120 title templates on a carrier |
| Something custom | `R.fx` tools + `R.key` (keyframes with easing, §2), then `R.save_fx` it into your own preset (§8) |
| One effect over several clips (a whole section, a cut) | `tl:CreateCompoundClip(items, {name = "x"})`, then `R.fx` on the compound item [L]. Adjustment clips can't be placed by script (the Insert* calls ripple V1) |
| Follow a moving object / blur a face | `track.py` + `R.track` (§6) |
| A whole-video look (grade, LUT) | Color page: `pages/color.md` (R.lut, R.cdl, R.group, DRX) |

## 1. Ready-made presets (`assets/fx/`, `R.effects`) [L]
`R.fx(item, R.effects .. "glitch.setting")`. Each was built with the code in §5, saved with `R.save_fx`, re-applied from the file to
a second clip and pixel-checked. Chain several: each call splices in before MediaOut. Tweak after applying: `comp:FindToolByID("Transform")`,
or rebuild from §5 with other numbers.

| Preset | What it does | Main knobs |
|---|---|---|
| `zoom-punch` | 135% -> 100% in 6 frames, snap ease, motion blur (beat hits, cuts) | Transform Size keys |
| `push-in` | slow 100% -> 112% over 90 frames, smooth (Ken Burns); retime keys for longer clips | Transform Size keys |
| `impact-shake` | decaying 13-frame jitter + small zoom (impacts, drops) | Transform Center keys |
| `handheld` | continuous gentle camera shake, scaled 106% so edges never show | CameraShake Overall Strength |
| `flicker` | unstable light / old film brightness flicker (ResolveFX Flicker Addition) | flickerRange, flickerSpeed |
| `strobe` | hard 2-on/2-off brightness strobe (expression) | `Gain` expression |
| `flash-in` | starts blown-out white, settles in 8 frames | BrightnessContrast Gain keys |
| `rgb-split` | constant chromatic offset (red right, blue left) | KD_ChannelShifter Center1/Center3 |
| `glitch` | 12-frame glitch burst: jumping RGB split, jolts, JPEG blocks, then clean | the key tables |
| `vhs` | horizontal smear, colour bleed, fine scanlines, grain, faded colour | Blur X, ScanlineV2 frequency |
| `film-look` | light grain + soft oval vignette | FilmGrain Strength, Vignette size |
| `letterbox` | 2.39:1 black bars (16:9 timelines) | RectangleMask Height |
| `black-white` | punchy black and white | Saturation 0, Contrast |
| `glow` | soft bloom on highlights | SoftGlow Threshold/Gain |
| `light-leak` | procedural warm light leak drifting across, screened over the clip | FastNoise colours, Merge Blend |
| `blur-region` | blurred ellipse (faces, plates); move or track its Center (§6) | EllipseMask Center/Width/Height |
| `zoom-blur-in` | rushes in from 150% through a radial zoom blur | Transform Size, ZoomBlur blend keys |
| `lower-third` | name bar: red bar wipes open + text slides up (apply to a CARRIER) | Text: `comp:FindToolByID("TextPlus")`; move: carrier Pan/Tilt |

Built-in templates (`R.templates`, unpacked by install.sh) add more, applied the same way:
- **Effects** (`Edit/Effects/<name>.setting`, on the clip): Hologram Glitch, Night Vision, Video Call (window frame), Pen Stroke Circle/Arrow/Line
  (hand-drawn annotation), Drone Overlay (HUD), CCTV, Binoculars, DSLR, DVE, Watermark, Slice, Repeat, Highlight Stretch, Stretch Region, Noise
  Distortion, Energy Mask, Paper Edge, Colored Border, Outer Stroke, Arrow Name, Flying Flag, Graphic Cross/Shape Overlay, Shape Circle, Video Camera.
  Checked on stills [L]: Hologram Glitch, Night Vision, Video Call, Pen Stroke Circle, Drone Overlay, CCTV, Binoculars, DVE, Watermark.
  **Comic Book renders BLACK and Digital Glitch fails R.still** [L]: avoid them.
- **Titles** (`Edit/Titles/<name>.setting`, on a carrier, ~120): lower thirds (Clean and Simple, Digital Glitch, Text Box Swipe In, Simple Box
  2 Lines, Callout Title Left/Right, Drop In, Fade On, Flip Up, Lift, Jitter, Scale Up, Vertical Reveal... "Lower Third" variants), headline styles
  (Neon Flicker, Pow!!, Rise Fade, Statement, Long Shadow, Ink Bleed, Random Write On, Headline, Glass, Retro Chrome, Superhero, Rolling Text...).
  Set every text: `for _, t in pairs(comp:GetToolList(false, "TextPlus")) do t:SetInput("StyledText", "...") end` (some have 2 lines). 12 tested [L].
- **Generators** (`Edit/Generators/`, on a carrier, full-frame backgrounds): Abstract Mesh, Gradient Lines, Honeycomb, Neo Future, Paper, Soft Waves,
  Starfield, Squares, Vintage Texture...

## 2. Keyframes, easing, expressions [L]
```lua
local x = R.fx(item, "Transform")
R.key(x, "Size", {{0, 1.35}, {6, 1.0}, ease = "snap"})          -- frames from the clip's first frame
R.key(x, "Center", {{0, {0.5, 0.5}}, {20, {0.6, 0.5}}}, "inout")   -- points: {x, y}, 0..1, y UP
R.key(x, "Angle", {{0, 0}, {10, 15}, {20, 0}, ease = {0.68, -0.6, 0.32, 1.6}})   -- any CSS cubic-bezier
```
| `ease` | Feel | Value at 1/3 of a 1 -> 2 move |
|---|---|---|
| (none) / `linear` | constant speed (Fusion's default for scripted keys) | 1.33 |
| `smooth` | Fusion "smooth" (flat handles) | 1.26 |
| `inout` | CSS ease-in-out: soft start and end | 1.23 |
| `in` / `out` | accelerate / decelerate | - / 1.49 |
| `snap` | very fast start, long settle (punches, slides) | 1.90 |
| `back` | overshoots then settles (1.0 -> 2.085 -> 2.0) | 1.96 |
| `hold` | jumps: keeps each value until the next key (glitch steps, word-by-word) | 1.0 |
- How it works: Fusion Bezier handles are RELATIVE to their key in `GetKeyFrames`/`SetKeyFrames` (`RH = {dframes, dvalue}`), but `.setting`
  files store them ABSOLUTE. Hold = `Flags = {StepIn = true}` on the LATER key. A Center/point input animates through an XYPath whose X and Y
  splines are eased separately (R.key does both).
- **Expressions** (no keys): `tool.Gain:SetExpression("iif(time % 4 < 2, 1, 0.25)")` (strobe), `"0.3 + 0.2*sin(time/3)"` (pulse),
  `txt.StyledText:SetExpression("Text(floor(min(time/30, 1)*1000))")` (counter 0 -> 1000 in 1 s). `time` = comp frame.
- Edit-page Inspector keyframes (the diamond buttons) have no API: animate in the clip's Fusion comp instead; it renders the same.
- **Keyframing a ResolveFX param live doesn't render** (it reads back right but renders the static value). `R.fx(item, "ofx...", {blend = {{0,0},{8,1}}})`
  handles it (it saves and re-pastes the tool); after a manual `R.key` on a ResolveFX do `R.save_fx({tool}, p)`, delete it, `R.fx(item, p)`.

## 3. Transitions: 98 by API [L]
`outgoing:AddTransition({type = name, category = "fusion"|"simple"|"ofx", position = "end", alignment = "center"|"left"|"right", duration = 12})`
on the clip BEFORE the cut (centre needs source handles on both clips). All 67 Fusion templates below returned a transition, and 12 were checked
mid-transition on stills.
| Use | Fusion templates (`category = "fusion"`) |
|---|---|
| Whip / swipe | **Pan Left, Pan Right, Pan Up, Pan Down** (whip pans with blur; the image mirrors mid-whip, so avoid them over text), Slide Left/Right/Up/Down, Slice Push, Slide and Hold |
| Zoom / speed | **Crash Zoom**, Zoom In, Zoom In and Out, Stretch Blur, Tunnel of Light |
| Flash | **Brightness Flash**, Inverse Flash, Three Color Flash, Glow |
| Glitch / digital | **Glitch**, Block Glitch, RGB Splitter, Shash, Posterize, Mosaic, Mosaic Center/Edge Wipe, Mosaic Dissolve, Noise Dissolve, Detail Dissolve |
| Energy / bounce | Camera Shake, Pop Wobble, Pop Wobble Reverse, Elastic Rubber, Fall and Bounce, Drop Warp, Ripple Warp, Warp |
| 3D / geometric | Cube, Flip 3D, Fold, Box Twist, Rotate, Rotate 90, Spin, Circle Spin, Round and Down, Perspective, Page Curl, Film Strip, Shatter, Disarrange, Edgy |
| Wipes / shapes | Box Wipe, Checker Wipe, Circles, Multi Circle Wipe, Horizon Reveal, Luma Wipe, Logo Wipe, Shape Transition, Tile Wipe, Vee Wipe, Radial, Foreground Wipe, Paint On |
| Dissolve | Cross Dissolve |
Simple (`category = "simple"`, 30): Cross/Additive/Blur/Dip To Color/Non-Additive Dissolve, Smooth Cut, 9 irises, Barn Door, Push, Slide, Split,
Box, Heart, Star, 8 wipes (list in `pages/fusion.md`). OFX: Burn Away. Rule of thumb: hard cuts on the beat; one transition family per video;
8-12 frames for whips/flashes, 15-20 for dissolves.

## 4. Titles and text animation [L]
```lua
R.title(tl, {text = "LAUNCH DAY", at = 30, len = 60, size = 0.12, anim = "rise", speed = 2})
```
| `anim` | Effect | How |
|---|---|---|
| `pop` (default) | scales in from 145% in 5 frames | Size keys, ease out |
| `fade` | fades in over 8 frames | Merge Blend |
| `type` | typewriter, `speed` frames for the line (default 1 char/frame) | Text+ Write On `End` 0 -> 1 (layout doesn't reflow) |
| `words` | word by word, on `word_at` frames (spoken timing from `captions.py --json`) or `speed` frames apart | `End` jumps to each word's end, hold keys |
| `rise` | letters rise and fade in one after another, `speed` frames apart | Follower modifier: `CharacterOffset` + `Opacity1` keys, `Delay` |
| `slide` | slides up into place and fades in | Center keys (snap) + Blend |
- Exit: `R.fade(item, 0, 8)` fades the title clip out (Edit-page fade).
- Per-character anything: `txt:AddModifier("StyledText", "StyledTextFollower")`; the Follower then holds the text (`fo:SetInput("Text", s)`), and
  its inputs (`CharacterOffset`, `CharacterSizeX/Y`, `CharacterAngleZ`, `Opacity1`, `Red1`...) animate each character `Delay` frames apart.
- Counter / ticker: the StyledText expression in §2. Lower third with a bar: the `lower-third` preset (§1) or §5's code.
- Word-pop captions from a transcript: `recipes.md` (talking head) + `transcribe.py`.

## 5. How each preset is built (copy, change the numbers, R.save_fx)
```lua
local OFX = "ofx.com.blackmagicdesign.resolvefx."
-- zoom-punch
local x = R.fx(it, "Transform", {MotionBlur = 1, Quality = 8, ShutterAngle = 180}); R.key(x, "Size", {{0, 1.35}, {6, 1.0}, ease = "snap"})
-- handheld
R.fx(it, "CameraShake", {XDeviation = 0.12, YDeviation = 0.12, RotationDeviation = 0.08, Speed = 0.35, OverallStrength = 0.25}); R.fx(it, "Transform", {Size = 1.06})
-- flicker
R.fx(it, OFX .. "FlickerAddition", {flickerRange = 0.6, flickerSpeed = 2, flickerRand = 0.8})
-- strobe
R.fx(it, "BrightnessContrast").Gain:SetExpression("iif(time % 4 < 2, 1, 0.25)")
-- flash-in
local bc = R.fx(it, "BrightnessContrast"); R.key(bc, "Gain", {{0, 5}, {8, 1}, ease = "out"}); R.key(bc, "Saturation", {{0, 0}, {8, 1}, ease = "out"})
-- rgb-split
R.fx(it, "KD_ChannelShifter", {Center1 = {0.508, 0.5}, Center3 = {0.492, 0.5}})
-- vhs
R.fx(it, "Blur", {LockXY = 0, XBlurSize = 2.5, YBlurSize = 0.3}); R.fx(it, "KD_ChannelShifter", {Center1 = {0.503, 0.5}, Center3 = {0.497, 0.5}})
R.fx(it, OFX .. "ScanlineV2", {frequency = 40, width = 0.4, blend = 0.8}); R.fx(it, "FilmGrain", {MasterStrength = 0.06, Monochrome = 1})
R.fx(it, "BrightnessContrast", {Saturation = 0.7, Contrast = -0.08, Lift = 0.04})
-- film-look
R.fx(it, "FilmGrain", {MasterStrength = 0.06}); R.fx(it, OFX .. "Vignette", {size = 0.8, softness = 0.8, transparency = 0.45})
-- letterbox: zero-gain BrightnessContrast outside an inverted rectangle
local bc = R.fx(it, "BrightnessContrast", {Gain = 0, Lift = 0}); local rc = it:GetFusionCompByIndex(1):AddTool("RectangleMask")
rc:SetInput("Width", 1.2); rc:SetInput("Height", (16 / 9) / 2.39); rc:SetInput("Invert", 1); bc.EffectMask = rc.Mask
-- glow / black-white
R.fx(it, "SoftGlow", {Threshold = 0.6, Gain = 1.5, XGlowSize = 25}) ; R.fx(it, "BrightnessContrast", {Saturation = 0, Contrast = 0.2})
-- light-leak: FastNoise (Detail 0, Contrast 1.6, XScale 0.6, SeetheRate 0.05, Color2 = orange) as Foreground of a Screen Merge, Center keyed across
local n = it:GetFusionCompByIndex(1):AddTool("FastNoise"); --[[ set inputs as listed ]] local m = R.fx(it, "Merge", {ApplyMode = "Screen", Blend = 0.75}); m.Foreground = n.Output
-- blur-region: Blur (XBlurSize 40) masked by an EllipseMask (EffectMask)
-- zoom-blur-in
local x = R.fx(it, "Transform"); R.key(x, "Size", {{0, 1.5}, {8, 1.0}, ease = "out"})
R.fx(it, OFX .. "ZoomBlur", {blend = {{0, 0}, {8, 1}, ease = "out"}})      -- ResolveFX blend: 0 = full effect, 1 = original
```
Every builder (incl. impact-shake, glitch, light-leak, lower-third) is in `assets/fx/build.lua`:
`dofile(R.effects .. "build.lua"); local tools = FX.b["glitch"](item)` builds it live; change numbers there and `R.save_fx` a variant.

## 6. Tracking: follow an object, blur a face, stabilize on a point [L]
Fusion's Tracker can't be run by script on free (`pages/fusion.md`), so track outside Resolve with OpenCV and write keyframes:
```bash
track.py src.mov --face --at 60 --end 150 --out ~/videos/p/face.lua      # biggest face at source frame 60 (Haar), CSRT tracker
track.py src.mov --box 1350,380,140,160 --at 60 --out ~/videos/p/ball.lua  # or a box: x,y,w,h in source pixels (or fractions)
```
LOOK at the `.jpg` it writes (6 frames with the box drawn). Frames are SOURCE frames (the clip's `GetSourceStartFrame()` numbering).
```lua
-- face blur that follows: ellipse sized to the tracked box (x1.3)
local b = R.fx(item, "Blur", {XBlurSize = 30}); local e = item:GetFusionCompByIndex(1):AddTool("EllipseMask"); b.EffectMask = e.Mask
R.track(item, e, "Center", "/abs/face.lua", {size = 1.3})
-- label that follows, on a title carrier above the clip (on = the carrier)
local car, _, txt = R.title(tl, {text = "CEO", at = 10, len = 70, anim = "none"})
R.track(item, txt, "Center", "/abs/face.lua", {offset = {0, 0.12}, on = car})
-- stabilize on the object (it stays where it was on the first tracked frame); scale up to hide the edges
local x = R.fx(item, "Transform", {Size = 1.1}); R.track(item, x, "Center", "/abs/face.lua", {stabilize = true})
```
- Verified on handheld footage: 91/91 frames tracked in ~13 s; the blur and the label stayed on the face.
- Whole-shot camera shake: `item:Stabilize()` (Edit-page stabilizer, works on free) is simpler. Color-page window tracking: `pages/color.md`.
- `--face` finds frontal faces only; otherwise give `--box` from a still (`prep.py still`, then read the pixel box). Lost frames are skipped
  (Fusion interpolates). Fast motion blur or occlusion: track a shorter range, or split and re-init.

## 7. Speed, composites, overlays [L]
```lua
R.fx(item, "TimeStretcher", {SourceTime = {{0, 0}, {30, 30}, {89, 30}, ease = "hold"}})   -- freeze frame from frame 30 (verified identical)
R.fx(item, "TimeStretcher", {SourceTime = {{0, 89}, {89, 0}}})                            -- reverse (frame 0 = the last source frame)
R.fx(item, "TimeStretcher", {SourceTime = {{0, 0}, {30, 15}, {60, 22}, {89, 80}}})        -- speed ramp (pages/fusion.md)
-- split screen 50/50, each clip's centre: crop in source pixels, pan in timeline pixels
left:SetProperties({Pan = -480, CropRight = 480}); right:SetProperties({Pan = 480, CropLeft = 480})   -- right clip on V2
-- picture in picture with a shadow: scale INSIDE Fusion (Edit-page zoom happens after the comp, so a shadow there falls outside the PiP)
R.fx(pip, "Transform", {Size = 0.35, Center = {0.78, 0.75}}); R.fx(pip, "ofx.com.blackmagicdesign.resolvefx.DropShadow")
-- overlay footage (light leak, dust, grain clip) on V2 with a blend mode
overlay:SetProperties({CompositeMode = resolve.COMPOSITE_SCREEN, Opacity = 70})   -- also COMPOSITE_ADD, _MULTIPLY, _OVERLAY ...
-- callout (box + leader line + label pill): dofile(R.effects .. "callout.lua"); R.callout(tl, {...})   (recipes.md B) [L]
-- green screen: the green clip on a track ABOVE the background; DeltaKeyer with the screen colour sampled from a frame
-- (ffmpeg -ss 1 -i g.mov -frames:v 1 -vf "crop=40:40:60:60,scale=1:1" -f rawvideo -pix_fmt rgb24 - | od -An -tu1)  [L, E2E 2026-11-03: no fringe, no holes]
R.fx(green, "DeltaKeyer", {BackgroundRed = 102/255, BackgroundGreen = 221/255, BackgroundBlue = 9/255, SpillMethod = "Medium", LowThreshold = 0.15, HighThreshold = 0.75})
```

## 8. Make your own preset
Build it on any clip with `R.fx`/`R.key`, check it on stills, then
```lua
R.save_fx({tool1, tool2, tool3}, "/abs/my-effect.setting")   -- tools in chain order, with their keys and modifiers
R.fx(other_item, "/abs/my-effect.setting")                    -- R.fx wires the chain head to the picture and the tail to MediaOut
```
Branches (a tool that reads the picture twice) need a pass-through head: start the chain with `R.fx(it, "PipeRouter")` and read from it.
Keys are in frames from the clip's start: an effect meant for a clip's END needs its keys moved (or put it on the next clip's start).
