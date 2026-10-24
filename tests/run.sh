#!/bin/bash
# Tests scripts/build-status.sh against sample responses of both APIs.
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)/status.json
UPDOWN_FILE=tests/fixtures/updown.json HEALTHCHECKS_FILE=tests/fixtures/healthchecks.json \
  scripts/build-status.sh "$out" >/dev/null

fail=0
check() {  # description, jq expression that must yield true
  if [ "$(jq "$2" "$out")" = "true" ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
check "order follows config.json, unknown and disabled sites are left out" \
  '[.websites[].name] == ["www.blaetter.de","pepgen.blaetter.de","stats.blaetter.de","insel-der-vernunft.de"]'
check "a down site is reported as down" '(.websites[] | select(.name=="stats.blaetter.de") | .up) == false'
check "certificate days are numbers" '(.websites[] | select(.name=="www.blaetter.de") | .ssl_days | type) == "number"'
check "fractional seconds in dates are parsed" '(.websites[] | select(.name=="pepgen.blaetter.de") | .ssl_days | type) == "number"'
check "missing SSL data yields null" '(.websites[] | select(.name=="insel-der-vernunft.de") | .ssl_days) == null'
check "no URLs or tokens are published" '[.. | objects | keys[]] | any(. == "url" or . == "token" or . == "host") | not'
check "servers use display names and states" '.servers == [
  {"name":"Live-Server","status":"up","last_ping":"2026-10-24T08:12:30+00:00"},
  {"name":"Statistik-Server","status":"down","last_ping":"2026-10-24T07:50:00+00:00"},
  {"name":"Stage-Server","status":null,"last_ping":null}]'
check "backups" '[.backups[].name] == ["Datenbank-Sicherung","Dateisicherung"] and .backups[1].status == "new"'
check "checks missing from config.json stay hidden" '[.. | strings] | any(. == "secret-check") | not'
check "timestamp and links" '(.generated | test("Z$")) and (.links.updown | startswith("https://"))'

echo '[]' > "${out%.json}-empty.json"
if UPDOWN_FILE="${out%.json}-empty.json" HEALTHCHECKS_FILE=tests/fixtures/healthchecks.json \
   scripts/build-status.sh "${out%.json}-x.json" 2>/dev/null; then
  echo "FAIL an empty updown response aborts"; fail=1
else
  echo "ok   an empty updown response aborts"
fi
exit $fail
