---
host_id: pro-data-tech-prod
provider: pro-data.tech
role: penpot-prod
last_verified: 2026-07-21
status: hardened
last_verified_note: 2026-07-21, run 2026-07-21-harden-stalwart-auto-ban-001, T-0121 done — Stalwart AllowedIp entries for 172.19.0.1 (id i9yv13qeaaqa) and 172.19.0.0/16 (id i9yv3mloabaa) created; nginx mail admin vhost restricted to loopback-only (allow 127.0.0.1; deny all; external returns 403); monitoring cron /usr/local/bin/mail-health-check.sh every 5 min; all mail ports confirmed reachable; Stalwart v0.16.13 healthy; proxyTrustedNetworks found to be PROXY protocol binary (not X-Forwarded-For) — reverted; deferred as follow-on. Prior note: 2026-07-20, manual, no run — resolved a Stalwart auto-ban incident (bridge gateway IP `172.19.0.1` permanently blocked, taking down external mail-server access; see host body and T-0121); created `postmaster@aiqadam.org` as the mailbox-request intake address per new `shared/mail-provisioning-protocol.md`. Prior note: T-0117 done 2026-07-19 via run 2026-07-19-install-mail-server-aiqadam-001 — self-hosted Stalwart mail server deployed for aiqadam.org (Compose project `stalwart-mail`, DNS cutover from the dead third-party mail.aiqadam.org host, test mailbox, nginx vhost, backup); took 9 executor attempts (full history in that run's `.attempts/`). Prior note: T-0113 (real CI/CD deploy.sh installed, syntax-checked, not yet invoked) done 2026-07-17 via run 2026-07-17-cicd-workflow-aiqadam-001 — placeholder deploy.sh replaced with real deploy logic (regex-validated git ref, rollback markers); `deploy` user granted `tvolodi` group membership for future checkout write access (preventive, no git op run as `deploy` on this host yet); Penpot confirmed unregressed; task remains in-progress (PR #15 open, not yet merged; prod's deploy.sh unexercised end-to-end until T-0115). Prior note: T-0112 (on-host provisioning complete, task remains in-progress pending GitHub Actions secrets paste) done 2026-07-17 via run 2026-07-14-ssh-deploy-keys-aiqadam-001 — dedicated `deploy` system user (uid 999, shell /bin/bash, forced-command-restricted via authorized_keys) created for CI/CD; `deploybots` group added to sshd AllowGroups; `aiqadam-prod-secrets` group grants `deploy` read access to deploy/.env. Prior note: T-0111 done 2026-07-13 — AiQadam prod app stack deployed (Compose project aiqadam-prod, 3 containers) alongside Penpot; nginx vhost + Let's Encrypt TLS live at https://aiqadam.org; Cloudflare apex A record repointed. Run 2026-07-13-setup-aiqadam-prod-infra-001, step-07 PASS.
ssh_user: tvolodi
ssh_port: 22
os: ubuntu-26.04
kernel: 7.0.0-14-generic
---

# pro-data-tech-prod

A pro-data.tech cloud VM (IPv4 `95.46.211.224`, hostname `drkkrgm-prod-instance`) added to the inventory on 2026-07-11. Provider is **pro-data.tech** (NOT Hetzner) — no Hetzner Cloud Firewall, no Hetzner API, no Hetzner Backups option; the host stands on its own with cloud-init defaults. Sister host `pro-data-tech-qa` (`95.46.211.230`) is on the same `/25` subnet and has been fully hardened (T-0093 through T-0099). Role: **penpot-prod** — hosts the Penpot 2.16 design tool (T-0108, 2026-07-11) and, as of T-0111 (2026-07-13), the AiQadam production app stack.

> **Security baseline complete + Penpot fully deployed (2026-07-11):** sshd hardened (T-0102), UFW active (T-0103), fail2ban active (T-0104), operator users provisioned (T-0105), Docker CE 29.6.1 (T-0106). **Penpot 2.16 deployed (T-0108, 2026-07-11) — 7 containers running, MCP enabled. nginx 1.28.3 + Let's Encrypt TLS active (T-0109, 2026-07-11) — https://penpot.aiqadam.org live.** **AiQadam prod app stack deployed (T-0111, 2026-07-13) — Compose project `aiqadam-prod` (postgres, oidc-stub, api), additive nginx vhost + Let's Encrypt TLS live at https://aiqadam.org, coexisting with Penpot.** Remaining items: auditd not installed (gap #4), pending package upgrades (gap #5).

Populated by discovery run [`2026-07-11-discovery-pro-data-tech-prod-001`](../../runs/2026-07-11-discovery-pro-data-tech-prod-001/).

## Hardware & OS

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes B, C).

- **Public IPv4:** `95.46.211.224` (provider: pro-data.tech, subnet `95.46.211.128/25`)
- **IPv6:** link-local only (`fe80::649a:e1ff:fe4e:baeb/64` on eth0); no global IPv6 assignment.
- **Hostname:** `drkkrgm-prod-instance` (provider-assigned; not project-controlled)
- **Server type:** **unknown**. pro-data.tech does not expose plan tier via in-host metadata; the canonical plan labels would need to be confirmed in the provider's control panel. From in-host enumeration: 16 vCPU, ~31 GiB RAM, 339 GB root disk — notably larger than the QA host (8 vCPU / 15 GiB / 145 GB).
- **vCPU / RAM:** 16 vCPU (`nproc=16`); ~31 GiB RAM total (972 MiB used, 28 GiB free); **no swap**.
- **Disk:** 339 GB `/dev/sda1` mounted on `/` (3.1 GB used, 1%, 336 GB available); 989 MB `/dev/sda13` for `/boot` (17%); 105 MB `/dev/sda15` for `/boot/efi` (7%).
- **CPU model:** Intel Xeon Platinum 8164 @ 2.00GHz.
- **Location:** **unknown**. pro-data.tech does not expose a datacenter label via in-host metadata. Verify in the provider console.
- **OS:** Ubuntu 26.04 LTS "Resolute Raccoon" (`VERSION_CODENAME=resolute`, `ID=ubuntu`).
- **Kernel:** `7.0.0-14-generic` (cloud-image default; **two minor versions behind the QA host's `7.0.0-27-generic`**; 12 pending package upgrades outstanding — see apt posture below).
- **Virtualization:** KVM (`systemd-detect-virt: kvm`; `qemu-guest-agent.service` running).
- **Cost:** **unknown**; verify in the provider control panel.

## Access

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes A, D, E).

- **Primary SSH user:** `tvolodi` (uid 1000). Key comment: `ai-dala-infra-mgmt@tvolodi-2026-05-12` (ED25519), at `/home/tvolodi/.ssh/authorized_keys`. Management key: `C:\Users\tvolo\.ssh\ai-dala-infra`. **Confirmed correct (T-0111, 2026-07-13):** this is the ONLY working key for `tvolodi` on this host — `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224`.
- **Break-glass SSH user:** `root` (uid 0). Key: `rsa-key-20260707` (RSA, provider-provisioned), at `/root/.ssh/authorized_keys`. Management key: `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk`. `PermitRootLogin prohibit-password` — key-only. Root remains in `sshusers` permanently. **This RSA `.ppk` key is the root break-glass key ONLY — it does NOT authenticate as `tvolodi` (confirmed rejected, T-0111, 2026-07-13). Prior documentation implying this key works for `tvolodi` was incorrect and has been corrected here.**
- **SSH host (primary):** `tvolodi@95.46.211.224`
- **SSH host (break-glass):** `root@95.46.211.224`
- **SSH key (management workstation, tvolodi):** `C:\Users\tvolo\.ssh\ai-dala-infra` (ED25519) — matches the QA host's (`pro-data-tech-qa`) key pattern for `tvolodi`.
- **SSH key (management workstation, root break-glass only):** `C:\Users\tvolo\.ssh\pro-data.tech-prod-instance_rsa.ppk` (OpenSSH-format RSA despite the misleading `.ppk` extension; file starts with `-----BEGIN RSA PRIVATE KEY-----`).
- **Sudo:** passwordless for `root` via `/etc/sudoers.d/90-cloud-init-users` (`root ALL=(ALL) NOPASSWD:ALL`; cloud-init default). Project-managed drop-ins: `/etc/sudoers.d/90-tvolodi`, `/etc/sudoers.d/90-viktor_d`, `/etc/sudoers.d/90-binali_r` (each: `<user> ALL=(ALL) NOPASSWD: ALL`, mode 0440, owner root). Full `visudo -c` parse: clean.
- **Local users:** `root` (uid 0), `tvolodi` (uid 1000), `viktor_d` (uid 1001), `binali_r` (uid 1002) — all login-capable with key-only auth. `nobody` (uid 65534, nologin). `deploy` (uid 999, system account, shell `/bin/bash`, forced-command-restricted) — provisioned 2026-07-17 for CI/CD, see "CI/CD deploy user" subsection below.
- **Currently logged in (at discovery time):** no active sessions other than the probe session (`who` returned empty).
- **SSH daemon config (sshd -T effective, 2026-07-11 — HARDENED per T-0102):**

  | Parameter | Effective value |
  |---|---|
  | `permitrootlogin` | `prohibit-password` — key-only root; password login blocked |
  | `passwordauthentication` | `no` |
  | `kbdinteractiveauthentication` | `no` |
  | `pubkeyauthentication` | `yes` |
  | `permitemptypasswords` | `no` |
  | `allowgroups` | `sshusers deploybots` — `sshusers` members: root, tvolodi, viktor_d, binali_r; `deploybots` members: deploy (added 2026-07-17, T-0112) |
  | `maxauthtries` | `3` |
  | `logingracetime` | `30` |
  | `x11forwarding` | `no` |
  | `clientaliveinterval` | `300` |
  | `clientalivecountmax` | `2` |
  | `usedns` | `no` |
  | `kexalgorithms` | `curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256` |
  | `ciphers` | `chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr` |
  | `macs` | `hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com` |

