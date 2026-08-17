---
run_id: 2026-07-23-deploy-roundcube-webmail-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-23T00:00:00Z
task_id: T-0122-deploy-roundcube-webmail-pro-data-tech-prod
inputs_read:
  - runs/2026-07-23-deploy-roundcube-webmail-001/step-01-task-reader.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/secrets-inventory.md
artifacts_changed: []
next_step_hint: solution-designer — design the Roundcube Docker Compose stack, nginx vhost for webmail.aiqadam.org, certbot cert acquisition, and Cloudflare A record; pay special attention to Docker networking approach (stalwart-mail_default vs host networking) given DEFAULT_FORWARD_POLICY=DROP on this host, and the Stalwart auto-ban risk from Roundcube's container IP.
---

## Summary

`pro-data-tech-prod` (95.46.211.224) is a production-hardened Ubuntu 26.04 KVM host running three live Docker Compose stacks (`penpot`, `aiqadam-prod`, `stalwart-mail`) behind nginx 1.28.3 with certbot-managed TLS. Stalwart (`stalwart-mail_default` bridge, gateway `172.19.0.1`/16, container IP ~`172.19.0.2`) publishes SMTP/SMTPS/submission/IMAPS (25/465/587/993) to `0.0.0.0` and has UFW ALLOW IN rules for all four. Port 143 (plain IMAP) is **not** published by Stalwart and is **not** in UFW — Roundcube must connect on 993 (IMAPS). The host's UFW `DEFAULT_FORWARD_POLICY="DROP"` (not ACCEPT as on the QA host) creates a cross-network Docker routing risk unless Roundcube is placed on the `stalwart-mail_default` network or runs with `network_mode: host`. The `webmail.aiqadam.org` Cloudflare A record was explicitly deleted during T-0117 (no current record exists). Disk space is ample (336 GB free). No Roundcube secrets are catalogued yet. The three expected user mailboxes (`vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`) are not documented in the landscape as provisioned and must be confirmed live.

## Details

### Relevant facts (sourced from landscape)

#### Docker stacks on pro-data-tech-prod

| Project | Compose dir | Containers | Network mode |
|---|---|---|---|
| `penpot` | `/opt/penpot/` | 7 (penpot-frontend, -backend, -exporter, -mcp, -postgres, -valkey, -mailcatch) | Docker bridge (`penpot_default`), except frontend binds `0.0.0.0:9001` |
| `aiqadam-prod` | `/opt/apps/aiqadam-prod/deploy/` | 4 (postgres, oidc-stub, api, web-next) | `network_mode: host` throughout |
| `stalwart-mail` | `/opt/stalwart-mail/` | 1 (`stalwart-mail-server-1`, `stalwartlabs/stalwart:v0.16`, v0.16.13) | Docker bridge (`stalwart-mail_default`) |

— _source: `landscape/hosts/pro-data-tech-prod.md`_, _source: `landscape/services.md`_

#### Stalwart Docker network and port exposure

- **Network:** `stalwart-mail_default` (Docker Compose bridge); gateway `172.19.0.1`; subnet `172.19.0.0/16`; container bridge IP `172.19.0.2` (expected; may change on recreation). — _source: `landscape/hosts/pro-data-tech-prod.md`_ (AllowedIp and JMAP runbook sections)
- **Published ports (to `0.0.0.0`):** 25 (SMTP), 465 (SMTPS), 587 (submission `NetworkListener id i9njnzefksaa`), 993 (IMAPS). Admin/JMAP UI on `127.0.0.1:8080` (loopback only). — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Stalwart Mail section)
- **Port 143 (plain IMAP): NOT published to the host and NOT listed in UFW.** Only 993 is confirmed as the IMAP endpoint. Roundcube must use IMAPS (993). — _source: `landscape/hosts/pro-data-tech-prod.md`_
- Stalwart's `AllowedIp` entries `172.19.0.1` (id `i9yv13qeaaqa`) and `172.19.0.0/16` (id `i9yv3mloabaa`) are permanent — any container on the `stalwart-mail_default` network is already whitelisted against Stalwart's auto-ban. A container on a **different** Docker network (different subnet) would NOT be covered and could trigger an auto-ban incident. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (AllowedIp configuration section)

#### UFW rules on pro-data-tech-prod

