# Contributing

Read AGENTS.md and SECURITY.md. Create a feature branch, run ./scripts/verify.sh, make one coherent change and include the actual validation output in your pull request. Do not commit private libraries, credentials, build caches or local diagnostics.

Tests use synthetic content. Bug reports should describe expected behavior, actual behavior, platform and a safe minimal example. Never include raw keyboard logs. Do not claim platform support from an unrelated platform's passing tests.

Keep the interface smaller when possible. New permissions, dependencies, network calls, payment flows and telemetry require explicit review. Running the app must not require an AI account.