- **sshd drop-in files (`/etc/ssh/sshd_config.d/`):** three files present (first-wins alphabetical sort):
  - `40-disable-password.conf` — `PasswordAuthentication no`, `KbdInteractiveAuthentication no`. Mode 644, owner root. (project-managed, T-0102)
  - `40-ai-dala-infra.conf` — `PermitRootLogin`, `MaxAuthTries`, `LoginGraceTime`, `X11Forwarding`, `ClientAliveInterval`, `ClientAliveCountMax`, `AllowGroups sshusers deploybots`, hardened KexAlgorithms/Ciphers/MACs. Mode 644, owner root. (project-managed, T-0102; `AllowGroups` extended to add `deploybots` 2026-07-17 by T-0112 — pre-edit backup preserved at `40-ai-dala-infra.conf.pre-T0112.20260717T063437Z.bak`, plus three earlier attempts' backups from the same run)
  - `60-cloudimg-settings.conf` — `PasswordAuthentication yes` (cloud-init default; overridden by the 40- files above). Mode 644, unchanged.
- **sshusers group:** gid 1000, created by T-0102. Current members: `root`, `tvolodi`, `viktor_d`, `binali_r` (`sshusers:x:1000:root,tvolodi,viktor_d,binali_r`). Root is a permanent member for break-glass SSH access — not removed. `PermitRootLogin prohibit-password` remains in effect regardless of group membership.
- **deploybots group:** gid 982, system group created 2026-07-17 by T-0112, added as a second `AllowGroups` entry so the CI/CD `deploy` user can authenticate without joining `sshusers` (reserved for human operators + root break-glass). Current members: `deploy`.
- **Note on socket activation:** `ssh.service` is socket-activated (`TriggeredBy: ssh.socket`, `Loaded: ... disabled; preset: enabled`). This is normal for Ubuntu 26.04. `systemctl is-active sshd` returns `active`.

## What runs here

See [`../services.md`](../services.md) for the canonical per-host table. High-level: **Penpot 2.16 deployed (T-0108, 2026-07-11) — 7 Docker Compose containers running under project `penpot`; MCP enabled (`penpot-mcp` running); nginx 1.28.3 + Let's Encrypt TLS active (T-0109, 2026-07-11) — https://penpot.aiqadam.org live.** **AiQadam prod app stack deployed (T-0111, 2026-07-13) — 4 Docker Compose containers running under project `aiqadam-prod`; nginx vhost + Let's Encrypt TLS live — https://aiqadam.org live.** **Stalwart mail server deployed (T-0117, 2026-07-19) — 1 Docker Compose container running under project `stalwart-mail`; nginx vhost + Let's Encrypt TLS at https://mail.aiqadam.org (admin UI restricted to loopback — external HTTPS returns 403, operator access via SSH port-forward required, T-0121 2026-07-21); SMTP/IMAP/submission serving their own internal-ACME-managed TLS cert.** Docker CE 29.6.1 (T-0106).

## Penpot

Deployed by run `2026-07-11-deploy-penpot-pro-data-tech-prod-001` (T-0108, 2026-07-11). Penpot 2.16 design tool running as a 7-container Docker Compose stack under project name `penpot` at `/opt/penpot/`.

- **Compose directory:** `/opt/penpot/`
- **Compose file:** `/opt/penpot/docker-compose.yaml` (7891 bytes; 3 patches applied: mailcatch loopback-only, env var interpolation for PENPOT_FLAGS/PENPOT_PUBLIC_URI/PENPOT_SECRET_KEY)
- **Env file:** `/opt/penpot/.env` (mode 600, owner root; 3 keys: `PENPOT_SECRET_KEY`, `PENPOT_PUBLIC_URI`, `PENPOT_FLAGS`)
- **PENPOT_PUBLIC_URI:** `https://penpot.aiqadam.org`
- **PENPOT_FLAGS:** `enable-prepl-server enable-mcp`
- **Frontend port:** `0.0.0.0:9001 → 8080/tcp` — HTTP 200 confirmed on `localhost:9001`
- **Mailcatch:** `127.0.0.1:1080 → 1080/tcp` (loopback-only; internet exposure blocked)
- **MCP:** enabled — `penpot-penpot-mcp-1` container (`penpotapp/mcp:2.16`) running
- **nginx / HTTPS:** **ACTIVE** (T-0109, 2026-07-11). nginx 1.28.3 reverse proxy; vhost `/etc/nginx/sites-available/penpot.aiqadam.org` (symlinked to `sites-enabled`); TLS via Let's Encrypt (cert `/etc/letsencrypt/live/penpot.aiqadam.org/fullchain.pem`, expires 2026-10-09, intermediate CA `YE1`/Let's Encrypt, auto-renewal via `certbot.timer`). `https://penpot.aiqadam.org` — HTTP 200 confirmed from external workstation.
- **First admin user:** not yet created — run `docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile` (one-time step)
- **Docker volumes:** `penpot_penpot_postgres_v15`, `penpot_penpot_assets`

### Containers (2026-07-11, post-T-0108)

| Container | Image:tag | Port binding | Health | Purpose |
|---|---|---|---|---|
| `penpot-penpot-frontend-1` | `penpotapp/frontend:2.16` | `0.0.0.0:9001→8080/tcp` | Up | Web frontend |
| `penpot-penpot-backend-1` | `penpotapp/backend:2.16` | (internal) | Up | Application backend |
| `penpot-penpot-exporter-1` | `penpotapp/exporter:2.16` | (internal) | Up | Export service |
| `penpot-penpot-mcp-1` | `penpotapp/mcp:2.16` | (internal) | Up | MCP server (Model Context Protocol) |
| `penpot-penpot-postgres-1` | `postgres:15` | (internal) | Up (healthy) | PostgreSQL 15 database |
| `penpot-penpot-valkey-1` | `valkey/valkey:8.1` | (internal) | Up (healthy) | Valkey (Redis-compatible) cache |
| `penpot-penpot-mailcatch-1` | `sj26/mailcatcher:latest` | `127.0.0.1:1080→1080/tcp` | Up | Mail catcher (loopback-only) |

## AiQadam Prod

Deployed by run `2026-07-13-setup-aiqadam-prod-infra-001` (T-0111, 2026-07-13). AiQadam production API running as a 3-container Docker Compose stack under project name `aiqadam-prod` at `/opt/apps/aiqadam-prod/`, coexisting with (and confirmed non-disruptive to) the pre-existing Penpot deployment.

