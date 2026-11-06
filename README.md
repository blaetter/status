# status.blaetter.de

Public overview of whether the services of *Blätter für deutsche und internationale Politik* are up. The page is for a quick look only; alerting is handled by the monitoring services themselves.

Two GitHub Actions workflows keep page and data apart, so neither depends on the monitored infrastructure:

- **Update status** (`status.yml`, every 5 minutes): queries updown.io and healthchecks.io, writes `status.json` and force-pushes it as the only file of the branch `status-data`. The page loads it from `https://raw.githubusercontent.com/blaetter/status/status-data/status.json` (cached for up to 5 minutes).
- **Publish page** (`pages.yml`): publishes `index.html` and `assets/` with GitHub Pages, only when they change on `main` or when started by hand.

Data updates therefore need no Pages deployment. While the whole site was deployed every 5 minutes, GitHub Pages once stopped applying new deployments for hours, although each one reported success. The page itself is in German, as it is meant for the Blätter team and readers.

## What becomes public

Only what `config.json` lists:

- **Websites** (updown.io): display name, up or down, days until the TLS certificate expires. Checks not listed under `websites` are left out.
- **Servers and backups** (healthchecks.io): the label from `config.json`, the check state (`up`, `grace`, `down`, `new`, `paused`) and the time of the last ping.

Check names, measurements, error messages and ping URLs are never published. The build uses read-only API keys, which do not expose ping URLs at all.

## Files

| File | Purpose |
|---|---|
| `index.html`, `assets/` | the page; logo and fonts are served from this repository, nothing is loaded from third parties |
| `status.json`, `status.ok.json` | **sample data** for local preview (`"sample": true`): with faults, and with everything fine; the live data lives in the branch `status-data` |
| `config.json` | which checks appear, under which label and in which order |
| `scripts/build-status.sh` | builds `status.json` from both APIs (`curl`, `jq`) |
| `tests/run.sh` | tests the build script against the sample responses in `tests/fixtures/` |
| `.github/workflows/status.yml` | tests, builds `status.json`, force-pushes it to `status-data` |
| `.github/workflows/pages.yml` | publishes the page with GitHub Pages when `index.html` or `assets/` change |
| `.github/dependabot.yml` | monthly pull requests for new versions of the GitHub Actions used |

## Setup

1. Repository secrets (*Settings → Secrets and variables → Actions*), both **read-only** keys:
   - `UPDOWN_API_KEY`: updown.io → *Settings → API*
   - `HEALTHCHECKS_API_KEY`: healthchecks.io → project → *Settings → API Access*
2. *Settings → Pages*: source **GitHub Actions**.
3. Trigger: GitHub runs short schedules unreliably, so an external scheduler calls the workflow every 5 minutes:
   - Fine-grained personal access token, resource owner `blaetter`, only this repository, permission *Actions: Read and write*.
   - `POST https://api.github.com/repos/blaetter/status/actions/workflows/status.yml/dispatches` with the headers `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28` and the body `{"ref":"main"}`. A successful call returns `204`.
   - The token expires; renew it in time. If it stops working, the page shows its data as outdated after 20 minutes.
4. Custom domain: verify `blaetter.de` for the organization (*Settings → Pages → Verified domains*), set `status.blaetter.de` as custom domain of this repository, add a `CNAME` record `status` → `blaetter.github.io`, then enable *Enforce HTTPS*.

## Local preview

```bash
python3 -m http.server 8765
```

Open <http://localhost:8765>; on `localhost` the page reads the sample data from `status.json` instead of the live data. `?sample=ok` shows `status.ok.json` instead, where everything is fine.

With real data (keys only in your own shell, never commit them):

```bash
UPDOWN_API_KEY=… HEALTHCHECKS_API_KEY=… scripts/build-status.sh /tmp/status.json
```

## Adding checks

Create the check at updown.io or healthchecks.io, then add it to `config.json`: websites by host name under `websites`, healthchecks.io checks by their name with a `label` and a `group` (`servers` or `backups`). Labels are shown on the page, so keep them free of internal details.

## Maintenance

- **GitHub Actions**: Dependabot opens a pull request when a new version is released. Review and merge it.
- **Runner image**: the workflow uses `ubuntu-latest`, which GitHub keeps updated. The build only needs `bash`, `curl` and `jq`, so image changes are not expected to matter.
- **Access token** of the external scheduler: renew before it expires. The main trigger is this external call (`workflow_dispatch`), which GitHub does not disable for inactive repositories; the fallback schedule may be disabled after 60 days without activity.
- **Branch `status-data`**: written only by the workflow; it always holds a single commit. Do not commit to it by hand.

## Licenses

The fonts in `assets/fonts/` are Playfair Display (SIL Open Font License 1.1), Droid Sans and Droid Serif (both Apache License 2.0); see the license files next to them. The design follows the design system of the Blätter archive. The logo belongs to *Blätter für deutsche und internationale Politik*.
