# status.blaetter.de

Öffentliche Übersicht, ob die Dienste der *Blätter* laufen. Die Seite dient nur dem Überblick; alarmiert wird über updown.io und healthchecks.io (Mail, ntfy).

Ein GitHub-Workflow fragt alle 5 Minuten die beiden Monitoring-Dienste ab, schreibt daraus `status.json` und veröffentlicht die Seite über GitHub Pages. Die Seite hängt damit nicht an den Hetzner-Servern.

## Was öffentlich wird

Nur, was in `config.json` eingetragen ist:

- **Websites** (updown.io): Name, läuft/läuft nicht, Resttage des Zertifikats. Checks, die nicht in `websites` stehen, erscheinen nicht.
- **Server und Sicherungen** (healthchecks.io): der Anzeigename aus `config.json`, der Zustand (`up`, `grace`, `down`, `new`, `paused`) und der Zeitpunkt der letzten Meldung. Interne Check-Namen, Messwerte, Fehlertexte und Ping-URLs gehen nicht auf die Seite.

## Dateien

| Datei | Zweck |
|---|---|
| `index.html`, `assets/` | die Seite; Logo und Schriften aus dem Blätter-Theme, nichts wird von Dritten geladen |
| `status.json` | **Beispieldaten** für die lokale Vorschau (`"sample": true`); online wird sie vom Workflow ersetzt |
| `config.json` | welche Checks unter welchem Namen erscheinen |
| `scripts/build-status.sh` | erzeugt `status.json` aus beiden APIs (`curl`, `jq`) |
| `tests/run.sh` | prüft das Skript mit Beispielantworten aus `tests/fixtures/` |
| `.github/workflows/status.yml` | Zeitplan, Test, Erzeugen, Veröffentlichen; montags ein Lebenszeichen-Commit |

## Einrichtung

1. Repository `blaetter/status` anlegen (öffentlich) und diesen Ordner pushen.
2. Lese-Schlüssel als Repository-Secrets hinterlegen (*Settings → Secrets and variables → Actions*):
   - `UPDOWN_API_KEY`: updown.io → *Settings → API*, der **read-only** Schlüssel
   - `HEALTHCHECKS_API_KEY`: healthchecks.io → Projekt → *Settings → API Access*, der **read-only** Schlüssel
3. *Settings → Pages*: Quelle **GitHub Actions**.
4. *Settings → Actions → General → Workflow permissions*: „Read and write permissions“ ist nicht nötig; der Lebenszeichen-Job bekommt sein Schreibrecht im Workflow selbst.
5. Eigene Domain: in der Organisation *Settings → Pages → Verified domains* `blaetter.de` verifizieren (schützt vor Übernahme der Subdomain), dann im Repo *Settings → Pages → Custom domain* `status.blaetter.de` eintragen und „Enforce HTTPS“ setzen.
6. DNS: `status.blaetter.de` als CNAME auf `blaetter.github.io`.

## Lokal ansehen

```bash
python3 -m http.server 8765
```

Dann <http://localhost:8765> öffnen. Angezeigt werden die Beispieldaten aus `status.json`.

Mit echten Daten (Schlüssel nur in der eigenen Shell, nicht committen):

```bash
UPDOWN_API_KEY=… HEALTHCHECKS_API_KEY=… scripts/build-status.sh /tmp/status.json
```

## Neue Checks aufnehmen

Bei updown.io oder healthchecks.io anlegen, dann in `config.json` eintragen: Websites mit ihrem Hostnamen unter `websites`, Checks von healthchecks.io unter ihrem Namen mit `label` und `group` (`servers` oder `backups`).
