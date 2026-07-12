---
run_id: 2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001
step: "02"
agent: landscape-reader
verdict: PASS
created: 2026-07-11T00:00:00Z
task_id: T-0109-nginx-letsencrypt-penpot-ai-qadam-org
inputs_read:
  - runs/2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/domains.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: task-validator (step 03) — validate that all preconditions hold before design
---

## Summary

Host `pro-data-tech-prod` (95.46.211.224, Ubuntu 26.04) is fully hardened and ready for T-0109. UFW is active with `deny-incoming` default and explicit `ALLOW IN` rules for 22/tcp, 80/tcp, and 443/tcp (v4+v6). Penpot 2.16 is deployed as a 7-container Docker Compose stack under project `penpot`; the frontend is bound to `0.0.0.0:9001→8080/tcp` and confirmed returning HTTP 200 on `localhost:9001`. `PENPOT_PUBLIC_URI` is already set to `https://penpot.aiqadam.org`. The DNS A record `penpot.aiqadam.org → 95.46.211.224` is live in Cloudflare (CF Record ID `fde29338774531998ae38c41cd2e28ad`), not proxied — correct for HTTP-01 cert issuance. nginx is not installed; no nginx configuration exists on the host. The preconditions stated in step 01 are confirmed by the landscape.

## Details

### Relevant facts (sourced from landscape)

- Host IP: `95.46.211.224`, hostname `drkkrgm-prod-instance`, Ubuntu 26.04, KVM — _source: `landscape/hosts/pro-data-tech-prod.md`_
- SSH access: `tvolodi@95.46.211.224` (primary), `root@95.46.211.224` (break-glass). Management keys at `C:\Users\tvolo\.ssh\ai-dala-infra` and `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **UFW: ACTIVE** (T-0103, 2026-07-11). `ufw default deny incoming`. Rules: `22/tcp ALLOW IN`, `80/tcp ALLOW IN`, `443/tcp ALLOW IN` (v4+v6). Port 80 is open — HTTP-01 challenge will succeed at the UFW layer. Docker coexistence block in `/etc/ufw/after.rules` (T-0106). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Penpot on localhost:9001**: `penpot-penpot-frontend-1` container (`penpotapp/frontend:2.16`) bound `0.0.0.0:9001→8080/tcp`, HTTP 200 confirmed. `PENPOT_PUBLIC_URI=https://penpot.aiqadam.org`. Env file at `/opt/penpot/.env` (mode 600). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **Port 9001 externally reachable today**: Docker bypasses UFW iptables chains; 9001 is currently accessible from the internet until nginx is added. Not a blocker for T-0109 but nginx must proxy and bind publicly to 80/443 only. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **nginx: not installed**. `nginx + HTTPS pending (T-0109)` is explicit in the host landscape note. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **DNS: `penpot.aiqadam.org → 95.46.211.224`**. Cloudflare zone `bec8854d698d56ff17cf917367634100`. CF Record ID `fde29338774531998ae38c41cd2e28ad`. Confirmed via T-0107. Not proxied (required for HTTP-01). — _source: `landscape/domains.md`_
- **Provider-level firewall**: pro-data.tech does not have a documented control-plane firewall (unlike Hetzner). Host relies solely on UFW for perimeter control. Executor should confirm port 80 is reachable externally before issuing certbot. — _source: `landscape/hosts/pro-data-tech-prod.md`_

### Stale or stub files encountered

None. Both landscape files carry `last_verified: 2026-07-11` (today).

### Gaps requiring live discovery

- Whether `nginx` or `certbot` / `python3-certbot-nginx` are partially installed from any prior attempt (not recorded in landscape).
- Contents of `/etc/nginx/sites-available/` and `/etc/nginx/sites-enabled/` — relevant only if nginx is found to be partially installed.
- Whether a default nginx site (`default`) exists that would conflict on port 80 during HTTP-01 challenge.
- External reachability of port 80 at the provider network layer (pro-data.tech control-plane firewall, if any) — must be confirmed by executor before running certbot.

## Issues / risks

- Port 9001 is currently bound to `0.0.0.0` via Docker (bypasses UFW) and is externally reachable. This is a pre-existing exposure, not introduced by T-0109. Post-T-0109 the operator should add a UFW rule or Docker network restriction to block direct external access to 9001, so all traffic routes through nginx. This is a follow-on hardening item, not a blocker for T-0109.
- If Cloudflare is switched to proxied mode after cert issuance, an SSL mode mismatch (Full vs Full-strict) could cause redirect loops. Cloudflare must be set to "Full (strict)" if proxy is ever enabled. User decision post-T-0109.
- 12 pending package upgrades on the host (security gap #5, HIGH). Not a blocker for T-0109 but should be tracked.
