# Fairlight page (audio)

Mixer, track EQ/dynamics, Fairlight FX, buses, ducking, loudness. **[L]** = verified on free 21.1.1 Linux.
Coordinates assume a 1920x1080 screen, maximized main window (1854x1048), default layout: screenshot first (`references/gui.md`).

## Which route for which job

| Job | Route | How |
|---|---|---|
| Clip volume, pan, pitch, fades | API | `item:SetProperty("AudioVolume", -6)` (dB), `AudioPan` (-100..100), `AudioPitchSemiTones`/`AudioPitchCents`; `item:SetFades({FadeIn=30, FadeOut=45})` frames [L] |
| Loudness normalize (clip gain) | API | `R.normalize(tl, items, "EBU R128", -23)`; modes from `tl:GetNormalizeAudioModes()` [L] |
| Sync external mic to camera | API | `R.sync(cam, mic)` (AutoSyncAudio, sample-accurate) [L] |
| **Whole mix: per-track EQ + dynamics + insert FX** | **Template** | Build once in the GUI, save a *Fairlight Configuration preset*, then `R.project():ApplyFairlightPresetToCurrentTimeline(name)` on any timeline [L] |
| Track EQ | Template file | `scripts/fl_eq.py NAME --hp 80 --band 3:300:-2 --band 5:5000:2.5` writes the XML; Resolve lists it immediately [L]. Apply with the Presets Library (below) |
| Track compressor/gate/limiter | Template file / GUI | Ship XML in `assets/fairlight/DYN/` (values are indices: save from the GUI, then copy) [L] |
| Ducking music under voice | GUI per timeline, or API by cutting | Ducker in the Inspector (below) [L]. **Config presets do NOT carry the Ducker** (measured: same LUFS as no ducking) [L]. API route: split the music bed at speech boundaries (`analyze.py silence` on the voice) with `R.keep`/`R.place`, then `R.volume(piece, -10)` on the pieces under speech plus `R.fade` ramps |
| Insert Fairlight FX (reverb, de-esser, noise reduction...) | GUI | Mixer "Effects +" menu [L]; plugin presets are binary `.dat` (save from the GUI) |
| Buses and sends | GUI | Fairlight > Bus Format, mixer "Bus Sends" [L] |
| Automation, ADR, recording | GUI only | Manual ch. 173-178. Not needed for agent edits |
| Voice isolation, Dialogue Separator, Music Remixer | Studio | Not on free. `tl:SetVoiceIsolationState` returns true but does nothing useful [L]. Clean up with ffmpeg (`afftdn`, `highpass`) before import |

There's no API for track EQ, dynamics, inserts, buses or ducking. The template route covers them, so the GUI is a one-time setup.

## Starter presets (installed by `install.sh` into `~/.local/share/DaVinciResolve/configs/Fairlight/Presets/`)
| Preset | Kind | What |
|---|---|---|
| `agent-voice-clean` | EQ | HPF 80 Hz, -2 dB at 300 Hz (mud), +2.5 dB at 5 kHz (presence) |
| `agent-music-under-voice` | EQ | HPF 40 Hz, -4 dB at 2 kHz (room for speech) |
| `agent-voice-comp` | Dynamics | Compressor -20 dB threshold, 4:1, 5 ms attack |
Built-in EQ presets also exist: "Dialog - Clean add hi end", "Dialog - Female lav mic fixer", "Dialog - Male lav finisher",
"Dialog - Male", "General - Telephone effect", "Music Master - Top end Boost".

## Preset files (template route) [L]
| Folder under `configs/Fairlight/Presets/` | Format | Notes |
|---|---|---|
| `EQ/<name>.xml` | XML `<FXPreset type="EQ"><Setting module="MT_TRACK" parameter=".." value=".."/>` | `BAND_*_0..5` = bands 1..6. `BAND_GAIN` in 0.1 dB. **Frequency is read from `BAND_LIMITED_FREQ_n`** = round(256·ln(f/lo)/ln(hi/lo)) inside the band's range (`BAND_RANGE` 0 L 30-399, 1 ML 100-1.5k, 2 MH 450-8k, 3 H 1.4k-22k; band 1 is L, band 6 is H). `BAND_FREQ` alone is ignored. `fl_eq.py` does this |
| `DYN/<name>.xml` | same XML | `COMP_IN/THRES (0.1 dB)/RATIO (index; 58 = 4.0:1)/ATT/REL`, `GATE_*`, `LIM_*`, `DYN_IN` |
| `PLUGIN/<Plugin>_<id>/<name>.dat` | binary (param names + float32 normalized) | Save from the plugin window "+" |
| `CONSOLE_FLEXI/<name>.dat` | binary | Fairlight Configuration presets: the whole mixer (track EQ, dynamics, insert FX; **not** Track FX like the Ducker). `resolve:GetFairlightPresets()` lists them |
A file written into `EQ/` or `DYN/` appears in the dropdowns at once (no restart). The `.drt` timeline export does **not** contain mixer state.

