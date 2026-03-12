---
name: script-automation
description: Build robust cross-platform automation scripts.
---

# Script Automation

## Overview

Use this skill to implement reliable, non-interactive automation scripts with a shared command-line contract across shell, AppleScript, PowerShell, and batch.

## Automation Style (Required)

- Keep onboarding helpers flag-driven.
- Support `-h/--help` in every script to explain purpose and available options.
- Do not add interactive prompts unless explicitly requested.
- Follow shared scripting conventions across shell, AppleScript, PowerShell, and batch.
- Include common helper functions in new scripts as defined in `scripts/README.md`.
- Provide a clear help block in each script that prints the following (exact) sections and spacing: `Description:`, `Usage:`, and `Options:`. Keep a script-name variable (for example `SCRIPT_PATH`) so usage lines remain stable across invocations.
- In `Options:`, explicitly label each option as required vs optional, and include a default value when one exists.
- For unknown flags or unexpected positional args, print an `ERROR:` line to stderr, print help, and exit non-zero.

### Shell help template

```shell
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF
Description:
  Brief summary of what the script does.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help              Show this help message and exit (optional)
  -x, --name VALUE        Describe what this option controls (required)
  -y, --mode MODE         Describe what this option controls (optional, default: auto)
EOF
}
```

### PowerShell help template

```powershell
$SCRIPT_PATH = Split-Path -Leaf $PSCommandPath

function Show-Help {
  @"
Description:
  Brief summary of what the script does.

Usage: $SCRIPT_PATH [OPTIONS]

Options:
  -h, --help              Show this help message and exit (optional)
  -x, --name <value>      Describe what this option controls (required)
  -y, --mode <mode>       Describe what this option controls (optional, default: auto)
"@ | Write-Output
}

# Unknown args: write ERROR: to stderr, show help, exit non-zero.
# [Console]::Error.WriteLine("ERROR: Unknown flag $arg")
```

### Batch help template

```bat
@echo off
setlocal enabledelayedexpansion
set "SCRIPT_PATH=%~nx0"

:print_help
echo Description:
echo   Brief summary of what the script does.
echo.
echo Usage: %SCRIPT_PATH% [OPTIONS]
echo.
echo Options:
echo   -h, --help              Show this help message and exit (optional)
echo   -x, --name VALUE        Describe what this option controls (required)
echo   -y, --mode MODE         Describe what this option controls (optional, default: auto)
exit /b 0

REM Unknown args: echo ERROR: to stderr, show help, exit non-zero.
REM >&2 echo ERROR: Unknown flag %1
```

## AppleScript conventions

AppleScript is not a POSIX CLI language, so keep the same contract through `osascript` argument handling:

- Define a `scriptPath`/script name constant for stable usage text.
- Implement a `showHelp` handler that prints `Description:`, `Usage:`, `Options:` with the same section order.
- Parse `argv` deterministically in `on run argv`.
- Treat unknown flags and unexpected positional args as errors: write `ERROR:` and return non-zero through the shell wrapper.
- Do not use dialogs or interactive prompts unless explicitly requested.

Use this baseline:

```applescript
on showHelp(scriptPath)
  return "Description:" & linefeed & ¬
    "  Brief summary of what the script does." & linefeed & linefeed & ¬
    "Usage: " & scriptPath & " [OPTIONS]" & linefeed & linefeed & ¬
    "Options:" & linefeed & ¬
    "  -h, --help              Show this help message and exit (optional)" & linefeed & ¬
    "  -x, --name VALUE        Describe what this option controls (required)" & linefeed & ¬
    "  -y, --mode MODE         Describe what this option controls (optional, default: auto)"
end showHelp

on run argv
  -- Parse argv and emit ERROR: ... for unknown inputs
end run
```

## Workflow

1. Choose target language by platform constraints (`.sh`, `.applescript`/`.scpt`, `.ps1`, `.bat`).
2. Implement flag parsing first, then help output, then core behavior.
3. Enforce non-interactive execution and deterministic defaults.
4. Validate unknown-arg behavior and non-zero exits for invalid input.
5. Run script-level checks where possible before finalizing.

## References

- For concrete parser patterns and error handling examples, read `references/cross-platform-cli-patterns.md`.
