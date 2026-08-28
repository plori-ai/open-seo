#!/bin/sh
# Self-host container entrypoint. The image contains a build for its default
# auth mode. If a deployment changes an env value that Vite inlines, the shared
# build helper detects the new fingerprint and rebuilds before serving.
set -e

echo 'OpenSEO sends an anonymous usage heartbeat (counts only). Disable: OPENSEO_TELEMETRY_DISABLED=1. Details: docs/SELF_HOSTING_DOCKER.md#telemetry'

# The preflight validates env BEFORE the slow steps, so misconfiguration fails
# in seconds with the exact fix instead of after a multi-minute build.
pnpm exec tsx scripts/selfhost-preflight.ts

if [ "${DATABASE_PROVIDER:-d1}" = "postgres" ]; then
  pnpm run db:migrate:pg
else
  pnpm run db:migrate:local
fi

sh scripts/selfhost-build.sh

exec pnpm exec vite preview --host 0.0.0.0 --port "${PORT:-3001}"
