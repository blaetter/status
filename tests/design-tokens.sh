#!/bin/bash
# Checks the colours of the page against the design tokens of the Blätter layouts:
# assets/css/tokens.css and tokens-dark.css must be verbatim copies of dist/ of the repository
# blaetter-design, index.html must not set colours of its own (no hex values outside comments), and
# assets/img/favicon.svg must be the palm in the muted grey of the tokens.
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

# The favicon is shown before the data has loaded, so it is the palm in the muted grey: an SVG
# favicon cannot read the tokens, so it must equal logo_palm.svg with that colour as first fill.
muted=$(sed -n 's/^  --blaetter-color-muted: \(#[0-9a-fA-F]*\);$/\1/p' assets/css/tokens.css | head -n 1)
expected=$(perl -pe 'BEGIN { $m = shift } if (!$done && s/fill="[^"]*"/fill="$m"/) { $done = 1 }' "$muted" assets/img/logo_palm.svg)
if [ -n "$muted" ] && [ "$expected" = "$(cat assets/img/favicon.svg)" ]; then
  echo "ok   assets/img/favicon.svg is the palm in --blaetter-color-muted"
else
  echo "FAIL assets/img/favicon.svg must be assets/img/logo_palm.svg with --blaetter-color-muted ($muted) as first fill"; fail=1
fi
exit $fail
