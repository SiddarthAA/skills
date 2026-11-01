# Recipes

Every video follows the same pipeline with **three checkpoints where the human approves**. Never skip a checkpoint
unless the user says so. Numbers (lengths, levels, safe zones) come from `craft-and-specs.md`.

```
intake -> analyze -> PLAN (checkpoint 1) -> prep -> build -> self-review stills -> PREVIEW (checkpoint 2)
       -> revise -> master -> finish + QA -> DELIVER (checkpoint 3)
```

Paths used below: `S=<skill>/scripts`, work dir `W=~/videos/<project>` (prep, plans, analysis),
render dir `~/Videos/<project>` (must be inside Resolve Media Storage; `rv 'return R.storage()'`).
**Never write into the source folder.**

## 0. Intake and analysis (all video types)

```bash
# what is there
for f in SRC/*; do ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate:format=duration -of compact=p=0 "$f"; done
$S/sheet.py SRC/clip.MOV --out $W/scan/clip.png            # look at every clip as one image (--start/--dur for a window)
$S/sheet.py SRC/*.JPG --grid --out $W/scan/photos.png        # photos
$S/analyze.py cuts reference.mp4                              # reference pacing (avg shot length)
$S/analyze.py beats song.wav --fps 30 > $W/beats.json         # bpm, beats_f, bars_f, drop_guess_f
$S/transcribe.py interview.wav --hotwords "Names, Brand" --out $W/tx   # words.json, .srt, .pop.srt (source clock)
yt-dlp -o "$W/ref.%(ext)s" URL                                # references (personal study only)
```
Read the sheets yourself (they are images). Note the best moments with timestamps.

## 1. PLAN (checkpoint 1)

Write `$W/plan.md` and show it to the user before building:
- Deliverables: platform(s), aspect, length, fps (from craft-and-specs §1).
- Structure with timings: hook / build / payoff / CTA, or the reference's structure.
- Shot list: `#, timeline in-out (frames), source file @ timecode, framing (crop cx), motion, text, sfx`.
- Look (LUT name), fonts and colours (brand kit), music source and its licence.
- Open questions.
Wait for "go" or edits.

## 2. Prep (Linux free needs ProRes)

```bash
$S/prep.py transcode SRC/*.MOV --out $W/media --size 1080x1920 --mode crop --cx 0.5 --fps 30   # vertical reframe
$S/prep.py transcode SRC/screen.mp4 --out $W/media --fps 30                                     # keep 16:9
$S/prep.py still SRC/DSC_1.JPG --out $W/media --size 1080x1920 --cx 0.4 --seconds 4             # photos -> clips
$S/prep.py carriers 1080x1920 --fps 30 --out ~/resolve-bridge/assets                            # if a new size/fps
```
Crop centre: look at the contact sheet and set `--cx` so the subject's face or the action is in frame (0 = left, 1 = right).
Photos at 24 MP and 4K phone footage crop to vertical cleanly. 1080p landscape video loses detail when cropped to
9:16, so keep those shots short, use `--mode blur` (whole frame over a blurred fill), or keep 16:9 and frame per cut
with `R.timeline{crop = true}` + `R.frame` (subjects that move).

## 3. Build in Resolve

```bash
resolve-up my-project            # launches Resolve, starts the bridge, opens/creates the project
rv 'return R.dump()'             # sanity
RV_TIMEOUT=300 rv < $W/build.lua
```
Write `$W/build.lua` as a small script using R helpers; keep shot data at the top so revisions are one-line edits.

## 4. Self-review before showing anyone

```bash
rv 'return #R.stills(R.tl(), {0, 15, 45, 300, 301, 450}, os.getenv("HOME").."/videos/P/review", "f")'
$S/sheet.py ~/videos/P/review/*.png --grid --out ~/videos/P/review.png     # then LOOK at it
grep -a "Fusion.*ERROR" ~/.local/share/DaVinciResolve/logs/ResolveDebug.txt | tail     # missing fonts etc.
```
Check: framing, text inside the safe zone (9:16: x 120-888, y 288-1248), no black or flash frames, grade consistent, text spelled right.

