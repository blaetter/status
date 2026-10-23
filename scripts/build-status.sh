#!/bin/bash
# Erzeugt status.json für status.blaetter.de aus updown.io und healthchecks.io.
#
# Umgebung:
#   UPDOWN_API_KEY, HEALTHCHECKS_API_KEY   Lese-Schlüssel der beiden Dienste
#   UPDOWN_FILE, HEALTHCHECKS_FILE         statt der API eine Datei lesen (Tests)
#   CONFIG                                 Konfiguration (Standard: config.json)
#
# Aufruf: scripts/build-status.sh [Ausgabedatei]   (Standard: _site/status.json)
#
# Öffentlich landet nur, was in config.json steht: Name, läuft/läuft nicht,
# Resttage des Zertifikats, Zustand und Zeitpunkt der letzten Meldung.
set -euo pipefail

OUT=${1:-_site/status.json}
CONFIG=${CONFIG:-config.json}

fetch_updown() {
  if [ -n "${UPDOWN_FILE:-}" ]; then
    cat "$UPDOWN_FILE"
  else
    curl -fsS -m 20 --retry 3 -H "X-API-KEY: ${UPDOWN_API_KEY:?fehlt}" https://updown.io/api/checks
  fi
}

fetch_healthchecks() {
  if [ -n "${HEALTHCHECKS_FILE:-}" ]; then
    cat "$HEALTHCHECKS_FILE"
  else
    curl -fsS -m 20 --retry 3 -H "X-Api-Key: ${HEALTHCHECKS_API_KEY:?fehlt}" https://healthchecks.io/api/v3/checks/
  fi
}

updown=$(fetch_updown)
healthchecks=$(fetch_healthchecks)

mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson updown "$updown" \
  --argjson hc "$healthchecks" \
  --slurpfile cfg "$CONFIG" '
  # ISO-Zeit (auch mit Sekundenbruchteilen oder +00:00) in Unix-Sekunden
  def epoch: sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601;
  def host: capture("^https?://(?<h>[^/:]+)").h;

  $cfg[0] as $c
  | now as $now
  | ($updown
      | map(select(.enabled != false))
      | map({
          name: (if (.alias // "") != "" then .alias else (.url | host) end),
          host: (.url | host),
          up: (.down != true),
          ssl_days: (if .ssl.expires_at then (((.ssl.expires_at | epoch) - $now) / 86400 | floor) else null end)
        })) as $sites
  | {
      generated: ($now | todate),
      links: $c.links,
      websites: [
        $c.websites[] as $h
        | $sites[] | select(.host == $h)
        | {name, up, ssl_days}
      ],
      servers: [
        $c.healthchecks | to_entries[] | select(.value.group == "servers")
        | .key as $k | .value.label as $label
        | ([$hc.checks[] | select(.name == $k)] | first) as $chk
        | {name: $label, status: ($chk.status // null), last_ping: ($chk.last_ping // null)}
      ],
      backups: [
        $c.healthchecks | to_entries[] | select(.value.group == "backups")
        | .key as $k | .value.label as $label
        | ([$hc.checks[] | select(.name == $k)] | first) as $chk
        | {name: $label, status: ($chk.status // null), last_ping: ($chk.last_ping // null)}
      ]
    }
' > "$OUT.tmp"

# Ohne Websites stimmt etwas mit der API oder der Konfiguration nicht:
# dann lieber nichts veröffentlichen, die Seite zeigt den alten Stand als veraltet.
if [ "$(jq '.websites | length' "$OUT.tmp")" -eq 0 ]; then
  echo "Keine Websites gefunden – API-Antwort oder config.json prüfen" >&2
  rm -f "$OUT.tmp"
  exit 1
fi
mv "$OUT.tmp" "$OUT"
echo "geschrieben: $OUT"
