# Color page

Nodes, primaries, curves, qualifiers, windows, tracking, LUTs, groups, versions, gallery/DRX. **[L]** = verified on free 21.1.1 Linux.
Coordinates: 1854x1048 main window, default layout (screenshot first, `references/gui.md`).

## Which route for which job

| Job | Route | How |
|---|---|---|
| A look on many clips | API | `R.group(name, items, lut)` (color-group pre-clip LUT) [L]; `R.lut(items, "agent/moody.cube")` puts it on node 1, i.e. BEFORE later nodes (their gain can re-clip highlights). For a finishing look use the group's post-clip graph: `item:GetColorGroup():GetPostClipNodeGraph():SetLUT(1, lut)` [L] |
| Lift/gamma/gain/sat per node | API | `item:SetCDL({NodeIndex="2", Slope="1.2 1 0.8", Offset="0 0 0", Power="1 1 1", Saturation="1.1"})` on ANY node index, including GUI-made nodes [L]. Side effects: it rewrites that node's RGB wheels (Slope 1.35 / Offset 0.02 / Power 0.9 showed as Gain 1.38 / Lift 0.01 / Gamma 0.03) and sets its **Lum Mix to 0**, so later master (Y) wheel edits on that node do nothing |
| Any global curve / custom look | API via LUT | `prep.py lut curve --points "0:0.06,0.5:0.5,0.9:0.85,1:0.92" --out /opt/resolve/LUT/agent/soft.cube` (in:out points, same on R/G/B), then `p:RefreshLUTList()`, `SetLUT(node, "agent/soft.cube")` [L] |
| **Copy a full grade** (node tree, windows, qualifiers, curves) | **Template (DRX)** | Grade once in the GUI, `tl:GrabStill()`, `album:ExportStills({st}, dir, prefix, "drx")` (writes `<prefix>_<still number>.drx`, e.g. `look_1.1.1.drx`: `ls` the folder); later `item:GetNodeGraph():ApplyGradeFromDRX(path, 0)` [L]. **ApplyGradeFromDRX crashed Resolve once** (SIGSEGV on the first call, issued from the Color page seconds after the export; the retry from the Edit page worked): `R.save()` first, one clip per `rv` call. Inside one project prefer `src:CopyGrades({targets})` |
| Add nodes | GUI keys | Node editor focused: Alt+S serial, Shift+S before, Alt+P parallel, Alt+L layer, **Alt+C/Q/G/B = node with circle/linear/polygon/curve window** [L]. Once in four, an Alt+C node came out with an empty mask: check the Key palette (1168,692) or an on/off still pair before grading; `ResetAllGrades()` clears a broken tree |
| Temp, tint, contrast, pivot, sat, hue, wheels by number | GUI fields | Primaries palette number fields: `gui field X Y VALUE` [L] |
| Power window shape/position/softness | GUI fields | Window palette transform fields [L], then grade inside with SetCDL on that node [L]. **Pan/Tilt: 50/50 = centre, about 82 px per unit at 1080p, Pan up = right, Tilt up = up**: for a subject at frame fractions (x, y from top-left), Pan ≈ 50 + (x - 0.5)·23.4, Tilt ≈ 50 - (y - 0.5)·13.2. Soft 1: default 2.07; 2-4 is a normal feather, 8 shrinks the core to a dot. Off-frame windows fail silently (no change) |
| Track a window | GUI | Select the window node, seek to the clip's FIRST frame (it tracks from the playhead), then Tracker palette track forward (823,751) [L]. 60 frames take about 6 s; the tracked window moves in stills and renders. Prove it by stills with `SetNodeEnabled` on/off at the first and last frames. Leave the "Cloud Tracker" dropdown alone |
| Qualifier (HSL key) | GUI fields + API grade | New node (Alt+S), Qualifier palette (928,692), type the ranges with `gui field`, then `SetCDL` on that node: verified highlights-only darkening (bright pixels 236 → 96, darks 40.8 → 40.9); `GetToolsInNode` then lists "HSL Qualifier" [L] |
| Curves, per-range wheels, windows by script | API (Fusion) | `R.curve`, `ColorCorrector` ranges, masked corrections: section below [L] |
| Curves by hand, color warper, magic mask | GUI / template / Studio | Curves and warper are GUI drags: do them once, then DRX (global curves: `prep.py lut curve` or `R.curve`). Magic Mask = Studio (`CreateMagicMask` returns false) [L] |
| Compare / review | API | `R.still(tl, f, png)`; average colour: `convert x.png -resize 1x1! -format '%[pixel:p{0,0}]' info:` |
| Node readout | API | `g:GetNumNodes()`, `g:GetToolsInNode(i)` e.g. {Primary Balance, Saturation Hue & Lum Mix} or {Power Windows}, `g:GetNodeLabel(i)`, `g:GetLUT(i)` [L] |

