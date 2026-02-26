#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<HELP
Description:
  Print shell wrapper functions for Docker-backed git and gh commands.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help              Show this help message and exit (optional)
  -s, --shell SHELL       Output format target: bash or zsh (optional, default: bash)
HELP
}

shell_type="bash"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -s|--shell)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: Missing value for $1" >&2
        print_help
        exit 1
      fi
      shell_type="$2"
      shift 2
      ;;
    -* )
      echo "ERROR: Unknown flag $1" >&2
      print_help
      exit 1
      ;;
    * )
      echo "ERROR: Unexpected positional argument: $1" >&2
      print_help
      exit 1
      ;;
  esac
done

if [[ "$shell_type" != "bash" && "$shell_type" != "zsh" ]]; then
  echo "ERROR: Unsupported shell '$shell_type'. Use bash or zsh." >&2
  print_help
  exit 1
fi

cat <<'WRAPPERS'
git() {
  docker run --rm -it -v "$HOME":/root -v "$PWD":/git -w /git alpine/git "$@"
}

gh() {
  docker run --rm -it \
    -e GH_TOKEN \
    -e HOME=/tmp/gh-home \
    -v "$HOME/.config/gh-docker":/tmp/gh-home \
    -v "$PWD":/work \
    -w /work \
    --add-host host.docker.internal:host-gateway \
    serversideup/github-cli gh "$@"
}
WRAPPERS
