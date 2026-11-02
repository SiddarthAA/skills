# Gotchas: free DaVinci Resolve 21.1 scripting

Read this before your first script. **[L]** = verified in our lab (free 21.1.1, Linux). **[R]** = reported by the
samuelgursky/davinci-resolve-mcp project (mostly Studio 21.x), not re-tested here.

## Silent effect and timing traps (added 2026-11-01)
| Trap | What happens | Do this instead |
|---|---|---|
| A new project's frame rate is **24 fps** until its first timeline; `R.timeline{fps = 30}` only works before that | 30 fps clips placed with `from`/`len` in source frames land shorter, leaving gaps that render BLACK (a "black transition") [L] | Pass `fps` on the project's FIRST `R.timeline` call; check `R.fps(tl)` |
| Keys added live to a ResolveFX param (`R.key(ofxTool, "blend", ...)`) | Reads back animated, renders the static value [L] | Key it through `R.fx(item, id, {p = {{f, v}...}})` (re-pastes), or `R.save_fx` + `R.fx(file)` |
| Edit-page zoom on a clip with a Fusion DropShadow | The shadow is drawn on the full frame BEFORE the Edit-page scale, so none shows around the PiP [L] | Scale inside Fusion (`R.fx(it, "Transform", {Size = 0.35})`) then DropShadow |
| `Trails` (echo) | Nothing in random-access stills (it needs sequential frames) [L] | Check a real render, or fake echo with several offset Merges |
| Built-in effect templates **Comic Book** (renders black) and **Digital Glitch** (R.still fails) | [L] | Hologram Glitch, the `glitch` preset, or the Glitch transition |
| `AddTransition` with a duration the handles can't fully cover | Comes out shorter (asked 14, got 9) with no error [L] | Read the transition item's `GetDuration()` back |
| A video file whose first frame starts after 0 (an ffmpeg `-ss` trim or rate change: `ffprobe -show_entries stream=start_time`) | Resolve shows frame 0 BLACK (stills and renders) [L] | `prep.py transcode` pads it since 2026-11-03 (`fps=...:start_time=0`); re-transcode older files |
| Text+ outline reverting to the thin red default later in a build (seen in 2 E2E runs, not reproduced in 8 lab tests) | Captions render with a thin red outline [L?] | Check a still; if red, loop over the title items and set `Red2/Green2/Blue2/Thickness2` again |
| A Text+ Follower that fades letters in with `Opacity1` only | The outline (element 2) isn't faded, so outlines show before their letters [L] | Key `Opacity2` the same way (R.title `anim = "rise"` does since 2026-11-03). The Follower's own `Red2`/`Thickness2` read back as defaults but don't override the Text+ outline |
| Pan Left/Right (whip) transitions over text | The image mirrors mid-whip, so text reads backwards for a few frames [L] | Fine on footage; over a title use Slide or Push |
| A keyframed `Center` of a pasted preset (e.g. the lower third's text) | `SetInput("Center", ...)` is ignored: the XYPath drives it [L] | Move the whole overlay with the carrier's `Pan`/`Tilt`, or re-key it |

## Things that crash or freeze Resolve

| Never do this | What happens | Do this instead |
|---|---|---|
| `tl:CreateSubtitlesFromAudio()`, `item:TranscribeAudio()`, `AnalyzeForIntellisearch`, `GenerateSpeech`, voice isolation and other AI calls on **free** | Crashed Resolve (Qt fatal) [L]. Reported elsewhere as an upgrade dialog that blocks every later call [R] | `scripts/transcribe.py` (faster-whisper) for captions and word timings |
| **`tl:ConvertTimelineToStereo()`, `mp:CreateStereoClip`, any stereo 3D setting** (stereo AUDIO tracks are fine) | **The PROJECT can no longer be opened on free**: loading shows the Studio upsell, then "Unable to Open Project" (log: `Stereo Project feature is not supported`). It cost us the claude-lab test project [L] | Never use stereo features. Back up with `pm:ExportProject` before probing unknown calls, and probe them in a throwaway project |
| `graph:ApplyGradeFromDRX(path, 0)` | Crashed Resolve once (SIGSEGV on the first call, from the Color page seconds after exporting the DRX); the retry worked [L] | `R.save()` first, one clip per `rv` call, issue it from the Edit page; inside one project use `CopyGrades` |
| `tl:AutoAlignClips()` | Returned false once and crashed Resolve twice, a moment after the call [L] | Media-pool `R.sync(cam, mic)` (AutoSyncAudio, sample-accurate) [L] |
| `pm:ArchiveProject(...)` with source or proxy media flags | SIGSEGV [R]. With all flags false it returns false, no file [L] | `pm:ExportProject(name, path.drp, false)` [L] |
| Studio-only calls: `DetectSceneCuts`, `PerformMulticamSmartSwitch`, `RemoveMotionBlur`, `PerformAudioClassification`, `AnalyzeForIntellisearch` | No crash, but the **"You have reached a limitation" upsell modal** opens, and while it's up later create calls silently return nil (CreateEmptyTimeline -> nil) [L] | Avoid; if `rv` warns about a dialog: `GUI_WIN='^Message$' gui key Escape` (= Not Yet). Full probe list: `capability-matrix.md` and the pages |
| Switching pages (`OpenPage`) while playback runs | Hangs the main thread and all scripting [R] | Never start playback from script |
| Project-settings preset writes on a never-saved project | Project can't be opened again [R] | `pm:SaveProject()` first |

## Silent failures (call returns true, nothing happens)

| Trap | Fix |
|---|---|
| **`comp:Lock()` around Fusion edits:** values read back fine but **do not render** (timeline, stills or Deliver) [L] | Never Lock. Write inputs directly. `comp:StartUndo("x") ... comp:EndUndo(true)` is the safe wrapper [R] |
| **A font Fusion can't see** gives an invisible Text+ (red Merge in Fusion), and `SetInput("Font")` still returns OK [L]. Fusion scans only `/usr/share/fonts` | `resolve:Fusion().FontManager:ScanDir(HOME.."/.local/share/fonts/")` (the bridge does it at start), then `R.has_font(family)`. ResolveDebug.txt logs `Could not find font` |
| **`InsertTitleIntoTimeline` / `InsertFusionTitleIntoTimeline` / `InsertGeneratorIntoTimeline` ripple-insert 150 frames on V1** at the playhead, splitting and pushing your edit [L]. They can't be targeted or sized. Locking V1 makes them return nil [L] | `R.title()`: a transparent carrier clip placed with exact track and frames, plus Text+ in its Fusion comp [L] |
| **`AppendToTimeline` `endFrame` is exclusive**, and `recordFrame` is absolute (`tl:GetStartFrame()` + rel) [L] | `R.place()` does the math |
| **A `trackIndex` that doesn't exist yet**: the clip lands at the END of track 1 and `recordFrame` is ignored [L] | `R.tracks(tl, kind, n)` first (R.place does it) |
| **Stills (jpg/png) ignore start/end frames** and always come in at the default 5 s [L] | `prep.py still` turns photos into ProRes clips of exact length |
| **H.264/HEVC/AAC on Linux free**: import "succeeds" but the clip has no resolution or frames (offline) [L] | `prep.py transcode` to ProRes (Mac free decodes these natively) |
| `CreateEmptyTimeline(name)` returns **nil if the name exists** [L] | `R.timeline()` adds a suffix |
| Render target outside **Media Storage**: `AddRenderJob()` returns `""` and a "Render Path Inaccessible" dialog appears [L] | `R.storage()` lists allowed roots (here `~/Videos`); render inside them |
| **Render settings stack on the loaded preset**: after "Audio Only" was loaded, a ProRes render came out audio-only [L] | `R.render()` loads "ProRes 422 HQ" first. Always ffprobe the output |
| Codec names: `SetCurrentRenderFormatAndCodec` wants the codec **ID** (`ProRes422HQ`, `DNxHRHQ`, `lpcm`), not the display name [L] | `p:GetRenderCodecs("mov")` maps display name to ID |
| `SetClipProperty("Clip Name", x)` returns false but renames [L] | Read back instead of trusting the bool |
| `DuplicateTimeline` makes the copy current [R] | `p:SetCurrentTimeline(orig)` after |
| `CopyGrades` replaces the target's grade wholesale, no undo version [R][L] | `tgt:AddVersion("pre-copy", 0)` first |
| `DeleteClips` leaves linked audio behind [R] | Pass the linked items too (`item:GetLinkedItems()`) |
| `SetSpeed({Percentage=200})` keeps the item's duration; the content plays faster [L] | Expected behaviour; trim the source range yourself if you need the shorter duration |
| A synced clip (`AutoSyncAudio`) carries **2 audio tracks**; on append it overwrites whatever is on A2 [L] | Give it its own A1/A2; put music and SFX on A3+ |
| Inspector keyframes on a clip override `SetProperties` (e.g. AAF imports) [R] | Verify with `R.still` before/after |
| `ImportTimelineFromFile` returns nil if the timeline name exists; FCPXML's internal sequence name can override `timelineName` [R] | Unique names. FCPXML 1.10 exports as a folder: import `<name>.fcpxml/Info.fcpxml` [L] |
| `MarkIn`/`MarkOut` render settings are ABSOLUTE frames; `GetMarkInOut()` is relative [R] | `R.render({range = {in, out}})` converts |
| Timeline-level node graph has 0 nodes and the API can't add any [L] | Use a color group pre-clip graph: `R.group(name, items, lut)` [L] |
| `SetLUT` with a path outside Resolve's master LUT folder returns false [L] | Install LUTs in `/opt/resolve/LUT/<sub>/` (Linux), call `p:RefreshLUTList()`, pass `"sub/name.cube"` |
| `item:ExportLUT(...)` returned false [L] | Generate looks with `prep.py lut` |
| Audio-only renders (preset "Audio Only" or `ExportVideo=false`) stayed "Ready" and never rendered [L] | Render the master, then `ffmpeg -i master.mov -vn -c:a pcm_s24le out.wav` |
| SRT: `AppendToTimeline` places nothing **without a subtitle track**; with one, `recordFrame` is ignored and cues land at SRT time + the timeline's current end. The SRT item is named without ".srt" [L] | `tl:AddTrack("subtitle")`, append the SRT FIRST on the empty timeline, burn in with `R.render{settings={ExportSubtitle=true, SubtitleFormat="BurnIn"}}` (`pages/edit.md`) |
| **ResolveFX wired on `Input` render BLACK** (their image input is `Source`); macros output on `MainOutput1`, not `Output` [L] | `R.fx` (FindMainInput/FindMainOutput) |
| **`comp:Paste()` returns false unless the comp is open in the Fusion page**; `Paste(nil)` pastes the CLIPBOARD; `bmd.readstring(s, x)` (2 args, e.g. via `assert`) returns nil [L] | `R.fx(item, "x.setting")` handles all three |
| `SetInput` on a misspelled input ID is ignored silently [L] | `R.inputs(tool)` lists IDs; R.fx asserts |
| `AppendToTimeline` with a source range past the clip's end succeeds (frozen frame, no handles); centred transitions then return nil [L] | `R.place` asserts the range |
| A timeline with **no video items** can't render (Duration 0, AddRenderJob "") [L] | Carrier/black clip on V1 |
| `mp:ImportTimelineFromFile(fcpxml)` silently changes the PROJECT resolution and imports items as Scaling = fit [L] | Save and restore the project resolution; set `Scaling = 0` / scaleToCrop (`pages/edit.md`) |
| Resolve's subtitle burn-in on 9:16 sits below the safe zone and clips long lines [L] | `--max-chars 16`, style in the GUI, or `finish.py --subs` |
| `LoadRenderPreset` doesn't reset a format/codec/name set earlier [L] | Set them explicitly every time (R.render) |
| The Fairlight Ducker has no threshold: over a voice track with room noise it applies a constant cut, pauses included [L] | Duck the bed with ffmpeg `sidechaincompress` before import, or cut-and-lower by API (`pages/fairlight.md`) |
| `SetTrackEnable("audio", n, false)` returns true, but the track still plays in renders [L] | `AudioVolume = -100` on its clips |
| EQ preset XML: `BAND_FREQ` is ignored; Resolve reads `BAND_LIMITED_FREQ` (a log index) [L] | `fl_eq.py` |
| DCTL as a LUT renders with a big "Studio" WATERMARK on free [L] | Bake .cube LUTs; look at the pixels after anything Studio-flavoured |
| `FlattenMulticam` returns nothing and does nothing; `InsertAudioToCurrentTrackAtPlayhead` true but no clip; `RenderWithQuickExport` nil; OTIO import nil [L] | Cut angles as clips; `R.place`; `R.render`; FCPXML |

## Media and analysis traps

| Trap | Fix |
|---|---|
| ffmpeg `silencedetect` compares **peaks**: in a noisy room, -40 dB (and even -35) finds no pauses and the whole clip comes back as one range [L] | `analyze.py silence` uses RMS with an auto noise floor and warns when it finds nothing |
| Transcripts are on the **source** clock; after jump cuts every caption is wrong [L] | `captions.py words.json --keep keep.json` remaps onto the timeline |
| Whisper mangles names in noisy rooms (product and person names come out as similar-sounding words). `initial_prompt` made it loop [L] | `transcribe.py --hotwords "..."`, then `captions.py --fix OLD=NEW`. Put doubtful words in the plan's questions |
| **libass (finish.py captions) uses fontconfig, not Fusion's list.** A family only Fusion has (Resolve bundles Open Sans) silently falls back [L] | `finish.py` picks an installed family via fc-list; `--font` to choose |
| A fixed vertical crop (`prep.py --cx`) loses a speaker who moves; guessing Pan units put 3 of 8 cuts off-frame [L] | Keep 16:9, `R.timeline{crop = true}`, `R.frame(item, x, zoom)` per cut, positions read off `sheet.py --ranges` |
| `R.dump()` in a project with no timeline | Returns a message (fixed); `R.tl()` is nil until `R.timeline` or `R.open` |

## Environment traps

- **Typed text in the main window fires shortcuts.** `(` is Shift+9, which opens Project Settings, a modal that blocks F6 and the console [L]. Only type into the verified console window (`rcon` refuses otherwise). Close stray modals with Escape (`resolve-up` does).
- **Resolve's process is named "GUI Thread":** `pgrep -x resolve` misses it. Use `pgrep -f '^/opt/resolve/bin/resolve'` [L].
- **After a crash** a "Problem Report for DaVinci Resolve" window stays up. Click **Ignore**, never Send, because sending uploads data. `resolve-up` handles it [L].
- **`bmd.readstring`/`bmd.writestring` are (de)serializers, not file I/O.** The console has no `io`, `require` or `os.execute`, but `ffi` works (the bridge uses libc) [L].
- **The console runs one script at a time.** While the bridge loop runs, typed console commands queue. Stop it with `rv 'stop()'` [L].
- **Long API calls** (renders, imports) block the bridge: use `RV_TIMEOUT=900 rv ...`. If `rv` times out, look for a dialog before retrying: `xdotool search --onlyvisible --class resolve` and the window names.
- **Debug log:** `~/.local/share/DaVinciResolve/logs/ResolveDebug.txt` (Fusion ERRORs such as missing fonts, plus crash dumps). After a crash it moves to `logs/LogArchive/ResolveDebug_C1.txt` [L].
- **Edits are saved by Resolve automatically**, but call `R.save()` before risky operations.
- **After a laptop suspend, CUDA dies** (cuInit 999) and Resolve shows "Unsupported GPU Processing Mode" at launch. Fix with Resolve closed:
  `sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm` (the user runs it) [L]. A Resolve left open over the suspend shows "The GPU failed to
  perform image processing" (error 719) instead: `rv 'R.save() resolve:Quit()'`, fix CUDA, relaunch. `resolve-up` checks CUDA before launching and prints the fix.
- **Resolve reuses top-level X windows: titles go stale**, so identify panels by screenshot; popups are windows titled `resolve`; popup list clicks can
  miss (use the keyboard); drags need gradual motion (`gui drag`) [L]. `references/gui.md`.
- Right after `OpenPage`, the first `SetCurrentTimecode` can be dropped, and on the Fusion page it is ignored [L]: `R.seek`.
