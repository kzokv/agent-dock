# Cross-Platform CLI Patterns

Use these patterns when implementing scripts under this skill.

## Shared rules

- Parse all arguments explicitly; do not ignore unknown inputs.
- Print `ERROR: ...` to stderr for invalid flags/args.
- Print help after argument errors and exit non-zero.
- Keep defaults deterministic and document them in `Options:`.
- Avoid interactive prompts unless explicitly requested.

## Shell

- Start with `set -euo pipefail` where compatible.
- Use `case` for flag parsing and shift safely.
- Reject positional arguments unless supported by design.

Pattern:

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_help; exit 0 ;;
    -x|--name) name="${2:-}"; shift 2 ;;
    -y|--mode) mode="${2:-auto}"; shift 2 ;;
    --) shift; break ;;
    -*)
      echo "ERROR: Unknown flag $1" >&2
      print_help
      exit 1
      ;;
    *)
      echo "ERROR: Unexpected positional argument: $1" >&2
      print_help
      exit 1
      ;;
  esac
done
```

## PowerShell

- Prefer explicit index-based parsing for predictable behavior.
- Write errors with `[Console]::Error.WriteLine(...)`.
- Exit with `exit 1` on validation failure.

## Batch

- Parse with a label loop and `shift`.
- Emit errors with `>&2 echo ERROR: ...`.
- Use `exit /b 1` for failures.

## AppleScript

- Parse `argv` sequentially in `on run argv`.
- Return errors in a way shell wrappers can detect non-zero completion.
- Keep text output machine-friendly and consistent with other script families.
