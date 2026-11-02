# Fairlight page (audio)

Mixer, track EQ/dynamics, Fairlight FX, buses, ducking, loudness. **[L]** = verified on free 21.1.1 Linux.
Coordinates assume a 1920x1080 screen, maximized main window (1854x1048), default layout: screenshot first (`references/gui.md`).

## Which route for which job

| Job | Route | How |
|---|---|---|
| Clip volume, pan, pitch, fades | API | `item:SetProperty("AudioVolume", -6)` (dB), `AudioPan` (-100..100), `AudioPitchSemiTones`/`AudioPitchCents`; `item:SetFades({FadeIn=30, FadeOut=45})` frames [L] |
| Loudness normalize (clip gain) | API | `R.normalize(tl, items, "EBU R128", -23)`; modes from `tl:GetNormalizeAudioModes()` [L] |
| Sync external mic to camera | API | `R.sync(cam, mic)` (AutoSyncAudio, sample-accurate) [L] |
| **Whole mix: per-track EQ + dynamics + insert FX + Ducker** | **Template** | Build once in the GUI, save a *Fairlight Configuration preset*, then `R.project():ApplyFairlightPresetToCurrentTimeline(name)` on any timeline with the same track layout [L]: a blind run's applied render was bit-identical to the hand-built one |
| Track EQ | Template file | `fl_eq.py NAME --hp 80 --band 3:300:-2 --band 5:5000:2.5` writes the XML; Resolve lists it immediately [L]. Band shapes are fixed: **2 = low shelf, 3-4 = bells, 5 = high shelf** (use band 3 or 4 for a bell). Frequencies snap to 257 log steps per range (350 Hz shows as 348). Apply with the Presets Library (below) |
| Track compressor/gate/limiter | Template file / GUI | Ship XML in `assets/fairlight/DYN/` (values are indices: save from the GUI, then copy) [L] |
| Ducking music under voice | GUI once, then config preset | Ducker in the Inspector (below); config presets carry it [L]. **The Ducker has no threshold**: with a voice track whose room noise sits around -44 dBFS it held a constant cut (exactly the Duck Level, in pauses too) [L]. For music that rises in pauses: split the bed at speech boundaries (`analyze.py silence` on the voice) with `R.keep`/`R.place`, `R.volume(piece, -10)` under speech plus `R.fade` ramps (API). **Real ducking with a threshold: ffmpeg before import** (below) [L] |
| Insert Fairlight FX (reverb, de-esser, noise reduction...) | GUI | Mixer "Effects +" menu [L]; plugin presets are binary `.dat` (save from the GUI) |
| Buses and sends | GUI | Fairlight > Bus Format, mixer "Bus Sends" [L] |
| Automation, ADR, recording | GUI only | Manual ch. 173-178. Not needed for agent edits |
| Voice isolation, Dialogue Separator, Music Remixer | Studio | Not on free. `tl:SetVoiceIsolationState` returns true but does nothing useful [L]. Clean up with ffmpeg (`afftdn`, `highpass`) before import |

**Ducking with a threshold, outside Resolve** [L 2026-11-03]: duck the music bed against the voice as it plays in the edit (a VO placed
uncut, or the dialogue from a music-free render), then import the result as the bed:
```bash
ffmpeg -i music.wav -i voice.wav -filter_complex "[0:a][1:a]sidechaincompress=threshold=0.02:ratio=20:level_sc=4:attack=50:release=500[d]" -map "[d]" music_ducked.wav
```
Measured: under a -31.5 dB camera voice the bed went -18.3 -> -31.7 dB during speech and stayed -16.6 dB in a pause. `level_sc` scales the
key: about 4 for a quiet camera voice, 1 for a VO near -20 dB. Check a speech window and a pause with `volumedetect`.

There's no API for track EQ, dynamics, inserts, buses or ducking. The template route covers them, so the GUI is a one-time setup.

