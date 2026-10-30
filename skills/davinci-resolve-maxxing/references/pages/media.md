# Media page + Media Pool

Import, bins, metadata, proxies, relink, audio sync, clip attributes. Nearly all of it is scriptable. **[L]** = verified on free 21.1.1 Linux.

## Which route for which job
| Job | Route | How |
|---|---|---|
| Import files (dedupes; warns on undecodable media) | API | `R.import(paths, bin)` [L]. Linux free can't decode H.264/HEVC/AAC: `prep.py transcode` first |
| Bins | API | `R.bin(name)` (top-level bin, created if missing), `mp:AddSubFolder(parent, name)`, `MoveClips`, `MoveFolders`, `DeleteFolders` (own bins only) [L] |
| Find a clip | API | `R.find(name)` (prefers file-backed clips over same-named compound clips). **SRT items are named without ".srt"** [L] |
| Metadata / notes / keywords / custom agent data | API | `SetMetadata({Keywords=..., Scene=...})`, `SetClipProperty("Comments", ...)`, `Set/GetThirdPartyMetadata(key, v)` [L] |
| Marks, markers, flags, colors | API | `SetMarkInOut(in, out, "all")`, `AddMarker`, `AddFlag`, `SetClipColor` [L] |
| Sync external audio | API | `R.sync(cam, mic)` (AutoSyncAudio waveform, sample-accurate) [L] |
| Proxies | API / ffmpeg | `LinkProxyMedia(path)`, `UnlinkProxyMedia()` [L]; make proxies with ffmpeg/prep.py (Resolve's proxy generator is GUI) |
| Relink / replace | API | `mp:UnlinkClips`, `mp:RelinkClips(clips, dir)`, `mpi:ReplaceClip(path)`, `ReplaceClipPreserveSubClip`, `LinkFullResolutionMedia` [L] |
| Bins as files | API | `folder:Export(path.drb)` then `mp:ImportFolderFromFile(path.drb)` round-trip [L] |
| Metadata to CSV | API | `mp:ExportMetadata(path.csv, clips)` [L] |
| Timeline from clips | API | `mp:CreateTimelineFromClips(name, clips)` [L] |
| Audio channel layout | API | `mpi:GetAudioMapping()` (JSON) / `SetAudioMapping(json)` [L]; Clip Attributes window = GUI |
| Scene cut detection | ffmpeg | `analyze.py cuts`. `tl:DetectSceneCuts()` = Studio upsell [L]; the Media page Scene Detector is GUI |
| Transcription / Intellisearch / audio classification / slate / motion-blur removal | Not on free | Return false, "package not installed", or the upsell modal [L]. **TranscribeAudio crashes**: use `transcribe.py` |
| Clone media (card offload) | API | `MediaStorage:StartCloneMedia/GetCloneStatus/StopCloneMedia` (status call verified only) |

## MediaPoolItem properties [L]
`clip:GetClipProperty()` keys used most: `Type` (Video, Audio, Still, Timeline, Compound, Multicam, Subtitle, Fusion Title...), `Resolution`,
`FPS`, `Frames` (**missing on audio-only items: use Duration**, `R.frames(clip)`), `Duration`, `File Path`, `Video Codec`, `Audio Codec`, `Audio Ch`,
`Sample Rate`, `Synced Audio`, `Audio Offset`, `Online Status`, `Comments`. `mpi:GetMediaId()` is a stable id; `mpi:GetTimeline()` for timeline items.

## Media Storage [L]
`resolve:GetMediaStorage()`: `GetMountedVolumeList()` = the Media Storage roots set in Preferences (here `~/Videos`). `GetFileList`/
`GetSubFolderList` return **empty outside those roots**; `AddItemListToMediaPool(paths)` accepts any path. Renders must also go inside a root
(`R.storage()`). Adding a root = Preferences > System > Media Storage (GUI, then restart).

## GUI
Shift+1 or `resolve:OpenPage("media")`. The Media page is for browsing and ingest (storage browser, clone tool, metadata editor, audio panel,
scene detector). The agent does all of it from the API above.
