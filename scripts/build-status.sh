#!/bin/bash
# Builds status.json from the updown.io and healthchecks.io APIs.
#
# Environment:
#   UPDOWN_API_KEY, HEALTHCHECKS_API_KEY   read-only API keys of both services
#   UPDOWN_FILE, HEALTHCHECKS_FILE         read a file instead of calling the API (tests)
#   CONFIG                                 configuration file (default: config.json)
#
# Usage: scripts/build-status.sh [output file]   (default: _site/status.json)
#
# Only what config.json lists ends up public: display name, up/down,
# days until certificate expiry, check state and time of the last ping.
set -euo pipefail

OUT=${1:-_site/status.json}
CONFIG=${CONFIG:-config.json}

fetch_updown() {
  if [ -n "${UPDOWN_FILE:-}" ]; then
    cat "$UPDOWN_FILE"
  else
    curl -fsS -m 20 --retry 3 -H "X-API-KEY: ${UPDOWN_API_KEY:?missing}" https://updown.io/api/checks
  fi
}

fetch_healthchecks() {
  if [ -n "${HEALTHCHECKS_FILE:-}" ]; then
    cat "$HEALTHCHECKS_FILE"
  else
    curl -fsS -m 20 --retry 3 -H "X-Api-Key: ${HEALTHCHECKS_API_KEY:?missing}" https://healthchecks.io/api/v3/checks/
  fi
}

updown=$(fetch_updown)
healthchecks=$(fetch_healthchecks)

mkdir -p "$(dirname "$OUT")"
jq -n \
  --argjson updown "$updown" \
  --argjson hc "$healthchecks" \
  --slurpfile cfg "$CONFIG" '
  # ISO timestamp (also with fractional seconds or +00:00) to Unix seconds
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

# No websites means the API answer or config.json is wrong: publish nothing,
# so the page keeps the previous state and marks it as outdated.
if [ "$(jq '.websites | length' "$OUT.tmp")" -eq 0 ]; then
  echo "No websites found - check the API response or config.json" >&2
  rm -f "$OUT.tmp"
  exit 1
fi
mv "$OUT.tmp" "$OUT"
echo "written: $OUT"