## API [L]
```lua
local it = tl:GetItemListInTrack("audio", 1)[1]
it:GetProperty()  -- {AudioVolume, AudioVolumeEnabled, AudioPan, AudioPanEnabled, AudioPitchSemiTones, AudioPitchCents, AudioPitchEnabled}
it:SetProperty("AudioVolume", -6); it:SetFades({FadeIn = 30, FadeOut = 45}); it:GetSpeed()  -- {Percentage, PitchCorrection}
tl:GetTrackSubType("audio", 1)   -- "stereo" | "mono" | "5.1" ...
resolve:GetFairlightPresets()    -- configuration presets (saved in the GUI)
R.project():ApplyFairlightPresetToCurrentTimeline("agent-mix")   -- true; EQ, comp and Reverb insert carried over (seen on screen)
mpi:GetAudioMapping() / mpi:SetAudioMapping(json); item:GetSourceAudioChannelMapping()
```
- Audio-only media pool items have no "Frames" property, only `Duration` + `FPS` (`R.frames(clip)` handles it).
- `p:InsertAudioToCurrentTrackAtPlayhead(path, offset, samples)`: false on Edit; true on Fairlight but nothing appears. Use `R.place(..., {media = "audio"})`.
- **A timeline with no video items can't render** (Deliver shows Duration 0, AddRenderJob returns ""). Put a carrier/black clip on V1 for the range.

## GUI how-to [L]
| Element | Where / how |
|---|---|
| Open the page | `resolve:OpenPage("fairlight")` or Shift+7 |
| Mixer strips | A1 x=1685, A2 x=1752, Bus 1 x=1819 (more tracks: scroll the mixer). Rows: Input 409, Track FX 436, Order 463, **Effects + 490**, **Dynamics 565**, **EQ 620**, Bus Sends 653, Pan 700 |
| EQ / Dynamics window | Double-click the graphic in the strip (`gui click 1685 620 double`). EQ window (1020x730): band on/off buttons y=443 (x=60, 225, 390, 555, 720, 885); Frequency fields y=515; Gain fields y=620; Q y=690; preset dropdown (155,44); "+" save (19,44). Dynamics: Compressor on (430,440); Threshold (342,572), Ratio (432,572), Attack (342,690), Hold (432,690) |
| Number fields | `gui field X Y VALUE` (double-click, Ctrl+A, type, Return). **Type the value in the field's display format**: ratio `4.0:1` (plain `4` is ignored); negative numbers OK |
| Insert an effect | Mixer "Effects +" (A2: `gui click 1752 490`) opens categories: Channel, Delay, Distortion, Dynamics, EQ, Instrument, Metering, Modulation, Multi Effect, Pitch, Restoration, Reverb, Spatial, Tools. Click a category, then the plugin (submenus open on click). A "Plugin UI Panel" window opens |
| Fairlight FX list (free) | Chorus, De-Esser, De-Hummer, Delay, Dialogue Processor, Distortion, Echo, Fairlight EQ, Flanger, Foley Sampler, Frequency Analyzer, Gain, LFE Filter, Limiter, Meter, Modulation, Multiband Compressor, Noise Reduction, Phase Meter, Pitch, Reverb (presets Cathedral/Concert Hall/Studio), Soft Clipper, Stereo Fixer, Stereo Width, Surround Analyzer, Vocal Channel. Track FX: Dialogue Leveler, Ducker |
| Save a preset in a plugin/EQ window | "+" at the top-left, then the `Message` "Create New" (407,161), then the `Input` dialog: `GUI_WIN='^Input$' gui click 207 87; gui type NAME`, Return |
| **Presets Library** | Fairlight menu (`gui click 580 9`), item 3. Window 661x422: Filter dropdown (183,44) (EQ / Dynamics / Plugins / Global Track / Global Bus / Fairlight Configuration presets); preset rows from y=73, step 27; track tiles y=85, x=345+89*i (toggle); Save New (517,399); Apply (604,399) |
| **Ducker** | Click the music track header (`gui click 540 457` for A2). Inspector button (1800,38). Switch to TRACK mode: 2nd icon at the Inspector's top-left (1481,67). Ducker on (1463,378); Source 1 dropdown (1669,407), then **keyboard Up/Down + Return**; Duck Level field (1741,433). Verified: -20.7 LUFS ducked vs -18.1 off |
| Bus Format | Fairlight menu item 1: Add Bus (81,560), OK (509,611) |
| AI Dialogue Leveler | A Track FX on every track by default (Inspector track mode) |

**Traps:** Resolve reuses X windows, so a plugin panel can be titled "Patch Input/Output": find it by size/screenshot and target it by id
(`GUI_WIN=<id>`). Clicks on popup list items sometimes don't register: use the keyboard. After a render the Ducker's Source can look blank
while the setting is still active.

## Recipe: mix template once, apply forever
1. In the GUI on a timeline with the target layout (A1 voice, A2 music, A3 SFX): Presets Library > Equalizer Presets: apply `agent-voice-clean` to A1,
   `agent-music-under-voice` to A2; Dynamics `agent-voice-comp` to A1; reverb or limiter inserts as needed.
2. Presets Library > Filter: Fairlight Configuration Presets > Save New > name it, e.g. `agent-talk-mix`.
3. In every later build: `R.project():ApplyFairlightPresetToCurrentTimeline("agent-talk-mix")` after placing the clips (needs the same track count).
4. Ducking: Ducker per timeline in the Inspector (step above), or cut-and-lower the music by API. Check with a render plus `finish.py` QA (LUFS).
