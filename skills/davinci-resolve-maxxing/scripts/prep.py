#!/usr/bin/env python3
"""Media prep for free DaVinci Resolve (stdlib + ffmpeg + ImageMagick). Never writes next to the sources.

  prep.py transcode SRC... --out DIR [--size 1080x1920 --mode crop|fit --cx 0.5] [--fps 30] [--start S --dur S]
      H.264/HEVC/AAC (undecodable on Linux free) -> ProRes 422 HQ + PCM. --size reframes:
      crop = fill around --cx (fixed), fit = black bars, blur = fit over a blurred fill. Moving subject? keep 16:9 and use
      R.timeline{crop=true} + R.frame per cut instead of a fixed crop.
  prep.py still IMG... --out DIR --size 1080x1920 [--cx 0.5 --cy 0.5] [--seconds 5] [--fps 30]
      Photos -> ProRes clips of exact length (Resolve ignores in/out on stills). EXIF rotation honoured.
  prep.py carriers WxH [--fps 30] [--seconds 20] --out DIR
      Transparent ProRes 4444 clip that titles ride on (lib.lua R.title).
  prep.py lut NAME --out FILE.cube      looks: moody, teal-orange, warm-film, clean, mono
  prep.py lut curve --points "0:0.06,0.5:0.5,0.9:0.85,1:0.92" --out FILE.cube   custom global curve (in:out, same on R/G/B)
"""
import argparse
import os
import subprocess
import sys


def run(*cmd):
    subprocess.run(cmd, check=True)


def size(s):
    w, h = s.lower().split("x")
    return int(w), int(h)


def ffmpeg(*args):
    run("ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", *args)


PRORES = ["-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le", "-vendor", "apl0"]


def reframe(w, h, mode, cx):
    if mode == "blur":  # whole frame fitted over a blurred, darkened fill of itself (talking heads, wide demos in 9:16)
        return (f"split[a][b];[a]scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h},boxblur=30:2,eq=brightness=-0.08[bg];"
                f"[b]scale={w}:{h}:force_original_aspect_ratio=decrease:flags=lanczos[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2")
    if mode == "fit":
        return f"scale={w}:{h}:force_original_aspect_ratio=decrease:flags=lanczos,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2"
    # crop: scale to cover, then crop around the horizontal centre cx (0..1)
    return (f"scale={w}:{h}:force_original_aspect_ratio=increase:flags=lanczos,"
            f"crop={w}:{h}:x='min(max({cx}*iw-{w}/2,0),iw-{w})':y=(ih-{h})/2")