## 5. Preview, revise, master, finish

```bash
RV_TIMEOUT=900 rv 'return R.render({dir = os.getenv("HOME").."/Videos/P", name = "P_master"})'
ffprobe -v error -show_entries stream=codec_type,width,height -of compact=p=0 ~/Videos/P/P_master.mov   # video stream present?
$S/finish.py ~/Videos/P/P_master.mov --to reels --name 20261029_p_hype_v01      # preview mp4 for checkpoint 2
```
Send the preview path and a contact sheet of it (checkpoint 2). Apply notes by editing build.lua data and re-running
(timelines get a numeric suffix), or with targeted `rv` edits. Final: `finish.py` for every platform (checkpoint 3).
Report the QA JSON (LUFS, true peak, black frames).

---

## A. Short-form hype reel (9:16, beat-synced)

Pattern from a shipped reel: dialogue or hook section (slow pushes, word-timed text), then a beat drop (cut every
1-2 beats, punch-ins, shake on the drop, whooshes on cuts, flash into the payoff), then a branded end card.

1. `analyze.py beats song.wav` gives `bpm`, `beats_f`, `drop_guess_f`. Cuts go on `beats_f` (or 1 frame early). Never round shot lengths independently: always cut at the beat frame.
2. Text timing: `transcribe.py song_or_vo.wav` gives words.json; put each text card's `at` on its word's `start_f`.
3. SFX: `analyze.py peak whoosh.mp3` gives `peak_s`. Place each SFX at `cut_frame - round(peak_s*fps)` so the peak lands on the cut.

```lua
-- build.lua (excerpt)
local W = os.getenv("HOME") .. "/videos/hype/media/"
local SHOTS = {  -- {file, at, len, motion}
  {"crowd.mov", 0, 45, {push = {from = 1.0, to = 1.08}}},
  {"speaker.mov", 45, 28, {push = {from = 1.04, to = 1.12}}},
  {"stage.mov", 300, 30, {punch = {from = 1.35, frames = 6}, shake = {amp = 0.02, frames = 10}}},  -- the drop
  {"demo.mov", 330, 14, {punch = {}}},
}
local tl = R.timeline("hype v1", {w = 1080, h = 1920, fps = 30, video = 3, audio = 3})
local files = {} for _, s in ipairs(SHOTS) do files[#files + 1] = W .. s[1] end
R.import(files, "shots")
local items = {}
for _, s in ipairs(SHOTS) do
  local it = R.place(tl, s[1], {at = s[2], len = s[3], media = "video"})[1]
  R.motion(it, s[4]); items[#items + 1] = it
end
R.group("hype look", items, "agent/moody.cube")
R.title(tl, {text = "MILLION", at = 70, len = 30, font = "Anton", style = "Regular", size = 0.16, center = {0.5, 0.33}})
R.title(tl, {text = "hacktober hack", at = 300, len = 29, font = "ArchitypeStedelijkW00", style = "Regular", size = 0.1, track = 3})
R.import({W .. "song.wav", W .. "whoosh.wav"}, "audio")
R.place(tl, "song.wav", {at = 0, media = "audio", track = 1})
for _, cut in ipairs({330, 361, 389}) do R.place(tl, "whoosh.wav", {at = cut - 5, media = "audio", track = 2}) end
return R.dump(tl)
```
- White flash into a payoff: place a 10-frame white clip on V2 (`ffmpeg -f lavfi -i color=white:s=1080x1920:r=30 -t 1 -c:v prores_ks white.mov`, then prep) and `R.fade(item, 0, 8)`.
- Black beat before the drop: just leave a gap on V1.
- Picture-in-picture: put the inset clip on V2 with `item:SetProperties({ZoomX=0.7, ZoomY=0.7, CropTop=..., CropBottom=...})`, or pre-composite it with ffmpeg.
- Grain/vignette: a mid-grey noise clip on the top track with `SetProperties({CompositeMode = resolve.COMPOSITE_OVERLAY, Opacity = 70})`.
- Copyrighted reference audio is for timing only. The deliverable uses licensed music, or no music so platform audio can be attached in-app.

