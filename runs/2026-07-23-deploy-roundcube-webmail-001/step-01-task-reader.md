---
run_id: 2026-07-23-deploy-roundcube-webmail-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-23T00:00:00Z
task_id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
inputs_read:
  - tasks/T-0122-deploy-roundcube-webmail-pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-reader — read pro-data-tech-prod host landscape, services.md, cloudflare.md, domains.md; confirm Docker network topology, UFW rules for IMAP/SMTP ports, and absence of conflicting DNS/vhost entries.
---

## Summary

T-0122 is a valid `in-progress` task requesting the deployment of Roundcube webmail as a Docker container on `pro-data-tech-prod`, fronted by a new nginx vhost (`webmail.aiqadam.org`) with TLS and a Cloudflare DNS A record. Blast radius is MEDIUM (new container + vhost + DNS + cert on a live production host); reversibility is FULL. Workflow is `infrastructure`. Task is clear and ready for downstream processing.

## Details

- **Workflow:** infrastructure
- **Target scope:**
  - `landscape/hosts/pro-data-tech-prod.md`
  - `landscape/services.md`
  - `landscape/cloudflare.md`
  - `landscape/domains.md`

### Why (verbatim from task)

> Stalwart provides IMAP/JMAP/SMTP services but no user-facing webmail interface. Users with `@aiqadam.org` mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`, and future accounts) currently have no way to read or send email via a browser. The admin UI at `https://mail.aiqadam.org/` is operator-only and loopback-restricted (T-0121). Roundcube is the established standard for self-hosted webmail and works directly over IMAP/SMTP — no changes to Stalwart's configuration are needed.

### Acceptance criteria (from "What done looks like")

1. Roundcube deployed as a Docker container on `pro-data-tech-prod`, connecting to Stalwart IMAP (port 993 or 143) and SMTP submission (port 587) via Docker network or bridge.
2. nginx vhost `webmail.aiqadam.org`: HTTPS + Let's Encrypt cert via certbot (reuse existing renewal infrastructure); proxy to Roundcube container; no access restrictions.
3. Cloudflare DNS: `webmail.aiqadam.org` A record → `95.46.211.224`, proxied, consistent with other records on this host.
4. `@aiqadam.org` users can log in at `https://webmail.aiqadam.org/` and read, compose, reply to, and delete mail.
5. Roundcube config: `mail.aiqadam.org` as default host; not user-configurable (single-tenant).
6. Session/temp data on a named Docker volume (survives container restarts).
7. Landscape files updated: `pro-data-tech-prod.md`, `services.md`, `cloudflare.md`, `domains.md`.

### Key design constraints from task notes

- Prefer SQLite for Roundcube's database (avoid cross-stack PostgreSQL dependency).
- Roundcube image: `roundcube/roundcubemail:latest` or a pinned stable tag — confirm at execution time.
- No Stalwart configuration changes required.
- nginx reload is non-disruptive; TLS cert acquisition may involve a brief nginx restart window.
- `aigerim.kambetbayeva@aiqadam.org` was created with temp password `AiQ-temp-2026!` — owner must change it; out of scope for this task but must be noted in completion notes.

### Blast radius and reversibility

- **Blast radius:** MEDIUM — new container + nginx vhost + DNS record + TLS cert on the live `pro-data-tech-prod` host alongside the existing `stalwart-mail` and Penpot stacks.
- **Reversibility:** FULL — stop container, remove vhost config, delete DNS record; no destructive changes to existing services.

### Constraints stated by user

- Deploy on `pro-data-tech-prod` only.
- Public-facing endpoint; no access restrictions on the vhost.
- Reuse existing Let's Encrypt / certbot renewal infrastructure.
- Single-tenant: `mail.aiqadam.org` as hard-coded default IMAP/SMTP host.

### Information gaps for downstream steps

- **Docker network topology:** Need to confirm how Roundcube container should reach Stalwart (shared Docker network name, `host.docker.internal`, or bridge IP). Landscape reader should surface this.
- **UFW rules:** Task notes that ports 143/993/587 should already be allowed from the Docker bridge — must be confirmed rather than assumed.
- **Pinned image tag:** Confirm the latest stable Roundcube tag at execution time (not just `latest`).
- **Existing DNS:** Confirm no `webmail.aiqadam.org` record already exists in Cloudflare before creating one.
- **Existing certbot certs:** Confirm certbot is installed and operational on `pro-data-tech-prod` (it was set up for `penpot.aiqadam.org` and `mail.aiqadam.org` — confirm renewal config path).
- **Port availability:** Confirm the local port chosen for the Roundcube container does not conflict with existing services.

## Issues / risks

- nginx restart during TLS cert issuance (brief ~5s downtime window on `pro-data-tech-prod`) — acceptable, must be noted in approval step.
- Roundcube `latest` tag is a moving target; executor should pin a specific version tag for reproducibility.
- `aigerim.kambetbayeva@aiqadam.org` temp password in the clear in the task file — executor must not log or echo it; note the password-change requirement in completion notes only.

## Open questions (optional)

- none
