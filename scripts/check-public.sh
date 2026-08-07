#!/usr/bin/env bash
# Pre-push check: fail if any tracked file contains internal references or
# blocklisted terms. The blocklist itself is maintainer-local (.publish-blocklist,
# gitignored) so the terms are never published in this script.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
# CONTRIBUTING.md quotes the banned words as rules; exclude it from its own scan.
files=$(git ls-files '*.md' '*.json' '*.html' | grep -v '^CONTRIBUTING\.md$')

# 1. Generic internal-reference patterns (public, safe to encode here)
patterns=(
  '#[0-9]{3,4}'            # issue/PR numbers
  '/Users/[a-z]'           # local filesystem paths
  '\bnot yet\b'
  '\bplanned\b'
  '\broadmap\b'
  '\bAs of: 20'
  'coming soon'
)
for p in "${patterns[@]}"; do
  hits=$(echo "$files" | xargs grep -lniE "$p" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "INTERNAL-PATTERN [$p]:"
    echo "$files" | xargs grep -niE "$p" 2>/dev/null | head -5
    fail=1
  fi
done

# 2. Maintainer-local blocklist (one term per line, case-insensitive)
if [ -f .publish-blocklist ]; then
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    case "$term" in \#*) continue;; esac
    hits=$(echo "$files" | xargs grep -lni -- "$term" 2>/dev/null || true)
    if [ -n "$hits" ]; then
      echo "BLOCKLISTED TERM found in: $hits"
      fail=1
    fi
  done < .publish-blocklist
else
  echo "note: no .publish-blocklist found (maintainer-local); pattern checks only"
fi

if [ "$fail" -eq 1 ]; then
  echo; echo "check-public: FAILED — scrub before pushing."
  exit 1
fi
echo "check-public: clean."
