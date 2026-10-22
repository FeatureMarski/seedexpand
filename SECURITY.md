# Security model

The current core/CLI is offline, has no dependencies and does not monitor the keyboard. Input libraries are data, never executable code. Imports are bounded and validated. Output files refuse overwrite. This is not a proof of absence of every vulnerability.

A native adapter must use least-privilege OS interfaces, never request screen recording for expansion, and never capture or persist raw typing. Permission checks are not proof that the focused field is safe. Focus, selection, secure-input and clipboard races require explicit policy and tests. On uncertainty, do not insert or delete text.

No shell snippets, plugins, remote includes, background telemetry or cloud AI calls are allowed in the initial release. Clipboard recovery must not replace a newer clipboard value. Imported content must be previewed; conflicts must never be silently discarded.

Report non-sensitive defects through an issue. Do not post passwords, private snippets, customer messages, token-containing logs or exploit details that put users at immediate risk in public issues. A private security reporting channel must be verified before it is advertised.

## Native development adapter

Monitoring is off at startup. Explicit onboarding requests Accessibility and
Input Monitoring only. The listener observes key-up events; there is no raw
input log, network client, script runner or clipboard insertion fallback.
Only target identity and caret offset survive an event; matching uses a bounded
suffix of a transient Accessibility value. Values are bounded to 1 MiB. Secure
input, secure/unknown subroles, noncollapsed selections, exclusions, permission
loss and uncertain focus refuse insertion. No automatic rollback is attempted.

The adapter sets a verified plain-text AX value once, then pauses. AX offers no
atomic compare-and-swap, so a final-check/write race remains. It can also discard
rich formatting or move the caret in an editor with unusual setter semantics.
Native compatibility validation is mandatory before recommending monitoring.
Manual Copy is deliberate and never restores an older clipboard value. No
automatic undo is offered without proof of target/range continuity.

Private files are created with mode 0600 before writing and stored beneath a
0700 directory. Imports are size bounded, fully validated and previewed before
merge. Export uses exclusive creation and refuses existing paths and symlinks.
This protects against accidental disclosure/overwrite; it does not protect
against another process running as the same user or privileged malware.
