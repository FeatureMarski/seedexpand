# SeedExpand

Small shortcuts. Complete thoughts. Your text stays yours.

SeedExpand is an original, MIT-licensed text-expansion project for reusable replies, long prompts and composable text blocks. The design target is a native Mac menu-bar app with no account, subscription, telemetry or AI service required to expand text.

## What works now

The Swift package includes a tested, bounded expansion matcher, validated JSON libraries, explicit ordered block composition, Apple text-replacement plist import/export and a command-line interface. There are no third-party package dependencies.

**The native Mac app and system-wide insertion adapter are not implemented in this initial core release.** The CLI is not a background keyboard listener. The native app build is the first agent milestone. Do not mistake passing core tests for an installed desktop app or verified iPhone sync.

## Run the core

Requires Swift 5.9 or newer on macOS 13 or newer, or a compatible Linux Swift toolchain.

```sh
./scripts/verify.sh
swift run seedexpand validate examples/starter.json
swift run seedexpand compose examples/starter.json evidence build
swift run seedexpand export-apple examples/starter.json SeedExpand.plist
```

Output files are never overwritten by the CLI. Choose a new name when one already exists.

## Apple keyboard compatibility

On a Mac, back up existing replacements in System Settings > Keyboard > Text Replacements by dragging the selected entries to a folder. Drag the exported plist into that Text Replacements window to import it. Apple documents syncing replacements with the same Apple Account and iCloud Drive configured on each device. This is not a direct iPhone plist installer, and app-specific expansion behavior can vary.

Reference: https://support.apple.com/en-za/guide/mac-help/mchl2a7bd795/mac

The core deliberately rejects ambiguous immediate-expansion trigger prefixes. For example, `;a` and `;abc` cannot coexist in one library. It also rejects duplicate IDs/triggers and oversized or malformed imports. Triggers currently use printable ASCII; expansion text supports Unicode and multiline prompts.

## Product direction

One searchable library. Shortcut, title, text. Preview before use. Optional block composition rather than magical rewriting. Native permission onboarding, pause, app exclusions and safe insertion before adding advanced integrations. Portable local files are the source of truth.

See [the build brief](docs/BUILD_BRIEF.md), [agent rules](AGENTS.md), [security model](SECURITY.md), [baseline evidence](docs/BASELINE.md), and [support policy](SUPPORT.md).

## Development status

This repository is early-stage open-source software, not a claim of production readiness or superiority over existing tools. Each release must identify what was actually tested, on which platform, and which integrations remain unverified.

## License

MIT. Donations are optional and not enabled yet. The core must remain useful without payment.
