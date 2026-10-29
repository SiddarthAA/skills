# Gotchas: free DaVinci Resolve 21.1 scripting

Read this before your first script. **[L]** = verified in our lab (free 21.1.1, Linux). **[R]** = reported by the
samuelgursky/davinci-resolve-mcp project (mostly Studio 21.x), not re-tested here.

## Things that crash or freeze Resolve

| Never do this | What happens | Do this instead |
|---|---|---|
| `tl:CreateSubtitlesFromAudio()`, `item:TranscribeAudio()`, `AnalyzeForIntellisearch`, `GenerateSpeech`, voice isolation and other AI calls on **free** | Crashed Resolve (Qt fatal) [L]. Reported elsewhere as an upgrade dialog that blocks every later call [R] | `scripts/transcribe.py` (faster-whisper) for captions and word timings |
| `tl:AutoAlignClips()` | Returned false once and crashed Resolve twice, a moment after the call [L] | Media-pool `R.sync(cam, mic)` (AutoSyncAudio, sample-accurate) [L] |
| `pm:ArchiveProject(...)` with source or proxy media flags | SIGSEGV [R] | `pm:ExportProject(name, path.drp, false)` [L] |
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
| SRT via API: `ImportMedia(srt)` works (Type=Subtitle), but `AppendToTimeline` places nothing [L]; there's no API to style captions | Captions: `finish.py --subs file.srt` (burn-in) or `R.title` per caption/word |

## Media and analysis traps

| Trap | Fix |
|---|---|
| ffmpeg `silencedetect` compares **peaks**: in a noisy room, -40 dB (and even -35) finds no pauses and the whole clip comes back as one range [L] | `analyze.py silence` uses RMS with an auto noise floor and warns when it finds nothing |
| Transcripts are on the **source** clock; after jump cuts every caption is wrong [L] | `captions.py words.json --keep keep.json` remaps onto the timeline |
| Whisper mangles names in noisy rooms ("Cordova" for Quad AI). `initial_prompt` made it loop [L] | `transcribe.py --hotwords "..."`, then `captions.py --fix OLD=NEW`. Put doubtful words in the plan's questions |
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
