#!/bin/sh
# Build the self-host bundle only when an env value that Vite inlines changes.
# This runs during the image build and again at container startup.
set -e

# POSTHOG_SOURCEMAPS (CI sourcemap uploads) moves Vite's outDir; keep the
# fingerprint marker beside the output it describes.
if [ "${POSTHOG_SOURCEMAPS:-}" = "true" ]; then OUT_DIR=dist-sourcemaps; else OUT_DIR=dist; fi
FP_FILE="$OUT_DIR/.openseo-build-env"

# Everything that changes build output: the envPrefix prefixes from
# vite.config.ts (keep in sync) plus POSTHOG_SOURCEMAPS.
FINGERPRINT="$(env | grep -E '^(VITE_|AUTH_MODE|BYPASS_EMAIL_VERIFICATION|POSTHOG_PUBLIC_KEY|POSTHOG_HOST|TURNSTILE_SITE_KEY|POSTHOG_SOURCEMAPS)' | sort | sha256sum | cut -d' ' -f1)"
# A missing sha256sum would yield an empty, always-matching fingerprint and
# silently disable rebuilds — fail loudly instead.
test -n "$FINGERPRINT"

if [ -f "$FP_FILE" ] && [ "$(cat "$FP_FILE")" = "$FINGERPRINT" ]; then
  echo "Reusing existing build (build-relevant env unchanged)."
else
  echo "Building client + server (build-relevant env changed or output is missing)..."
  rm -f "$FP_FILE"
  pnpm run build
  printf '%s' "$FINGERPRINT" > "$FP_FILE"
fi
