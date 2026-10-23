#!/bin/bash
# Prüft scripts/build-status.sh mit Beispielantworten der beiden APIs.
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)/status.json
UPDOWN_FILE=tests/fixtures/updown.json HEALTHCHECKS_FILE=tests/fixtures/healthchecks.json \
  scripts/build-status.sh "$out" >/dev/null

fail=0
check() {  # Beschreibung, jq-Ausdruck, der true ergeben muss
  if [ "$(jq "$2" "$out")" = "true" ]; then echo "ok   $1"; else echo "FEHL $1"; fail=1; fi
}
check "Reihenfolge wie config.json, unbekannte und deaktivierte Sites fehlen" \
  '[.websites[].name] == ["www.blaetter.de","pepgen.blaetter.de","stats.blaetter.de","insel-der-vernunft.de"]'
check "stats ist down" '(.websites[] | select(.name=="stats.blaetter.de") | .up) == false'
check "Zertifikatstage sind Zahlen" '(.websites[] | select(.name=="www.blaetter.de") | .ssl_days | type) == "number"'
check "Sekundenbruchteile im Datum gehen" '(.websites[] | select(.name=="pepgen.blaetter.de") | .ssl_days | type) == "number"'
check "fehlendes SSL ergibt null" '(.websites[] | select(.name=="insel-der-vernunft.de") | .ssl_days) == null'
check "keine URLs oder Tokens öffentlich" '[.. | objects | keys[]] | any(. == "url" or . == "token" or . == "host") | not'
check "Server mit Klarnamen und Zustand" '.servers == [
  {"name":"Live-Server","status":"up","last_ping":"2026-10-24T08:12:30+00:00"},
  {"name":"Statistik-Server","status":"down","last_ping":"2026-10-24T07:50:00+00:00"},
  {"name":"Stage-Server","status":null,"last_ping":null}]'
check "Sicherungen" '[.backups[].name] == ["Datenbank-Sicherung","Borg-Sicherung"] and .backups[1].status == "new"'
check "nicht konfigurierte Checks erscheinen nicht" '[.. | strings] | any(. == "geheimer-check") | not'
check "Zeitstempel und Links" '(.generated | test("Z$")) and (.links.updown | startswith("https://"))'

echo '[]' > "${out%.json}-leer.json"
if UPDOWN_FILE="${out%.json}-leer.json" HEALTHCHECKS_FILE=tests/fixtures/healthchecks.json \
   scripts/build-status.sh "${out%.json}-x.json" 2>/dev/null; then
  echo "FEHL leere updown-Antwort bricht ab"; fail=1
else
  echo "ok   leere updown-Antwort bricht ab"
fi
exit $fail
