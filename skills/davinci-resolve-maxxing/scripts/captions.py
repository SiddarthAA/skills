#!/usr/bin/env python3
"""Captions on the EDITED timeline's clock (transcripts are on the source clock; jump cuts move every word).

  captions.py WORDS.json --keep KEEP.json [--at 0] [--fps 30] --out captions.srt
              [--style lines|pop] [--max-chars 24] [--lines 2] [--words 3] [--fix "Cordova=Quad AI" ...] [--json pop.json]

  WORDS.json  transcribe.py output (start/end seconds on the source clock)
  KEEP.json   analyze.py silence output (uses keep_f), or a JSON list of [in, out] source frames (out exclusive),
              i.e. exactly the ranges you passed to R.keep. --at = timeline frame where the first range starts.
  --style lines: readable 1-2 line captions (9:16: 22-26 chars/line; 16:9: 42). pop: N words per card (short-form).
  --fix OLD=NEW  repeatable, case-insensitive whole-phrase replacement (names whisper got wrong).
  --json         also write [{text, at, len}] in timeline frames for R.title word-pop cards.
"""
import argparse
import json
import re


def ts(t):
    t = max(t, 0.0)
    h, rem = divmod(t, 3600); m, s = divmod(rem, 60)
    return f"{int(h):02d}:{int(m):02d}:{int(s):02d},{int(round((s - int(s)) * 1000)):03d}"


def remap(words, ranges, fps, at):
    """Source-clock words -> timeline frames. Words outside every kept range are dropped."""
    out, offset = [], at
    for a, b in ranges:
        for w in words:
            sf, ef = w["start"] * fps, w["end"] * fps
            if a <= sf < b:
                out.append({"word": w["word"], "at": offset + (sf - a), "end": offset + (min(ef, b) - a)})
        offset += b - a
    return sorted(out, key=lambda w: w["at"])


def group(words, style, max_chars, lines, n, max_gap_f):
    cues, cur = [], []
    for w in words:
        text = " ".join(x["word"] for x in cur + [w])
        gap = cur and w["at"] - cur[-1]["end"] > max_gap_f
        full = (len(cur) >= n) if style == "pop" else wrap(text, max_chars).count("\n") >= lines
        if cur and (gap or full):
            cues.append(cur); cur = []
        cur.append(w)
    if cur: cues.append(cur)
    return cues


def wrap(text, max_chars):
    lines, line = [], ""
    for t in text.split():
        if line and len(line) + 1 + len(t) > max_chars:
            lines.append(line); line = t
        else:
            line = (line + " " + t).strip()
    lines.append(line)
    if len(lines) == 2 and len(lines[0]) > len(lines[1]) + 4:  # bottom-heavy reads better (Netflix rule)
        words = text.split(); best = None
        for i in range(1, len(words)):
            a, b = " ".join(words[:i]), " ".join(words[i:])
            if len(a) <= max_chars and len(b) <= max_chars and len(a) <= len(b) and (best is None or len(b) - len(a) < best[0]):
                best = (len(b) - len(a), [a, b])
        if best: lines = best[1]
    return "\n".join(lines)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("words"); p.add_argument("--keep", required=True); p.add_argument("--at", type=int, default=0)
    p.add_argument("--fps", type=float, default=30); p.add_argument("--out", required=True)
    p.add_argument("--style", choices=["lines", "pop"], default="lines"); p.add_argument("--max-chars", type=int, default=24)
    p.add_argument("--lines", type=int, default=2); p.add_argument("--words", dest="per", type=int, default=3)
    p.add_argument("--fix", action="append", default=[]); p.add_argument("--json")
    a = p.parse_args()
    words = json.load(open(a.words))
    keep = json.load(open(a.keep))
    ranges = keep["keep_f"] if isinstance(keep, dict) else keep
    tw = remap(words, ranges, a.fps, a.at)
    cues = group(tw, a.style, a.max_chars, a.lines, a.per, max_gap_f=0.6 * a.fps)
    fixes = [f.split("=", 1) for f in a.fix]
    out, cards = [], []
    for c in cues:
        text = " ".join(w["word"] for w in c)
        for old, new in fixes:
            text = re.sub(r"(?i)\b" + re.escape(old) + r"\b", new, text)
        start, end = c[0]["at"], max(c[-1]["end"], c[0]["at"] + round(0.5 * a.fps))  # >= 0.5 s on screen
        cards.append({"text": text, "at": round(start), "len": round(end - start)})
        out.append((start / a.fps, end / a.fps, wrap(text, a.max_chars) if a.style == "lines" else text))
    for i in range(len(cards) - 1):  # cards share one track: each ends where the next begins
        cards[i]["len"] = max(1, min(cards[i]["len"], cards[i + 1]["at"] - cards[i]["at"]))
    for i in range(len(out) - 1):  # no overlaps, keep a 2-frame gap
        if out[i][1] > out[i + 1][0] - 2 / a.fps:
            out[i] = (out[i][0], out[i + 1][0] - 2 / a.fps, out[i][2])
    with open(a.out, "w") as f:
        for i, (s, e, t) in enumerate(out, 1):
            f.write(f"{i}\n{ts(s)} --> {ts(e)}\n{t}\n\n")
    if a.json:
        json.dump(cards, open(a.json, "w"), indent=1)
    print(json.dumps({"words_in": len(words), "words_kept": len(tw), "captions": len(out), "srt": a.out, "json": a.json}))


if __name__ == "__main__":
    main()
