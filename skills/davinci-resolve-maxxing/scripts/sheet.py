#!/usr/bin/env python3
"""Contact sheets so an agent can SEE footage cheaply (one image instead of hundreds of frames).

  sheet.py VIDEO [--cells 48] [--cols 8] [--width 240] [--out sheet.png]   evenly sampled, timestamped
  sheet.py VIDEO --start 115 --dur 45 ...                                   only part of a long file
  sheet.py IMAGES... --grid [--cols 6] [--width 270] [--out sheet.png]       e.g. R.stills() output, photos
  sheet.py VIDEO --ranges keep.json [--fps 30]   in / middle / out frame of every range, with a 10% grid:
                                                  read subject positions per cut (for R.frame) off this
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile


def video(a):
    dur = a.dur or float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", a.inputs[0]], text=True)) - (a.start or 0)
    step = max(dur / a.cells, 0.04)
    rows = -(-a.cells // a.cols)
    vf = (f"fps=1/{step:.4f},scale={a.width}:-2,drawtext=text='%{{pts\\:hms}}':x=3:y=3:fontsize=14:fontcolor=yellow:"
          f"box=1:boxcolor=black@0.6,tile={a.cols}x{rows}:padding=2")
    # -skip_frame nokey: decode keyframes only, ~10x faster on long camera files (sampling is coarse anyway)
    cut = (["-ss", str(a.start)] if a.start else []) + ["-i", a.inputs[0]] + (["-t", str(a.dur)] if a.dur else [])
    subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", *(["-skip_frame", "nokey"] if dur > 60 else []),
                    *cut, "-vf", vf, "-frames:v", "1", "-an", a.out], check=True)


def ranges(a):
    keep = json.load(open(a.ranges))
    rs = keep["keep_f"] if isinstance(keep, dict) else keep
    tmp, shots = tempfile.mkdtemp(), []
    for i, (s, e) in enumerate(rs, 1):
        for tag, f in (("in", s), ("mid", (s + e) // 2), ("out", max(s, e - 1))):
            png = os.path.join(tmp, f"{i:03d}_{tag}.png")
            label = f"cut {i} {tag} f{f}"
            subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{f / a.fps:.3f}", "-i", a.inputs[0],
                            "-frames:v", "1", "-vf", f"scale={a.width}:-2,drawgrid=w=iw/10:h=ih/10:t=1:c=white@0.35,"
                            f"drawtext=text='{label}':x=3:y=3:fontsize=14:fontcolor=yellow:box=1:boxcolor=black@0.6", png], check=True)
            if os.path.exists(png): shots.append(png)  # ranges past the end of the file yield no frame
    subprocess.run(["montage", *shots, "-tile", "3x", "-geometry", "+2+2", "-background", "black", a.out], check=True)


def grid(a):
    subprocess.run(["montage", "-auto-orient", "-define", f"jpeg:size={a.width * 2}x{a.width * 2}", *a.inputs,
                    "-thumbnail", f"{a.width}x", "-tile", f"{a.cols}x", "-geometry", "+2+2", "-background", "black",
                    "-fill", "yellow", "-pointsize", "12", "-label", "%t", a.out], check=True)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inputs", nargs="+"); p.add_argument("--grid", action="store_true")
    p.add_argument("--cells", type=int, default=48); p.add_argument("--cols", type=int)
    p.add_argument("--width", type=int); p.add_argument("--out", default="sheet.png")
    p.add_argument("--start", type=float); p.add_argument("--dur", type=float)
    p.add_argument("--ranges"); p.add_argument("--fps", type=float, default=30)
    a = p.parse_args()
    a.cols = a.cols or (6 if a.grid else 8)
    a.width = a.width or (270 if a.grid else 240)
    (ranges if a.ranges else grid if a.grid else video)(a)
    print(a.out)


if __name__ == "__main__":
    sys.exit(main())
