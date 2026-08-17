---
run_id: 2026-07-23-deploy-roundcube-webmail-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-23T00:00:00Z
task_id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
inputs_read:
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-01-task-reader.md
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-02-landscape-reader.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
artifacts_changed: []
next_step_hint: solution-designer — design the Roundcube Compose stack, nginx vhost, certbot cert acquisition, and Cloudflare A record; MUST use the stalwart-mail_default Docker network (resolves both the DEFAULT_FORWARD_POLICY=DROP gap and the Stalwart auto-ban risk); decide on internal port 143 vs IMAPS 993 for IMAP connectivity; blast radius is MEDIUM so MUST emit NEEDS_APPROVAL.
---

## Summary

T-0122 is validated. All six checks pass. The task is well-formed, in-scope, not already done, non-conflicting, has sufficient landscape coverage for design, and the workflow-specific constraints (MEDIUM blast radius → `NEEDS_APPROVAL`) are satisfiable. Two design-guidance findings are forwarded: the `DEFAULT_FORWARD_POLICY=DROP` gap on `pro-data-tech-prod` is not a blocker (resolved by joining Roundcube to `stalwart-mail_default`), and port 143 vs 993 is flagged as a designer decision with a recommended approach.

## Details

### Validation results

1. **Well-formed: PASS** — T-0122 names a concrete, verifiable end state (7 enumerated acceptance criteria: Roundcube container live, nginx vhost at `webmail.aiqadam.org` with TLS, Cloudflare A record, login-to-read-compose flow confirmed, single-tenant IMAP host, named Docker volume, landscape files updated). Workflow is named (`infrastructure`). Blast radius (`MEDIUM`) and reversibility (`FULL`) are both declared.

2. **In-scope: PASS** — All work is confined to `pro-data-tech-prod` (new Docker Compose stack, nginx vhost addition, certbot cert) and the Cloudflare `aiqadam.org` zone (single A record `webmail.aiqadam.org → 95.46.211.224`). No other hosts, no Stalwart config changes, no other zones touched.

3. **Not already done: PASS** — No Roundcube container exists on `pro-data-tech-prod`. The `webmail.aiqadam.org` Cloudflare A record was explicitly deleted during T-0117 (2026-07-19) and is confirmed absent in `landscape/cloudflare.md`. No TLS cert for `webmail.aiqadam.org` exists under `/etc/letsencrypt/`. The target state is fully absent.

4. **No conflict with current state: PASS** — T-0112 (in-progress) is awaiting a manual GitHub Actions secrets paste — a human UI action on GitHub.com that does not touch nginx, Docker networks, or Cloudflare DNS on `pro-data-tech-prod`. No live concurrency conflict. No other in-progress tasks are modifying nginx vhosts, Docker Compose stacks, or Cloudflare zone records on this host.

