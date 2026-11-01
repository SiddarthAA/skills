#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["faster-whisper"]
# ///
"""Speech -> word timings + captions (Resolve's own transcription is Studio-only and crashes free).

  transcribe.py AUDIO_OR_VIDEO [--model small.en] [--fps 30] [--out DIR] [--words-per-caption 3] [--max-chars 42]

Writes next to --out (default: the input's folder):
  <stem>.words.json   [{word, start, end, start_f, end_f}]   -> word-pop captions (R.title per word/group)
  <stem>.srt          sentence captions, <= max-chars per line, <= 2 lines -> finish.py --subs
  <stem>.pop.srt      groups of N words -> punchy short-form captions
Models (first use downloads into ~/.cache/huggingface): tiny.en 75 MB, base.en 145 MB, small.en 485 MB (default),
medium.en 1.5 GB. Noisy rooms: pass names/jargon with --hotwords "Names, Product" (initial prompts made whisper loop).
Always proof-read names; fix leftovers with captions.py --fix OLD=NEW.
"""
import argparse
import json
import os
import sys


def ts(t):
    h, rem = divmod(max(t, 0), 3600); m, s = divmod(rem, 60)
    return f"{int(h):02d}:{int(m):02d}:{int(s):02d},{int(round((s - int(s)) * 1000)):03d}"


def write_srt(path, cues):
    with open(path, "w") as f:
        for i, (a, b, text) in enumerate(cues, 1):
            f.write(f"{i}\n{ts(a)} --> {ts(b)}\n{text}\n\n")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("media", nargs="?"); p.add_argument("--model", default="small.en")
    p.add_argument("--hotwords", help="comma-separated names/terms to bias recognition")
    p.add_argument("--prefetch", action="store_true", help="only download the model, then exit"); p.add_argument("--fps", type=float, default=30)
    p.add_argument("--out"); p.add_argument("--words-per-caption", type=int, default=3); p.add_argument("--max-chars", type=int, default=42)
    p.add_argument("--language", default=None)
    p.add_argument("--device", default="cpu", help="cpu (default, works everywhere) or cuda (needs CUDA 12 cuBLAS/cuDNN)")
    a = p.parse_args()
    import sys
    try:
        from faster_whisper import WhisperModel
    except ImportError:  # `python3 transcribe.py` skips the uv script header that installs it
        sys.exit("transcribe.py: run it directly (./transcribe.py ..., a `uv run --script`), not with python3")
    print(f"loading whisper '{a.model}' (first run downloads it; see --help for sizes)...", file=sys.stderr, flush=True)
    model = WhisperModel(a.model, device=a.device, compute_type="int8")
    if a.prefetch:
        return print("model ready")
    segs, info = model.transcribe(a.media, word_timestamps=True, vad_filter=True, language=a.language, hotwords=a.hotwords)
    words, sentences = [], []
    for s in segs:
        ws = [w for w in (s.words or []) if w.word.strip()]
        words += [{"word": w.word.strip(), "start": round(w.start, 3), "end": round(w.end, 3),
                   "start_f": round(w.start * a.fps), "end_f": round(w.end * a.fps)} for w in ws]
        sentences.append((s.start, s.end, s.text.strip(), ws))
    out = a.out or os.path.dirname(os.path.abspath(a.media))
    os.makedirs(out, exist_ok=True)
    stem = os.path.join(out, os.path.splitext(os.path.basename(a.media))[0])
    json.dump(words, open(stem + ".words.json", "w"), indent=1)
    # sentence captions: wrap at max-chars, split into <= 2-line cues on word boundaries
    cues = []
    for start, end, text, ws in sentences:
        line, lines, cue_start = "", [], start
        for w in ws:
            t = w.word.strip()
            if len(line) + len(t) + 1 > a.max_chars:
                lines.append(line); line = ""
                if len(lines) == 2:
                    cues.append((cue_start, w.start, "\n".join(lines))); lines, cue_start = [], w.start
            line = (line + " " + t).strip()
        if line: lines.append(line)
        if lines: cues.append((cue_start, end, "\n".join(lines)))
    write_srt(stem + ".srt", cues)
    n = a.words_per_caption
    pops = [(g[0]["start"], g[-1]["end"], " ".join(w["word"] for w in g)) for g in (words[i:i + n] for i in range(0, len(words), n))]
    write_srt(stem + ".pop.srt", pops)
    print(json.dumps({"language": info.language, "words": len(words), "captions": len(cues),
                      "files": [stem + ".words.json", stem + ".srt", stem + ".pop.srt"]}))


if __name__ == "__main__":
    main()
