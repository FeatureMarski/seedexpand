#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift test --jobs 1
swift run --skip-build seedexpand validate examples/starter.json
work="$(mktemp -d "${TMPDIR:-/tmp}/seedexpand-verify.XXXXXX")"
trap 'rm -f "$work/export.plist" "$work/roundtrip.json"; rmdir "$work"' EXIT HUP INT TERM
swift run --skip-build seedexpand export-apple examples/starter.json "$work/export.plist"
swift run --skip-build seedexpand import-apple "$work/export.plist" "$work/roundtrip.json"
swift run --skip-build seedexpand validate "$work/roundtrip.json"
if swift run --skip-build seedexpand export-apple examples/starter.json "$work/export.plist"; then
    echo 'ERROR: existing output was overwritten' >&2
    exit 1
fi
printf 'Verification complete. Existing-file overwrite refusal was expected.\n'
