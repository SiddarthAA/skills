# Edit page (timeline, Inspector, Effects Library, subtitles, multicam)

Almost everything on the Edit page is scriptable. The GUI is only needed for the Effects Library drag (R.fx is the scripted alternative),
subtitle styling, retime curves and Inspector keyframes (Fusion keyframes are the scripted alternative). **[L]** = verified on free 21.1.1 Linux.

## Which route for which job

| Job | Route | How |
|---|---|---|
| New timeline (any size/fps) | API | `R.timeline(name, {w, h, fps, crop, video, audio})` (unique names; fps only before the project's first timeline) [L] |
| Place clips exactly | API | `R.place(tl, clip, {track, at, from, len, media, atrack})` asserts the position and the source range [L] |
| Selects / silence cuts | API | `R.keep(tl, clip, {{in,out},...})` [L] |
| Reframe per cut (vertical from 16:9) | API | `R.timeline{crop=true}` + `R.frame(item, x, zoom)` [L] |
| Transform, crop, opacity, flip, composite, retime quality | API | `item:SetProperty(k, v)`, 32 keys (below) [L] |
| Animated moves (punch, push, shake, zoom-to-point) | API (Fusion) | `R.motion`, `R.zoom`, or `R.fx(item, "Transform", {Size = {{0,1.2},{8,1}}})` [L] |
| Effects on a clip | API (Fusion) | `R.fx(item, id, params)`: any ResolveFX, Fusion tool or .setting template (`pages/fusion.md`) [L] |
| Effects Library drag (human way) | GUI | Search box + `gui drag` (below) [L]. Not visible to the API afterwards |
| Transitions | API | `outgoing:AddTransition({type = "Cross Dissolve", category = "simple", position = "end", alignment = "center", duration = 12})` on the clip BEFORE the cut; centre splits the duration evenly (6+6). Returns the transition item. 98 work: 67 Fusion templates (whip pans, crash zoom, glitch, flashes...), 30 simple, 1 OFX (`effects.md` §3) [L] |
| Titles | API | `R.title` (carrier + Text+) or a title template via `R.fx(carrier, R.templates.."Edit/Titles/X.setting")` [L]. Never `Insert*IntoTimeline` |
| Speed | API | `item:SetSpeed({Percentage=50})` keeps the item length [L]. **Ramps**: `R.fx(item, "TimeStretcher", {SourceTime = {{0,0},{30,15},{60,22},{89,80}}})` (frame-exact, `pages/fusion.md`) [L]; or the retime curve (GUI) |
| Stabilize | API | `item:Stabilize()` works on free [L] |
| Subtitles (native) | API | Subtitle track + SRT append + `R.render{settings={ExportSubtitle=true, SubtitleFormat="BurnIn"}}` [L] (recipe below) |
| Subtitle styling | GUI | Select the subtitle track, then Inspector > Track style. Or burn styled captions with `finish.py --subs` / `R.title` |
| Markers, flags, colors, takes, compound, Fusion clip, tracks | API | Below [L] |
| Multicam | API (create only) | `CreateMulticamClip` works; switching/flatten don't on free (below) |
| Interchange | API | Export EDL / FCPXML / OTIO / AAF / CSV / DRT; import FCPXML / EDL / DRT [L] |

## TimelineItem properties [L]
`item:GetProperty()` returns 32 keys: `Pan`, `Tilt` (timeline pixels, scaled by zoom: see R.frame), `ZoomX/ZoomY`, `ZoomGang`, `RotationAngle`,
`AnchorPointX/Y`, `Pitch`, `Yaw`, `FlipX/FlipY`, `CropLeft/Right/Top/Bottom`, `CropSoftness`, `CropRetain`, `CroppingEnabled`, `Opacity` (0-100),
`CompositeMode` (int; `resolve.COMPOSITE_*`), `CompositeEnabled`, `DynamicZoomEnabled`, `DynamicZoomEase`, `RetimeProcess` (0 project,
1 nearest, 2 frame blend, 3 optical flow), `MotionEstimation`, `Scaling` (0 project, 1 crop, 2 fit, 3 fill, 4 stretch), `ResizeFilter`,
`Distortion`, `LensCorrectionEnabled`, `TransformEnabled`, `RetimeAndScalingEnabled`. Audio items have `AudioVolume/Pan/Pitch*` (`pages/fairlight.md`).
`SetProperty` returned true for all tested keys, and transform/crop/flip/opacity/composite modes (`resolve.COMPOSITE_SCREEN` = 5 ...) render
(checked on stills). `DynamicZoomEnabled = true` animates a default push (the first frame already differs from the original); its start/end
rectangles are GUI-only (viewer overlay), so use `R.zoom`/`R.motion` for exact framing.

## Timeline API [L]
```lua
tl:AddTrack("video") ; tl:AddTrack("audio", "stereo") ; tl:AddTrack("subtitle") ; tl:DeleteTrack("video", 3)
tl:SetTrackName("video", 1, "A-roll") ; tl:SetTrackEnable("video", 2, false) ; tl:SetTrackLock("video", 2, true) ; tl:GetTrackSubType("audio", 1)
tl:AddMarker(frame, "Red", "hook", "note", 1, "custom-id") ; tl:GetMarkerByCustomData("custom-id") ; tl:UpdateMarkerCustomData(frame, "x")
tl:DeleteMarkerAtFrame(f) ; tl:DeleteMarkerByCustomData("x") ; tl:DeleteMarkersByColor("Red")       -- same set on items
item:AddFlag("Green") ; item:ClearFlags("All") ; item:SetClipColor("Pink") ; item:SetClipEnabled(false) ; item:SetName("hero")
item:GetLeftOffset() ; item:GetSourceStartTime() ; item:GetTrackTypeAndIndex() ; item:GetLinkedItems() ; tl:SetClipsLinked(items, false)
item:AddTake(mpi, startFrame, endFrame) ; item:SelectTakeByIndex(2) ; item:FinalizeTake() ; item:DeleteTakeByIndex(2)
tl:CreateCompoundClip(items, {name = "cc"}) ; tl:CreateFusionClip(items) ; tl:DuplicateTimeline("v2")   -- the duplicate becomes current
tl:SetStartTimecode("00:59:50:00") ; tl:GetSettings() (69 keys) ; tl:SetSettings({...}) ; tl:SetOutputBlanking({top=0.1, bottom=0.1})
tl:Export(path, resolve.EXPORT_FCPXML_1_10 | EXPORT_EDL | EXPORT_OTIO | EXPORT_TEXT_CSV | EXPORT_DRT, resolve.EXPORT_NONE)
tl:Export(path, resolve.EXPORT_AAF, resolve.EXPORT_AAF_NEW)
mp:ImportTimelineFromFile(path, {timelineName = "x"})   -- FCPXML: point at x.fcpxml/Info.fcpxml (it's a folder); EDL ok; DRT keeps its own name
tl:DeleteClips(items, ripple)   -- pass linked audio too
```
- **Transitions are items too**: after AddTransition, `GetItemListInTrack` (and `R.items`) include them and clip indexes shift. Filter with
  `it:GetType() == "video"` (transitions return "transition") or keep the items `R.place` returned.
- Own timelines: delete with `R.mp():DeleteTimelines({tl})` (only ones you made). Source range of an item: `GetSourceStartFrame()`/`GetSourceEndFrame()`
  (check handles before centred transitions).
- **AppendToTimeline happily places a source range past the clip's end** (frozen last frame, no handles); `R.place` asserts against it.
- **A missing track index drops the clip at the end of V1**; occupied ranges make Resolve append at the track end. `R.place` deletes the stray item and errors.
- `InsertFusionGeneratorIntoTimeline`, `InsertFusionCompositionIntoTimeline`, `InsertTitleIntoTimeline`... **ripple-insert 150 frames into V1 at the playhead**, splitting clips. Don't.
- OTIO export works but **OTIO import returns nil** (the exported OTIO has an empty name). Author edits as FCPXML instead.
- **FCPXML round trip is lossy, and `ImportTimelineFromFile` silently changes the PROJECT resolution** to the timeline's size [L]. Save
  `p:GetSetting("timelineResolutionWidth"/"Height")` before an import and set them back after. Exports drop the external mic track, the subtitle track
  and clip volume (the EDL is V1 only). Imported items come in with `Scaling = 2` (fit) and follow the project settings: set the timeline's
  `useCustomSettings = "1"`, `timelineInputResMismatchBehavior = "scaleToCrop"` and each item's `Scaling = 0` to match the original. Imports link to
  existing pool clips and land in the current media-pool folder.

## Subtitles by script [L]
```lua
local tl = R.timeline("captioned", {w = 1080, h = 1920, fps = 30})
tl:AddTrack("subtitle")
local srt = R.import({path_to_srt})[1]                         -- the media pool name has NO ".srt" ("subs")
R.mp():AppendToTimeline({{mediaPoolItem = srt, trackIndex = 1}}) -- FIRST, on the empty timeline
-- ... now place the video ...
R.render({dir = ..., name = ..., settings = {ExportSubtitle = true, SubtitleFormat = "BurnIn"}})  -- or "SeparateFile" / "EmbeddedCaptions"
```
- `recordFrame` is ignored for SRT items: cues land at their SRT time **plus the current end of the timeline**, so append before any other clip.
- `tl:ImportIntoTimeline(srt)` returns false. Subtitle items: `tl:GetItemListInTrack("subtitle", 1)`, `item:GetName()` = the cue text.
- **Default burn-in on a 1080x1920 timeline is about 100 px text at y≈1430-1650, OUTSIDE the 9:16 safe zone (y ≤ 1248)**, and lines over
  about 16-18 characters clip at the sides (`captions.py --max-chars 16`). Style it in the GUI (subtitle track Inspector), or burn styled,
  safe-zone captions with `finish.py --subs` instead.
- Changing captions later: there's no swap. Write the SRT under a NEW file name (R.import reuses by path) and rebuild the timeline with the SRT appended first.

## Multicam [L]
`R.mp():CreateMulticamClip({camA, camB}, {name = "mc", angleSyncMode = resolve.MULTICAM_ANGLE_SYNC_IN})` returns a **list** with one MediaPoolItem
(Type "Multicam"), which places like any clip. On free: `FlattenMulticam` returns nothing and changes nothing; **`PerformMulticamSmartSwitch`
opens the Studio upsell modal**, after which create calls fail silently until it is dismissed (Escape). Switching angles is GUI only (multicam viewer, number
keys). Agent route: sync once (`R.sync` / AutoSyncAudio), then cut the angles as ordinary clips with `R.place`.

## GUI how-to [L]
| Element | Where |
|---|---|
| Open | `resolve:OpenPage("edit")` or Shift+4 |
| Top bar | Media Pool (62,38), Effects (220,38), Index (310,38), Sound Library (440,38), Quick Export (1440,38), Mixer (1540,38), Metadata (1650,38), Inspector (1760,38) |
| Effects Library | Toolbox (Video/Audio Transitions, Titles, Generators, Effects), Resolve FX (Filters 58,282 / Transitions), Audio FX (Fairlight FX), Favorites. Search: magnifier (370,66), then `GUI_TEXT_FIELD=1 gui type Glow` (only after a screenshot shows the search box focused) |
| Drag an effect onto a clip | `gui drag 290 183 <clip x> <clip y>` (first result tile at (290,183)). Qt drags need press, a small move, then gradual moves (gui drag does it). Verified Glow: luminance 0.55 -> 0.70 |
| Inspector | Video, Audio, Effects, Transition, Image, File tabs; clip vs track mode = the 2 icons at its top-left. Number fields: `gui field` |
| Keys (from the exported DaVinci Resolve keymap) | Blade mode B, razor at playhead Ctrl+B, ripple delete Shift+Backspace/Del, mark I/O, zoom to fit Shift+Z, snapping N, linked selection Shift+Ctrl+L, Project Manager Shift+0, Project Settings Shift+9 |

## Cut page
Same timeline and API as the Edit page. Its extras (source tape, sync bin, smart insert, dual timeline, Smart Reframe = Studio) speed up
human editing; an agent gets the same results with `R.place`/`R.keep`. Open with Shift+3. `pages/cut.md` has the details.