5. **Discoverable scope: PASS** — All facts required for solution design are available in the landscape: Docker network topology (`stalwart-mail_default`, gateway `172.19.0.1`, subnet `172.19.0.0/16`), UFW rules (no port 143 rule; 993 present), nginx vhost pattern (certbot-managed HTTP-01, proxy_pass to localhost), certbot installation and cert paths, conflicting loopback port list (8080, 9998, 3115, 1080 in use — designer must pick a free port for Roundcube), Cloudflare zone ID and DNS state. One soft gap remains: the three user mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`) are not confirmed as provisioned in the landscape — executor must verify live before marking UAT complete, but this is not a design blocker.

6. **Workflow-specific rules respected: PASS** — Blast radius is MEDIUM. The `infrastructure` workflow requires `NEEDS_APPROVAL` for MEDIUM blast radius. The solution-designer can satisfy this: the design is fully plannable from landscape data, all rollback steps are clearly articulable (stop container, remove nginx vhost symlink, delete DNS record, revoke cert), and no irreversible mutations are involved.

---

### DEFAULT_FORWARD_POLICY=DROP finding — resolution

`DEFAULT_FORWARD_POLICY=DROP` is **not a hard blocker**. It becomes a blocker only if Roundcube is placed on a _separate_ isolated Docker bridge (`roundcube_default`), which would require cross-bridge packet forwarding to reach Stalwart — and this host's DROP policy (without an explicit FORWARD rule for inter-bridge traffic) would silently drop those packets.

**Recommended resolution:** Place Roundcube on the existing `stalwart-mail_default` network by adding an `external: true` network declaration in the Roundcube Compose file. This:
- Eliminates cross-bridge forwarding entirely (both containers on the same bridge).
- Automatically covers Roundcube under Stalwart's existing `AllowedIp` entries (`172.19.0.1` id `i9yv13qeaaqa` and `172.19.0.0/16` id `i9yv3mloabaa`), preventing the auto-ban incident class that occurred on 2026-07-20.
- Requires no UFW rule changes, no iptables additions, no `DEFAULT_FORWARD_POLICY` flip.

Alternative (less preferred): `network_mode: host` — Roundcube connects via `127.0.0.1`; loopback routing bypasses the forwarding issue. Downside: exposes the Roundcube HTTP port to `0.0.0.0` unless the designer explicitly binds to `127.0.0.1`, and loses Docker network isolation.

**Designer must document chosen approach explicitly.**

---

### Port 143 (internal) vs port 993 (IMAPS) — design decision for the designer

Both approaches are functional; the designer must choose one explicitly.

| Approach | How it works | Pros | Cons |
|---|---|---|---|
| **Shared network + internal port 143** | Roundcube joins `stalwart-mail_default`; connects to `stalwart-mail-server-1` container by hostname or container IP on port 143 (the container's internal IMAP port — not a published host port) | No TLS overhead on the Docker bridge; simpler config; cleaner semantics (TLS terminates at the public boundary, not inside a bridge) | Requires shared network approach (already recommended); relies on container hostname resolution within the bridge |
| **IMAPS on port 993** | Roundcube connects to `127.0.0.1:993` (the published host port) or `mail.aiqadam.org:993` (loopback via nginx/Stalwart's public-facing TLS) | Works from any network topology (no shared network required if using host loopback) | TLS overhead on every IMAP session within the Docker host; cert validation may require trusting Stalwart's internal ACME cert |

**Recommendation:** shared network + internal port 143 is cleaner. If the designer chooses IMAPS, they must address the TLS cert trust issue in the Roundcube config (`imap_conn_options` with `ssl_verify_peer: false` or adding the cert to the Roundcube container's trust store).

**Flag this decision explicitly in the solution-design handoff.**

---

### Blast radius MEDIUM → NEEDS_APPROVAL confirmation

Blast radius is MEDIUM: new Docker Compose project + nginx vhost addition + Let's Encrypt cert acquisition (brief nginx stop window ~5s) + Cloudflare DNS record on a live production host that currently serves `penpot.aiqadam.org`, `aiqadam.org`, and `mail.aiqadam.org`. The solution-designer **must** emit `verdict: NEEDS_APPROVAL`. Auto-approval (`PASS` from step 04) is not permitted for this task.

## Issues / risks

- **Unconfirmed mailbox provisioning:** `vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva` mailboxes are not recorded in the landscape as provisioned. Executor must verify live before declaring UAT complete.
- **Roundcube loopback port selection:** Ports 8080, 9998, 3115, 1080 are in use on `127.0.0.1`. Designer must choose a free port for the Roundcube container's HTTP binding (e.g., 8888 or 9090 — confirm against live `ss -tlnp` output at execution time).
- **Roundcube image pinning:** `roundcube/roundcubemail:latest` is a moving target. Executor should pin a specific stable version tag (e.g., `1.6.x-apache`) — confirm at execution time from Docker Hub tags.
- **Roundcube DES key:** No secret catalogued yet. Executor must generate via `openssl rand -base64 24` and add to `landscape/secrets-inventory.md` under a new `roundcube-des-key` entry (reference by name only; value in external storage).
- **`aigerim.kambetbayeva@aiqadam.org` temp password:** Visible in task file as `AiQ-temp-2026!`. Executor must not log or echo it. Note the password-change requirement in completion notes only.
- **nginx brief stop window:** ~5s during `certbot --nginx` initial cert issuance. Acceptable per step-01; must be called out in the approval-gate presentation.

## Open questions (optional)

- none
