# codex-home

Shared Codex home for cross-platform reuse.

## Tracked

- `skills/`
- `agents/`
- `automations/`
- `memory.md` (optional)
- `scripts/`
- `config.base.toml`

## Not tracked

Secrets, machine-local runtime state, and caches are excluded via `.gitignore`.

## Link this repo to ~/.codex

```bash
./scripts/onboarding.sh
```

You can also target a custom Codex home path:

```bash
./scripts/onboarding.sh /path/to/codex-home
```

The onboarding script:

- backs up an existing target path (`~/.codex` by default) before creating the symlink
- upserts machine-local trust settings for this repo by rewriting its `[projects."…"]` block in `config.local.toml` (ignored), preserving other local settings and other project blocks
- regenerates `config.toml` from `config.base.toml` + `config.local.toml`
- fails fast with a non-zero exit if `config.base.toml` is missing

Config ownership:

- `config.base.toml` is tracked and is the source of shared defaults
- `config.local.toml` is machine-local and ignored
- `config.toml` is generated runtime config and ignored

If onboarding is re-run, it preserves other local config and keeps config generation idempotent.
Never edit `config.toml` directly; treat it as the generated runtime view of the shared (`config.base.toml`) + machine-local (`config.local.toml`) inputs.
Make shared edits in `config.base.toml`, machine-local edits in `config.local.toml`, then run onboarding to regenerate `config.toml`.

## Config migration hygiene

When migrating config layout (for example, replacing tracked `config.toml` with generated `config.toml` + tracked `config.base.toml`), commit the migration atomically so tracked/ignored files do not drift.

```bash
./scripts/check-config-migration.sh
```

## Validate onboarding

Ensure the onboarding script still behaves as expected (trust block insertion, symlink handling, idempotent config regeneration) by running:

```bash
./scripts/test-onboarding.sh
```

## Install required skills

```bash
./scripts/install-required-skills.sh
```
