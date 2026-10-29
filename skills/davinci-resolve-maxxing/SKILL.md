---
name: davinci-resolve-maxxing
description: Edit, cut, grade, caption, mix and render production videos in DaVinci Resolve (FREE edition, Linux; macOS documented) by driving Resolve from the agent through a Lua-console bridge. Covers hype reels, product demos, talking-head/podcast and event recaps/ads, with human checkpoints. Use whenever someone wants a video made or edited in DaVinci Resolve, wants Resolve automated or scripted, or hands over footage plus references for an edit.
---

# DaVinci Resolve Maxxing

Turns raw footage + references into platform-ready videos by scripting free DaVinci Resolve from inside its own Lua Console, with three human checkpoints (plan, preview, delivery).

## When to use

- "Make / edit / cut a reel, demo, recap, podcast clip, ad ... in DaVinci Resolve"
- "Automate / script / control Resolve", "build this timeline", "grade and export this"
- Footage folder + reference video(s) + "make it like this"
- Fixing or re-exporting an existing Resolve project, captions, loudness, platform cutdowns
- Not for Studio-only features (Resolve AI transcription, voice isolation, magic mask): use this skill's scripts instead (`transcribe.py`, ffmpeg)

## Steps

1. **Set up once.** Linux: `bash scripts/install.sh`. It links the bridge into `~/resolve-bridge`, puts `rv`/`rcon`/`resolve-up` on PATH, gets xdotool (no sudo needed), makes title carriers, and installs looks as `agent/<look>.cube`. macOS: `references/mac.md` (untested).
2. **Connect.** `resolve-up <project>` launches or recovers Resolve, starts the bridge in the Lua Console, and opens or creates the project. Check with `rv 'return R.dump()'`.
   - How it works: free 21.1 blocks external and Python scripting. `rv` writes Lua into `~/resolve-bridge/req.lua`, and `bridge.lua` (a loop running in Resolve's console) executes it with the full API plus the `R` helpers (`scripts/lib.lua`), then writes the reply.
3. **Intake and analyze.** Contact sheets (`sheet.py`, `--start/--dur` for a window of a long file), reference pacing (`analyze.py cuts`), music beats (`analyze.py beats`), speech (`transcribe.py --hotwords "names"`), pauses (`analyze.py silence`). Look at the sheets yourself. See `references/recipes.md` §0.
4. **PLAN, checkpoint 1.** Write `~/videos/<project>/plan.md` (deliverables, structure with timings, shot list in frames, look, fonts, music licence, questions). Show it and wait for approval.
5. **Prep media.** `prep.py transcode` (Linux can't decode H.264/HEVC/AAC; it also reframes to 9:16), `prep.py still` (photos to clips of exact length), `prep.py carriers` (new size or fps). Sources stay untouched.
6. **Build.** A small `build.lua` with shot data at the top, using `R.timeline`, `R.place`/`R.keep`, `R.frame` (per-cut framing), `R.motion`/`R.zoom`, `R.title`, `R.group`/`R.lut`, `R.volume`/`R.fade`/`R.sync`. Captions after jump cuts: `captions.py` remaps the transcript onto the timeline. Run it with `RV_TIMEOUT=300 rv < build.lua`. Per-genre recipes with code: `references/recipes.md` A-D. Numbers (pacing, levels, safe zones, caption sizes): `references/craft-and-specs.md`.
7. **Self-review.** `R.stills()` frames into `sheet.py --grid`, then LOOK. Grep `ResolveDebug.txt` for Fusion errors. Check the safe zone, text, framing, grade and gaps.
8. **PREVIEW, checkpoint 2.** `R.render({dir = "~/Videos/<project>", name = ...})` (must be inside Media Storage), `ffprobe` that a video stream exists, then `finish.py master --to <platform>`. Share the MP4 and a sheet, apply notes, rebuild.
9. **DELIVER, checkpoint 3.** `finish.py` for every platform (two-pass loudness to -14 LUFS / -1 dBTP, H.264, burned captions via `--subs`). Report file paths and the QA JSON (LUFS, true peak, black frames). Then `R.save()` and `pm:ExportProject(name, path.drp, false)` as a backup.

## Notes

**Hard rules** (each one cost a crash or a silent failure in testing; details in `references/gotchas.md`):
- Never modify, move or write next to source media. Work in `~/videos/<project>`, render in `~/Videos/<project>`.
- Never delete projects, timelines or clips you didn't create. Make new versions (`R.timeline` adds a suffix).
- Never call Resolve AI/Studio APIs on free (`CreateSubtitlesFromAudio`, `TranscribeAudio`, `AutoAlignClips`...): they crash Resolve.
- Never use `Insert*IntoTimeline` for titles or generators (they ripple-insert 5 s into V1). Use `R.title` (carrier + Text+).
- Never wrap Fusion edits in `comp:Lock()`: the values read back fine but nothing renders.
- Fonts must be visible to Fusion (`R.has_font`); a missing font renders nothing and raises no error.
- `AppendToTimeline` end frames are exclusive and record frames absolute; a missing track index drops the clip at the end of V1. `R.place` handles all three.
- Prove every claim with pixels: `R.still` for edits, `ffprobe` for renders, `finish.py` QA for audio.
- GUI: screenshot only Resolve's window (the user may be working). Never type into the main window. Never click Send/Download/Buy.
- Reference or ripped music is for timing only. Final audio must be licensed, or exported without music so the platform's audio library can be used.

**Files**

| Path | Use |
|---|---|
| `scripts/bridge.lua`, `scripts/lib.lua` | Console mailbox loop; `R` helper library (read its comments) |
| `scripts/rv`, `rcon`, `resolve-up`, `install.sh` | Send Lua; type in the console; launch/recover; setup |
| `scripts/prep.py` | transcode (crop / fit / blur reframes) / still / carriers / lut |
| `scripts/analyze.py`, `transcribe.py`, `captions.py`, `sheet.py` | beats, cuts, silence (RMS), loudness, SFX peak; word timings; captions on the timeline clock; contact sheets (clips, windows, per-cut ranges with a grid) |
| `scripts/finish.py` | Master to Reels/TikTok/Shorts/YouTube/LinkedIn/X/hero/podcast, loudness, captions, QA |
| `references/api.md` | R helpers plus verified raw API by area |
| `references/gotchas.md` | Everything that crashes, blocks or fails silently |
| `references/recipes.md` | Pipeline, checkpoints, and genre recipes with code |
| `references/craft-and-specs.md` | Platform specs, safe zones, loudness, editing craft (sourced) |
| `references/gui-fallback.md`, `references/mac.md`, `references/brand-kits.md` | xdotool fallback; macOS; brand kits (Failproof AI first) |

Tested on DaVinci Resolve **21.1.1 free, Ubuntu 24.04, X11**. Studio differences: external scripting works there (the bridge isn't needed), plus H.264 on Linux and the AI tools. The `R` helpers still apply.