## Grade by script in Fusion: curves, ranges, windows (no GUI) [L]
The Color page has no API for curves, wheels per range, qualifiers or windows, but the clip's Fusion comp does, and it renders in the timeline
and Deliver like a Color-page grade (Fusion runs BEFORE the Color page, so a Color-page LUT/CDL still sits on top). Verified 2026-11-01 by pixel means:
```lua
R.curve(item, {{0, 0.05}, {0.25, 0.18}, {0.75, 0.85}, {1, 0.97}})          -- S-curve, soft blacks/whites (contrast std 0.357 -> 0.374)
R.curve(item, {{0, 0}, {1, 0.5}}, "r")                                   -- one channel: red mean 0.541 -> 0.270 exactly, G/B untouched
-- lift / gamma / gain / contrast / saturation, master or per range (Shadows / Midtones / Highlights) and per channel:
R.fx(item, "ColorCorrector", {MasterRGBContrast = 1.1, MasterRGBGamma = 1.05, Saturation1 = 1.15})
R.fx(item, "ColorCorrector", {ShadowsBlueGain = 1.25, ShadowsRedGain = 0.85, HighlightsRedGain = 1.12, HighlightsBlueGain = 0.85})  -- teal/orange
--   measured: shadows R 0.051 -> 0.045, B 0.067 -> 0.079; highlights B 0.217 -> 0.190. Input names: <Master|Shadows|Midtones|Highlights><RGB|Red|Green|Blue><Gain|Lift|Gamma|Contrast|Brightness>
-- power window: any correction inside a soft mask (relight a face, darken a sky); track it with R.track (effects.md §6)
local cr = R.fx(item, "ColorCorrector", {MasterRGBGain = 1.35}); local e = item:GetFusionCompByIndex(1):AddTool("EllipseMask")
e:SetInput("Center", {0.25, 0.45}); e:SetInput("Width", 0.3); e:SetInput("Height", 0.45); e:SetInput("SoftEdge", 0.1); cr.EffectMask = e.Mask
--   measured: inside 0.558 -> 0.740, outside unchanged
-- global saturation: HueCurves with every Sat key set to the same value (keep the table's handles): x0.2 -> sat 0.095 -> 0.021
local hc = R.fx(item, "HueCurves"); local sp = hc.Sat:GetConnectedOutput():GetTool(); local k = sp:GetKeyFrames()
for _, v in pairs(k) do v[1] = 0.2 end; sp:SetKeyFrames(k, true)
```
- **Hue-selective changes (HueCurves with different values per hue) do nothing when set by script** (bit-identical output) [L]. Hue qualifiers:
  Color page GUI route below, or a keyer (Fusion `ChromaKeyer`/`DeltaKeyer`, untested) as the correction's EffectMask.
- Save a grade built this way as a preset (`R.save_fx({cc, cr}, path)`) and re-apply it to every clip of a scene with `R.fx(item, path)`.
- Whole-video looks are still best as a LUT (`R.lut`/`R.group`): one node, cheap, and it follows the project's colour management.

## API [L]
```lua
local g = item:GetNodeGraph()
g:SetLUT(1, "agent/moody.cube"); g:SetNodeEnabled(2, false); g:SetNodeCacheMode(1, 1); g:ResetAllGrades(); g:ApplyArriCdlLut()
g:ApplyGradeFromDRX(path, 0)      -- 0 no keyframes, 1 source TC aligned, 2 start frames aligned
item:AddVersion("look-b", 0); item:LoadVersionByName("look-b", 0); item:GetVersionNameList(0); item:RenameVersionByName(a, b, 0); item:DeleteVersionByName(n, 0)
item:SetClipColor("Orange"); item:SetColorOutputCache(0); item:ResetAllNodeColors()
local grp = p:AddColorGroup("cam-A"); item:AssignToColorGroup(grp); grp:GetPreClipNodeGraph(); grp:GetPostClipNodeGraph(); grp:GetClipsInTimeline(tl); p:DeleteColorGroup(grp)
local gal = p:GetGallery(); local al = gal:GetCurrentStillAlbum()       -- also CreateGalleryStillAlbum / CreateGalleryPowerGradeAlbum / SetAlbumName
local st = tl:GrabStill(); al:SetLabel(st, "hero"); al:ExportStills({st}, dir, "look", "drx"); al:ImportStills({path.drx}); al:DeleteStills({st})
tl:GrabAllStills(1)               -- one still per clip
```
- `AddVersion(name, 0)` makes the new version current with a BLANK one-node grade (not a copy). `ResetAllGrades()` also deletes extra nodes.
  `GetToolsInNode` returns nil for an empty node. `ApplyGradeFromDRX` switches to the Color page. `ExportStills(..., "drx")` writes only the .drx.
