#!/usr/bin/env bash
# Pre-push check: fail if any tracked file contains internal references or
# blocklisted terms.
#
# The blocklist lives in the PRIVATE internal tooling repo, at config/publish-blocklist,
# for two reasons. Publishing a list of our customers would be the leak this script
# exists to prevent, and a gitignored copy per clone drifts: on 2026-10-08 two
# machines held different lists, so the same push got two different answers.
#
# Set ATLAS_TOOLS to override the location. A legacy .publish-blocklist here is
# still read if present. If NO list is found this FAILS rather than passing on the
# generic patterns alone: a check that cannot see its list has not checked.
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

# 2. Shared blocklist from the private repo (one term per line, case-insensitive)
blocklist=""
for candidate in \
  "${ATLAS_TOOLS:-}/config/publish-blocklist" \
  "$HOME/code/graphite/internal tooling/config/publish-blocklist" \
  "../internal tooling/config/publish-blocklist" \
  ".publish-blocklist"
do
  [ -n "$candidate" ] && [ -f "$candidate" ] && { blocklist="$candidate"; break; }
done

if [ -z "$blocklist" ]; then
  echo "check-public: CANNOT FIND THE BLOCKLIST."
  echo "  Looked for config/publish-blocklist in internal tooling (set ATLAS_TOOLS to override)."
  echo "  Clone the private internal tooling repo, or set ATLAS_TOOLS, then run this again."
  echo "  Refusing to pass on the generic patterns alone: those catch issue numbers and"
  echo "  roadmap words, not a customer's name."
  exit 2
fi

echo "blocklist: $blocklist ($(grep -vc '^#\|^$' "$blocklist") terms)"
while IFS= read -r term; do
  case "$term" in ''|\#*) continue;; esac
  hits=$(echo "$files" | xargs grep -lni -- "$term" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "BLOCKLISTED TERM [$term] found in: $hits"
    fail=1
  fi
done < "$blocklist"

if [ "$fail" -eq 1 ]; then
  echo; echo "check-public: FAILED — scrub before pushing."
  exit 1
fi
echo "check-public: clean."