| Port/Proto | Rule | Added |
|---|---|---|
| 22/tcp | ALLOW IN (v4+v6) | T-0103, 2026-07-11 |
| 80/tcp | ALLOW IN (v4+v6) | T-0103, 2026-07-11 |
| 443/tcp | ALLOW IN (v4+v6) | T-0103, 2026-07-11 |
| 25/tcp | ALLOW IN (v4+v6) | T-0117, 2026-07-19 |
| 465/tcp | ALLOW IN (v4+v6) | T-0117, 2026-07-19 |
| 587/tcp | ALLOW IN (v4+v6) | T-0117, 2026-07-19 |
| 993/tcp | ALLOW IN (v4+v6) | T-0117, 2026-07-19 |
| 143/tcp | **not present** | — |

- **`DEFAULT_FORWARD_POLICY="DROP"`** (not ACCEPT). The after.rules DOCKER-USER coexistence block (`-A DOCKER-USER -i eth0 -j RETURN` + MASQUERADE for 172.16.0.0/12) covers eth0-inbound routing but **does not explicitly permit forwarding between two different Docker bridge interfaces**. Docker adds its own iptables FORWARD rules for containers on the same bridge. Cross-bridge forwarding (Roundcube on `roundcube_default` → Stalwart on `stalwart-mail_default`) would be affected by the DROP policy. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Network section), _source: `landscape/services.md`_
- The pro-data-tech-qa host had the same DROP gap and resolved it by explicitly changing `DEFAULT_FORWARD_POLICY` to `ACCEPT` (T-0090). That change has NOT been made on pro-data-tech-prod. — _source: `landscape/services.md`_

#### nginx setup (existing vhost pattern)

- **nginx version:** 1.28.3 (`nginx 1.28.3-2ubuntu1.6`), `active` and `enabled`. — _source: `landscape/services.md`_
- **Vhost file pattern:** `/etc/nginx/sites-available/<domain>` (symlinked to `/etc/nginx/sites-enabled/<domain>`)
- **Config pattern:** HTTP→HTTPS redirect on port 80 (certbot-managed via `location /.well-known/acme-challenge`); HTTPS on port 443; `proxy_pass` to a localhost port; `proxy_set_header Host/X-Forwarded-For/X-Real-IP` present on the Stalwart vhost (can be reused).
  - `penpot.aiqadam.org` → `http://localhost:9001/` with `client_max_body_size 367001600`, WebSocket + SSE proxying
  - `aiqadam.org` → `http://127.0.0.1:3115/`
  - `mail.aiqadam.org` → `http://127.0.0.1:8080` (with `allow 127.0.0.1; deny all;` restriction — NOT a model for webmail which is public)
- **certbot:** version 4.0.0 + python3-certbot-nginx 4.0.0 installed; `certbot.timer` active and enabled. HTTP-01 challenge. — _source: `landscape/services.md`_ (certbot section)
- **Existing cert paths:**
  - `/etc/letsencrypt/live/penpot.aiqadam.org/` (ECDSA, expires 2026-10-09)
  - `/etc/letsencrypt/live/aiqadam.org/` (ECDSA, expires 2026-10-11)
  - `/etc/letsencrypt/live/mail.aiqadam.org/` (ECDSA, expires 2026-10-17)
- **New cert target:** `/etc/letsencrypt/live/webmail.aiqadam.org/` (to be obtained; renewal config `/etc/letsencrypt/renewal/webmail.aiqadam.org.conf`) — _source: `landscape/domains.md`_

#### Loopback ports currently bound (nginx proxy targets / conflicts to avoid)

| Port | Listener | Notes |
|---|---|---|
| 127.0.0.1:1080 | penpot-mailcatch | |
| 127.0.0.1:8080 | stalwart admin UI | **cannot be reused for Roundcube** |
| 127.0.0.1:9998 | aiqadam-prod-oidc-stub | |
| 127.0.0.1:3115 | aiqadam-prod-api | |
| 0.0.0.0:9001 | penpot-frontend (Docker iptables) | |
| 0.0.0.0:3114 | aiqadam-prod-postgres (host mode) | |

— _source: `landscape/hosts/pro-data-tech-prod.md`_ (Network / TCP listeners section)

#### Cloudflare zone (aiqadam.org, zone ID `bec8854d698d56ff17cf917367634100`)