## B. Product demo / screen recording (16:9 or 9:16)

1. Transcode the recording (`prep.py transcode`, keep 16:9; for 9:16 use `--mode blur` and let zooms do the work).
2. VO first (`transcribe.py vo.wav`), then cut picture to the VO: one idea every 5-10 s, hold each result for 2 s or more.
3. Zoom-ins: `R.zoom` (Fusion Transform, eased in, hold, eased out). Read the target off a screenshot or contact sheet
   as fractions from the TOP-LEFT. Verified pixel-exact: the target point lands at frame centre.
```lua
local it = R.place(tl, "screen.mov", {at = 0, len = 900, media = "video"})[1]
R.zoom(it, {target = {0.72, 0.31}, scale = 2.0, at = 120, hold = 210, ease = 15})   -- button at 72% across, 31% down
R.zoom(it, {target = {0.30, 0.80}, scale = 1.5, at = 400, hold = 480})              -- more zooms add keyframes
```
   Rules: 125-150% for a panel, about 200% for a button. Hold until the result is visible. At most one zoom move every 3-5 s.
4. Captions: `captions.py vo.words.json --keep keep.json` if the VO was cut, then `finish.py --subs` (never over the UI being shown; caption in a band).
5. Blur secrets (emails, keys) before export: ffmpeg `boxblur` on a crop region in prep, or a Fusion Blur with a mask.
6. Look: `agent/clean.cube`; loudness -14 LUFS.

## C. Talking head / podcast

Validated end to end (a 21 s Reels clip from a 5-minute camera file: 8 jump cuts, per-cut framing, punch-ins, hook
title, burned captions, -14.0 LUFS).

1. **Source window.** `sheet.py cam.MOV --start 115 --dur 45` to find the usable stretch, then
   `prep.py transcode cam.MOV --out $W/media --start 115 --dur 45 --fps 30` and **keep it 16:9** (a fixed vertical crop
   loses a speaker who moves).
2. **External mic.** `R.sync(R.find("cam.mov"), R.find("mic.wav"))`. The synced clip carries 2 audio tracks: A1 = camera audio, A2 = mic. For mic-only
   sound mute the A1 items (`AudioVolume = -100`). "Audio Offset" on the camera clip = frames, mic time = camera time + offset.
3. **Transcript.** `$S/transcribe.py $W/media/cam.mov --hotwords "Quad AI, Failproof, <names>" --out $W/tx` (run it directly: it is a uv script).
   The camera track keeps the camera clock; if you transcribe the cleaner mic file instead, pass `captions.py --shift -<AudioOffset/fps>` in step 7.
   Proof-read names. Uncertain words go in the plan's open questions.
4. **Silence cuts.** `analyze.py silence $W/media/cam.mov --min 0.35 --pad 0.1 > $W/keep.json` (long-form: `--min 0.7 --pad 0.25`). RMS with an auto noise floor; it warns if it finds nothing. Check `gaps_cut` > 0.
5. **Repeats, stammers, false starts.** Read `words.json`. Where a phrase repeats ("we built, we built a ...") or a sentence restarts, drop the source frames of the first take from the keep list by hand (split a range into two). Prefer cutting at word ends (`end_f`) next to RMS dips.
6. **Place and frame:**
```bash
$S/sheet.py $W/media/cam.mov --ranges $W/keep.json --width 480 --out $W/scan/cuts.png   # in/mid/out of every cut on a 10% grid; 480 px cells read x within about 0.05
```
   Read the speaker's x (fraction of source width) per cut off that sheet. A 9:16 window shows only about 0.32 of a 16:9 source width: if the
   speaker walks further than that inside one cut, split the range in two and frame each half. Then:
