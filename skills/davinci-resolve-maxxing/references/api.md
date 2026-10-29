# Resolve scripting cheatsheet (Lua, via the bridge)

Code runs inside Resolve's Lua Console (LuaJIT = Lua 5.1: no `//` operator, use `math.floor`; arrays are 1-based).
Globals inside a request: `resolve`, `R` (scripts/lib.lua), `print`, `reload()`, `stop()`, plus `bmd`, `ffi`.
Ground truth for signatures: `/opt/resolve/Developer/Scripting/DaVinciResolveScript.pyi` (Python stub, same names).
**[L]** verified in our lab on free 21.1.1 Linux; **[R]** reported, not re-tested.

## R helpers (scripts/lib.lua)

Frames are relative to the timeline start (0 = first frame).

| Helper | Does |
|---|---|
| `R.project()`, `R.mp()`, `R.tl()`, `R.save()` | Handles; save the project |
| `R.find(name)` | Media-pool clip by exact name, searching every bin |
| `R.import(paths, bin)` | Import into a bin (created if missing). Reuses clips already in the pool. Warns on undecodable media |
| `R.timeline(name, {w, h, fps, crop, video, audio})` | New timeline with a unique name. `w`/`h` set a per-timeline resolution (vertical inside a 16:9 project). `crop = true` makes other-aspect sources fill (scaleToCrop) so `R.frame` can pick what shows. `fps` only works before the project's first timeline |
| `R.open(name)` | Make an existing timeline current |
| `R.tracks(tl, kind, n)` | Ensure n tracks of "video" / "audio" / "subtitle" |
| `R.place(tl, clip, {track, at, from, len, media, atrack})` | Exact placement (exclusive end handled, position asserted). Returns `{video, linked audio...}` |
| `R.frame(item, x, zoom)` | Frame a subject in a wider source (crop timeline): x = position as a fraction of source width. Sets `Pan = (0.5 - x) * timeline_width * zoom` (pixel-verified), clamped against black edges |
| `R.keep(tl, clip, ranges, {track, at, media})` | Lay `{{in,out},...}` source ranges back to back (silence cuts, selects). Returns items and the end frame |
| `R.items(tl, kind, track)`, `R.dump(tl)` | List items; a readable map of every track |
| `R.tc(tl, rel)`, `R.fps(tl)` | Relative frame to timecode; integer fps |
| `R.has_font(family)`, `R.default_font()` | Is the family visible to Fusion (rescans ~/.local/share/fonts); first available of Open Sans / Inter / DejaVu Sans / Helvetica Neue / Arial |
| `R.title(tl, {text, at, len, track=2, font, style, size, color, center, anim, tracking, outline})` | Title on a carrier clip with Text+. `anim` = "pop" (default) / "fade" / "none". Returns `item, comp, textTool` |
| `R.template(tl, comp_path, {at, len, track, text})` | Reuse a saved `.comp` title, retargeting its Text+ |
| `R.motion(item, {punch={from,to,frames}, push={from,to}, shake={amp,frames}, blur})` | Keyframed Fusion Transform on a clip (renders in timeline and Deliver) |
| `R.zoom(item, {target={x,y} top-left fractions, scale, at, hold, ease})` | Demo zoom onto a point and back (pixel-verified maths) |
| `R.key(tool, input, {{frame, value}, ...})` | Keyframe any Fusion input (BezierSpline, or XYPath for Center) |
| `R.lut(items, "agent/moody.cube")` | LUT on node 1. The path is relative to the master LUT folder |
| `R.cdl(item, {slope={r,g,b}, offset, power, sat})` | ASC CDL on node 1 |
| `R.group(name, items, lut)` | Color group with a pre-clip LUT: one look for many clips |
| `R.volume(item, db)`, `R.fade(item, in, out)` | Clip gain (dB), fades (frames), audio or video |
| `R.normalize(tl, items, mode, target)` | Clip-gain loudness normalize ("EBU R128" -23, "YouTube", "True Peak"...) |
| `R.sync(cam, mic)` | Waveform-sync an external recorder to a camera clip |
| `R.markers(tl, frames, color, name)` | Beat / cue markers |
| `R.still(tl, rel, png)`, `R.stills(tl, frames, dir, prefix)` | **The agent's eyes:** full timeline composite PNGs at timeline resolution (Edit page) |
| `R.storage()` | Media Storage roots (the only places renders may go) |
| `R.render({dir, name, format, codec, range, audio, preset})` | Blocking render. Returns status, seconds, path. Default ProRes 422 HQ .mov |

