#!/usr/bin/env bash
set -euo pipefail
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v pwsh >/dev/null 2>&1; then
  printf '%s\n' 'PowerShell 7 (pwsh) is required. See SETUP.md.' >&2
  exit 127
fi
exec pwsh -NoLogo -NoProfile -File "$script_dir/start-agent.ps1" "$@"
