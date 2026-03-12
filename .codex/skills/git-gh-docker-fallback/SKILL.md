---
name: git-gh-docker-fallback
description: Use Docker wrappers when `git` or `gh` is unavailable.
---

# Git/GH Docker Fallback

## Overview

Use this skill to establish temporary shell wrappers for `git` and `gh` via Docker so Git and GitHub workflows can proceed when native binaries are not installed.

## Workflow

1. Check native availability of `git` and `gh`.
2. If either binary is missing, load shell wrappers from `scripts/enable_wrappers.sh`.
3. Verify wrappers with `git --version` and `gh --version`.
4. Continue the normal Git/PR workflow.

## Guardrails

- Use wrappers only when native commands are unavailable.
- Keep wrappers session-scoped; do not persist shell aliases without explicit request.
- Ensure required auth env vars (for example `GH_TOKEN`) are present before `gh` usage.

## Resources

- `scripts/enable_wrappers.sh`: emits shell functions for Docker-backed `git` and `gh`.
