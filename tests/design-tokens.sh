#!/bin/bash
# Checks the colours of the page against the design tokens of the Blätter layouts:
# assets/css/tokens.css and tokens-dark.css must be verbatim copies of dist/ of the repository
# blaetter-design, and index.html must not set colours of its own (no hex values outside comments).
#   tests/design-tokens.sh [path to a blaetter-design checkout, default ../blaetter-design]
set -euo pipefail
cd "$(dirname "$0")/.."
design=${1:-../blaetter-design}

fail=0
for f in tokens.css tokens-dark.css; do
  if [ ! -f "$design/dist/$f" ]; then
    echo "FAIL $design/dist/$f not found"; fail=1
  elif cmp -s "$design/dist/$f" "assets/css/$f"; then
    echo "ok   assets/css/$f matches blaetter-design"
  else
    echo "FAIL assets/css/$f differs from blaetter-design: cp $design/dist/$f assets/css/"; fail=1
  fi
done

hex=$(perl -0pe 's#/\*.*?\*/##gs' index.html | grep -noE '#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b' || true)
if [ -z "$hex" ]; then
  echo "ok   index.html uses only the tokens"
else
  echo "FAIL index.html sets colours of its own (use the --blaetter-* tokens):"; echo "$hex"; fail=1
fi
exit $fail
