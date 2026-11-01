#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["opencv-contrib-python-headless<5", "numpy"]
# ///
"""Track an object or a face in a video with OpenCV -> a Lua track file for R.track (Fusion keyframes).

  track.py VIDEO (--box X,Y,W,H | --face) [--at F] [--start S] [--end E] [--out PATH.lua] [--tracker csrt|kcf]

--box   the object at frame --at, in source pixels (or fractions of the frame when every value is <= 1). Read it off a still
        (prep.py still / R.still): top-left corner + size.
--face  detect the biggest face at --at instead (OpenCV Haar cascade; frontal faces only).
Tracks forward from --at to --end (default: the end of the file) and backward to --start (default: --at). Frames are SOURCE
frame numbers (0 = first frame of the file), the same numbers as an item's GetSourceStartFrame().
Writes PATH.lua: return {w=, h=, fps=, frames = {[f] = {x, y, bw, bh}}} with the box centre in Fusion units (fractions, y UP)
and its size as fractions of width/height, plus PATH.jpg: 6 frames with the tracked box drawn. LOOK at it before using the track.
Frames where the tracker lost the object are left out (Fusion interpolates over the gap); the count is printed.
"""
import argparse
import os
import sys

import cv2
import numpy as np


def make_tracker(kind):
    if kind == "kcf":
        return cv2.TrackerKCF_create()
    return cv2.TrackerCSRT_create()


def read_frames(cap, start, end):
    cap.set(cv2.CAP_PROP_POS_FRAMES, start)
    frames = []
    for _ in range(start, end + 1):
        ok, fr = cap.read()
        if not ok:
            break
        frames.append(fr)
    return frames


def biggest_face(frame):
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    casc = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
    faces = casc.detectMultiScale(gray, 1.1, 5, minSize=(40, 40))
    if len(faces) == 0:
        sys.exit("track.py: no face found at that frame; pass --box or another --at")
    return tuple(int(v) for v in max(faces, key=lambda b: b[2] * b[3]))


def run(frames, box, kind):
    """Track through frames (frames[0] holds box). Returns a list of boxes or None per frame."""
    t = make_tracker(kind)
    t.init(frames[0], box)
    out = [box]
    for fr in frames[1:]:
        ok, b = t.update(fr)
        out.append(tuple(int(v) for v in b) if ok else None)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--box")
    ap.add_argument("--face", action="store_true")
    ap.add_argument("--at", type=int, default=0)
    ap.add_argument("--start", type=int)
    ap.add_argument("--end", type=int)
    ap.add_argument("--out")
    ap.add_argument("--tracker", default="csrt", choices=["csrt", "kcf"])
    a = ap.parse_args()
    if not (a.box or a.face):
        ap.error("pass --box X,Y,W,H or --face")

    cap = cv2.VideoCapture(a.video)
    if not cap.isOpened():
        sys.exit(f"track.py: OpenCV cannot open {a.video}")
    W, H = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)), int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps, total = cap.get(cv2.CAP_PROP_FPS), int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    start = a.at if a.start is None else a.start
    end = total - 1 if a.end is None else min(a.end, total - 1)
    assert start <= a.at <= end, "need --start <= --at <= --end"

    frames = read_frames(cap, start, end)
    at = a.at - start
    if a.face:
        box = biggest_face(frames[at])
    else:
        v = [float(x) for x in a.box.split(",")]
        if all(x <= 1 for x in v):
            v = [v[0] * W, v[1] * H, v[2] * W, v[3] * H]
        box = tuple(int(round(x)) for x in v)

    fwd = run(frames[at:], box, a.tracker)
    back = run(frames[: at + 1][::-1], box, a.tracker)[::-1] if at > 0 else [box]
    boxes = back[:-1] + fwd  # index i = source frame start + i

    out = a.out or os.path.splitext(a.video)[0] + ".track.lua"
    lost = 0
    with open(out, "w") as f:
        f.write(f"return {{w = {W}, h = {H}, fps = {fps:g}, frames = {{\n")
        for i, b in enumerate(boxes):
            if b is None:
                lost += 1
                continue
            x, y, bw, bh = b
            f.write(f"[{start + i}] = {{{(x + bw / 2) / W:.5f}, {1 - (y + bh / 2) / H:.5f}, {bw / W:.5f}, {bh / H:.5f}}},\n")
        f.write("}}\n")

    # preview: 6 frames with the box drawn
    picks = np.linspace(0, len(frames) - 1, 6).astype(int)
    tiles = []
    for i in picks:
        fr = frames[i].copy()
        if boxes[i]:
            x, y, bw, bh = boxes[i]
            cv2.rectangle(fr, (x, y), (x + bw, y + bh), (0, 255, 255), max(2, W // 300))
        cv2.putText(fr, f"f{start + i}", (20, 60), cv2.FONT_HERSHEY_SIMPLEX, W / 800, (0, 255, 255), max(2, W // 400))
        tiles.append(cv2.resize(fr, (480, int(480 * H / W))))
    sheet = np.vstack([np.hstack(tiles[:3]), np.hstack(tiles[3:])])
    cv2.imwrite(os.path.splitext(out)[0] + ".jpg", sheet)
    print(f"{out}: frames {start}-{start + len(boxes) - 1}, {len(boxes) - lost} tracked, {lost} lost; preview {os.path.splitext(out)[0]}.jpg")


if __name__ == "__main__":
    main()