- **Timeline-level node graph has 0 nodes** and the API can't add nodes; use color-group pre/post graphs or clip nodes.
- `SetLUT` paths are relative to the master LUT folder (`/opt/resolve/LUT` on Linux) and need `p:RefreshLUTList()` after adding files. `ExportLUT` returns false.
- DRX = XML wrapper with a zstd-compressed (probably protobuf) `<Body>`: **not hand-authorable**. Stills live in `~/Videos/.gallery`.
- **DCTL**: a DCTL used as a LUT renders on free but with a big "DaVinci Resolve Studio" **watermark** [L]. Don't ship DCTL looks; bake .cube LUTs.
- `item:Stabilize()` works on free, no watermark [L] (it lives in the Color page's tracker/stabilizer).
- Free-edition limits: no Magic Mask, no noise reduction (Studio), max UHD 60p timelines.

## GUI how-to [L]
| Element | Where |
|---|---|
| Open | `resolve:OpenPage("color")` or Shift+6 |
| Clips strip | Thumbnails at y=540, x = 70 + 136*i (click to make a clip current) |
| Node editor | Top-right; click empty area (1500,350) to focus it before node shortcuts |
| Palette buttons (y=692, each verified by its title) | Left palette: Camera Raw 31, Color Match 90, **Primaries 149**, HDR 208, RGB Mixer 269, Motion Effects 330. Centre palette: **Curves 747**, ColorSlice 806, Color Warper 868, **Qualifier (HSL) 928**, **Window 988**, **Tracker 1048**, Blur 1106, Key 1168, Sizing 1228. Scopes 1765. No Magic Mask button on free |
| Primaries fields | Temp (171,750), Tint (289,750), Contrast (408,750), Pivot (529,750), Mid/Detail (647,750); Lift/Gamma/Gain/Offset values row y=924 (Lift x=31..145, Gamma 203..317, Gain 375..489, Offset 553..653); Col Boost (91,996), Shad (202,996), Hi/Light (313,996), Sat (425,996), Hue (536,996), L.Mix (647,996). The title "Primaries - Color Bars" is the display mode, not the clip |
| Qualifier palette (HSL) | Hue: Center (860,838), Width (955,838), Soft (1048,838), Sym (1145,838). Saturation: Low (860,911), High (955,911), L.Soft (1048,911), H.Soft (1145,911). Luminance: Low (860,984), High (955,984), L.Soft (1048,984), H.Soft (1145,984). Hue/Sat/Lum on-off toggles at x=715, y=791/864/936 (all on by default; Hue 50/100 and Sat 0/100 = everything). Matte finesse fields at x≈1340 (Pre-Filter 811 ... In/Out Ratio 985). Eyedropper (720,752) |
| Windows palette | Linear/Circle/Polygon/Curve/Gradient buttons on the top row; shape list; Transform: Size (1220,772), Aspect (1342,772), Pan (1220,800), Tilt (1342,800), Rotate (1220,828), Opacity (1342,828); Soft 1 (1220,887) |
| Tracker palette | Track forward (823,751); Pan/Tilt/Zoom/Rotate/3D toggles; "Clip / Frame" mode |
| Viewer tools | Highlight Shift+H, bypass grades Shift+D, wipe Ctrl+W, window outline Alt+H |
| Versions / memories | Ctrl+Y add version, Ctrl+N/B next/prev, Alt+1..8 save memory A..H |

## Recipe: GUI grade into a reusable look file
1. `resolve:OpenPage("color")` (again after every `R.still`, which leaves you on the Edit page). Make a clip current (thumbnail click). Build nodes with keys
   (Alt+S, Alt+C), set fields (`gui field`), and add a window, qualifier or curve.
2. `rv 'local st = R.tl():GrabStill(); R.project():GetGallery():GetCurrentStillAlbum():ExportStills({st}, "<dir>", "mylook", "drx")'`
3. Keep `mylook_<still number>.drx` with the project's assets; apply with `ApplyGradeFromDRX(path, 0)` one clip per call after `R.save()`, on any clip, any project. Verify with `R.still`.
