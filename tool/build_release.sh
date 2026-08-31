#!/usr/bin/env bash
# ============================================================================
# Qurani release build helper (macOS / Linux / CI)
# ============================================================================
# ALWAYS builds with the Supabase credentials injected via --dart-define-from-file.
# A plain `flutter build ... --release` silently ships a build with NO Supabase
# config (no news, no stats, no DB reciters), because the credentials are
# compile-time defines. This script makes that mistake impossible.
#
# Usage (from the project root):
#   tool/build_release.sh              # default: Android App Bundle (AAB)
#   tool/build_release.sh apk          # Android APK
#   tool/build_release.sh ipa          # iOS (macOS only)
#   tool/build_release.sh web          # Web
#
# CI note: if supabase.env.json isn't on disk (it's gitignored), set the env
# vars SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY instead and this script will
# build a temporary file from them.
# ============================================================================
set -euo pipefail

# Project root = parent of this script's dir.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/supabase.env.json"

# If the file is missing but CI env vars exist, synthesize it.
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_PUBLISHABLE_KEY:-}" ]]; then
    echo "supabase.env.json not found; building it from CI env vars."
    printf '{\n  "SUPABASE_URL": "%s",\n  "SUPABASE_PUBLISHABLE_KEY": "%s"\n}\n' \
      "$SUPABASE_URL" "$SUPABASE_PUBLISHABLE_KEY" > "$ENV_FILE"
  else
    echo "ERROR: supabase.env.json not found and SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY not set." >&2
    echo "Building without them ships a broken (Supabase-disabled) app." >&2
    exit 1
  fi
fi

# Reject obvious placeholders.
if grep -q '<' "$ENV_FILE"; then
  echo "ERROR: supabase.env.json contains placeholder values (<...>). Fill in real values." >&2
  exit 1
fi

TARGET="${1:-appbundle}"
DEFINE="--dart-define-from-file=supabase.env.json"

# Echo what was actually resolved, so a CI log is self-documenting. A build with
# missing credentials fails silently at RUNTIME (no news, no stats, no DB
# reciters) and looks completely green here, which is exactly how an iOS release
# shipped with stats disabled and went unnoticed. The URL is not a secret - it
# ships in the client bundle either way - but the key is only ever reported as a
# length so it never lands in a build log.
RESOLVED_URL="$(grep -o '"SUPABASE_URL"[[:space:]]*:[[:space:]]*"[^"]*"' "$ENV_FILE" | sed 's/.*"\([^"]*\)"$/\1/')"
RESOLVED_KEY="$(grep -o '"SUPABASE_PUBLISHABLE_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$ENV_FILE" | sed 's/.*"\([^"]*\)"$/\1/')"
if [[ -z "$RESOLVED_URL" || -z "$RESOLVED_KEY" ]]; then
  echo "ERROR: supabase.env.json is missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY." >&2
  exit 1
fi

echo "Building '$TARGET' (release) with Supabase config from supabase.env.json..."
echo "  SUPABASE_URL            = $RESOLVED_URL"
echo "  SUPABASE_PUBLISHABLE_KEY = (${#RESOLVED_KEY} chars)"

case "$TARGET" in
  appbundle|aab) flutter build appbundle --release "$DEFINE" ;;
  apk)           flutter build apk --release "$DEFINE" ;;
  ipa)           flutter build ipa --release "$DEFINE" ;;
  web)           flutter build web --release "$DEFINE" ;;
  *)
    echo "Unknown target '$TARGET'. Use: appbundle | apk | ipa | web" >&2
    exit 1
    ;;
esac

echo "Done. (Supabase URL: $RESOLVED_URL)"