- **`webmail.aiqadam.org` A record: DOES NOT EXIST.** It was explicitly deleted during T-0117 (2026-07-19) as a stale record pointing at the dead third-party host. A new one must be created. — _source: `landscape/cloudflare.md`_ (Deleted stale records table)
- **Pattern for this repo's A records:** Type A, value `95.46.211.224`, `proxied: false`, TTL 1 (auto) — consistent across `penpot.aiqadam.org` (id `fde29338774531998ae38c41cd2e28ad`) and `mail.aiqadam.org`. — _source: `landscape/cloudflare.md`_
- **Zone is shared infrastructure** — treat as shared-resource surgery (freshness-check before each mutation). — _source: `landscape/cloudflare.md`_
- **Wildcard `*.aiqadam.org` A record** (id `c13cf65703dd761c6f54437554b84f24`) still points at `212.20.151.29` (proxied). Adding an explicit `webmail.aiqadam.org` A record takes precedence over the wildcard for that exact name per DNS resolution rules. — _source: `landscape/cloudflare.md`_

#### domains.md existing TLS certs and subdomain pattern

- `webmail.aiqadam.org` is NOT listed in `domains.md` (the old record is gone; no new entry exists). — _source: `landscape/domains.md`_
- New entry will follow the established pattern: A record in the subdomains table + certbot-managed ECDSA cert entry in the TLS certs table.

#### Disk space and resources

- **Disk:** 339 GB root disk, 3.1 GB used (1%), **336 GB available** — no constraint. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Hardware & OS section)
- **RAM:** ~31 GiB total, ~972 MiB used at last verification — ample headroom. — _source: `landscape/hosts/pro-data-tech-prod.md`_
- **vCPU:** 16. No resource constraints noted.

#### Secrets inventory — Roundcube

- **No Roundcube-related secrets are catalogued.** The existing catalogue covers Cloudflare, Penpot, AiQadam QA/Prod, and Stalwart mailbox credentials. — _source: `landscape/secrets-inventory.md`_
- New secrets to be created: at minimum a Roundcube session/DES encryption key (randomly generated). SQLite-preferred (per task constraints) eliminates the need for a separate DB password entry.

#### Deployment quirks and gotchas specific to this host