- **Checkout:** `/opt/apps/aiqadam-prod/` — git HEAD `dfd2a7c` (pinned, detached HEAD — not tracking a moving branch), from `https://github.com/aiqadam/ai-qadam-platform.git`. Same commit already validated on QA via T-0110.
- **Compose directory:** `/opt/apps/aiqadam-prod/deploy/`
- **Compose file:** `/opt/apps/aiqadam-prod/deploy/docker-compose.prod.yml` (3 services: `postgres`, `oidc-stub`, `api`; all `network_mode: host`)
- **Env file:** `/opt/apps/aiqadam-prod/deploy/.env` (owner `tvolodi:aiqadam-prod-secrets`, mode 640 as of 2026-07-17 per T-0112 — was `tvolodi:tvolodi` mode 600; content untouched, group/mode-only change to grant the `deploy` CI user read access) — 3 new secrets, names only: `aiqadam-prod-jwt-signing-secret`, `aiqadam-prod-internal-api-token`, `aiqadam-prod-postgres-password` (see [`../secrets-inventory.md`](../secrets-inventory.md); `POSTGRES_PASSWORD` generated via `openssl rand -hex 24` to avoid URL-metacharacters)
- **Database:** dedicated `aiqadam_prod` database inside the new `aiqadam-prod-postgres-1` container (postgres:16) — NOT shared with QA's `aiqadam_qa`/`aiqadam_test` databases on `pro-data-tech-qa`. Volume `aiqadam-prod_aiqadam_prod_pgdata`.
- **Postgres bind-address posture:** binds `0.0.0.0:3114`/`[::]:3114` under `network_mode: host` (not app-layer loopback-restricted) — protected solely by UFW's default-deny-incoming policy (only 22/80/443/tcp allowed in), matching the existing Penpot `postgres:15` precedent on this same host rather than introducing a new per-service hardening posture.
- **Containers:** see [`../services.md`](../services.md#running-containers-2026-07-13-post-t-0111) for the full table.
- **nginx vhost:** `/etc/nginx/sites-available/aiqadam.org` (symlinked to `sites-enabled`) — additive, new file; proxies to `127.0.0.1:3115`; bare apex only (`server_name aiqadam.org;`, no `www`); coexists with, and does not modify, the pre-existing `penpot.aiqadam.org` vhost.
- **TLS:** separate Let's Encrypt cert for `aiqadam.org` (ECDSA, issued 2026-07-13, expires 2026-10-11), auto-renewing via the same `certbot.timer` already active on this host. Penpot's own cert (`penpot.aiqadam.org`, expires 2026-10-09) is a fully independent cert, unaffected.
- **Cloudflare:** the `aiqadam.org` apex A record (zone `bec8854d698d56ff17cf917367634100`, record ID `bf1113199732117bd147ebd87d6e356d`) was repointed from `212.20.151.29` (a third-party, unrelated PaaS host) to `95.46.211.224`, and `proxied` flipped from `true` to `false`. See [`../cloudflare.md`](../cloudflare.md) for full zone detail.
- **Health endpoint:** `GET https://aiqadam.org/health` → `200`, `{"status":"ok","service":"api","tenant":{"code":"uz",...}}` — resolves via the app's `DEFAULT_TENANT_CODE='uz'` fallback because `aiqadam` (and `www`) are hardcoded into the app's own `NON_TENANT_LABELS` set (confirmed by reading `tenant.middleware.ts` source — an intentional, source-confirmed exemption, distinct from the length-based fallback QA's `qa-uz.aiqadam.org` relies on).
- **Known deviation:** bare `GET https://aiqadam.org/` returns 404 (no route handler for `/` in the Nest/Express app) — pre-existing app behavior, same as QA, confirmed unrelated to infra.
- **Scope decision (superseded 2026-07-18, see below):** originally only `apps/api` was containerized for prod — `apps/web`/`apps/web-next` were NOT deployed here. OIDC login and Directus-CMS-backed routes were non-functional in this environment by design (schema-valid placeholder env vars satisfy boot-time validation only). Matched the QA precedent (T-0110).
- **Update 2026-07-19 (discovered via a T-0117 mail-server-deployment no-regression check, user-confirmed expected):** a 4th container, `aiqadam-prod-web-next-1`, is now running alongside the original 3 (`postgres`, `oidc-stub`, `api`) — deployed by separate, out-of-band work on 2026-07-18 (same day as the `qa.aiqadam.org`/`auth.qa.aiqadam.org` Cloudflare records discovered via the same mechanism — see [`../cloudflare.md`](../cloudflare.md)). Not tracked by any task file in this repo as of this writing. The AiQadam-prod Compose project is therefore 4 containers, not 3, as of 2026-07-19.
- **Known gap:** no Redis/Valkey service is included in this stack. The `api` container logs continuous `ioredis ECONNREFUSED` from `JtiRevocationService`/`OutboxRelayService`/internal-cron/Telegram module — the app boots and `/health` passes (zod default for `REDIS_URL`), but token-revocation-on-signout and background cron/Telegram features are silently non-functional. Same underlying gap exists in the QA environment. Tracked as a pending follow-on task (see `tasks/`).
- **Full detail:** see run [`2026-07-13-setup-aiqadam-prod-infra-001`](../../runs/2026-07-13-setup-aiqadam-prod-infra-001/) and [`shared/app-registry.md`](../../shared/app-registry.md) for the complete deploy record.

## Stalwart Mail

Deployed by run [`2026-07-19-install-mail-server-aiqadam-001`](../../runs/2026-07-19-install-mail-server-aiqadam-001/) (T-0117, 2026-07-19; 9 executor attempts — full troubleshooting history in that run's `.attempts/`). Self-hosted Stalwart mail server running as a single-container Docker Compose stack under project name `stalwart-mail` at `/opt/stalwart-mail/`, replacing the dead third-party `mail.aiqadam.org` (`212.20.151.29`, Globe Cloud LLC/Uzbekistan — unreachable on 25/443/993, no credentials in this repo) and cutting `aiqadam.org` mail routing over to repo-owned infrastructure for the first time.

- **Compose directory:** `/opt/stalwart-mail/`
- **Image:** `stalwartlabs/stalwart:v0.16` (pinned)
- **Volumes (bind mounts):** `var-lib-stalwart` (RocksDB data store, mail/account data), `etc-stalwart` (Bootstrap config) — both under `/opt/stalwart-mail/`
- **UID:** container runs as UID 2000
- **Ports published:** 25 (SMTP), 465 (SMTPS/submissions), 587 (submission), 993 (IMAPS), plus the admin/JMAP web UI on `127.0.0.1:8080` (loopback-only, reverse-proxied by nginx — see below)
- **`stalwart-cli`:** installed at `/home/tvolodi/.cargo/bin/stalwart-cli` (separate tool, not bundled with the server image — see "Stalwart CLI gotchas" below) — the only supported way to configure/administer this deployment; there is no bundled admin UI form for these objects at the version deployed.
- **Container:** `stalwart-mail-server-1`, `healthy`, low restart count throughout deployment.

### Domain object (live configuration)

The Stalwart `Domain` object for `aiqadam.org` (id `b`) is wired as follows (confirmed via `stalwart-cli get Domain b`):

- **`dnsManagement`: Automatic** — `dnsServerId: i9njy0ssaaqb` (the `DnsServer` object pointing at this zone's Cloudflare API), **scoped via `publishRecords: {"tlsa": true}`** — i.e. Stalwart is only permitted to self-manage TLSA records in the shared `aiqadam.org` Cloudflare zone, not the full default set (`autoConfig, autoConfigLegacy, autoDiscover, caa, dkim, dmarc, mtaSts, mx, spf, srv, tlsRpt` — 11 of the 12 `DnsRecordType` enum members). This scoping was a deliberate, user-approved decision (see run for full reasoning) to avoid granting Stalwart standing write access to MX/SPF/DKIM/DMARC/etc. in a zone shared with third parties.
- **`certificateManagement`: Automatic** — `acmeProviderId: i9noabxeabab` (Let's Encrypt production, `challengeType: Dns01`, real account registered, `accountUri` populated). Stalwart issues and renews its own certificate for SMTP/IMAP/submission (465/587/993) independently of the nginx/certbot cert used for the admin UI (see "Dual TLS mechanism" below).
- **DKIM:** `DkimSignature` selector `mail`, type `Dkim1Ed25519Sha256`, id `i9njnzd3krqa`.
- **`NetworkListener`:** name `submission`, port 587, id `i9njnzefksaa`.
- **`DnsServer`:** Cloudflare variant, id `i9njy0ssaaqb`, TTL 5m, timeout 30s — uses the existing `cloudflare-ai-qadam-api-token` (same token the executor uses directly for DNS cutover PATCHes).
- **Self-managed DNS churn (ongoing, not one-time):** because of the `publishRecords: {tlsa:true}` scoping, Stalwart continuously maintains ~20 TLSA records (roughly 4 per mail-related hostname) plus a `_acme-challenge.aiqadam.org` TXT record in the Cloudflare zone as part of its own ACME renewal cycle. These are expected, self-managed, recurring records — not one-time facts — and their presence/count may fluctuate slightly across renewal cycles. See [`../cloudflare.md`](../cloudflare.md) for the current snapshot.

### Mailbox provisioning

**Process (who can request one, who creates them):** see [`shared/mail-provisioning-protocol.md`](../../shared/mail-provisioning-protocol.md) — self-service request via emailing `postmaster@aiqadam.org`, admin-created via the web panel or the mechanism below. Routine creation should use the admin panel at `https://mail.aiqadam.org/` (any admin login) — the CLI/JMAP method below is for when the panel is unavailable or for scripted/bulk work.

Mailboxes are created via `stalwart-cli create Account` (or the equivalent `apply`-with-NDJSON `upsert` mechanism), or directly via a raw JMAP `x:Account/set` call if the CLI itself is unreachable (e.g. during the auto-ban incident described under "Stalwart CLI gotchas" below, where a peer-container workaround was needed). Confirmed working payload shape — note the top-level `@type: "User"` is required (an easy thing to miss; omitting it fails with `"Missing or invalid '@type' property"`):

```json
{"@type":"User","name":"postmaster","domainId":"b","credentials":{"0":{"@type":"Password","secret":"<value>"}}}
```

- **`objectList`-typed fields gotcha:** `Account.credentials` is an `objectList<x:Credential>` field and must be encoded as a JSON **map keyed by plain numeric-string indices** (`{"0": {...}}`), NOT a JSON array (`["...", ...]` → rejected: "Invalid value for object property") and NOT a map with descriptive string keys (`{"password-1": {...}}` → rejected: "Invalid key for object property"). This is related to, but distinct from, the `set<T>`-typed map-encoding quirk described below (`publishRecords`, `AcmeProvider.contact`) — `set<T>` fields accept descriptive string keys as boolean flags; `objectList<T>` fields require numeric-string positional keys.
- **`x:Account` is itself a tagged-union type** (`variants: User | Group`) — the top-level object needs its own `@type` field (`"User"` for a mailbox), separate from and in addition to the `@type` inside each credential entry. Confirmed by direct schema inspection 2026-07-20; not obvious from the CLI's own error messages alone (the first failed attempt without it returned a generic `"Missing or invalid '@type' property"` with an empty `properties: [""]`, not naming which field).
- Mailboxes provisioned so far: `test@aiqadam.org` (id `e`, secret `stalwart-mail-test-account-password`), `admin@aiqadam.org` (id `b`, domain-admin account, secret `stalwart-mail-domain-admin-password`), `postmaster@aiqadam.org` (id `f`, created 2026-07-20 as the mailbox-request intake address, secret `stalwart-mail-postmaster-password`).
- `describe Credential` fails via the CLI (`no object or enum named Credential`) because it's an internal (`x:`-prefixed) schema type not exposed by `describe`'s top-level `objects` map — see "Stalwart CLI gotchas" below for how to discover its shape anyway.

### nginx vhost (admin UI)

- **Vhost:** `/etc/nginx/sites-available/mail.aiqadam.org` (symlinked to `sites-enabled`) — HTTP→HTTPS redirect on 80; HTTPS on 443 proxying `/` → `http://127.0.0.1:8080` (Stalwart's web admin UI/JMAP), WebSocket upgrade headers, matching the existing `penpot.aiqadam.org`/`aiqadam.org` vhost pattern on this host.
- **TLS cert reused:** the vhost reuses a Let's Encrypt cert for `mail.aiqadam.org` that was orphaned from executor attempt 1 of this run (obtained, then unused when that attempt's approach changed) — `/etc/letsencrypt/live/mail.aiqadam.org/`, ECDSA, expires 2026-10-17, auto-renewing via the same `certbot.timer` already active on this host.
- **Access restriction (T-0121, 2026-07-21):** nginx `location /` block has `allow 127.0.0.1; deny all;` as first two directives. External HTTPS now returns **HTTP 403** (confirmed from management workstation). The admin UI is accessible from the host's loopback only. Operators access the admin UI via SSH port-forward: `ssh -L 9080:127.0.0.1:8080 -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224` then browse to `http://localhost:9080/`. Pre-change backup: `/var/backups/mail.aiqadam.org.pre-T0121.20260721T150501Z.bak`.
- **nginx headers:** `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` and `proxy_set_header X-Real-IP $remote_addr;` are present in the vhost (from T-0117) and ready for when Stalwart exposes header-based real-IP trust (see proxyTrustedNetworks subsection below).

### Dual TLS mechanism (important — two independent cert paths for the same hostname)

`mail.aiqadam.org` is served over TLS two different ways for two different purposes, and this is intentional, not a conflict:

1. **nginx + certbot** — terminates TLS for the admin/web UI on port 443 (the orphaned attempt-1 cert, above), using this host's existing certbot-based Let's Encrypt workflow (HTTP-01).
2. **Stalwart's own internal ACME** (`AcmeProvider i9noabxeabab`, DNS-01 challenge via the scoped `dnsManagement: Automatic` object above) — issues and renews a separate cert used directly by Stalwart for SMTP/IMAP/submission TLS on 25/465/587/993. Confirmed live: `CN=*.aiqadam.org`, issuer Let's Encrypt (`YE2`), valid 2026-07-19 through 2026-10-17.

Both certs currently cover `mail.aiqadam.org`/`*.aiqadam.org` and both auto-renew independently — there is no shared renewal hook between them.

### AllowedIp configuration (T-0121, 2026-07-21)

Two permanent `AllowedIp` entries were created in Stalwart's config store via JMAP `x:AllowedIp/set`, ensuring the Docker bridge addresses are never auto-banned:

| JMAP ID | Address | Reason | expiresAt |
|---|---|---|---|
| `i9yv13qeaaqa` | `172.19.0.1` | Docker bridge gateway IP — stalwart-mail_default network — T-0121 | null (permanent) |
| `i9yv3mloabaa` | `172.19.0.0/16` | Docker bridge subnet for stalwart-mail_default — belt-and-suspenders — T-0121 | null (permanent) |

Both entries survive container restarts (stored in Stalwart's on-disk RocksDB config store). Confirmed present via `x:AllowedIp/query` + `x:AllowedIp/get` after two successive container restarts.

### Monitoring (T-0121, 2026-07-21)

A host-resident cron-based mail-reachability monitor is installed to catch the "container healthy but externally unreachable" failure mode that masked the 2026-07-20 incident:

- **Script:** `/usr/local/bin/mail-health-check.sh` (mode `-rwxr-xr-x`, owner `root:root`, 1934 bytes)
- **Checks:** HTTPS (`https://mail.aiqadam.org/`), SMTP port 25, submission port 587, IMAPS port 993
- **Schedule:** `*/5 * * * * /usr/local/bin/mail-health-check.sh` in root's crontab
- **Logging:** writes structured log entries to syslog via `logger`, also to `/var/log/mail-health-check.log`
- **Verified:** script exits 0, log shows `[OK] all checks passed`; cron entry confirmed via `sudo crontab -l`

### Stalwart JMAP emergency remediation runbook

Use this when the normal `docker-proxy`-mediated path to Stalwart's admin UI (port 8080 via host loopback) is broken — e.g., due to an active ban on the bridge gateway IP, or because `proxyTrustedNetworks` was misconfigured. The peer-container path bypasses Docker's bridge proxy entirely.

**Stalwart version:** v0.16.13 (confirmed 2026-07-21).

**Step 1 — Get container bridge IP:**

```bash
docker inspect stalwart-mail-server-1 \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
# Expected: 172.19.0.2 (may change on container recreation)
```

**Step 2 — JMAP calls from a peer container on the `stalwart-mail_default` network:**

```bash
CONTAINER_IP=172.19.0.2
# Query all BlockedIp IDs:
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<password>" -X POST -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/query",{},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap

# Get details for a specific BlockedIp entry (replace <id>):
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<password>" -X POST -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/get",{"ids":["<id>"]},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap

# Destroy a specific BlockedIp entry:
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<password>" -X POST -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/set",{"destroy":["<id>"]},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap

# Add an AllowedIp entry:
docker run --rm --network stalwart-mail_default curlimages/curl:latest \
  curl -sf -u "admin:<password>" -X POST -H "Content-Type: application/json" \
  -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:AllowedIp/set",{"create":{"a":{"address":"<ip>","reason":"<reason>"}}},"0"]]}' \
  http://${CONTAINER_IP}:8080/jmap
```

After deleting a ban, a `docker compose restart` is still required to clear Stalwart's in-memory copy.

**Recovery from a `proxyTrustedNetworks` mistake:** start a local Python PROXY-protocol tunnel (prepends `PROXY TCP4 10.0.0.1 127.0.0.1 12345 8080\r\n` before each HTTP connection), use `stalwart-cli` against the tunnel port to set `{"proxyTrustedNetworks":{}}`, then restart the container.

### proxyTrustedNetworks — PROXY protocol, not X-Forwarded-For (T-0121 finding)

Stalwart v0.16.13's `SystemSettings.proxyTrustedNetworks` (type: `set<string<ipNetwork>>`) enables **HAProxy-format PROXY protocol** at the transport level — NOT header-based X-Forwarded-For trust. Setting it to include `127.0.0.1` caused Stalwart to require a binary PROXY protocol preamble from all local connections, breaking plain HTTP access to the admin UI after the next container restart. It was immediately reverted (run 2026-07-21-harden-stalwart-auto-ban-001, step 06).

- **Do not enable `proxyTrustedNetworks`** unless nginx is also configured with `proxy_protocol on;` upstream (requires `ngx_http_realip_module` and listener changes — out of scope for T-0121).
- The nginx `X-Forwarded-For` and `X-Real-IP` headers are already present (from T-0117) and will be ready when a future Stalwart version exposes header-based real-IP trust distinct from PROXY protocol.
- Mitigation C (X-Forwarded-For trust) is deferred as a follow-on upgrade task.

### Stalwart CLI gotchas

Operational tribal knowledge accumulated across this run's 9 executor attempts, recorded here since it will recur for anyone touching this Domain/Account configuration later:

- **`stalwart-cli` is a separate tool from the server image** — `github.com/stalwartlabs/cli`, not bundled with `stalwartlabs/stalwart:v0.16`. Installed independently at `/home/tvolodi/.cargo/bin/stalwart-cli` via `cargo install`.
- **`update Bootstrap` requires a container restart to take effect** — not documented by Stalwart itself; discovered empirically. Applying a Bootstrap-config change via the CLI alone does not hot-reload the running server.
- **Several fields documented as `set<T>` actually require JSON-map encoding, not JSON-array encoding.** Confirmed for two fields specifically:
  - `AcmeProvider.contact` — must be `{"mailto:postmaster@aiqadam.org": true}`-style map, not `["mailto:postmaster@aiqadam.org"]`.
  - `Domain.dnsManagement.publishRecords` — must be `{"tlsa": true}`-style map (`minItems:1` is genuinely enforced; an empty map/array is rejected), not an array of type names.
- **`objectList`-typed fields** (e.g. `Account.credentials`) are a related-but-distinct quirk: they require **numeric-string-keyed** maps (`{"0": {...}}`), not descriptive-string keys and not arrays. See "Mailbox provisioning" above.
- **The full raw schema** is available at `GET /api/schema` (302-redirect + gzip-encoded response body — requires `curl -L --compressed`) for anything not covered by `describe <Type>`, which only reads the schema's public `objects` map and cannot see internal (`x:`-prefixed) types like `x:Credential`/`x:PasswordCredential`.
- **`stalwart-cli snapshot <Type>`** is the reliable way to discover an object's exact apply-plan JSON shape before constructing a real `apply`/`upsert` payload — used throughout this run to de-risk each new object type before touching production.
- **Stalwart has a built-in auto-ban feature that can block the Docker bridge gateway IP, taking down ALL external access while `docker exec`/Docker healthchecks still report the container healthy.** Confirmed incident 2026-07-20 (see [T-0121](../../tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md)): scanning/probe traffic against the admin UI triggered a permanent (`expiresAt: null`) ban on `172.19.0.1` (the `stalwart-mail_default` bridge gateway) instead of the real scanner IPs — since every external connection is NAT'd through that one address, this silently blocks everyone. A container restart does NOT clear this (the ban is stored in the on-disk config store, not memory-only) — the entry must be found and deleted.
  - **Diagnosis:** if the admin UI/SMTP/IMAPS are externally unreachable (502, empty replies, TLS handshake failures) but `docker exec ... curl http://127.0.0.1:8080/...` succeeds and `docker inspect` shows `Health: healthy`, suspect this. Confirm by testing from a disposable peer container on the same Docker network (bypasses the broken `docker-proxy` path entirely): `docker run --rm --network stalwart-mail_default curlimages/curl:latest curl http://<container-bridge-ip>:8080/healthz/live`.
  - **Object type:** `x:BlockedIp` (internal, `x:`-prefixed — not in `stalwart-cli describe`'s default object list; found via the raw `/api/schema` dump). Query/delete via raw JMAP, run from the same peer-container path (needed because the normal host→docker-proxy→container path is itself blocked by the ban being investigated):
    ```
    docker run --rm --network stalwart-mail_default curlimages/curl:latest \
      curl -u "admin:<password>" -X POST -H "Content-Type: application/json" \
      -d '{"using":["urn:ietf:params:jmap:core"],"methodCalls":[["x:BlockedIp/query",{},"0"]]}' \
      http://<container-bridge-ip>:8080/jmap
    ```
    Then `x:BlockedIp/get` with the returned `ids` to see `address`/`reason`/`createdAt`/`expiresAt` for each, and `x:BlockedIp/set` with `{"destroy":["<id>"]}` to remove only the bridge-gateway entry (leave genuine external-scanner bans in place).
  - **After deleting the ban, a `docker compose restart` is still required** to clear an in-memory copy Stalwart holds independently of the on-disk store.
  - Permanent mitigations applied by run `2026-07-21-harden-stalwart-auto-ban-001` ([T-0121](../../tasks/T-0121-harden-stalwart-auto-ban-against-bridge-ip.md), done 2026-07-21): (A) `AllowedIp` entries for `172.19.0.1` (id `i9yv13qeaaqa`) and `172.19.0.0/16` (id `i9yv3mloabaa`) created in Stalwart's config store; (B) nginx admin vhost restricted to loopback-only (`allow 127.0.0.1; deny all;`, external HTTPS returns 403); (C) `proxyTrustedNetworks` found to enable PROXY protocol binary (not X-Forwarded-For) — reverted, deferred as follow-on. See dedicated subsections above (AllowedIp configuration, Monitoring, Stalwart JMAP emergency remediation runbook, proxyTrustedNetworks).

## nginx

**Installed and active** (T-0109, 2026-07-11). nginx 1.28.3.

- **Package:** `nginx 1.28.3-2ubuntu1.6` (Ubuntu apt)
- **Service:** `nginx.service` — `active` and `enabled`
- **Vhost (Penpot):** `/etc/nginx/sites-available/penpot.aiqadam.org` (symlinked to `/etc/nginx/sites-enabled/penpot.aiqadam.org`)
- **Vhost (AiQadam prod, T-0111, 2026-07-13):** `/etc/nginx/sites-available/aiqadam.org` (symlinked to `/etc/nginx/sites-enabled/aiqadam.org`) — bare apex only, proxies to `127.0.0.1:3115`
- **Vhost (Stalwart mail admin UI, T-0117, 2026-07-19):** `/etc/nginx/sites-available/mail.aiqadam.org` (symlinked to `/etc/nginx/sites-enabled/mail.aiqadam.org`) — proxies to `127.0.0.1:8080`; see [Stalwart Mail](#stalwart-mail) above for the dual-TLS-mechanism note
- **Config (Penpot):** HTTP→HTTPS redirect on port 80; HTTPS on port 443 with `client_max_body_size 367001600`; WebSocket proxy for `/ws/notifications` and `/mcp/ws`; SSE proxy for `/mcp/stream`; general proxy for `/` → `http://localhost:9001/`
- **Config (AiQadam prod):** HTTP→HTTPS redirect on port 80 (certbot-managed); HTTPS on port 443 proxying `/` → `http://127.0.0.1:3115/`
- **Config (Stalwart mail admin UI):** HTTP→HTTPS redirect on port 80; HTTPS on port 443 proxying `/` → `http://127.0.0.1:8080` with WebSocket upgrade headers; `X-Forwarded-For` and `X-Real-IP` headers present; **IP restriction (T-0121, 2026-07-21): `allow 127.0.0.1; deny all;` in `location /` — external HTTPS returns HTTP 403; operators use SSH port-forward to access the admin UI**
- **TLS (Penpot):** Let's Encrypt via certbot 4.0.0; cert at `/etc/letsencrypt/live/penpot.aiqadam.org/` (ECDSA, expires 2026-10-09, intermediate CA `YE1`); auto-renewal via `certbot.timer` (active)
- **TLS (AiQadam prod):** Let's Encrypt via certbot 4.0.0; cert at `/etc/letsencrypt/live/aiqadam.org/` (ECDSA, expires 2026-10-11); auto-renewal via the same `certbot.timer` (active)
- **TLS (Stalwart mail admin UI):** Let's Encrypt via certbot 4.0.0; cert at `/etc/letsencrypt/live/mail.aiqadam.org/` (ECDSA, expires 2026-10-17) — reused from an orphaned executor-attempt-1 cert; auto-renewal via the same `certbot.timer` (active). Independent of Stalwart's own internal-ACME cert used for SMTP/IMAP/submission — see [Stalwart Mail](#stalwart-mail).
- **Access URLs:** `https://penpot.aiqadam.org`, `https://aiqadam.org`, and `https://mail.aiqadam.org` — all HTTP 200/302 confirmed from external workstation (step-07 PASS, T-0109, T-0111, T-0117 respectively)

## Network

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes F, G, supplemental network probe).

- **Cloudflare proxied:** no — `penpot.aiqadam.org` and `aiqadam.org` (apex) both resolve to this host via Cloudflare DNS (`aiqadam.org` zone, see [`../cloudflare.md`](../cloudflare.md)), but both records are unproxied (`proxied: false`, orange-cloud off) to allow certbot HTTP-01 validation directly against the origin. This note originated at initial discovery (2026-07-11, pre-dating T-0107/T-0109/T-0111) when the host had no DNS presence yet; corrected here now that it does.
- **Provider-level firewall:** **unknown**. pro-data.tech may or may not provide a control-plane firewall. Per project policy the host should rely on a **host-level firewall** (T-0103) for defense-in-depth.
- **Host firewall (UFW):** **ACTIVE** (T-0103, 2026-07-11). `ufw default deny incoming`, `ufw default allow outgoing`, `DEFAULT_FORWARD_POLICY="DROP"`. Rules: 22/tcp ALLOW IN Anywhere (v4+v6), 80/tcp ALLOW IN Anywhere (v4+v6), 443/tcp ALLOW IN Anywhere (v4+v6), **25/tcp ALLOW IN Anywhere (v4+v6), 465/tcp ALLOW IN Anywhere (v4+v6), 587/tcp ALLOW IN Anywhere (v4+v6), 993/tcp ALLOW IN Anywhere (v4+v6) — added T-0117, 2026-07-19, for the Stalwart mail server (SMTP/SMTPS/submission/IMAPS)**. Backup of pre-run defaults at `/var/backups/ufw-defaults-pre-T0103.bak`. **Docker UFW coexistence block appended to `/etc/ufw/after.rules` (T-0106, 2026-07-11):** DOCKER-USER filter chain (`-A DOCKER-USER -i eth0 -j RETURN`) + MASQUERADE nat rule (`-A POSTROUTING -s 172.16.0.0/12 -o eth0 -j MASQUERADE`); backup at `/var/backups/ufw-after.rules-pre-T0106.bak`.
- **nftables:** empty ruleset.
- **ip6tables:** fully open (all chains `policy ACCEPT`, no rules).
- **Network interfaces:**

  | Interface | Address | Notes |
  |---|---|---|
  | `lo` | 127.0.0.1/8, ::1/128 | loopback |
  | `eth0` | 95.46.211.224/25 brd 95.46.211.255 | public internet; gateway 95.46.211.129 |
  | `eth1` | 192.168.0.3/24 brd 192.168.0.255 | **private LAN** — not present on the QA host; likely a provider-managed private network between prod and other servers in the same account. QA host's expected LAN address would be `192.168.0.x` on the same `/24`. |

- **Default route:** `default via 95.46.211.129 dev eth0`.
- **IPv6:** link-local only on eth0 (`fe80::649a:e1ff:fe4e:baeb/64`) and eth1 (`fe80::e82f:86ff:fef3:bb89/64`). No global IPv6 assignment.
- **TCP listeners on 0.0.0.0:**

  | Port | Process | UFW rule | Notes |
  |---|---|---|---|
  | 22 | sshd | **ALLOW IN** (T-0103) | sshd hardened (T-0102): key-only, `PermitRootLogin prohibit-password`, `PasswordAuthentication no` |
  | 80 | nginx | **ALLOW IN** (T-0103) | HTTP → HTTPS redirect for penpot.aiqadam.org (T-0109) and aiqadam.org (T-0111, 2026-07-13) |
  | 443 | nginx | **ALLOW IN** (T-0103) | HTTPS; TLS via Let's Encrypt; proxies to penpot `localhost:9001` (T-0109) and aiqadam-prod-api `127.0.0.1:3115` (T-0111, 2026-07-13) |
  | 9001 | penpot-frontend (Docker) | No explicit UFW rule; Docker manages own iptables chains | Penpot frontend (T-0108). Port bound to 0.0.0.0 via Docker iptables bypass; nginx is the recommended entry point. |
  | 3114 | aiqadam-prod-postgres-1 (Docker, `network_mode: host`) | No explicit UFW rule; not reachable externally because 3114 is not in UFW's ALLOW list (deny-incoming default) | AiQadam prod Postgres (T-0111, 2026-07-13). Binds `0.0.0.0:3114`/`[::]:3114` at the process level; protection relies on UFW's default-deny, matching the Penpot postgres precedent. |
  | 25 | stalwart-mail-server-1 (Docker) | **ALLOW IN** (T-0117, 2026-07-19) | SMTP inbound |
  | 465 | stalwart-mail-server-1 (Docker) | **ALLOW IN** (T-0117, 2026-07-19) | SMTPS (submissions) |
  | 587 | stalwart-mail-server-1 (Docker) | **ALLOW IN** (T-0117, 2026-07-19) | Submission (`NetworkListener` id `i9njnzefksaa`) |
  | 993 | stalwart-mail-server-1 (Docker) | **ALLOW IN** (T-0117, 2026-07-19) | IMAPS inbound |

- **TCP listeners on loopback only:** `127.0.0.53:53`, `127.0.0.54:53` (systemd-resolved); `127.0.0.1:1080` (penpot-mailcatch, T-0108); `127.0.0.1:9998` (aiqadam-prod-oidc-stub-1, T-0111, 2026-07-13); `127.0.0.1:3115` (aiqadam-prod-api-1, T-0111, 2026-07-13); `127.0.0.1:8080` (stalwart-mail-server-1 admin/JMAP UI, T-0117, 2026-07-19 — reverse-proxied by nginx at `https://mail.aiqadam.org/`).
- **UDP:** `127.0.0.54:53` and `127.0.0.53:53` (systemd-resolved), `127.0.0.1:323` and `[::1]:323` (chronyd).
- **Effective exposure today:** SSH port 22 (UFW ALLOW IN). nginx ports 80/443 (UFW ALLOW IN; nginx handles HTTP→HTTPS redirect and TLS for `penpot.aiqadam.org`, `aiqadam.org`, and `mail.aiqadam.org`). Penpot port 9001 bound to 0.0.0.0 via Docker iptables bypass (remains externally accessible; nginx is the recommended entry point). AiQadam prod Postgres port 3114 bound to 0.0.0.0/[::]  via Docker `network_mode: host` but not reachable externally (UFW default-deny, no ALLOW rule for 3114). Stalwart mail ports 25/465/587/993 (UFW ALLOW IN, T-0117, 2026-07-19). UFW: deny-incoming default; 22/tcp, 80/tcp, 443/tcp, 25/tcp, 465/tcp, 587/tcp, 993/tcp explicitly ALLOW IN.

## Security posture

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probes E, F, M).

> **Host is hardened (2026-07-11).** T-0102 sshd, T-0103 UFW, T-0104 fail2ban, T-0105 operator users — all P1 tasks complete. Remaining gaps: auditd (gap #4) and pending package upgrades (gap #5).

### Security gaps (vs QA baseline)

| # | Severity | Gap | Target state (per QA baseline) | Current state | Tracked by |
|---|---|---|---|---|---|
| 4 | HIGH | auditd not installed | active, CIS ruleset | not present | (pending task) |
| 5 | HIGH | 12 pending package upgrades | 0 | 12 outstanding | (pending task) |

### AppArmor

Module loaded. 179 profiles loaded, 103 in enforce mode (stock Ubuntu 26.04 default — same count as QA host).

### fail2ban

**Installed and active** (T-0104, 2026-07-11). fail2ban 1.1.0-9. systemd service `fail2ban.service`: `active` and `enabled`. Jail: `[sshd]` — `bantime = 1h`, `findtime = 10m`, `maxretry = 5`, `ignoreip = 127.0.0.1/8 ::1`. Config: `/etc/fail2ban/jail.local`. Currently banned: 0 (at install time). Journal-based log matching: `_SYSTEMD_UNIT=ssh.service + _COMM=sshd`. Note: management workstation IP (`178.89.57.135`) not in `ignoreip` — localhost-only list per execution parameters; run `fail2ban-client unban 178.89.57.135` if needed.

### auditd

**Not installed.** `auditctl` not found.

### Operator users

Three operator accounts provisioned (T-0105, 2026-07-11). All have locked passwords (key-only auth), membership in `sudo` and `sshusers`, and NOPASSWD sudo via individual drop-ins. Verified: 16/16 checks passed (run `2026-07-11-create-operator-users-pro-data-tech-prod-001`, step-07 PASS).

| User | UID | GID | Home | Groups | Sudoers drop-in | Key comment |
|---|---|---|---|---|---|---|
| `tvolodi` | 1000 | 1001 | `/home/tvolodi` | `sudo`, `sshusers`, `docker` (gid 986) | `/etc/sudoers.d/90-tvolodi` (0440) | `ai-dala-infra-mgmt@tvolodi-2026-05-12` (ED25519) |
| `viktor_d` | 1001 | 1002 | `/home/viktor_d` | `sudo`, `sshusers` | `/etc/sudoers.d/90-viktor_d` (0440) | `viktor_d@ai-dala-infra-2026-06-27` (ED25519) |
| `binali_r` | 1002 | 1003 | `/home/binali_r` | `sudo`, `sshusers` | `/etc/sudoers.d/90-binali_r` (0440) | `binali_r@ai-dala-infra-2026-06-27` (ED25519) |

### CI/CD deploy user

Provisioned 2026-07-17 by run [`2026-07-14-ssh-deploy-keys-aiqadam-001`](../../runs/2026-07-14-ssh-deploy-keys-aiqadam-001/) (task [T-0112](../../tasks/T-0112-github-actions-ssh-deploy-keys-aiqadam.md), on-host provisioning verified end-to-end; task remains `in-progress` pending the GitHub Actions secrets paste — see task file).

- **User:** `deploy`, uid 999, gid 981, home `/home/deploy`, shell `/bin/bash`, `useradd --system` (password-locked, no `passwd` set).
- **Groups:** `deploy` (primary, gid 981), `docker` (gid 986), `deploybots` (gid 982), `aiqadam-prod-secrets` (gid 980).
- **No sudo grant:** no `/etc/sudoers.d/90-deploy` file exists (confirmed absent).
- **SSH access:** admitted via the `deploybots` group added to sshd's `AllowGroups` (see "SSH daemon config" table above). `/home/deploy/.ssh/authorized_keys` (mode 600, owner `deploy:deploy`) contains exactly one line: a dedicated ed25519 CI key (`aiqadam-prod-deploy-ci`, workstation path `C:\Users\tvolo\.ssh\aiqadam-prod-deploy-ci`, fingerprint `SHA256:KLpw03147K4mknHrkZvoBv5PqDxWDAAugcc65IEGyUo`), restricted via `command="/opt/apps/aiqadam-prod/deploy/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`. The real login shell (`/bin/bash`, not `/usr/sbin/nologin`) is required for sshd to execute the forced command at all; `no-pty` + `command=`'s unconditional override are the sole and sufficient lockdown (no interactive access possible) — live-verified via both a legitimate forced-command run and a negative-control command-injection attempt, both PASS.
- **`aiqadam-prod-secrets` group:** gid 980, system group, members: `tvolodi`, `deploy`. Grants group-read access to `deploy/.env` (see "AiQadam Prod" section below).
- **Deploy script (real, T-0113):** `/opt/apps/aiqadam-prod/deploy/deploy.sh` (mode 750, owner `deploy:deploy`) — installed 2026-07-17 by run [`2026-07-17-cicd-workflow-aiqadam-001`](../../runs/2026-07-17-cicd-workflow-aiqadam-001/) (task [T-0113](../../tasks/T-0113-github-actions-cicd-workflow-aiqadam-platform.md)), replacing the T-0112 placeholder. Reads the requested git ref from `SSH_ORIGINAL_COMMAND` (set by sshd even under the `authorized_keys` `command=` override), expected format `deploy:<7-40 hex char commit SHA>`, validated by regex then confirmed to exist via `git fetch origin` + `git cat-file -e "<ref>^{commit}"` before any checkout. On success: records the pre-deploy `HEAD` to `.last-deployed-commit.previous`, does `git checkout --detach <ref>`, writes the new `HEAD` to `.last-deployed-commit`, then runs `docker compose -p aiqadam-prod -f docker-compose.prod.yml up -d --build`. Never runs `git clean` (the `deploy/` directory — compose files, `.env`, `deploy.sh` itself — is untracked by git and must survive every deploy; only a hard rule in the script's own header comment enforces this, not a technical control). Pre-replacement backup preserved at `/opt/apps/aiqadam-prod/deploy/deploy.sh.pre-T0113.20260717T081828Z.bak`. Rollback markers (once first invoked): `/opt/apps/aiqadam-prod/deploy/.last-deployed-commit` (current deployed SHA) and `.last-deployed-commit.previous` (prior SHA). **Syntax-checked only (`bash -n` → OK), NOT yet invoked against the running stack** — no `.last-deployed-commit` file exists yet; the first real invocation is T-0115's job, gated by the `production` GitHub Environment's required reviewer.
- **`deploy` user's `tvolodi`-group grant (unplanned, added 2026-07-17, T-0113):** the app checkout (`/opt/apps/aiqadam-prod/`, including `.git/` and `deploy/`) is owned `tvolodi:tvolodi` mode `775`/`755` — the same structural gap found and fixed on QA. `deploy` was added as a secondary member of the `tvolodi` group (`sudo usermod -aG tvolodi deploy`) preventively, so the script is ready for its first real use, without running any git command as `deploy` on this host during this task. Reversible (`sudo gpasswd -d deploy tvolodi` to undo).
- **Remaining gap (not part of this host's state):** the private key and host key for this CI account are not yet pasted into GitHub Actions repository secrets (`PROD_SSH_DEPLOY_KEY`, `PROD_SSH_HOST_KEY` in `aiqadam/ai-qadam-platform`) — a manual user action tracked by task T-0112, which stays `in-progress` until confirmed done.
- **No regression to Penpot:** the sshd reload (Step 5) and all subsequent steps were gated by a mandatory Penpot no-regression check (all 7 containers `Up`, external HTTPS 200) both immediately after the reload and again at the end of the run.

## Backups

- **Provider-level snapshots:** **unknown and intentionally not used** (per project policy — consistent with the Hetzner precedent; cf. `wontfix` [T-0001](../../tasks/T-0001-enable-hetzner-snapshots.md)).
- **Application-level backups:** Stalwart mail data (T-0117, 2026-07-19) — see below. No other backup tools (restic, borg, duplicity) installed for Penpot/AiQadam prod. No other project backup directories.
- **Application data (T-0108, 2026-07-11):** Penpot Docker volumes: `penpot_penpot_postgres_v15` (PostgreSQL 15 database), `penpot_penpot_assets` (uploaded files). No automated backup strategy configured yet (follow-on task to be scheduled after T-0109).
- **Stalwart mail data (T-0117, 2026-07-19):** local-disk-only tarball backup at `/var/backups/stalwart-mail/` — `tar czf` of `/opt/stalwart-mail/{var-lib-stalwart,etc-stalwart}`. First backup: `stalwart-data-20260719T072302Z.tar.gz` (750998 bytes, 29 entries). Taken manually this run; a daily cron/systemd-timer with 14-day local retention was recommended as a follow-on but not built into this pass.

## apt posture

Verified by discovery run `2026-07-11-discovery-pro-data-tech-prod-001` (probe L).

- **Pending upgrades:** **12** (unattended-upgrades has not yet applied them; last apt activity `2026-07-07 11:23` UTC — cloud-init bootstrap).
- **unattended-upgrades:** active and enabled (daily cycle).
- **Allowed-Origins:** stock Ubuntu (`security`, `ESM apps`, `ESM infra`).
- **Sources:** deb822 format at `/etc/apt/sources.list.d/ubuntu.sources` (Ubuntu 26.04 stock). No third-party repositories.
- **Kernel:** `7.0.0-14-generic` — the same kernel version the QA host ran before T-0099 upgraded it to `7.0.0-27-generic`.

## Native systemd services (running)

21 services running at discovery time — all standard Ubuntu cloud-image base. No application services.

| Unit | User | What it does |
|---|---|---|
| `ssh.service` | root | sshd (HARDENED — T-0102; socket-activated via `ssh.socket`) |
| `ufw.service` | root | **Enabled and active** — deny-incoming default, allow outgoing, 22/tcp 80/tcp 443/tcp ALLOW IN (v4+v6), DEFAULT_FORWARD_POLICY="DROP". Configured 2026-07-11 via T-0103. |
| `fail2ban.service` | root | Brute-force protection — sshd jail enabled (`bantime=1h`, `findtime=10m`, `maxretry=5`, `ignoreip=127.0.0.1/8 ::1`); config at `/etc/fail2ban/jail.local`. Installed 2026-07-11 via T-0104. || `docker.service` | root | Docker Engine — active, enabled. CE 29.6.1, Compose plugin v5.3.1, containerd.io 2.2.6 as runtime. UFW after.rules DOCKER-USER coexistence block in place (T-0106, 2026-07-11). || `chrony.service` | root | NTP client (Ubuntu 26.04 default) |
| `unattended-upgrades.service` | root | Automatic security upgrades (daily) |
| `qemu-guest-agent.service` | root | pro-data.tech KVM guest agent |
| `cloud-init.{local,network,main,config,final}.service` | root | Cloud-init bootstrap stages |
| `snapd.service` | root | Snap daemon |
| `apparmor.service` | root | AppArmor MAC (179 profiles, 103 enforce) |
| `systemd-resolved.service` | root | Local DNS stub on 127.0.0.53 / 127.0.0.54 |
| `nginx.service` | root | nginx 1.28.3 reverse proxy — **active** and **enabled** (T-0109, 2026-07-11; T-0111, 2026-07-13). HTTP→HTTPS redirect on port 80; HTTPS TLS termination on port 443 for `penpot.aiqadam.org` (proxies to `localhost:9001`) and `aiqadam.org` (proxies to `127.0.0.1:3115`, T-0111). |
| `certbot.timer` | root | Let's Encrypt auto-renewal timer — **active** and **enabled** (T-0109, 2026-07-11; T-0111, 2026-07-13). Renews certs for `penpot.aiqadam.org` (expires 2026-10-09) and `aiqadam.org` (expires 2026-10-11). |
| `rsyslog.service`, `cron.service`, `dbus.service`, `fwupd.service`, `getty@tty1.service`, `ModemManager.service`, `multipathd.service`, `networkd-dispatcher.service`, `polkit.service`, `serial-getty@ttyS0.service`, `systemd-journald.service`, `systemd-logind.service`, `systemd-networkd.service`, `systemd-udevd.service`, `udisks2.service`, `user@0.service` | root | Standard Ubuntu cloud-image base |

Also present in the image but noted: `open-vm-tools.service` (enabled but not running — unusual for a KVM host; likely baked into the provider image alongside `qemu-guest-agent`).

## Open tasks affecting this host

Pending work that affects this host is tracked in [`tasks/`](../../tasks/). See [`tasks/_index.md`](../../tasks/_index.md) for the current open set.

## Change log

| Date | Run ID | Change |
|---|---|---|
| 2026-07-11 | `2026-07-11-discovery-pro-data-tech-prod-001` | T-0101: Initial discovery run. Host populated with hardware, OS, access, network, firewall, sshd, security, and backup findings. State: fresh Ubuntu 26.04 cloud image, no project services, no Docker, no nginx, no host firewall, no fail2ban, no auditd. 5 CRITICAL/HIGH security gaps identified; tracked as T-0102 through T-0105. Notable: eth1 192.168.0.3/24 private LAN (absent on QA host). |
| 2026-07-11 | `2026-07-11-harden-sshd-pro-data-tech-prod-001` | T-0102: sshd hardened — PermitRootLogin prohibit-password, PasswordAuthentication no, KbdInteractiveAuthentication no, AllowGroups sshusers (root in sshusers; transitional until T-0105), MaxAuthTries 3, LoginGraceTime 30, X11Forwarding no, hardened KexAlgorithms/Ciphers/MACs. Drop-in files 40-disable-password.conf and 40-ai-dala-infra.conf created (mode 644). sshd reloaded; 25/25 checks passed. |
| 2026-07-11 | `2026-07-11-install-ufw-pro-data-tech-prod-001` | T-0103: UFW installed and activated — deny-incoming default, allow outgoing, 22/tcp 80/tcp 443/tcp ALLOW IN (v4+v6), DEFAULT_FORWARD_POLICY="DROP". Backup at /var/backups/ufw-defaults-pre-T0103.bak. Security gap #1 (UFW inactive/CRITICAL) resolved. |
| 2026-07-11 | `2026-07-11-install-fail2ban-pro-data-tech-prod-001` | T-0104: fail2ban 1.1.0-9 installed and activated — sshd jail enabled, bantime=1h, findtime=10m, maxretry=5, ignoreip=127.0.0.1/8 ::1, journal backend. Config at /etc/fail2ban/jail.local. Security gap #2 (fail2ban not installed/HIGH) resolved. |
| 2026-07-11 | `2026-07-11-create-operator-users-pro-data-tech-prod-001` | T-0105: Operator users tvolodi (uid 1000), viktor_d (uid 1001), binali_r (uid 1002) created — sshusers+sudo group membership, NOPASSWD sudoers drop-ins (mode 0440), ed25519 keys installed. Root remains in sshusers (break-glass, permanent). Security gap #3 (no operator users/HIGH) resolved. 16/16 checks passed. All P1 security tasks complete; security baseline established. |
| 2026-07-11 | `2026-07-11-install-docker-pro-data-tech-prod-001` | T-0106: Docker CE 29.6.1 + Compose plugin v5.3.1 installed from official Docker apt repo (keyring method, resolute stable channel). docker.service enabled+active. containerd.io 2.2.6 as runtime. UFW after.rules appended with DOCKER-USER coexistence block (eth0-scoped MASQUERADE 172.16.0.0/12); backup at /var/backups/ufw-after.rules-pre-T0106.bak. tvolodi added to docker group (gid 986). `docker run hello-world` verified. |
| 2026-07-11 | `2026-07-11-deploy-penpot-pro-data-tech-prod-001` | T-0108: Penpot 2.16 deployed via Docker Compose at /opt/penpot/ (7 containers: penpot-frontend, penpot-backend, penpot-exporter, penpot-mcp, penpot-postgres, penpot-valkey, penpot-mailcatch). MCP enabled. PENPOT_PUBLIC_URI=https://penpot.aiqadam.org. Frontend HTTP 200 on localhost:9001. Mailcatch bound to 127.0.0.1:1080. .env mode 600 (owner root). nginx+HTTPS pending (T-0109). |
| 2026-07-11 | `2026-07-11-nginx-letsencrypt-penpot-aiqadam-org-001` | T-0109: nginx 1.28.3 installed and active; vhost `/etc/nginx/sites-available/penpot.aiqadam.org` created (HTTP→HTTPS redirect, HTTPS TLS termination, WebSocket/SSE/general proxy to localhost:9001). Let's Encrypt cert obtained (ECDSA, expires 2026-10-09, CA YE1); certbot.timer active for auto-renewal. `https://penpot.aiqadam.org` confirmed HTTP 200 from external workstation. Penpot fully operational. |
| 2026-07-13 | `2026-07-13-setup-aiqadam-prod-infra-001` | T-0111: AiQadam prod app stack deployed — Compose project `aiqadam-prod` at `/opt/apps/aiqadam-prod/` (git HEAD `dfd2a7c`; 3 containers: `aiqadam-prod-postgres-1` postgres:16 on `3114`, `aiqadam-prod-oidc-stub-1` nginx:alpine on `127.0.0.1:9998`, `aiqadam-prod-api-1` on `127.0.0.1:3115`), dedicated `aiqadam_prod` database; additive nginx vhost `/etc/nginx/sites-available/aiqadam.org` (bare apex only); Let's Encrypt cert for `aiqadam.org` obtained (ECDSA, expires 2026-10-11); Cloudflare apex A record `bf1113199732117bd147ebd87d6e356d` repointed `212.20.151.29`→`95.46.211.224`, `proxied` true→false. `https://aiqadam.org/health` confirmed 200; Penpot confirmed unregressed (7/7 containers, external 200) at every checkpoint. Corrected prior landscape documentation error: the RSA `.ppk` key does NOT work for `tvolodi` (root break-glass only) — `ai-dala-infra` ED25519 is the correct `tvolodi` key, matching the QA host's pattern. Known gap: no Redis/Valkey service (ioredis ECONNREFUSED, non-blocking) — tracked as a new task. |
| 2026-07-17 | `2026-07-14-ssh-deploy-keys-aiqadam-001` | T-0112 on-host provisioning done (task remains in-progress — GitHub Actions secrets paste still pending) — `deploy` system user created (uid 999, shell /bin/bash, groups deploy/docker/deploybots/aiqadam-prod-secrets), forced-command-restricted via `/home/deploy/.ssh/authorized_keys`; `deploybots` group added to sshd `AllowGroups`; `aiqadam-prod-secrets` group created, granting `deploy` read access to `/opt/apps/aiqadam-prod/deploy/.env` (group/mode changed to `tvolodi:aiqadam-prod-secrets 640`, content untouched); placeholder `deploy.sh` installed at `/opt/apps/aiqadam-prod/deploy/deploy.sh` (mode 750, owner deploy:deploy). Live SSH end-to-end test + negative control both PASS; Penpot confirmed unregressed (7/7 containers, external 200) throughout. |
| 2026-07-17 | `2026-07-17-cicd-workflow-aiqadam-001` | T-0113 in-progress (PR #15 open, not merged) — placeholder `deploy.sh` replaced with real deploy logic reading a git ref from `SSH_ORIGINAL_COMMAND` (format `deploy:<7-40 hex sha>`), regex + `git cat-file -e` validated, rollback markers `.last-deployed-commit`/`.last-deployed-commit.previous` (written on first invocation), `git clean` never invoked; backup at `deploy.sh.pre-T0113.20260717T081828Z.bak`. Unplanned fix: `deploy` user added to `tvolodi` group (preventive, matching the QA fix) to grant future write access to the `tvolodi`-owned checkout. Syntax-checked (`bash -n` OK) but NOT invoked against the running stack — no container restarted, `.last-deployed-commit` absent by design; Penpot and the `aiqadam-prod` stack both confirmed unregressed (unchanged `Created` timestamps, external 200). |
| 2026-07-19 | `2026-07-19-install-mail-server-aiqadam-001` | T-0117 done — Stalwart mail server deployed (Compose project `stalwart-mail` at `/opt/stalwart-mail/`, image `stalwartlabs/stalwart:v0.16`, UID 2000); `stalwart-cli` installed at `/home/tvolodi/.cargo/bin/stalwart-cli`; UFW opened 25/465/587/993; `Domain aiqadam.org` wired `dnsManagement`/`certificateManagement` both Automatic (DNS scoped to `publishRecords: {tlsa:true}`); Let's Encrypt cert (internal ACME, DNS-01) live for SMTP/IMAP/submission; nginx vhost `mail.aiqadam.org` reusing an orphaned attempt-1 certbot cert for the admin UI; test mailbox `test@aiqadam.org` created; Cloudflare `aiqadam.org` MX/A/SPF/DKIM/DMARC cut over to `95.46.211.224`, 8 stale third-party records deleted (webmail, mta-sts×2, ua-auto-config×2, caldavs/carddavs/pop3s SRV), plus 2 more (autoconfig, autodiscover CNAMEs) deleted in a follow-up attempt after validator review; local-disk backup taken. Penpot and AiQadam-prod confirmed unregressed throughout. Took 9 executor attempts (image/API/Bootstrap/restart/encoding/DNS-scoping issues along the way — see task file Result section and run `.attempts/` for full history). |
| 2026-07-20 | (manual, no run — outside the 8-step workflow) | Stalwart auto-ban incident: the mail server's built-in scan-detection banned the Docker bridge gateway IP (`172.19.0.1`, `reason: portScanning`, permanent), blocking all external access to the admin UI/SMTP/IMAPS while `docker exec`-based healthchecks stayed green. Diagnosed via a peer-container JMAP query against `x:BlockedIp` (the normal CLI/docker-proxy path was itself blocked); the one bad entry was deleted (3 legitimate external-scanner bans left in place) and the container restarted to clear an in-memory copy. Root-cause hardening tracked in T-0121 (not yet done). Also created `postmaster@aiqadam.org` (id `f`) as the intake address for `shared/mail-provisioning-protocol.md` (new file, documents the mailbox-request process). |
| 2026-07-21 | `2026-07-21-harden-stalwart-auto-ban-001` | T-0121 done — (A) Stalwart `AllowedIp` entries for `172.19.0.1` (id `i9yv13qeaaqa`) and `172.19.0.0/16` (id `i9yv3mloabaa`) created permanently (JMAP `x:AllowedIp/set`, `expiresAt: null`); (B) nginx `mail.aiqadam.org` vhost restricted to loopback-only (`allow 127.0.0.1; deny all;` in `location /`, external HTTPS returns 403); (C) `proxyTrustedNetworks` investigated — found to enable HAProxy PROXY protocol binary, not X-Forwarded-For header trust; reverted to `{}`; deferred as follow-on; (D) monitoring cron `/usr/local/bin/mail-health-check.sh` every 5 min installed (checks HTTPS+25/587/993, logs to syslog); Stalwart v0.16.13; container healthy; all mail ports 25/587/993 externally reachable; Penpot and AiQadam prod unregressed. |
