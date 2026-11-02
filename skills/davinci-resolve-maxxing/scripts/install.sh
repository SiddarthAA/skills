#!/usr/bin/env bash
# One-time setup for the davinci-resolve-maxxing skill on Linux (macOS: see references/mac.md).
# Idempotent. Never touches projects or media.
set -eu
SKILL=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
B=$HOME/resolve-bridge
BIN=$HOME/.local/bin
LUTDIR=${RESOLVE_LUT_DIR:-/opt/resolve/LUT}/agent
mkdir -p "$B/assets" "$BIN"
say(){ echo "install: $*"; }

# 1. bridge + helper library live in ~/resolve-bridge (the Console dofile path); symlinks keep them in sync with the skill
ln -sf "$SKILL/scripts/bridge.lua" "$B/bridge.lua"
ln -sf "$SKILL/scripts/lib.lua" "$B/lib.lua"
for f in rv rcon resolve-up gui fl_eq.py prep.py analyze.py sheet.py captions.py transcribe.py finish.py track.py; do
  chmod +x "$SKILL/scripts/$f"; ln -sf "$SKILL/scripts/$f" "$BIN/$f"
  [ -f "$B/$f" ] && [ ! -L "$B/$f" ] && rm "$B/$f"  # old hand-made copies would shadow the real scripts
done
chmod +x "$SKILL/scripts/"*.py "$SKILL/scripts/"*.sh
say "bridge in $B; rv, rcon, resolve-up, gui and the .py tools in $BIN"

# 2. xdotool (GUI fallback + typing the bridge line). No sudo? unpack the Ubuntu .deb locally.
if ! command -v xdotool >/dev/null && ! command -v xdo >/dev/null; then
  if command -v apt >/dev/null; then
    T=$HOME/.local/share/resolve-bridge-xdo; mkdir -p "$T/deb"
    (cd "$T/deb" && apt download xdotool libxdo3 >/dev/null 2>&1) && for d in "$T"/deb/*.deb; do dpkg -x "$d" "$T/root"; done
    printf '#!/bin/sh\nLD_LIBRARY_PATH=%s/root/usr/lib/x86_64-linux-gnu exec %s/root/usr/bin/xdotool "$@"\n' "$T" "$T" > "$BIN/xdo"
    chmod +x "$BIN/xdo"; say "xdotool unpacked locally as 'xdo'"
  else
    say "WARNING: install xdotool (GUI fallback needs it)"
  fi
fi

# 3. transparent title carriers (titles ride on these; see lib.lua R.title)
for size in 1080x1920 1920x1080 1080x1350 1080x1080; do
  for fps in 30; do "$SKILL/scripts/prep.py" carriers "$size" --fps "$fps" --out "$B/assets" >/dev/null; done
done
for size in 1920x1080 1080x1920; do  # 24 fps (cinematic pieces); other rates: R.carrier's error prints the command
  [ -f "$B/assets/carrier_${size}_24.mov" ] || "$SKILL/scripts/prep.py" carriers "$size" --fps 24 --out "$B/assets" >/dev/null
done
say "carriers in $B/assets (more: prep.py carriers WxH --fps N --out $B/assets)"

# 4. LUTs: SetLUT only accepts files inside Resolve's master LUT folder
if mkdir -p "$LUTDIR" 2>/dev/null && [ -w "$LUTDIR" ]; then
  for look in moody teal-orange warm-film clean mono; do
    [ -f "$LUTDIR/$look.cube" ] || "$SKILL/scripts/prep.py" lut "$look" --out "$LUTDIR/$look.cube" >/dev/null
  done
  say "LUTs in $LUTDIR (use as 'agent/<look>.cube')"
else
  say "WARNING: cannot write $LUTDIR; rerun with sudo or set RESOLVE_LUT_DIR"
fi

# 5. starter Fairlight presets (EQ/Dynamics XML): they show up at once in the EQ/Dynamics windows and Fairlight > Presets Library
FL=$HOME/.local/share/DaVinciResolve/configs/Fairlight/Presets
for kind in EQ DYN; do mkdir -p "$FL/$kind"; cp "$SKILL/assets/fairlight/$kind/"*.xml "$FL/$kind/"; done
say "Fairlight presets in $FL (make more: fl_eq.py)"

# 6. Resolve's 417 built-in Fusion templates as plain .setting files (R.fx pastes them; R.templates points here)
DRFX=${RESOLVE_DIR:-/opt/resolve}/Fusion/Templates/Templates.drfx
[ -f "$DRFX" ] && unzip -qo "$DRFX" -d "$B/templates" && say "templates in $B/templates (R.templates)"

# 7. the skill's effect presets (glitch, vhs, zoom-punch...): R.fx(item, R.effects .. "<name>.setting")
ln -sfn "$SKILL/assets/fx" "$B/fx" && say "effect presets in $B/fx (R.effects)"

# 8. dependencies
for c in ffmpeg ffprobe uv convert montage import; do command -v "$c" >/dev/null || say "WARNING: missing $c"; done
[ -x /opt/resolve/bin/resolve ] || say "WARNING: Resolve not at /opt/resolve/bin/resolve (set RESOLVE_BIN)"
echo "$PATH" | tr ':' '\n' | grep -qx "$BIN" || say "WARNING: add $BIN to PATH"
if [ "${1:-}" = "--with-whisper" ]; then "$SKILL/scripts/transcribe.py" --prefetch --model small.en; fi
say "done. Next: resolve-up <project>   (optional: install.sh --with-whisper pre-downloads the 485 MB speech model)"
