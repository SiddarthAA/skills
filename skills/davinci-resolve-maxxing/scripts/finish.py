#!/usr/bin/env python3
"""Master (ProRes/DNxHR from Resolve) -> platform deliverables, loudness-normalized, with QA.
Free Resolve on Linux cannot encode H.264/AAC, so every deliverable is encoded here.

  finish.py MASTER --to reels [--to youtube ...] [--out DIR] [--name STEM] [--version v01] [--lufs -14]
            [--subs captions.srt [--font "DejaVu Sans"] [--size 72]]
  Output: {name}_{preset}_{W}x{H}_{fps}p[_{version}].mp4. Use name = YYYYMMDD_project_piece.
  presets: reels tiktok shorts youtube linkedin x hero podcast   (see references/craft-and-specs.md)

Two-pass EBU R128 loudnorm to the preset target (true peak -1 dBTP), H.264 High with closed GOP,
BT.709 tags, faststart. --subs burns an SRT in (bold, outlined, inside the 9:16 safe zone).
QA after each encode: integrated LUFS / true peak re-measured, black frames reported.
"""
import argparse
import json
import os
import re
import subprocess
import sys

H264 = ["-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p", "-preset", "slow", "-bf", "2",
        "-x264-params", "open-gop=0", "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-movflags", "+faststart"]
PRESETS = {  # crf, maxrate, lufs, audio kbps, extension
    "reels": dict(crf=17, maxrate="20M", lufs=-14, abr="320k"),
    "tiktok": dict(crf=17, maxrate="20M", lufs=-14, abr="320k"),
    "shorts": dict(crf=17, maxrate="20M", lufs=-14, abr="384k"),
    "youtube": dict(crf=17, maxrate="40M", lufs=-14, abr="384k"),
    "linkedin": dict(crf=18, maxrate="16M", lufs=-14, abr="320k"),
    "x": dict(crf=18, maxrate="12M", lufs=-14, abr="320k"),
    "hero": dict(crf=26, maxrate=None, lufs=None, abr=None),          # silent web loop (+ .webm)
    "podcast": dict(crf=None, maxrate=None, lufs=-16, abr="192k"),    # audio-only .m4a
}


def probe(path):
    out = subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "stream=codec_type,r_frame_rate,height,width",
                                   "-of", "json", path], text=True)
    return json.loads(out)["streams"]


def ff(*args, capture=False):
    r = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-y", *args], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(r.stderr[-2000:])
    return r.stderr


def measure(path, target):
    """Pass 1 of loudnorm: returns the measured_* values for pass 2."""
    err = ff("-i", path, "-af", f"loudnorm=I={target}:TP=-1:LRA=11:print_format=json", "-f", "null", "-")
    m = json.loads(err[err.rfind("{"):err.rfind("}") + 1])
    return (f"loudnorm=I={target}:TP=-1:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
            f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")


def qa(path, has_audio, fps):
    rep = {"file": path}
    if has_audio:
        s = ff("-i", path, "-af", "ebur128=peak=true", "-f", "null", "-")
        s = s[s.rfind("Summary:"):]
        rep["lufs"] = float(re.search(r"I:\s+(-?[\d.]+)", s).group(1))
        rep["true_peak"] = float(re.search(r"Peak:\s+(-?[\d.]+)", s).group(1))
    b = ff("-i", path, "-vf", "blackdetect=d=0.01:pix_th=0.06", "-an", "-f", "null", "-")
    rep["black"] = [[float(x), float(y)] for x, y in re.findall(r"black_start:([\d.]+) black_end:([\d.]+)", b)]
    return rep


def pick_font(want):
    """libass uses fontconfig, NOT Fusion's font list: a missing family silently falls back. Pick one that exists."""
    for f in ([want] if want else []) + ["Open Sans", "Inter", "DejaVu Sans", "Arial", "Helvetica"]:
        r = subprocess.run(["fc-list", f":family={f}"], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            return f
    return "Sans"


def subs_filter(srt, height, font, size_px):
    # Bold sans, white with black outline, bottom of the universal 9:16 safe rect (y <= 1248 of 1920).
    size = size_px or (72 if height > 1700 else round(height * 0.05))  # 9:16 default 72 px (craft: 60-75)
    margin = round(height * 0.36) if height > 1700 else round(height * 0.08)
    style = (f"FontName={font},Bold=1,FontSize={round(size * 288 / height)},PrimaryColour=&H00FFFFFF,"
             f"OutlineColour=&H00000000,BorderStyle=1,Outline=3,Shadow=0,Alignment=2,MarginV={round(margin * 288 / height)}")
    return f"subtitles='{srt}':force_style='{style}'"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("master"); p.add_argument("--to", action="append", required=True, choices=PRESETS)
    p.add_argument("--out"); p.add_argument("--name"); p.add_argument("--subs"); p.add_argument("--lufs", type=float)
    p.add_argument("--font"); p.add_argument("--size", type=int, help="caption px at output height"); p.add_argument("--version")
    a = p.parse_args()
    out = a.out or os.path.dirname(os.path.abspath(a.master))
    stem = a.name or os.path.splitext(os.path.basename(a.master))[0].replace("_master", "")
    streams = probe(a.master)
    v = next(s for s in streams if s["codec_type"] == "video")
    has_audio = any(s["codec_type"] == "audio" for s in streams)
    num, den = map(int, v["r_frame_rate"].split("/")); fps = num / den
    reports = []
    for name in a.to:
        pr = PRESETS[name]
        lufs = a.lufs if a.lufs is not None else pr["lufs"]
        vf = [subs_filter(os.path.abspath(a.subs), int(v["height"]), pick_font(a.font), a.size)] if a.subs else []
        af = [measure(a.master, lufs)] if (has_audio and lufs is not None) else []
        if name == "podcast":
            dst = os.path.join(out, f"{stem}_{name}{'_' + a.version if a.version else ''}.m4a")
            ff("-i", a.master, "-vn", "-af", af[0], "-c:a", "aac", "-b:a", pr["abr"], "-ar", "48000", dst)
        else:
            dst = os.path.join(out, f"{stem}_{name}_{v['width']}x{v['height']}_{round(fps)}p{'_' + a.version if a.version else ''}.mp4")
            vid = H264 + ["-crf", str(pr["crf"]), "-g", str(max(1, round(fps / 2)))]
            if pr["maxrate"]: vid += ["-maxrate", pr["maxrate"], "-bufsize", str(int(pr["maxrate"][:-1]) * 2) + "M"]
            aud = ["-an"] if name == "hero" or not has_audio else ["-af", af[0], "-c:a", "aac", "-b:a", pr["abr"], "-ar", "48000"]
            ff("-i", a.master, *(["-vf", ",".join(vf)] if vf else []), *vid, *aud, dst)
            if name == "hero":
                ff("-i", a.master, "-an", "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "36", "-row-mt", "1", dst[:-4] + ".webm")
        reports.append(qa(dst, has_audio and name != "hero", fps))
    print(json.dumps(reports, indent=1))


if __name__ == "__main__":
    main()
