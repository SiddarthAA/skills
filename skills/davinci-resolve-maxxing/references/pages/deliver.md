# Deliver page (render)

**[L]** = verified on free 21.1.1 Linux. Default flow: `R.render` (ProRes master inside Media Storage), then `ffprobe`, then `finish.py` for every platform.

## Which route for which job
| Job | Route | How |
|---|---|---|
| Master render | API | `R.render({dir, name, format="mov", codec="ProRes422HQ", range={in,out}, audio, preset, settings={...}})` returns status, seconds, path [L] |
| Platform files (H.264/AAC, loudness, captions) | ffmpeg | `finish.py master.mov --to reels|tiktok|shorts|youtube|linkedin|x|hero|podcast` [L] |
| Burn in Resolve subtitles | API | `settings = {ExportSubtitle = true, SubtitleFormat = "BurnIn"}` ("SeparateFile", "EmbeddedCaptions" too) [L] |
| One file per clip | API | `p:SetCurrentRenderMode(0)` (files get frame-number suffixes); back to 1 for single clip [L] |
| Presets | API | `SaveAsNewRenderPreset`, `UpdateRenderPreset`, `DeleteRenderPreset`, `resolve:ExportRenderPreset(name, xml)` / `ImportRenderPreset(xml)` [L] |
| Stop a render | API | `p:StopRendering()`: job Cancelled, partial file kept [L] |
| Quick Export | (none) | `RenderWithQuickExport("ProRes 422 HQ", {...})` returned nil / Inactive: not working by API [L] |
| Audio-only file | ffmpeg | Render the master, then `ffmpeg -i master.mov -vn -c:a pcm_s24le out.wav` (audio-only jobs stayed "Ready") |
| DCP/IMF, tape | Studio / hardware | Not for this skill |

## Must-knows [L]
- **Target dir must be inside a Media Storage root** (`R.storage()`, here `~/Videos`), or AddRenderJob returns "" plus a "Render Path Inaccessible" dialog.
- **A timeline with no video items renders nothing**: Duration 0, "Add to Render Queue" greyed out, AddRenderJob "". Put a carrier/black clip on V1 (audio-only timelines too).
- **Settings stack on whatever was loaded before, and `LoadRenderPreset` does NOT reset a format/codec/CustomName set earlier** (an APV job leaked into a later
  "ProRes 422 HQ" render). Always set format, codec, name and range explicitly; R.render does.
- Codec IDs, not display names: `p:GetRenderCodecs("mov")` maps them (ProRes422HQ, ProRes4444, DNxHRHQ, FFV1..., lpcm).
- Linux free formats: mov, mxf, mkv, avi, mp4, dpx, exr, tif, png, jpg, gif, webp, wav... **No H.264/HEVC.** MP4 here = APV 422 10-bit video
  (ffmpeg 6 can't decode it) + FLAC audio (AudioCodec "aac" was rejected). "YouTube - *" presets load as format "unknown". Hence ProRes + finish.py.
- `MarkIn`/`MarkOut` are absolute frames (R.render's `range` is relative). `GetRenderResolutions(fmt, codec)` lists sizes (19 for ProRes).
- Render keys (`SetRenderSettings`): SelectAllFrames, MarkIn, MarkOut, TargetDir, CustomName, UseUniqueFilenames, UniqueFilenameStyle, ExportVideo,
  ExportAudio, FormatWidth, FormatHeight, FrameRate, PixelAspectRatio, VideoQuality, AudioFormat, AudioCodec, AudioBitDepth, AudioSampleRate,
  ColorSpaceTag, GammaTag, ExportAlpha, AlphaMode, EncodingProfile, MultiPassEncode, NetworkOptimization, ClipStartFrame, TimelineStartTimecode,
  ReplaceExistingFilesInPlace, ExportSubtitle, SubtitleFormat, UseFullExtents, AddFrameHandles, DataBurnIn.
- Always `ffprobe` the output (a stray "Audio Only" preset once produced audio-only masters).

## GUI
Shift+8. "Add to Render Queue" bottom-left of Render Settings (about (344,990)); "Render All" in the queue (about (1778,510)). Only needed
if the API refuses a job: screenshot first.
