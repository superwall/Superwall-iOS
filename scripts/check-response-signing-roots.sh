#!/usr/bin/env bash
# Fails unless ResponseSigningRoots embeds both response-signing roots (active and standby).
#
# A release without them can't verify any signed response: report-only apps would report every
# one, and apps that enforce signatures would reject them all. The roots come from
# superwall/paywall-next `export-root-key` (see packages/response-signing/README.md there).
#
# Usage: scripts/check-response-signing-roots.sh [path to ResponseSigningRoots.swift]
set -euo pipefail

file="${1:-$(dirname "$0")/../Sources/SuperwallKit/Network/Response Signing/ResponseSigningRoots.swift}"
# One line per declaration, so a value the export script split over two lines is read whole.
source=$(tr '\n' ' ' < "$file")
status=0
values=()

for name in active standby; do
  value=$(grep -oE "static let ${name}: String\? = +\"[A-Za-z0-9+/=]+\"" <<< "$source" \
    | grep -oE '"[^"]+"' | tr -d '"' || true)
  hex=$(printf '%s' "$value" | base64 -d 2>/dev/null | od -An -tx1 | tr -d ' \n' || true)
  if [[ -z "$value" ]]; then
    echo "::error file=$file::ResponseSigningRoots.$name isn't set. Paste the line export-root-key prints."
    status=1
  elif [[ ${#hex} -ne 130 || "${hex:0:2}" != "04" ]]; then
    echo "::error file=$file::ResponseSigningRoots.$name isn't base64 of a 65-byte uncompressed P-256 key."
    status=1
  fi
  values+=("$value")
done

if [[ $status -eq 0 && "${values[0]}" == "${values[1]}" ]]; then
  echo "::error file=$file::ResponseSigningRoots.active and .standby are the same key; they must be two roots."
  status=1
fi
[[ $status -eq 0 ]] && echo "Both response-signing roots are embedded."
exit $status
