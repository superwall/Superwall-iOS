#!/bin/bash
#
# Prints the CHANGELOG.md section for a version: everything under its
# "## <version>" heading up to the next "## " heading, without the heading
# itself or surrounding blank lines. Exits non-zero if the section is missing
# or empty. Used for the GitHub release notes (see .github/workflows/release.yml).
#
# Usage: scripts/release-notes.sh 4.19.0

set -euo pipefail

cd "$(dirname "$0")/.."

version="${1:?Usage: scripts/release-notes.sh <version>}"

notes=$(awk -v heading="## $version" '
  $0 == heading { found = 1; next }
  found && /^## / { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')

if [ -z "$notes" ]; then
  echo "No notes for $version in CHANGELOG.md." >&2
  exit 1
fi

printf '%s\n' "$notes"
