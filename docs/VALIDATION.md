# Validation status

Second controlled implementation phase, branch `build/native-macos-v1`, based on
`34802fe9c47226820d5745b75a234c821d28db17`. One worker. No commits, pushes,
Git metadata changes, GUI launches, permission activation or financial actions.

The coordinator supplied the unchanged baseline: 32 XCTest tests and CLI
import/export/overwrite gates passed on GitHub macOS 14 arm64, Swift 5.10,
run 39719739851. The same 32 tests passed on Linux Swift 6.2.1.
Those results precede these changes. The previous local diagnostic history is
preserved in ITERATIONS.md. SwiftPM was not retried in this phase.

| Area | Actual status |
| --- | --- |
| Existing matcher, library and CLI implementations | Preserved |
| Native menu bar, searchable editor, validation, preview, Copy | Source implemented; runtime untested |
| Explicit ordered composition and text export | Source implemented; runtime untested |
| Private versioned persistence, atomic save, backup and load failure | Source implemented; new tests authored, not executed |
| Permission onboarding, pause, exclusions, diagnostics | Source implemented; runtime untested |
| Bounded adapter policy and Unicode replacement | Source implemented; new tests authored, not executed |
| Native adapter | Listen-only key-up plus verified AX plain-value replacement; runtime untested |
| New automated tests | Five XCTest methods authored; execution pending |
| Swift syntax parsing, including new tests | Exit 0 |
| Shell syntax for packaging and verification scripts | Exit 0 |
| Whitespace diff check | Exit 0 |
| Direct compiler typechecking | No result; interrupted, exit 130 |
| Full updated suite, Linux compatibility and native linking | Pending coordinator |
| Unsigned packaging command | Source implemented, shell syntax passed; packaging not run |
| Installation and uninstall | Documented, not performed |
| TextEdit | Not run |
| Browser plain textarea | Not run |
| Contenteditable | Not run |
| Focus switching and selection changes | Not run |
| OS secure input and secure fields | Not run |
| Permission revocation | Not run |
| Pause/resume and exclusions | Not run |
| Unicode and long native insertion | Not run |
| Clipboard changed during insertion | Not run; automatic adapter does not access clipboard |
| Unsupported target | Not run; policy refuses unknown/nonwritable targets |
| Matcher p95 with 1,000 snippets | Not measured |
| Startup, idle CPU and memory | Not measured |
| Signed/notarized distribution | Not performed |
| Donation endpoint | Not enabled |
| Draft PR | Reserved for coordinator after review |

## Build and review checkpoint

Run `./scripts/verify.sh` in the coordinator's authorized environment, then
`./scripts/package-macos.sh` on macOS. Use the resource gate exactly once for
heavy local builds. Do not disable sandbox protections. Package output is
`dist/SeedExpand.app`; the script does not launch or install it. README contains
complete local build, installation, recovery and removal instructions.

Review must include native compiler errors, the full existing plus new suite,
packaging and every manual matrix row before claiming native compatibility.
No new test count or latency result is claimed. macOS 13 remains the declared
minimum; it has not been runtime validated.

## Self-review and remaining limits

- Focus: same element, process, caret progress, exact suffix, current value and
  permissions are checked. Delayed events over 150 ms refuse insertion. AX has
  no atomic conditional write; the final check/write race remains. Each write
  pauses. This is an explicit development limitation, not proven safe universal
  editor support.
- Secure fields: secure event input and secure/unknown subroles refuse; native
  behavior and permission revocation remain untested. No permission workaround.
- Unicode: UTF-16 offsets convert through Swift grapheme boundaries. Invalid
  ranges, selection and word-interior matches refuse. Text is not synthesized as
  keystrokes, so multiline text cannot send Return events.
- Clipboard: automatic expansion never reads, writes or restores it. Explicit
  Copy replaces clipboard content only at the user's request.
- Imports: regular files only, bounded read, core schema/content validation,
  visible text preview, conflict-refusing merge and pre-save backup. No silent
  overwrite; private exports use exclusive creation. One backup is retained.
- Recovery: load failures block writes and monitoring; save failures leave the
  previous library in memory and stop monitoring. Private staging and atomic
  rename protect normal replacement, not directory power-loss durability or a
  hostile process with the same user privileges.
- AX plain-value replacement may change formatting/caret/undo behavior. No
  automatic rollback or undo is attempted. The adapter intentionally abstains
  in many custom/rich editors. Manual Copy remains useful without monitoring.
