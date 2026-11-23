#!/bin/bash
#
# Prints SuperwallKit's version: the `let sdkVersion = """…"""` declaration
# in Constants.swift. Comments are stripped first, since the file's header
# comment shows the format with an example version.
#
# With --check, also fails unless SuperwallKit.podspec has the same version.
# Used by the release workflow, and checked on every push by tests.yml.
#
# Usage: scripts/sdk-version.sh [--check]

set -euo pipefail

cd "$(dirname "$0")/.."

version=$(python3 - <<'PY'
import re
source = open("Sources/SuperwallKit/Misc/Constants.swift").read()
# Block comments, then line comments (none of the strings here contain //).
code = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
code = re.sub(r"//[^\n]*", "", code)
matches = re.findall(r'^\s*let sdkVersion = """\s*\n\s*(\S+)\s*\n\s*"""', code, flags=re.M)
if len(matches) != 1:
    raise SystemExit(f"Expected one sdkVersion declaration in Constants.swift, found {len(matches)}.")
print(matches[0])
PY
)

if [ "${1:-}" = "--check" ]; then
  podspec=$(sed -nE 's/^[[:space:]]*s\.version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' SuperwallKit.podspec)
  if [ "$podspec" != "$version" ]; then
    echo "SuperwallKit.podspec says $podspec, Constants.swift says $version." >&2
    exit 1
  fi
fi

echo "$version"