## Raw API by area

### Project and media pool
| Call | Notes |
|---|---|
| `p:GetSetting()` (158 keys), `p:SetSetting(k, v)` | Values are strings. `timelineFrameRate` only changes before the first timeline [L]. Useful keys: `timelineResolutionWidth/Height`, `timelineInputResMismatchBehavior` (`scaleToFit/scaleToCrop/centerCrop/stretch`), `colorScienceMode`, `superScale`, `timelineSampleRate` [R] |
| `pm:CreateProject(name)`, `pm:LoadProject(name)`, `pm:SaveProject()`, `pm:ExportProject(name, path.drp, false)` | Save before switching projects; an unsaved current project is lost [R] |
| `mp:AddSubFolder(root, name)`, `mp:SetCurrentFolder(f)`, `mp:MoveClips(clips, folder)` | [L] |
| `clip:GetClipProperty(key)` | Keys: `Type`, `Resolution`, `FPS`, `Frames`, `Duration`, `File Path`, `Video Codec`, `Audio Ch`, `Synced Audio`, `Audio Offset`... [L] |
| `clip:AddMarker(frame, color, name, note, dur, customData)`, `SetClipColor`, `AddFlag`, `SetMetadata("Comments", s)` | [L] |
| `mp:AutoSyncAudio({cam, mic}, {[resolve.AUDIO_SYNC_MODE]=resolve.AUDIO_SYNC_WAVEFORM, ...})` | Sample-accurate [L]. Keys must be the constants [R]. Check the `Synced Audio` property |
| `mp:CreateMulticamClip(clips, {name, angleSyncMode=resolve.MULTICAM_ANGLE_SYNC_MODE_SOUND})` | Returned a non-clip value [L]; for podcasts prefer cutting angles yourself (recipes.md) |
| `mp:ImportTimelineFromFile(path, {timelineName, importSourceClips=false})` | OTIO and FCPXML import as new timelines [L]. Lets an agent author a whole edit as a file |

### Timeline
| Call | Notes |
|---|---|
| `tl:SetSetting("useCustomSettings","1")` + resolution keys | Per-timeline resolution [L] |
| `tl:AddTrack(kind[, "mono"/"stereo"])`, `SetTrackName`, `SetTrackLock`, `SetTrackEnable`, `DeleteTrack` | [L] |
| `item:SetProperties({ZoomX, ZoomY, Pan, Tilt, RotationAngle, Opacity 0-100, CropLeft..., CompositeMode=resolve.COMPOSITE_OVERLAY, DynamicZoomEnabled})` | Static transform [L]. **Pan/Tilt are in timeline pixels, scaled by zoom** (see R.frame) [L]. Animated: use `R.motion` (Fusion) |
| `item:SetSpeed({Percentage=50})` | [L]; 50% pixel-exact [R] |
| `item:SetFades({FadeIn=n, FadeOut=n})`, `GetFades()` | Video and audio [L] |
| `item:AddTransition({type="Cross Dissolve", category="simple", position="end", alignment="center", duration=12})` | [L] |
| `tl:CreateCompoundClip(items, {name})`, `tl:CreateFusionClip(items)` | [L] compound |
| `tl:DeleteClips(items, rippleDelete)`, `tl:SetClipsLinked(items, bool)` | Pass linked audio too [R] |
| `tl:AddMarker(frame, color, name, note, dur, customData)` | [L] |
| `tl:SetCurrentTimecode(tc)` + `p:ExportCurrentFrameAsStill(png)` | Composite frame grab, Edit page [L]; fails on the Fusion page [L] |
| `tl:Export(path, resolve.EXPORT_FCPXML_1_10 / EXPORT_EDL / EXPORT_OTIO / EXPORT_AAF + EXPORT_AAF_NEW / EXPORT_DRT / EXPORT_TEXT_CSV, resolve.EXPORT_NONE)` | All [L] |
| `tl:DuplicateTimeline(name)` | Makes the copy current [R] |

