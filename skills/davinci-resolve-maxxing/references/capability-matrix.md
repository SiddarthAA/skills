# Capability matrix: what an agent can drive in free Resolve 21.1 (Linux), and how

Routes, in order of preference: **API** (Lua through the bridge) > **Template** (a file or preset made once and re-applied: .setting, DRX,
Fairlight XML/config preset, LUT, FCPXML, SRT) > **GUI** (`scripts/gui`: keys, number fields, drags) > **ffmpeg** (outside Resolve) > ✗ (not on free).
✓ = verified in the lab (free 21.1.1, Ubuntu 24.04). Details live in `pages/<page>.md`.

## Scorecard
| Measure | 2026-10-29 | 2026-10-31 |
|---|---|---|
| API methods exercised (of 416 in the 21.1 stub) | 149 (36%) | **396 (95%)**. Untouched: cloud projects (5), burn-in presets (4), clone tool (4), mattes (3), Quit, EncryptDCTL, CreateStereoClip, RegenerateMagicMask |
| ResolveFX usable from script | 0 of 53 (rendered black) | **53 of 53** attach and render through Fusion (41 change the frame at defaults; 12 are identity until set) |
| Fusion tools proven | 6 | any tool via `R.fx` (registry of about 500) + expressions + `.setting` macros |
| Fusion templates usable | 0 | **417** built-in via `R.fx` (CCTV, Watermark, Binoculars, DVE, Headline title verified) |
| Transitions by API | 6 | **49** (30 simple, 18 Fusion, 1 OFX) |
| Fairlight EQ / dynamics / inserts | none (ffmpeg only) | **template route**: XML presets written by script, config presets applied by API |
| Color beyond LUT/CDL | groups, versions | **+ DRX grade templates**, CDL on GUI-made window nodes, node keys, primaries/window fields, tracker |
| Subtitles | burn with ffmpeg only | **native**: SRT on a subtitle track + Resolve burn-in |
| Page coverage (rough: share of the page's everyday features an agent can reach) | Media 70, Edit 60, Deliver 60, Color 30, Fairlight 20, Fusion 10-15 | Media 90, Cut 85, Edit 90, Fusion 90, Color 70, Fairlight 75, Deliver 90 |

## Media
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Import, bins, move, delete own bins | ✓ | | | `R.import`, `R.bin`. H.264/HEVC/AAC need `prep.py transcode` on Linux |
| Metadata, keywords, comments, custom (third-party) fields | ✓ | | | |
| Marks, markers (custom data), flags, clip colors | ✓ | | | |
| Audio sync (waveform) | ✓ | | | `R.sync`. Multicam create ✓; switch/flatten ✗ |
| Proxies link/unlink, relink, replace | ✓ | | | Generate proxies with ffmpeg |
| Bin export/import (.drb), metadata CSV | ✓ | | | |
| Scene cut detection | ✗ (Studio upsell) | | Media page detector | `analyze.py cuts` (ffmpeg) |
| Transcription, Intellisearch, classification, slate | ✗ | | | `transcribe.py`. TranscribeAudio CRASHES |

## Edit / Cut
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Timelines (size, fps, tracks, names, lock/enable) | ✓ | | | `R.timeline`, `AddTrack`... Audio track "enable" doesn't mute renders |
| Exact placement, selects, silence cuts, reframing | ✓ | | | `R.place`, `R.keep`, `R.frame` |
| Transform / crop / opacity / flip / composite / retime quality | ✓ | | Inspector | 32 properties |
| Keyframed motion | ✓ (Fusion) | | Inspector keyframes | `R.motion`, `R.zoom`, `R.fx(..., {{f, v}})` |
| Effects on clips | ✓ (Fusion, `R.fx`) | .setting | Effects Library drag ✓ | Drag-applied OFX are invisible to the API |
| Transitions | ✓ 49 | Fusion transition templates | | Center alignment needs handles |
| Titles | ✓ `R.title` | ✓ title templates | | Never `Insert*IntoTimeline` (ripples 150 frames) |
| Generators, particles, backgrounds | ✓ carrier + `R.fx(carrier, R.templates.."Edit/Generators/Starfield.setting")` (Starfield, Snow verified) | 417 templates | | |
| Speed, ramps | ✓ constant; ✓ ramps via Fusion TimeStretcher (frame-exact) | | retime curve | Don't use TimeSpeed |
| Stabilize | ✓ | | | |
| Compound / Fusion clip / takes / duplicate | ✓ | | | |
| Subtitles (place, burn-in) | ✓ | SRT | styling ✓ | Append SRT FIRST on an empty timeline |
| Interchange | ✓ export EDL/FCPXML/OTIO/AAF/CSV/DRT, import FCPXML/EDL/DRT | FCPXML | | Lossy (mic track, subtitles, volume dropped); import changes project resolution; OTIO import ✗ |
| Smart Reframe, scene detect, smart switch | ✗ | | | Studio |

## Fusion
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Node graph build/connect, any of about 500 tools | ✓ | | | `comp:AddTool`, `FindMainInput/Output` |
| ResolveFX (53) | ✓ | | | Image input is `Source` |
| Keyframes, splines, expressions | ✓ | | | `R.key`, `SetExpression` |
| Macros/templates (.setting) | ✓ paste (Fusion page open) | ✓ 417 built-in + your own via `SaveSettings` | | `R.fx(item, path)` |
| Text+ | ✓ | | | Fonts must be visible to Fusion |
| Particles, 3D, masks, keyers | ✓ tools by script; particles via templates (Snow verified) | 417 templates | | |
| Fusion tracking (Tracker/PlanarTracker) | tools add, but TrackForward can't be triggered by script | | Fusion Inspector buttons | Or track outside Resolve and write keyframes |
| OGraf HTML titles | ✗ on Linux | | | macOS/Windows only |

## Color
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| LUT per node, color group pre/post | ✓ | .cube | | `R.lut`, `R.group` |
| CDL per node (incl. GUI-made nodes) | ✓ | | | |
| Copy grade / reuse looks | ✓ CopyGrades, ApplyGradeFromDRX | ✓ DRX | | DRX isn't hand-authorable |
| Versions, node enable, cache, reset, labels/tools readout | ✓ | | | |
| Add nodes (serial/parallel/layer/window) | ✗ | DRX | ✓ keys | Alt+S/P/L, Alt+C/Q/G/B |
| Primaries (temp, tint, contrast, wheels, sat, hue) | ✗ (CDL covers lift/gamma/gain/sat) | DRX | ✓ number fields | |
| Curves, warper, ColorSlice | ✗ | ✓ LUT (global) / DRX | drag | |
| Qualifier, power windows | ✗ (grade them by API: SetCDL on that node) | DRX | ✓ fields (both verified with pixel tests) | |
| Tracking | ✗ | | ✓ tracker ▶ | |
| Gallery stills/albums (grab, label, export/import DRX) | ✓ | | | |
| DCTL | watermark on free | | | Studio |
| Magic Mask, noise reduction | ✗ | | | Studio |

## Fairlight
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Clip volume/pan/pitch/fades | ✓ | | | |
| Loudness normalize | ✓ | | | `R.normalize`; final loudness in `finish.py` |
| Track EQ | ✗ | ✓ XML written by `fl_eq.py`; apply via config preset or Presets Library | ✓ fields | |
| Track dynamics | ✗ | ✓ XML (save from GUI) | ✓ fields | |
| Insert FX (reverb, de-esser, NR...) | ✗ | ✓ config preset carries them | ✓ Effects + | |
| Whole-mix template | ✓ `ApplyFairlightPresetToCurrentTimeline` | ✓ config preset | save once | Same track count |
| Ducking | cut-and-lower via API | ✓ config preset carries the Ducker | ✓ Ducker | No threshold: a constant cut over room noise |
| Buses / sends | ✗ | config preset (untested) | ✓ Bus Format | |
| Automation, ADR, recording | ✗ | | GUI (untested) | Not needed for agent edits |
| Voice isolation, dialogue separator | ✗ | | | Studio |

## Deliver
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Render ProRes/DNxHR master, range, single or per clip | ✓ | render presets XML | | inside Media Storage only |
| Presets save/update/delete/import/export | ✓ | | | |
| Subtitle burn-in | ✓ | | | |
| Stop render | ✓ | | | |
| H.264/HEVC/AAC delivery | ✗ on Linux free | | | `finish.py` (ffmpeg) |
| Quick Export | ✗ by API | | ✓ button | |
| Audio-only render | ✗ (stays Ready) | | | ffmpeg from the master |

## Project / app
| Feature | API | Template | GUI | Notes |
|---|---|---|---|---|
| Create/load/save/close/import/export/delete own projects, PM folders | ✓ | .drp | | ArchiveProject returns false |
| Project + timeline settings, settings presets | ✓ | binary preset file | | FCPXML import changes the project resolution |
| Keyboard / layout / preferences presets | ✓ | text / opaque / XML | | |
| Media Storage roots | ✗ | | ✓ Preferences | restart needed |
