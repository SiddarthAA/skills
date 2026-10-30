---
name: davinci-resolve-maxxing
description: Edit, cut, grade, caption, mix, add effects to and render production videos in DaVinci Resolve (FREE edition, Linux; macOS documented) by driving every page of Resolve from the agent through a Lua-console bridge, template files and a GUI driver. Covers hype reels, product demos, talking-head/podcast and event recaps/ads, with human checkpoints. Use whenever someone wants a video made or edited in DaVinci Resolve, wants Resolve automated or scripted (Media, Edit, Fusion, Color, Fairlight, Deliver), wants effects/transitions/titles/grades/audio mixes applied, or hands over footage plus references for an edit.
---

# DaVinci Resolve Maxxing

Turns raw footage + references into platform-ready videos by scripting free DaVinci Resolve from inside its own Lua Console, with three
human checkpoints (plan, preview, delivery). It reaches every page: about 95% of the scripting API is mapped and verified on free, template
files cover what the API can't (Fairlight mixes, grades, Fusion macros), and a GUI driver covers the rest.

## When to use

- "Make / edit / cut a reel, demo, recap, podcast clip, ad ... in DaVinci Resolve"
- "Automate / script / control Resolve", "build this timeline", "grade / mix / caption / add effects and export this"
- Footage folder + reference video(s) + "make it like this"
- Fixing or re-exporting an existing Resolve project, captions, loudness, platform cutdowns
- Not for Studio-only features (Magic Mask, voice isolation, AI transcription, scene detection, H.264 export on Linux): this skill's
  scripts replace them (`transcribe.py`, `analyze.py`, `finish.py`, ffmpeg)

## Steps

