# Security model

The current core/CLI is offline, has no dependencies and does not monitor the keyboard. Input libraries are data, never executable code. Imports are bounded and validated. Output files refuse overwrite. This is not a proof of absence of every vulnerability.

A native adapter must use least-privilege OS interfaces, never request screen recording for expansion, and never capture or persist raw typing. Permission checks are not proof that the focused field is safe. Focus, selection, secure-input and clipboard races require explicit policy and tests. On uncertainty, do not insert or delete text.

No shell snippets, plugins, remote includes, background telemetry or cloud AI calls are allowed in the initial release. Clipboard recovery must not replace a newer clipboard value. Imported content must be previewed; conflicts must never be silently discarded.

Report non-sensitive defects through an issue. Do not post passwords, private snippets, customer messages, token-containing logs or exploit details that put users at immediate risk in public issues. A private security reporting channel must be verified before it is advertised.
