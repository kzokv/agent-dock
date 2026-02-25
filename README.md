# codex-home

Shared Codex home for cross-platform reuse.

## Tracked

- `skills/`
- `agents/`
- `automations/`
- `memory.md` (optional)
- `scripts/`

## Not tracked

Secrets, machine-local runtime state, and caches are excluded via `.gitignore`.

## Link this repo to ~/.codex

```bash
./scripts/link.sh
```

The linker script backs up an existing `~/.codex` before creating the symlink.

## Install required skills

```bash
./scripts/install-required-skills.sh
```