### Fusion (on a timeline item)
| Call | Notes |
|---|---|
| `item:AddFusionComp()`, `GetFusionCompByIndex(1)`, `GetFusionCompCount()` | Comp starts with `MediaIn1` and `MediaOut1`; comp frame 0 = the item's first frame [L] |
| `comp:AddTool("TextPlus"/"Merge"/"Transform"/"Background"/...)` | [L] |
| Connect: `merge.Background = mi.Output`, `merge.Foreground = txt.Output`, `mo.Input = merge.Output` | [L] |
| `tool:SetInput(id, v)`, `GetInput(id, frame)`; disconnect animation with `tool.Size:ConnectTo(nil)` | [L] |
| Keyframes: `tool:AddModifier("Size","BezierSpline"); tool.Size[0]=2.0; tool.Size[8]=1.2` | [L] |
| `item:ExportFusionComp(path, 1)` / `item:ImportFusionComp(path)` | Save and reuse templates [L] |
| `resolve:Fusion().FontManager:GetFontList()` / `:ScanDir(dir)` | [L] |
| Text+ inputs | `StyledText`, `Font`, `Style`, `Size`, `Center` {x,y} (0..1, **y up**), `Red1/Green1/Blue1/Alpha1`, `CharacterSpacing`, `LineSpacing`, `Enabled2..8` (shading elements; element 2 = outline: `Thickness2`, `Red2..`, `ElementShape2`), `Softness1` [L] |

### Color
| Call | Notes |
|---|---|
| `item:GetNodeGraph()` then `:GetNumNodes()`, `:SetLUT(n, rel)`, `:GetLUT(n)`, `:SetNodeEnabled(n, b)`, `:ApplyGradeFromDRX(path, mode)`, `:ResetAllGrades()` | [L] (DRX apply [R]) |
| `item:SetCDL({NodeIndex=1, Slope="1.2 1 0.8", Offset="0 0 0", Power="1 1 1", Saturation="1.3"})` | Strings [L] |
| `src:CopyGrades({targets})` | Wholesale replace [L][R] |
| `item:AddVersion(name, 0)`, `GetVersionNameList(0)`, `LoadVersionByName(name, 0)` | Local versions [L] |
| `p:AddColorGroup(name)`, `item:AssignToColorGroup(g)`, `g:GetPreClipNodeGraph():SetLUT(1, lut)` | Group look [L] |
| `tl:GrabStill()` (Color page), `p:GetGallery():GetCurrentStillAlbum():ExportStills({st}, dir, prefix, "drx")` | Grade export [L] |

### Audio
| Call | Notes |
|---|---|
| `item:SetProperties({AudioVolume=-12})` dB; `AudioPan=-0.5` | Read back -12 / -0.5 [L] (Pan range reported as -100..100 [R]: read back after setting) |
| `tl:NormalizeAudioLevel(items, {normalizationMode, targetLoudness, targetLevel, setLevelMode})` | Modes: `tl:GetNormalizeAudioModes()` (EBU R128, YouTube, Netflix, True Peak, ATSC A/85...) [L] |
| Dialogue leveler props `AudioDialogueLevelerEnabled`, `AudioDialogueLevelerMode` | 21.1, free [R] |
| Ducking, EQ, compression | Not scriptable (Fairlight GUI). Bake with ffmpeg (`sidechaincompress`, `loudnorm`) or set levels by hand with `R.volume` |

### Render
| Call | Notes |
|---|---|
| `p:GetRenderFormats()`, `p:GetRenderCodecs("mov")` (display name to ID), `p:GetRenderPresetList()` | Linux free: no H.264/HEVC/AAC; ProRes, DNxHR, FFV1, Cineform, etc. [L] |
| `p:LoadRenderPreset(name)`, `SetCurrentRenderFormatAndCodec("mov","ProRes422HQ")`, `SetRenderSettings({TargetDir, CustomName, SelectAllFrames, MarkIn, MarkOut, ExportVideo, ExportAudio, FormatWidth, FormatHeight})` | [L] |
| `id = p:AddRenderJob()`, `p:StartRendering({id})`, poll `IsRenderingInProgress()`, `GetRenderJobStatus(id).JobStatus` | [L] |
| Subtitle burn-in `{ExportSubtitle=true, SubtitleFormat="BurnIn"}` | Untested on 21.x [R]; use finish.py --subs |