## Starter presets (installed by `install.sh` into `~/.local/share/DaVinciResolve/configs/Fairlight/Presets/`)
| Preset | Kind | What |
|---|---|---|
| `agent-voice-clean` | EQ | HPF 80 Hz, -2 dB bell at 300 Hz (mud), +2.5 dB high shelf from 5 kHz (air/presence) |
| `agent-music-under-voice` | EQ | HPF 40 Hz, -4 dB at 2 kHz (room for speech) |
| `agent-voice-comp` | Dynamics | Compressor -20 dB threshold, 3.9:1 (shown on screen), 5 ms attack |
Built-in EQ presets also exist: "Dialog - Clean add hi end", "Dialog - Female lav mic fixer", "Dialog - Male lav finisher",
"Dialog - Male", "General - Telephone effect", "Music Master - Top end Boost".

## Preset files (template route) [L]
| Folder under `configs/Fairlight/Presets/` | Format | Notes |
|---|---|---|
| `EQ/<name>.xml` | XML `<FXPreset type="EQ"><Setting module="MT_TRACK" parameter=".." value=".."/>` | `BAND_*_0..5` = bands 1..6 (slots 6-7 exist but aren't shown in the window). `BAND_SHAPE` sets the filter type. `BAND_GAIN` in 0.1 dB. **Frequency is read from `BAND_LIMITED_FREQ_n`** = round(256·ln(f/lo)/ln(hi/lo)) inside the band's range (`BAND_RANGE` 0 L 30-399, 1 ML 100-1.5k, 2 MH 450-8k, 3 H 1.4k-22k; band 1 is L, band 6 is H). `BAND_FREQ` alone is ignored. `fl_eq.py` does this |
| `DYN/<name>.xml` | same XML | `COMP_IN/THRES (0.1 dB)/RATIO (index; 58 shows as 3.9:1)/ATT/REL`, `GATE_*`, `LIM_*`, `DYN_IN` |
| `PLUGIN/<Plugin>_<id>/<name>.dat` | binary (param names + float32 normalized) | Save from the plugin window "+" |
| `CONSOLE_FLEXI/<name>.dat` | binary | Fairlight Configuration presets: the whole mixer (track EQ, dynamics, insert FX, Track FX incl. the Ducker: the file contains `BMDDucker::DUCK_AMOUNT/DUCK_SOURCE`). `resolve:GetFairlightPresets()` lists them, **0-indexed** (`ipairs` skips the first: use `pairs`) |
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
- **A timeline with no video items can't render** (Deliver shows Duration 0, AddRenderJob returns ""). Put a carrier on V1 for the range. Carriers are 20 s
  (600 frames): place several, or make a longer one with `prep.py carriers WxH --fps 30 --seconds 120 --out ~/resolve-bridge/assets`.
- `tl:SetTrackEnable("audio", n, false)` reads back false but **the track still plays in renders**. To silence a track for a test render: `AudioVolume = -100` on its clips.
- Building a timeline (`R.timeline`/`R.place`) jumps Resolve to the Edit page: `OpenPage("fairlight")` again before GUI work.

## GUI how-to [L]
| Element | Where / how |
|---|---|
| Open the page | `resolve:OpenPage("fairlight")` or Shift+7 |
| Mixer strips | Media Pool open, Inspector closed (default): A1 x=1685, A2 x=1752, Bus 1 x=1819. **With the Inspector open** the Media Pool closes and strips move to A1 x=1264, A2 x=1331, Bus 1 x=1398; track headers move to x≈95. Closing the Inspector doesn't bring the Media Pool back (button (82,38) does). Rows: Input 409, Track FX 436, Order 463, **Effects + 490**, **Dynamics 565**, **EQ 620**, Bus Sends 653, Pan 700. The mixer can't show the Ducker (Track FX row shows only "Dial Lev"); check it in the Inspector |
| EQ / Dynamics window | Double-click the graphic in the strip (`gui click 1685 620 double`). EQ window (1020x730): band on/off buttons y=443 (x=60, 225, 390, 555, 720, 885); Frequency fields y=515; Gain fields y=620; Q y=690; preset dropdown (155,44); "+" save (19,44). Dynamics: Compressor on (430,440); Threshold (342,572), Ratio (432,572), Attack (342,690), Hold (432,690) |
| Number fields | `gui field X Y VALUE` (double-click, Ctrl+A, type, Return). **Type the value in the field's display format**: ratio `4.0:1` (plain `4` is ignored); negative numbers OK |
| Insert an effect | Mixer "Effects +" (A2: `gui click 1752 490`) opens categories: Channel, Delay, Distortion, Dynamics, EQ, Instrument, Metering, Modulation, Multi Effect, Pitch, Restoration, Reverb, Spatial, Tools. Click a category, then the plugin (submenus open on click). A "Plugin UI Panel" window opens |
| Fairlight FX list (free) | Chorus, De-Esser, De-Hummer, Delay, Dialogue Processor, Distortion, Echo, Fairlight EQ, Flanger, Foley Sampler, Frequency Analyzer, Gain, LFE Filter, Limiter, Meter, Modulation, Multiband Compressor, Noise Reduction, Phase Meter, Pitch, Reverb (presets Cathedral/Concert Hall/Studio), Soft Clipper, Stereo Fixer, Stereo Width, Surround Analyzer, Vocal Channel. Track FX: Dialogue Leveler, Ducker |
| Save a preset in a plugin/EQ window | "+" at the top-left, then the `Message` "Create New" (407,161), then the `Input` dialog: `GUI_WIN='^Input$' gui click 207 87; gui type NAME`, Return |
| **Presets Library** | Fairlight menu (`gui click 580 9`), then item 3 at (60,56) in the popup. Window 661x422: Filter dropdown (183,44) (EQ / Dynamics / Plugins / Global Track / Global Bus / Fairlight Configuration presets; it reopens on the last filter); "All Tracks" dropdown (608,44); preset rows from y=73, step 27 (the first row is pre-selected); track tiles y=85, x=345+89*i (toggle; cleared after every Apply); Save New (517,399); Apply (604,399). **Save New with a preset selected asks "Update / Create New": Update OVERWRITES that preset**; Create New is at about (407,166). After an Apply the EQ/Dynamics windows say "Default*": confirm by the values, not the name |
| **Ducker** | Click the music track header (`gui click 540 457` for A2). Inspector button (1800,38). It always opens in clip mode: switch to TRACK mode with the 2nd icon at its top-left (1481,67). **Rows shift with the AI Dialogue Leveler section above**: collapsed/off it is Ducker on (1461,244), Source 1 (1669,274), Duck Level (1740,298), Advanced (1461,334) (Lookahead/Rise/Hold/Recovery fields at x≈1740, y≈364/389/414/439); expanded it was (1463,378)/(1669,407)/(1741,433). Screenshot the Inspector first. Source 1 defaults to the first other track; pick others with the keyboard (Up/Down + Return). Duck Level default 2.7 dB; about 10 dB is a usual music bed. Verified: music under speech -33.2 dBFS ducked vs -23.2 off |
| Bus Format | Fairlight menu item 1: Add Bus (81,560), OK (509,611) |
| AI Dialogue Leveler | A Track FX on every track by default (Inspector track mode) |

**Traps:** Resolve reuses X windows, so a plugin panel can be titled "Patch Input/Output": find it by size/screenshot and target it by id
(`GUI_WIN=<id>`). Clicks on popup list items sometimes don't register: use the keyboard. After a render the Ducker's Source can look blank
while the setting is still active.

## Recipe: mix template once, apply forever
1. In the GUI on a timeline with the target layout (A1 voice, A2 music, A3 SFX): Presets Library > Equalizer Presets: apply `agent-voice-clean` to A1,
   `agent-music-under-voice` to A2; Dynamics `agent-voice-comp` to A1; Ducker on A2 (source A1, about 10 dB); reverb or limiter inserts as needed.
2. Presets Library > Filter: Fairlight Configuration Presets > Save New > name it, e.g. `agent-talk-mix`.
3. In every later build: `R.project():ApplyFairlightPresetToCurrentTimeline("agent-talk-mix")` after placing the clips (needs the same track count).
   The Ducker set in step 1 is included. Check the result in the Inspector (track mode) and with a render plus `finish.py` QA (LUFS).
