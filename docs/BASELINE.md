# Baseline evidence

Initial verification performed on 2026-10-22 UTC in an isolated Linux x86_64 workspace with Swift 6.2.1. No build was run on the maintainer's Mac for this baseline.

Command: `./scripts/verify.sh`

- 32 XCTest cases executed, 0 failures.
- CLI validated the 3-snippet synthetic example library.
- Apple plist export and reimport succeeded; reimported library validated.
- Existing output-file overwrite was rejected as expected.
- Unicode, 50,000-character text roundtrip, collision validation, bounded matcher state, secure-input flag, pause, focus reset contract and nonrecursive matching are covered by tests.

Not tested: actual macOS native keyboard event interception, insertion, Accessibility/Input Monitoring authorization, editor compatibility, GUI usability, signed/notarized packaging, iPhone expansion or iCloud sync. No native app existed at this baseline. The pure engine's secure-input flag is not an OS secure-field detector.

Do not reuse this count after changing tests without rerunning them. Core tests do not establish production readiness.