1. **Set up once.** Linux: `bash scripts/install.sh`. It links the bridge into `~/resolve-bridge`, puts `rv`/`rcon`/`resolve-up`/`gui` on PATH, gets xdotool (no sudo), makes title carriers, installs looks as `agent/<look>.cube` and starter Fairlight presets, and unpacks the 417 built-in Fusion templates. macOS: `references/mac.md` (untested).
2. **Connect.** `resolve-up <project>` launches or recovers Resolve, starts the bridge in the Lua Console, and opens or creates the project. Check with `rv 'return R.dump()'`.
   - How it works: free 21.1 blocks external and Python scripting. `rv` writes Lua into `~/resolve-bridge/req.lua`, and `bridge.lua` (a loop in Resolve's console) runs it with the full API plus the `R` helpers (`scripts/lib.lua`, `references/api.md`), then writes the reply. `rv` warns if a Resolve dialog is open, because API calls fail silently behind modals.
3. **Intake and analyze.** Contact sheets (`sheet.py`), reference pacing (`analyze.py cuts`), music beats (`analyze.py beats`), speech (`transcribe.py --hotwords "names"`), pauses (`analyze.py silence`). Look at the sheets yourself. `references/recipes.md` §0.
4. **PLAN, checkpoint 1.** Write `~/videos/<project>/plan.md` (deliverables, structure with timings, shot list in frames, look, fonts, music licence, questions). Show it and wait for approval.
5. **Prep media.** `prep.py transcode` (Linux can't decode H.264/HEVC/AAC; it also reframes), `prep.py still`, `prep.py carriers`. Sources stay untouched.
6. **Build.** A small `build.lua` with shot data at the top. Pick the route per job from `references/capability-matrix.md`, then follow the page reference:

   | Page | Reference | Main tools |
   |---|---|---|
   | Media | `references/pages/media.md` | `R.import`, `R.find`, metadata, `R.sync` |
   | Edit / Cut | `references/pages/edit.md`, `pages/cut.md` | `R.timeline`, `R.place`, `R.keep`, `R.frame`, `R.title`, transitions, subtitles |
   | Fusion + effects | `references/pages/fusion.md` | **`R.fx(item, id, params)`**: any of the 53 ResolveFX, about 500 Fusion tools, 417 templates; `R.motion`, `R.zoom` |
   | Color | `references/pages/color.md` | `R.lut`, `R.cdl`, `R.group`, DRX grade templates, node keys |
   | Fairlight | `references/pages/fairlight.md` | clip levels, `R.normalize`, `fl_eq.py`, config presets via `ApplyFairlightPresetToCurrentTimeline` |
   | Deliver | `references/pages/deliver.md` | `R.render`, then `finish.py` |
   | Project / prefs | `references/project-and-prefs.md` | projects, settings presets, keyboard/layout presets |
   | GUI-only parts | `references/gui.md` | `gui shot/key/click/field/drag` |

   Genre recipes with code: `references/recipes.md` A-D. Numbers (pacing, levels, safe zones, caption sizes): `references/craft-and-specs.md`. Run it with `RV_TIMEOUT=300 rv < build.lua`.
7. **Self-review.** `R.stills()` frames into `sheet.py --grid`, then LOOK. Numbers: `compare -metric MAE a.png b.png null: 2>&1` (before/after an effect). Grep `ResolveDebug.txt` for Fusion errors. Check the safe zone, text, framing, grade, gaps, black frames from broken effect wiring, and Studio watermarks.
8. **PREVIEW, checkpoint 2.** `R.render({dir = "~/Videos/<project>", name = ...})` (inside Media Storage), `ffprobe` that a video stream exists, then `finish.py master --to <platform>`. Share the MP4 and a sheet, apply notes, rebuild.
9. **DELIVER, checkpoint 3.** `finish.py` for every platform (two-pass loudness to -14 LUFS / -1 dBTP, H.264, burned captions). Report file paths and the QA JSON. Then `R.save()` and `pm:ExportProject(name, path.drp, false)` as a backup.

## Notes

**Hard rules** (each one cost a crash, a black frame or a silent failure in testing; details in `references/gotchas.md`):
- Never modify, move or write next to source media. Work in `~/videos/<project>`, render in `~/Videos/<project>`.
- Never delete projects, timelines, bins or presets you didn't create (prefix yours `agent-`; the skill's own `_carriers` bin is fine). Make new versions (`R.timeline` adds a suffix).
- Never use stereo 3D features (`ConvertTimelineToStereo`, stereo 3D clips; stereo audio tracks are fine): on free the whole project becomes unopenable. Probe unknown calls in a throwaway project.
- Never call `TranscribeAudio`, `CreateSubtitlesFromAudio` or `AutoAlignClips` (they crash Resolve). Other Studio calls open an upsell modal: dismiss it with Escape.
- Never use `Insert*IntoTimeline` (they ripple-insert 150 frames into V1). Titles: `R.title` or a title template on a carrier.
- Never wrap Fusion edits in `comp:Lock()`. Apply effects with `R.fx` (ResolveFX need their `Source` input; macros their `MainOutput1`).
- Fonts must be visible to Fusion (`R.has_font`); a missing font renders nothing and raises no error.
- `R.place` for every clip: exclusive ends, absolute record frames, missing tracks and out-of-range sources all fail silently otherwise.
- Prove every claim with pixels or numbers: `R.still` before/after for edits and effects, `ffprobe` for renders, `finish.py` QA (LUFS) for audio.
- GUI: screenshot Resolve's windows only (the user may be working), never type letters into the main window, prefer the keyboard for dropdowns, never click Send/Buy/Download.
- Reference or ripped music is for timing only. Final audio must be licensed, or exported without music so the platform's audio library can be used.

**Files**

| Path | Use |
|---|---|
| `scripts/bridge.lua`, `scripts/lib.lua` | Console mailbox loop; `R` helper library (`references/api.md`) |
| `scripts/rv`, `rcon`, `resolve-up`, `gui`, `install.sh` | Send Lua; type in the console; launch/recover; drive the GUI; setup |
| `scripts/prep.py` | transcode (crop / fit / blur reframes) / still / carriers / lut |
| `scripts/analyze.py`, `transcribe.py`, `captions.py`, `sheet.py` | beats, cuts, silence, loudness; word timings; captions on the timeline clock; contact sheets |
| `scripts/finish.py` | Master to Reels/TikTok/Shorts/YouTube/LinkedIn/X/hero/podcast, loudness, captions, QA |
| `scripts/fl_eq.py`, `assets/fairlight/` | Write Fairlight EQ presets; starter EQ/Dynamics presets |
| `references/capability-matrix.md` | Every feature: API / template / GUI / not on free, plus the coverage scorecard |
| `references/pages/*.md`, `references/project-and-prefs.md` | Per-page how-to with verified calls, templates and GUI coordinates |
| `references/effects-catalog.tsv` | The 53 ResolveFX on free: ID, category, image input, params with defaults |
| `references/api.md`, `gotchas.md`, `gui.md` | R helpers; everything that crashes, blocks or fails silently; GUI driving |
| `references/recipes.md`, `craft-and-specs.md`, `brand-kits.md`, `mac.md` | Genre recipes; platform specs and craft; brand kits (Failproof AI first); macOS |

Tested on DaVinci Resolve **21.1.1 free, Ubuntu 24.04, X11**. Studio differences: external scripting works there (the bridge isn't needed), plus H.264 on Linux, the AI tools and DCTL without a watermark. The `R` helpers still apply.
