#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "librosa"]
# ///
"""Media analysis for planning edits. All times in seconds AND timeline frames (--fps). JSON on stdout.

  analyze.py beats SONG [--fps 30]          tempo, beat + bar frames, loudness curve, drop guess
  analyze.py cuts VIDEO [--threshold 0.3]   scene-cut times (study a reference edit's pacing)
  analyze.py silence AUDIO [--min 0.35 --pad 0.1 --fps 30 --db auto]  speech ranges to KEEP (RMS, auto noise floor)
  analyze.py loudness FILE                  integrated LUFS, LRA, true peak (EBU R128)
  analyze.py peak SFX                       time of the loudest moment (align whoosh/impact peaks to cuts)
"""
import argparse
import json
import re
import subprocess
import sys


def ff(*args):
    return subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", *args], capture_output=True, text=True).stderr


def beats(a):
    import librosa
    import numpy as np
    y, sr = librosa.load(a.file, sr=None, mono=True)
    tempo, bt = librosa.beat.beat_track(y=y, sr=sr)
    bt = librosa.frames_to_time(bt, sr=sr)
    rms = librosa.feature.rms(y=y)[0]
    rt = librosa.times_like(rms, sr=sr)
    win = 0.5
    curve = [round(float(rms[(rt >= t) & (rt < t + win)].mean()), 4) for t in np.arange(0, len(y) / sr, win)]
    # drop guess: biggest jump in 0.5 s loudness after a quiet stretch
    jumps = [curve[i] - min(curve[max(0, i - 4):i] or [curve[i]]) for i in range(len(curve))]
    drop = float(np.argmax(jumps) * win)
    bpm = float(np.atleast_1d(tempo)[0])
    print(json.dumps({
        "bpm": round(bpm, 2), "frames_per_beat": round(a.fps * 60 / bpm, 3),
        "beats_s": [round(float(t), 3) for t in bt],
        "beats_f": [round(float(t) * a.fps) for t in bt],
        "bars_f": [round(float(t) * a.fps) for t in bt[::4]],
        "drop_guess_s": drop, "drop_guess_f": round(drop * a.fps),
        "loudness_0.5s": curve, "duration_s": round(len(y) / sr, 3),
    }, indent=1))


def cuts(a):
    err = ff("-i", a.file, "-vf", f"select='gt(scene,{a.threshold})',showinfo", "-an", "-f", "null", "-")
    ts = [float(t) for t in re.findall(r"pts_time:([0-9.]+)", err)]
    gaps = [round(b - a_, 3) for a_, b in zip([0.0] + ts, ts)]
    print(json.dumps({"cuts_s": ts, "count": len(ts), "shot_lengths_s": gaps,
                      "avg_shot_s": round(sum(gaps) / len(gaps), 3) if gaps else None}, indent=1))


def silence(a):
    """RMS in 50 ms windows (ffmpeg silencedetect compares peaks and misses pauses in noisy rooms).
    Threshold = measured noise floor + a margin, unless --db is given."""
    import numpy as np
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", a.file, "-ac", "1", "-ar", "16000", "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    y, hop = np.frombuffer(raw, np.float32), 800  # 50 ms at 16 kHz
    n = len(y) // hop
    db = 20 * np.log10(np.sqrt((y[:n * hop].reshape(n, hop) ** 2).mean(1)) + 1e-9)
    floor, speech = float(np.percentile(db, 10)), float(np.percentile(db, 90))
    thr = a.db if a.db is not None else floor + max(6.0, 0.35 * (speech - floor))
    quiet, gaps, i = db < thr, [], 0
    while i < n:
        if quiet[i]:
            j = i
            while j < n and quiet[j]: j += 1
            # skip gaps that the padding would mostly fill anyway
            if (j - i) * 0.05 >= a.min and (j - i) * 0.05 - 2 * a.pad >= 0.1: gaps.append((i * 0.05, j * 0.05))
            i = j
        else:
            i += 1
    dur = len(y) / 16000
    keep, t = [], 0.0
    for s, e in gaps:
        if s > t: keep.append((max(0.0, t - a.pad), min(dur, s + a.pad)))
        t = e
    if t < dur: keep.append((max(0.0, t - a.pad), dur))
    if not gaps:
        print(f"WARN no pauses >= {a.min}s below {thr:.1f} dBFS (noise floor {floor:.1f}, speech {speech:.1f}). "
              "Lower --min or raise --db.", file=sys.stderr)
    print(json.dumps({"threshold_db": round(thr, 1), "noise_floor_db": round(floor, 1), "speech_db": round(speech, 1),
                      "gaps_cut": len(gaps), "keep_s": [[round(s, 3), round(e, 3)] for s, e in keep],
                      "keep_f": [[round(s * a.fps), round(e * a.fps)] for s, e in keep],
                      "kept_s": round(sum(e - s for s, e in keep), 2), "source_s": round(dur, 2)}, indent=1))


def loudness(a):
    err = ff("-i", a.file, "-af", "ebur128=peak=true", "-f", "null", "-")
    summ = err[err.rfind("Summary:"):]
    get = lambda k: float(re.search(k + r":\s+(-?[\d.]+)", summ).group(1))
    print(json.dumps({"integrated_lufs": get("I"), "lra_lu": get("LRA"), "true_peak_dbtp": get("Peak")}))


def peak(a):
    import librosa
    import numpy as np
    y, sr = librosa.load(a.file, sr=None, mono=True)
    rms = librosa.feature.rms(y=y)[0]
    print(json.dumps({"peak_s": round(float(librosa.frames_to_time(int(np.argmax(rms)), sr=sr)), 3),
                      "duration_s": round(len(y) / sr, 3)}))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, extra in (("beats", ["fps"]), ("cuts", ["threshold"]), ("silence", ["db", "min", "pad", "fps"]),
                        ("loudness", []), ("peak", [])):
        s = sub.add_parser(name); s.add_argument("file")
        if "fps" in extra: s.add_argument("--fps", type=float, default=30)
        if "threshold" in extra: s.add_argument("--threshold", type=float, default=0.3)
        if "db" in extra: s.add_argument("--db", type=float, default=None, help="dBFS RMS threshold (default: noise floor + margin)")
        if "min" in extra: s.add_argument("--min", type=float, default=0.35)
        if "pad" in extra: s.add_argument("--pad", type=float, default=0.1)
    a = p.parse_args()
    {"beats": beats, "cuts": cuts, "silence": silence, "loudness": loudness, "peak": peak}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
