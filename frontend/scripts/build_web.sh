#!/usr/bin/env bash
# firebase.json's hosting.predeploy invokes this script instead of running
# `flutter build web --dart-define=...` directly. Firebase's predeploy hooks
# run through cross-env-shell, which parses the WHOLE command as a single
# string looking for `word=value` env-setter tokens (its syntax for
# `VAR=val command`) — any `=` anywhere in that string, including inside a
# --dart-define flag, gets swallowed as a bogus assignment and the command
# silently never runs (exit 0, no output, nothing rebuilt). Keeping the `=`
# characters inside this script instead of in the predeploy command string
# sidesteps that parser entirely.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter build web --release \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}" \
  --dart-define=SENTRY_ENVIRONMENT=production
