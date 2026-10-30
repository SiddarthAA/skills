#!/usr/bin/env python3
"""Write a Fairlight EQ preset (XML) that Resolve lists immediately in the EQ window and Presets Library.

  fl_eq.py agent-voice-clean --hp 80 --band 3:300:-2 --band 5:5000:2.5
  fl_eq.py music-duck --hp 40 --band 4:2000:-4 --lp 16000 --out ./my-presets

Bands are numbered as in the EQ window: 1 = high-pass, 2 = low shelf, 3-4 = bells, 5 = high shelf (--band N:Hz:dB), 6 = low-pass.
Shapes and Q stay as in the template; frequencies snap to 257 log steps per range (350 Hz shows as 348).
Resolve reads the frequency from BAND_LIMITED_FREQ_<n>, a 0..256 log index inside the band's range
(L 30-399, ML 100-1.5k, MH 450-8k, H 1.4k-22k), not from BAND_FREQ. Gains are stored in 0.1 dB.
"""
import argparse, math, os, re
from pathlib import Path

RANGES = [(30, 399), (100, 1500), (450, 8000), (1400, 22000)]  # BAND_RANGE 0..3
TEMPLATE = Path(__file__).resolve().parent.parent / "assets/fairlight/EQ/agent-voice-clean.xml"
DEST = Path.home() / ".local/share/DaVinciResolve/configs/Fairlight/Presets/EQ"  # macOS: see references/mac.md


def index(hz, rng):
    lo, hi = RANGES[rng]
    return round(256 * math.log(hz / lo) / math.log(hi / lo))


def best_range(band, hz):  # the band's own default range (band 2 = L ... band 5 = H) when the frequency fits
    lo, hi = RANGES[band - 2]
    return band - 2 if lo <= hz <= hi else next(i for i, (lo, hi) in enumerate(RANGES) if lo <= hz <= hi)


def put(xml, key, val):
    xml, n = re.subn(rf'parameter="{key}" value="[-0-9]+"', f'parameter="{key}" value="{val}"', xml)
    assert n == 1, key
    return xml


def build(hp=None, lp=None, bands=()):
    x = re.sub(r"<!--.*?-->\n", "", TEMPLATE.read_text())
    for b in range(6):
        x = put(x, f"BAND_IN_{b}", 0)
        x = put(x, f"BAND_GAIN_{b}", 0)
    if hp:
        x = put(put(put(x, "BAND_IN_0", 1), "BAND_FREQ_0", hp), "BAND_LIMITED_FREQ_0", index(hp, 0))
    if lp:
        x = put(put(put(x, "BAND_IN_5", 1), "BAND_FREQ_5", lp), "BAND_LIMITED_FREQ_5", index(lp, 3))
    for n, hz, db, *_ in bands:
        b, r = n - 1, best_range(n, hz)
        assert 2 <= n <= 5, "bells are bands 2-5"
        for k, v in [("IN", 1), ("FREQ", hz), ("LIMITED_FREQ", index(hz, r)), ("RANGE", r), ("GAIN", round(db * 10))]:
            x = put(x, f"BAND_{k}_{b}", v)
    return x


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name")
    ap.add_argument("--hp", type=float)
    ap.add_argument("--lp", type=float)
    ap.add_argument("--band", action="append", default=[], help="N:Hz:dB, N = 2 (low shelf), 3-4 (bell), 5 (high shelf)")
    ap.add_argument("--out", default=str(DEST))
    a = ap.parse_args()
    bands = [tuple(float(v) for v in s.split(":")) for s in a.band]
    bands = [(int(b[0]), b[1], b[2]) for b in bands]
    os.makedirs(a.out, exist_ok=True)
    path = Path(a.out) / f"{a.name}.xml"
    path.write_text(build(round(a.hp) if a.hp else None, round(a.lp) if a.lp else None, [(n, round(hz), db) for n, hz, db in bands]))
    print(path)
    # self-check: indices Resolve itself wrote for 100 Hz (L), 240 Hz (ML), 1223 Hz (MH), 6048 Hz (H)
    assert [index(100, 0), index(240, 1), index(1223, 2), index(6048, 3)] == [119, 83, 89, 136]