1. **Stalwart auto-ban risk (HIGH):** Roundcube will make continuous IMAP connections to Stalwart. The existing `AllowedIp` entries cover `172.19.0.1` and `172.19.0.0/16` — i.e., containers on the `stalwart-mail_default` network are safe. A Roundcube container on a _different_ Docker network (different bridge subnet, e.g. `172.20.x.x`) would NOT be covered and could trigger the same permanent-ban incident that occurred on 2026-07-20 (blocking all mail access). The solution design must either: (a) put Roundcube on the `stalwart-mail_default` network, (b) use `network_mode: host` so Roundcube connects via the host loopback, or (c) add a new `AllowedIp` entry for Roundcube's subnet before starting the container. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Stalwart CLI gotchas / auto-ban section)
2. **DEFAULT_FORWARD_POLICY=DROP (MEDIUM):** Unlike the QA host (which had DROP changed to ACCEPT for Docker), this host retains DROP. A Roundcube container on its own isolated Docker bridge would NOT be able to reach Stalwart's published ports via cross-bridge routing under this policy. The cleanest mitigations are: (a) share the `stalwart-mail_default` network so no forwarding between bridges is required, or (b) use `network_mode: host`. Avoid creating a new isolated network for Roundcube without addressing this. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Network section) and _source: `landscape/services.md`_
3. **Port 143 not published by Stalwart:** Only 993 (IMAPS) is confirmed as a published IMAP endpoint. Roundcube's `config.inc.php` must be hardcoded to `ssl://mail.aiqadam.org:993` (or `ssl://127.0.0.1:993` depending on networking choice), not port 143. — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Stalwart Mail / Ports published)
4. **Roundcube session encryption key generation:** Required to be a randomly-generated secret at deploy time. Use `openssl rand -base64 24` or similar. Store under a new `roundcube-des-key` entry in `secrets-inventory.md`.
5. **nginx restart window:** Certbot HTTP-01 requires a brief nginx stop/start for the initial cert acquisition (or reload only if using certbot's nginx plugin with the webroot method). Approximately 5s downtime on `pro-data-tech-prod` during cert issuance — acceptable per step-01. — _source: `runs/2026-07-23-deploy-roundcube-webmail-001/step-01-task-reader.md`_
6. **Port 9001 (Penpot) bound to 0.0.0.0 via Docker iptables bypass:** Not a conflict for Roundcube's HTTP port, but a reminder that Docker containers can expose ports to the public internet bypassing UFW. Roundcube's HTTP port should be bound to `127.0.0.1` only (nginx is the public-facing endpoint) — this is the same pattern used by `aiqadam-prod-api-1` (127.0.0.1:3115) and `aiqadam-prod-oidc-stub-1` (127.0.0.1:9998). — _source: `landscape/hosts/pro-data-tech-prod.md`_ (Network section)

### Stale or stub files encountered

All landscape files are recent:
- `landscape/hosts/pro-data-tech-prod.md` — `last_verified: 2026-07-21`, status `hardened` — 2 days old, within threshold.
- `landscape/services.md` — `last_verified: 2026-07-21` — 2 days old, within threshold.
- `landscape/cloudflare.md` — `last_verified: 2026-07-19` — 4 days old, within threshold.
- `landscape/domains.md` — `last_verified: 2026-07-19` — 4 days old, within threshold.
- `landscape/secrets-inventory.md` — no frontmatter `last_verified` date; contents cross-reference T-0121 (2026-07-21) as most recent entry — consistent with other files, no concern.

None flagged as stale (> 30 days) or stub.

### Gaps requiring live discovery

1. **Port 143 availability inside Stalwart:** The landscape only documents published host ports (993 for IMAP). Whether Stalwart internally listens on 143 (plain IMAP) — accessible from a shared Docker network without going through the published host port — is unknown. The solution designer should assume 993 (IMAPS) only; the executor should confirm at runtime if a plaintext IMAP option is considered.
2. **Roundcube HTTP loopback port:** No explicit port allocation for Roundcube is documented. Ports 1080, 8080, 9998, 3115 are taken; a free port (e.g., 8888, 9002, 8081) must be confirmed available by the executor via `ss -tlnp | grep <port>` before use.
3. **Roundcube image tag:** `roundcube/roundcubemail:latest` is the known image; the specific stable pinned tag must be confirmed at execution time by inspecting Docker Hub.
4. **User mailboxes existence:** `vladimir.titenko@aiqadam.org`, `binali.rustamov@aiqadam.org`, and `aigerim.kambetbayeva@aiqadam.org` are referenced as existing in the task but are NOT documented in `landscape/secrets-inventory.md` or `landscape/hosts/pro-data-tech-prod.md`. The executor must confirm these accounts exist in Stalwart before the acceptance test (step 4 of "What done looks like"). `aigerim.kambetbayeva@aiqadam.org` was confirmed created with temp password `AiQ-temp-2026!` per step-01 notes, but Stalwart account creation date/status is not in the landscape.
5. **Roundcube Docker networking approach:** The landscape does not document a preferred approach for Roundcube-to-Stalwart connectivity. The solution designer must choose one of the two safe options (shared `stalwart-mail_default` network or `network_mode: host`); this choice determines the `IMAP_HOST` and `SMTP_HOST` values in the Roundcube config.
6. **`DEFAULT_FORWARD_POLICY` on prod vs QA difference:** Whether Docker can route between different bridges under DROP is not explicitly tested on this host. The solution should avoid relying on cross-bridge forwarding to be safe.

## Issues / risks

- **Stalwart auto-ban (HIGH):** If the solution designer picks a network approach that puts Roundcube on a new Docker subnet (not `172.19.0.0/16`), the container's gateway/source IPs will trigger Stalwart's auto-ban on IMAP connection attempts. This must be designed away, not mitigated after the fact. Preferred design: share `stalwart-mail_default` or use host networking.
- **Port 8080 conflict:** `127.0.0.1:8080` is already the Stalwart admin UI. If the Roundcube image defaults to port 80 internally and is bound to 8080 on the host, there will be a conflict. The solution design must specify a different host port (e.g., 8888).
- **No Redis/session persistence concern for Roundcube:** The aiqadam-prod stack has a known ioredis gap. Roundcube does not use Redis by default (SQLite for DB, filesystem for sessions unless configured otherwise). This is not a blocking issue but the designer should confirm Roundcube's session storage is not impacted.
- **`aigerim.kambetbayeva@aiqadam.org` temp password** (`AiQ-temp-2026!`) appears in the task file and step-01 handoff. The executor must NOT log or echo this value; it appears only as a note that the user must be prompted to change their password after first login. This is explicitly out of scope for the task.
- **CAA record (`0 issue "letsencrypt.org"`):** Zone-wide CAA restricts issuance to Let's Encrypt only — certbot's HTTP-01 challenge will satisfy this. No conflict.
