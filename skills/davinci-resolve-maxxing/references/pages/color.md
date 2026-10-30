# Color page

Nodes, primaries, curves, qualifiers, windows, tracking, LUTs, groups, versions, gallery/DRX. **[L]** = verified on free 21.1.1 Linux.
Coordinates: 1854x1048 main window, default layout (screenshot first, `references/gui.md`).

## Which route for which job

| Job | Route | How |
|---|---|---|
| A look on many clips | API | `R.lut(items, "agent/moody.cube")` or `R.group(name, items, lut)` (color-group pre-clip LUT) [L] |
| Lift/gamma/gain/sat per node | API | `item:SetCDL({NodeIndex="2", Slope="1.2 1 0.8", Offset="0 0 0", Power="1 1 1", Saturation="1.1"})` on ANY node index, including GUI-made nodes [L] |
| Any global curve / custom look | API via LUT | Bake it into a .cube (`prep.py lut` or numpy), put it in `/opt/resolve/LUT/agent/`, `p:RefreshLUTList()`, `SetLUT(node, "agent/x.cube")` [L] |
| **Copy a full grade** (node tree, windows, qualifiers, curves) | **Template (DRX)** | Grade once in the GUI, `tl:GrabStill()`, `album:ExportStills({st}, dir, prefix, "drx")`; later `item:GetNodeGraph():ApplyGradeFromDRX(path, 0)` [L]. Or `src:CopyGrades({targets})` inside one project |
| Add nodes | GUI keys | Node editor focused: Alt+S serial, Shift+S before, Alt+P parallel, Alt+L layer, **Alt+C/Q/G/B = node with circle/linear/polygon/curve window** [L] |
| Temp, tint, contrast, pivot, sat, hue, wheels by number | GUI fields | Primaries palette number fields: `gui field X Y VALUE` [L] |
| Power window shape/position/softness | GUI fields | Window palette transform fields [L], then grade inside with SetCDL on that node [L] |
| Track a window | GUI | Tracker palette ▶ (track forward) or Ctrl+T [L]. Results are only visible on screen |
| Qualifier (HSL key), curves by hand, color warper, magic mask | GUI / template / Studio | Qualifier and curves are GUI drags/fields: do them once, then DRX. Magic Mask = Studio (`CreateMagicMask` returns false) [L] |
| Compare / review | API | `R.still(tl, f, png)`; average colour: `convert x.png -resize 1x1! -format '%[pixel:p{0,0}]' info:` |
| Node readout | API | `g:GetNumNodes()`, `g:GetToolsInNode(i)` e.g. {Primary Balance, Saturation Hue & Lum Mix} or {Power Windows}, `g:GetNodeLabel(i)`, `g:GetLUT(i)` [L] |

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
| Windows palette | Linear/Circle/Polygon/Curve/Gradient buttons on the top row; shape list; Transform: Size (1220,772), Aspect (1342,772), Pan (1220,800), Tilt (1342,800), Rotate (1220,828), Opacity (1342,828); Soft 1 (1220,887) |
| Tracker palette | Track forward (823,751); Pan/Tilt/Zoom/Rotate/3D toggles; "Clip / Frame" mode |
| Viewer tools | Highlight Shift+H, bypass grades Shift+D, wipe Ctrl+W, window outline Alt+H |
| Versions / memories | Ctrl+Y add version, Ctrl+N/B next/prev, Alt+1..8 save memory A..H |

## Recipe: GUI grade into a reusable look file
1. Make a clip current (thumbnail click). Build nodes with keys (Alt+S, Alt+C), set fields (`gui field`), and add a window, qualifier or curve.
2. `rv 'local st = R.tl():GrabStill(); R.project():GetGallery():GetCurrentStillAlbum():ExportStills({st}, "<dir>", "mylook", "drx")'`
3. Ship `mylook_<label>.drx` with the brand kit; apply with `ApplyGradeFromDRX(path, 0)` on any clip, any project. Verify with `R.still`.