```lua
local tl = R.timeline("talk v1", {w = 1080, h = 1920, fps = 30, crop = true, video = 3, audio = 2})
R.import({W .. "cam.mov"}, "media")
local keep = {{0, 128}, {137, 184}, {189, 252}}             -- keep_f, edited
local xs = {0.62, 0.70, 0.84}                              -- speaker x per cut, read off cuts.png
local items = R.keep(tl, "cam.mov", keep)
for i, it in ipairs(items) do R.frame(it, xs[i], i % 2 == 0 and 1.15 or 1.0) end   -- framing + alternating punch-in
```
   Re-check with `R.stills` at each cut's middle. The speaker's face should sit near x 540 and inside the safe zone.
7. **Captions on the timeline clock** (jump cuts move every word):
```bash
$S/captions.py $W/tx/cam.words.json --keep $W/keep.json --out $W/captions.srt --max-chars 24 --fix "Cordova=Quad AI"
$S/finish.py master.mov --to reels --subs $W/captions.srt --size 72 --name 20261029_talk_piece --version v01
# short-form word-pop instead: --style pop --words 2 --json $W/pop.json, then one R.title per card (at, len, text)
```
   If you hand-edit the keep ranges after `analyze.py`, pass captions.py the SAME list you gave `R.keep` (a JSON array works). captions.py starts a new
   cue at every jump cut, sentence end and pause, and keeps each cue at least 0.83 s. `--max-chars 24` suits finish.py's burn-in; for Resolve's own
   subtitle burn-in (`pages/edit.md`) use 16.
8. **Multicam podcast.** Build the speaker timeline from the transcript (who speaks when). Place each speaker's camera ranges on V1 with `R.place(..., {media = "video"})`, and keep one continuous mixed audio on A1. Switch when a new speaker talks for more than 1.5-2 s; wide shot every 30-60 s.
9. **Levels.** `R.normalize(tl, audioItems, "EBU R128", -23)` evens out clip gain; `finish.py` does the final -14 LUFS (podcast feed: `--to podcast`, -16).
10. **Dialogue EQ, compression, de-ess, ducking:** no direct API, but a template route exists (`pages/fairlight.md`): apply a saved Fairlight
    configuration preset with `R.project():ApplyFairlightPresetToCurrentTimeline("agent-talk-mix")` (EQ, compressor, inserts; make EQs with `fl_eq.py`),
    including the Ducker if the preset was saved with one. Without a saved preset, process the WAV with ffmpeg before import, e.g.
    `highpass=f=90,acompressor=threshold=-20dB:ratio=3:attack=10:release=150,deesser`.

## D. Event recap / ad (16:9 + 9:16 cutdowns)

1. Structure (30 s): hook 0-3 s (best moment), context 3-8 s (lower third: event, place, date), build 8-22 s (escalating montage, 1-2 sound bites of 8 s or less), payoff 22-27 s, CTA / end card for the last 2-4 s.
2. Music bed cut on bars (`bars_f`), ending on the track's own ending.
3. Lower third:
```lua
R.title(tl, {text = "Asha Rao", at = 95, len = 120, font = "Open Sans", style = "Bold", size = 0.05, center = {0.25, 0.2}, anim = "fade", track = 3})
R.title(tl, {text = "Founder, Acme", at = 100, len = 115, font = "Open Sans", style = "Regular", size = 0.035, center = {0.25, 0.16}, anim = "fade", track = 4})
```
4. Cutdowns: make the 16:9 master first, then build 9:16 by re-placing the same shot data into `R.timeline("recap 9x16", {w=1080, h=1920})` with re-prepped vertical crops.
5. End card: brand kit (brand-kits.md): a background clip plus logo plus CTA via `R.title`.