def rate(src):
    """Average frame rate (r_frame_rate is 90000/1 on some phone VFR files)."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=avg_frame_rate,r_frame_rate",
                          "-of", "csv=p=0", src], capture_output=True, text=True).stdout.strip().split(",")
    return next((r for r in out[::-1] if r and not r.startswith("0/")), "30")


def transcode(a):
    os.makedirs(a.out, exist_ok=True)
    for src in a.src:
        dst = os.path.join(a.out, os.path.splitext(os.path.basename(src))[0] + ".mov")
        if os.path.exists(dst) and not a.force:
            print("skip", dst); continue
        vf = [reframe(*size(a.size), a.mode, a.cx)] if a.size else []
        # constant rate, first frame at 0: a seek (--start) or a rate change otherwise starts the file a frame late,
        # and Resolve shows that missing frame 0 as BLACK
        vf.append(f"fps={a.fps or rate(src)}:start_time=0")
        cut = (["-ss", str(a.start)] if a.start else []) + ["-i", src] + (["-t", str(a.dur)] if a.dur else [])
        ffmpeg(*cut, *(["-vf", ",".join(vf)] if vf else []), *PRORES, "-c:a", "pcm_s24le", "-ar", "48000", dst)
        print("ok", dst)


def still(a):
    os.makedirs(a.out, exist_ok=True)
    w, h = size(a.size)
    for src in a.src:
        dst = os.path.join(a.out, os.path.splitext(os.path.basename(src))[0] + ".mov")
        if os.path.exists(dst) and not a.force:
            print("skip", dst); continue
        info = subprocess.check_output(["identify", "-format", "%w %h %[EXIF:Orientation]", src + "[0]"], text=True).split()
        iw, ih = int(info[0]), int(info[1])
        if len(info) > 2 and info[2] in ("5", "6", "7", "8"):  # rotated 90/270: dimensions swap after auto-orient
            iw, ih = ih, iw
        if iw / ih > w / h:   # source wider: crop width around cx
            cw, ch = round(ih * w / h), ih
            x, y = min(max(round(a.cx * iw - cw / 2), 0), iw - cw), 0
        else:                 # source taller: crop height around cy
            cw, ch = iw, round(iw * h / w)
            x, y = 0, min(max(round(a.cy * ih - ch / 2), 0), ih - ch)
        jpg = dst[:-4] + ".tmp.jpg"
        # ponytail: 1.33x the target size leaves headroom for punch-ins without a 24MP intermediate
        run("convert", src, "-auto-orient", "-crop", f"{cw}x{ch}+{x}+{y}", "+repage",
            "-resize", f"{round(w * 4 / 3)}x{round(h * 4 / 3)}!", "-quality", "95", jpg)
        ffmpeg("-loop", "1", "-framerate", str(a.fps), "-i", jpg, "-frames:v", str(round(a.seconds * a.fps)),
               *PRORES, "-r", str(a.fps), dst)
        os.remove(jpg)
        print("ok", dst)


def carriers(a):
    os.makedirs(a.out, exist_ok=True)
    w, h = size(a.size)
    dst = os.path.join(a.out, f"carrier_{w}x{h}_{a.fps}.mov")
    if os.path.exists(dst):
        print("skip", dst); return
    ffmpeg("-f", "lavfi", "-i", f"color=black@0.0:s={w}x{h}:r={a.fps}:d={a.seconds},format=yuva444p10le",
           "-c:v", "prores_ks", "-profile:v", "4", "-alpha_bits", "16", "-pix_fmt", "yuva444p10le", dst)
    print("ok", dst)


# ── LUT looks (Rec.709 display-referred in, out). Pure Python: 33^3 points. ──
def _look(name):
    def luma(r, g, b): return 0.2126 * r + 0.7152 * g + 0.0722 * b
    def clamp(v): return 0.0 if v < 0 else 1.0 if v > 1 else v

    def split(r, g, b, sh, hi, sat, lift):
        y = clamp(luma(r, g, b)); ws, wh = (1 - y) ** 2.2, y ** 2
        r, g, b = (r + ws * sh[0] + wh * hi[0], g + ws * sh[1] + wh * hi[1], b + ws * sh[2] + wh * hi[2])
        y = clamp(luma(r, g, b))
        return tuple(lift + clamp(y + (c - y) * sat) * (1 - lift) for c in (r, g, b))

    def s_curve(v, amt): return v + (v * v * (3 - 2 * v) - v) * amt

    looks = {
        # dark, teal shadows / amber highlights, milky blacks (Social Network / Fincher feel)
        "moody": lambda r, g, b: split(*(s_curve(c ** 1.45 * 0.93, 0.4) for c in (r, g, b)),
                                       (-0.04, 0.012, 0.05), (0.05, 0.018, -0.045), 0.8, 0.025),
        # brighter commercial teal-orange, more saturation
        "teal-orange": lambda r, g, b: split(*(s_curve(c ** 1.1, 0.35) for c in (r, g, b)),
                                             (-0.05, 0.01, 0.06), (0.06, 0.02, -0.05), 1.05, 0.0),
        # warm, soft film: lifted blacks, rolled highlights, gentle desat
        "warm-film": lambda r, g, b: split(*(s_curve(c, 0.25) * 0.97 for c in (r, g, b)),
                                           (0.01, 0.0, -0.02), (0.04, 0.015, -0.03), 0.88, 0.035),
        # neutral: just contrast, for screen recordings and talking heads
        "clean": lambda r, g, b: tuple(clamp(s_curve(c, 0.2)) for c in (r, g, b)),
        "mono": lambda r, g, b: (lambda y: (y, y, y))(clamp(s_curve(clamp(luma(r, g, b)), 0.45))),
    }
    return looks[name]


def _curve(spec):
    """Piecewise-linear tone curve from "in:out,..." points (0..1), applied to R, G and B."""
    pts = sorted(tuple(float(v) for v in p.split(":")) for p in spec.split(","))
    def y(x):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x <= x1:
                return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        return pts[-1][1]
    assert y(pts[0][0]) == pts[0][1]
    return lambda r, g, b: (y(r), y(g), y(b))


def lut(a):
    f, n = (_curve(a.points) if a.name == "curve" else _look(a.name)), 33
    with open(a.out, "w") as out:
        out.write(f'TITLE "{a.name}"\nLUT_3D_SIZE {n}\n')
        for bi in range(n):
            for gi in range(n):
                for ri in range(n):  # .cube order: red fastest
                    r, g, b = (min(max(v, 0.0), 1.0) for v in f(ri / (n - 1), gi / (n - 1), bi / (n - 1)))
                    out.write(f"{r:.6f} {g:.6f} {b:.6f}\n")
    print("ok", a.out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("transcode"); t.add_argument("src", nargs="+"); t.add_argument("--out", required=True)
    t.add_argument("--size"); t.add_argument("--mode", choices=["crop", "fit", "blur"], default="crop"); t.add_argument("--cx", type=float, default=0.5)
    t.add_argument("--fps", type=float); t.add_argument("--start", type=float); t.add_argument("--dur", type=float); t.add_argument("--force", action="store_true")
    s = sub.add_parser("still"); s.add_argument("src", nargs="+"); s.add_argument("--out", required=True); s.add_argument("--size", required=True)
    s.add_argument("--cx", type=float, default=0.5); s.add_argument("--cy", type=float, default=0.5)
    s.add_argument("--seconds", type=float, default=5); s.add_argument("--fps", type=int, default=30); s.add_argument("--force", action="store_true")
    c = sub.add_parser("carriers"); c.add_argument("size"); c.add_argument("--fps", type=int, default=30)
    c.add_argument("--seconds", type=int, default=20); c.add_argument("--out", required=True)
    l = sub.add_parser("lut"); l.add_argument("name", choices=["moody", "teal-orange", "warm-film", "clean", "mono", "curve"]); l.add_argument("--out", required=True)
    l.add_argument("--points", default="0:0,1:1", help='curve only: "in:out,..." e.g. lifted blacks + soft roll-off "0:0.06,0.5:0.5,0.9:0.85,1:0.92"')
    a = p.parse_args()
    {"transcode": transcode, "still": still, "carriers": carriers, "lut": lut}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
