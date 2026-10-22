# SeedExpand

Small shortcuts. Complete thoughts. Your text stays yours.

SeedExpand is an original, MIT-licensed text-expansion project for reusable replies, long prompts and composable text blocks. The design target is a native Mac menu-bar app with no account, subscription, telemetry or AI service required to expand text.

## What works now

The Swift package includes a tested, bounded expansion matcher, validated JSON libraries, explicit ordered block composition, Apple text-replacement plist import/export and a command-line interface. There are no third-party package dependencies.

Native app source and an opt-in Accessibility adapter are included. Runtime validation is pending. The CLI does not monitor the keyboard. Core tests do not establish native editor compatibility or iPhone sync.

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

## Native development app

The repository now includes a macOS 13 SwiftUI menu-bar app. Native compilation,
packaging and interactive compatibility are pending coordinator validation; see
[the validation matrix](docs/VALIDATION.md). This is an unsigned development build.

On an authorized Mac with Xcode command-line tools and Swift 5.9 or newer:

```sh
./scripts/verify.sh
./scripts/package-macos.sh
```

Heavy local builds should be run through the owner's resource gate, once only.
The packaging script uses one compiler job and writes `dist/SeedExpand.app`.
It does not launch, install, sign, notarize or publish the app. For local testing,
copy that app into your Applications folder and open it normally. Respect macOS
security prompts; do not disable Gatekeeper. Permission identity can change when
an unsigned app is rebuilt or moved. Signed distribution remains future work.

Open **Library, Copy and Settings** from the menu bar. Create a title, ASCII
trigger and multiline text, inspect Preview, then Save. Search includes text.
Copy works without any OS permission. Expand the advanced section to compose
saved blocks in an explicit order, preview/copy/export the result, import with a
conflict preview, or export portable JSON and Apple plist. Merge refuses the
entire import on duplicate IDs, triggers or ambiguous prefixes. Existing entries
are never silently replaced. Apple plist is a user-controlled import route.

Automatic expansion is optional: Request Permissions, grant Accessibility and
Input Monitoring in System Settings, then explicitly Enable Monitoring. The app
never requests Screen Recording or Full Disk Access and does not start monitoring
at launch. Use bundle IDs in exclusions, for example `org.example.SyntheticEditor`.
Pause is available from the menu and library. Stop Monitoring removes the listener.

The initial adapter supports only enabled Accessibility text fields/text areas
with a readable value, readable nonsecure subrole, collapsed selection and
writable value. It requires consecutive caret progress in the same target and
an exact trigger suffix at a word boundary. After a focus change, type a space
before the trigger to establish continuity. Selection, navigation, modified keys,
secure input and unsupported fields abort matching. IME, key repeat, rich text,
very large documents and custom editors may refuse expansion; use Copy instead.

Insertion replaces the field's plain string value through Accessibility, with a
second focus/value/selection check immediately before writing. No clipboard,
synthetic keys, Return events or recursive matching are involved. Each insertion
pauses for review. Caret position, editor undo, formatting and app-specific value
setter semantics are not guaranteed. Accessibility has no compare-and-swap:
a target can change between the final check and setter. This residual race needs
native review before routine use; Copy is the deliberate alternative. There is
no automatic undo or retry after an uncertain write.

Library files live in `~/Library/Application Support/SeedExpand/`, directory mode
0700 and files mode 0600. Saves use a private staging file and atomic rename,
with one previous file at `library.backup.json`. Import also goes through that
save path. A read error blocks writes and monitoring instead of creating an empty
library. To recover, quit, preserve the damaged file separately, copy the backup
to `library.json`, reopen and Retry Loading. Atomic replacement does not promise
power-loss durability of the directory metadata. Exclusions alone are stored in
app preferences. Diagnostics contain state, not typing or snippet contents.

To uninstall: Quit SeedExpand, remove the app, remove its Accessibility and Input
Monitoring entries in System Settings, and optionally delete its Application
Support directory and `org.seedexpand.app` preferences. Export first if you want
to retain your library. No login item, service or Apple replacement database is
installed. Donations are optional; no receiving endpoint is enabled.
