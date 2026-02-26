# Onboarding Script Helpers

## Scripts

- [`scripts/onboarding.sh`](onboarding.sh)
  - `log` keeps lifecycle messages namespaced and suitable for automation; it also captures when the optional `codex_home` flag is supplied or defaults to the live dotfile location.
  - `canonical_path` and `resolve_link_target_path` normalize symlink targets so the script can detect canonical equivalence before touching the host path.
  - `ensure_repo_trust_block` centralizes the trust-level write-upsert, so the template helper only adjusts the `[projects."$repo_root"]` block once.
  - `generate_runtime_config` merges `config.base.toml` and the helper-updated `config.local.toml` without duplicating blank lines or conflicting sections.
  - `-h/--help` prints the helper-driven usage summary; the script remains flag-driven and never prompts interactively.

- [`scripts/test-onboarding.sh`](test-onboarding.sh)
  - `fail`, `assert_file_contains`, and `assert_eq` codify helper test expectations, letting subsequent helper assertions remain expressive and machine-friendly.
  - `make_fixture` builds a throwaway repo, copies `onboarding.sh`, and gives downstream helpers their own `codex_home` flag target so tests stay isolated.
  - The helper tests validate the log and config helpers indirectly by rerunning onboarding in a fixture and asserting idempotent trust block behavior.

- [`scripts/check-config-migration.sh`](check-config-migration.sh)
  - `log` is the helper that prefixes every message with `[check-config-migration]` so tooling can quickly filter for migration hygiene reports.
  - `errors`, `assert_tracked`, `assert_untracked`, and `assert_ignored` are helper routines that keep each check isolated while still letting the script report multiple failures before exiting.
  - `print_help` documents the flag-driven mode and explains that `-h/--help` is the only supported flag before the helper checks run.

## Flag-driven helpers & tests
- `onboarding.sh` treats the optional first argument as a `codex_home` flag, so helper functions such as `log`, `ensure_repo_trust_block`, and `generate_runtime_config` can operate deterministically even when tests override the real home directory.
- `test-onboarding.sh` is the new helper test suite that reuses the helper functions and fixtures to exercise flag-based flows; it depends on the `fail`, `assert_*`, and `make_fixture` helpers to confirm the onboarding helpers remain idempotent with each pass.

## Guidelines for future helpers
Always implement helper functions in any onboarding-related script and document them here before committing new behavior. Helpers should explain why they exist, how they relate to optional flags (such as `--codex-home`), and surface in the helper test suite.
