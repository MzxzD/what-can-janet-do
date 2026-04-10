#!/usr/bin/env bash
# Copy janet-mascot-web into ./janet/ so https://heyjanet.org/janet/ ships with the same Pages deploy.
# Source of truth: https://github.com/MzxzD/janet-mascot-web
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${JANET_MASCOT_WEB:-$ROOT/../janet-mascot-web}"
DST="$ROOT/janet"
if [[ ! -d "$SRC" ]]; then
  echo "sync-janet-mascot: missing source repo at $SRC (set JANET_MASCOT_WEB)" >&2
  exit 1
fi
mkdir -p "$DST"
# _redirects is for janet-mascot-web.pages.dev only; copying it under heyjanet.org/janet/ would loop.
rsync -a --delete --exclude '.git' --exclude 'wrangler.toml' --exclude '_redirects' "$SRC/" "$DST/"
echo "sync-janet-mascot: updated $DST ($(find "$DST" -type f | wc -l | tr -d ' ') files)"
