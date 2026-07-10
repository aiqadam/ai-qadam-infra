---
run_id: 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090
inputs_read:
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-01-task-reader.md
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/app-registry.md
  - tasks/_index.md
artifacts_changed: []
next_step_hint: Send to solution-designer (step 04) — all five preconditions are green; the UFW-FORWARD reconciliation, the Docker install, and the qadam-test.stack are the three primary design decisions still to make.
---

## Summary

`pro-data-tech-qa` (95.46.211.230) is in the exact prerequisite state T-0090 requires: sshd hardened (T-0093 done), UFW active with `DEFAULT_FORWARD_POLICY="DROP"` (T-0094 done — the DROP is the next operator action, not a blocker today), fail2ban installed with sshd jail (T-0095 done), and three operator users with NOPASSWD sudo in the `sshusers` group (T-0097 done). The ai-qadam prod reference Compose stack is fully cataloged (Next.js app + Postgres 16 db; 2 containers; current prod path `/var/www/ai-qadam/`, current prod port `3000`); the QA instance will mirror this minimal shape — but with the QA port slot `127.0.0.1:3112`, the QA DNS name `qadam-test.ai-dala.com`, and compose project `ai-qadam-test`. The local source checkout is confirmed at `c:\Users\tvolo\dev\ai-dala\aiqadam` (canonical ai-qadam monorepo), distinct from the older sibling `c:\Users\tvolo\dev\ai-dala\AI-Qadam\aiqadam\` doc drop. No app-registry entry for `ai-qadam` exists yet — T-0090 creates it.

## Details

### Live baseline verification (pro-data-tech-qa, 2026-07-08)

Probes executed via `ssh root@95.46.211.230` (provider key from `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk`, OpenSSH-format RSA-2048 despite the `.ppk` extension):

| Probe | Expected | Actual | Status |
|---|---|---|---|
| `systemctl is-active ssh` | active | `active` | PASS — T-0093 hardened, `MaxAuthTries 3`, `LoginGraceTime 30`, `AllowGroups sshusers`, key-only, `PermitRootLogin prohibit-password` |
| `systemctl is-active ssh` (root-via-key) | active | `active` | PASS — sshd accepted the provider RSA key |
| `systemctl is-active fail2ban` | active | `active` | PASS — T-0095 (7/7 checks); sshd jail with `banaction=iptables-multiport`, `maxretry=3`, `bantime=600s`, `findtime=600s`; mgmt workstation IP `178.89.57.135` in `ignoreip` |
| `sudo ufw status verbose` | deny-in / allow-out / IPv6-on / FWD-DROP / allow 22/tcp | `Status: active`; `Default: deny (incoming), allow (outgoing), disabled (routed)`; `22/tcp ALLOW IN Anywhere` (v4+v6, comment `sshd - operator access T-0094 baseline`) | PASS — T-0094 done; FWD-DROP is deliberate and the next operator action (T-0090 § step 6a) — see "Issues / risks" below |
| `grep DEFAULT_FORWARD_POLICY /etc/default/ufw` | `"DROP"` | `DEFAULT_FORWARD_POLICY="DROP"` | CONFIRMED — must be flipped to `ACCEPT` (option a) OR Docker `"iptables": false` (option b) BEFORE `apt install docker.io` |
| `id tvolodi viktor_d binali_r` | users exist, in `sshusers` (gid 1000) | `tvolodi` (uid 1001, groups `tvolodi, sudo, users, sshusers`), `viktor_d` (uid 1002, same), `binali_r` (uid 1003, same) | PASS — T-0097 done (16/16 checks); multi-PC SSH acceptance criterion met for `tvolodi`; server-side `ssh-keygen -lf` parse verified for `viktor_d` / `binali_r`; live handshakes for those two remain deferred to each operator's own workstation (by design) |
| `getent group sshusers` | `root,tvolodi,viktor_d,binali_r` | `sshusers:x:1000:root,tvolodi,viktor_d,binali_r` | PASS — 4 members |
| `/var/www/` | absent | `No such file or directory` | PASS — no prior app installs on this host |
| `/opt/apps/` | absent | `No such file or directory` | PASS — fresh start for the QA app stack |

### Relevant facts (sourced from landscape)

**Host facts (pro-data.tech-qa)** — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Public IPv4: `95.46.211.230`; hostname: `drkkrgm-qa-instance`; provider: pro-data.tech (NOT Hetzner); role: `unassigned`; `last_verified: 2026-07-08`.
- 8 vCPU / 15 GiB RAM / 145 GB root disk; Ubuntu 26.04 LTS (kernel 7.0.0-14-generic); 0 pending apt upgrades.
- sshd hardened (T-0093 done 2026-07-08; 21/21 PASSED); AllowGroups sshusers; provider key preserved as break-glass in `/root/.ssh/authorized_keys`.
- UFW active (T-0094 done 2026-07-08; 10/10 PASSED). Defaults: `DEFAULT_FORWARD_POLICY="DROP"` (deliberate divergence — T-0090 step 6a reconciles), `DEFAULT_INPUT_POLICY="DROP"`, `DEFAULT_OUTPUT_POLICY="ACCEPT"`, `IPV6=yes`. 22/tcp allowed from any source per 2026-07-08 user decision.
- fail2ban installed (T-0095 done 2026-07-08; 7/7 PASSED); sshd jail via iptables-multiport.
- 3 operator users (T-0097 done; 16/16 PASSED): `tvolodi` (uid 1001, workstation-validated live SSH), `viktor_d` (uid 1002), `binali_r` (uid 1003). All in `sshusers` + `sudo` + `users`. NOPASSWD sudo via `/etc/sudoers.d/90-<user>` (0440, root:root, `visudo -c` clean).
- SSH key on mgmt workstation: `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048; the `.ppk` extension is misleading — see T-0098 hygiene follow-on); ssh config alias `pro-data-tech-qa` points to `95.46.211.230` as `root` with this identity.
- No Hetzner Cloud Firewall analogue exists; defense-in-depth is UFW + AllowGroups sshusers + fail2ban (per 2026-07-08 user decision).
- No app-registry entry for `pro-data-tech-qa` today; the role needs assigning. Cloudflare doesn't currently serve any DNS for this IP.

**ai-qadam prod reference pattern** — _source: `landscape/hosts/hetzner-prod.md`, `landscape/services.md`, and direct probe (today)_
- The prod ai-qadam stack (`/var/www/ai-qadam/docker-compose.yml`, deployed on `hetzner-prod` per `landscape/services.md` rows "Running Compose projects → ai-qadam" and "Running containers → ai-qadam-app-1 / ai-qadam-db-1"): 2 services:
  - `app` — `ai-qadam-app` local build, image built from `Dockerfile` at `/var/www/ai-qadam/Dockerfile`, port `3000 → 3000`, currently bound to `0.0.0.0` (drift item T-0036 superseded by T-0062 — note for future), env: `DATABASE_URL=postgresql://aiqadam:aiqadam_secret@db:5432/aiqadam`, `NODE_ENV=production`. `depends_on: db (condition: service_healthy)`.
  - `db` — `postgres:16-alpine`, env: `POSTGRES_USER=aiqadam`, `POSTGRES_PASSWORD=aiqadam_secret`, `POSTGRES_DB=aiqadam`. Healthcheck: `pg_isready -U aiqadam` every 5s. Volume `pgdata` named.
- Named volume: `pgdata` (single volume for the db; no app volume).
- Build context: project root (`./`); Dockerfile is `./Dockerfile`.
- Reverse proxy (hetzner-prod nginx vhost `ai-qadam.conf`): listens 80 (301→443) + 443 ssl http2; `ssl_certificate /etc/ssl/cloudflare/ai-dala.pem` + `/etc/ssl/cloudflare/ai-dala.key`; `client_max_body_size 50M`; `location /` proxies to `http://127.0.0.1:3000` with WebSocket upgrade headers + 300s proxy_read_timeout; `location /_next/static` proxies with `proxy_cache_valid 200 60m` + `Cache-Control "public, immutable"`; `location ~ /\. { deny all; }`.
- DNS: `ai-qadam.ai-dala.com` is a Cloudflare-proxied A record → `91.98.28.126` (record ID implicit; zone `ai-dala.com`, zone ID `4a2748e92ef7ddaac7fddf375be2da53`).
- Env-file shape (`.env` on hetzner-prod, mode 600 root:root, keys-only): `DATABASE_URL`, `NEXT_PUBLIC_SITE_URL`, `NEXT_PUBLIC_TELEGRAM_URL`, `NODE_ENV`. Values never pasted in this repo.
- App-backup schedule on hetzner-prod already covers `ai-qadam-db-1` (db: `aiqadam`, user: `aiqadam`); T-0090 does NOT need to mirror this on pro-data-tech-qa — backups are T-0098 follow-on.

**Workflow scope constraints (this run)** — _source: `tasks/_index.md`, `landscape/README.md`_
- `T-0090` frontmatter: `kind: task, status: pending, priority: P1, blocked_by: [T-0093, T-0094], related: [T-0093, T-0094, T-0095, T-0096, T-0097, T-0098], workflow: infrastructure, estimated_blast_radius: high, estimated_reversibility: full, affects: [landscape/hosts/pro-data-tech-qa.md, landscape/services.md]`.
- All four `blocked_by` / `related` dependencies resolved (T-0093, T-0094, T-0095, T-0097 all `status: done`).
- `T-0062` (remove ai-qadam from hetzner-prod) is `status: pending, P0, kind: task` — NOT blocking T-0090 and explicitly NOT in scope. The QA stack is additive; prod stack stays until T-0062 runs separately.
- `T-0096` (auditd) `P3 observation` — deferrable per T-0088 precedent, not in T-0090 scope.
- `T-0098` (host-level backup strategy) `P3 observation` — explicitly deferred until role lands. T-0090 lands the role, so T-0098 is the natural follow-on but out of scope here.
- No Hetzner Cloud Firewall API or pro-data.tech control-plane firewall API in this workflow; all network changes are UFW-on-host + nginx-on-host.

**Cloudflare + DNS** — _source: `landscape/cloudflare.md`, `landscape/domains.md`_
- Zone `ai-dala.com` (zone ID `4a2748e92ef7ddaac7fddf375be2da53`) already hosts 13 DNS records (12 proxied, 1 DNS-only for `git.ai-dala.com`).
- New A record needed: `qadam-test.ai-dala.com` → `95.46.211.230`, `proxied: true`. Mirror of the `bilimbaga-test.ai-dala.com` pattern (record ID `e0ab20b87a1a1504a00587f8550ef9d2`, added 2026-05-14 by T-0064). DNS-records → 14.
- Universal SSL already covers `*.ai-dala.com` (Google Trust Services, active) — no edge-cert step needed for the QA hostname.
- Origin cert: `/etc/ssl/cloudflare/ai-dala.pem` + `/etc/ssl/cloudflare/ai-dala.key` lives on hetzner-prod only. **Two options for TLS-at-origin on pro-data-tech-qa** (decision for solution-designer): (a) copy the existing cert pair from hetzner-prod via `scp` and trust both .pem + .key (mode 600) onto the QA host; (b) issue a fresh Cloudflare origin cert in the Cloudflare console for `*.ai-dala.com` (the cert would be identical; same-key reuse is blocked by Cloudflare — must reissue per host); (c) DNS-only mode (`proxied: false`, like `git.ai-dala.com`) which avoids origin-TLS entirely.
- Write token: `C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token` — PRESENT and confirmed by Cloudflare landscape (token id `711c7e77c4a74b4d0589f0885838ec85` for read; write token is separately scoped to DNS:Edit on the ai-dala.com zone).
- Both zones run on Cloudflare Universal SSL (ai-dala.com: Google CA, bizdala.com: Let's Encrypt); HSTS enabled at edge (`max-age=300`); min_tls_version 1.2; always_use_https on; ssl mode `strict`. All zone settings already hardened.

**App-registry port convention** — _source: `shared/app-registry.md`_
- Test backend port range: `127.0.0.1:3110–3119`. Currently in use: `3110` (productfactory-test), `3111` (bilimbaga-test). **Next free test slot: `127.0.0.1:3112` — T-0090 claims it for qadam-test.**
- Prod backend port range: `127.0.0.1:3100–3109`. Currently: `3100` reserved for productfactory-prod (not yet deployed), `3101` reserved for bilimbaga-prod. ai-qadam prod on hetzner-prod binds `0.0.0.0:3000` (legacy from before the registry existed — out of scope for T-0090).
- Test subdomain convention: `<app>-test.ai-dala.com`. T-0090 claims `qadam-test.ai-dala.com` (matches the prefix `qadam` because the official app registry app-id candidate is `ai-qadam` but the subdomain follows the user-facing name `qadam`).
- No `ai-qadam` entry exists today in `shared/app-registry.md` — only `ProductFactory` and `BilimBaga`. **T-0090 adds the registry entry** (test environment only — prod stays on hetzner-prod until T-0062).

**Canonical ai-qadam source on workstation** — _source: direct probe `Get-ChildItem 'c:\Users\tvolo\dev\ai-dala' | Where-Object Name -Like '*qadam*'` and `Get-ChildItem 'c:\Users\tvolo\dev\ai-dala\aiqadam'`_
- Canonical path: **`c:\Users\tvolo\dev\ai-dala\aiqadam`** (lowercase monorepo, contains `apps/`, `packages/`, `infrastructure/`, `tools/`, etc., all conventional monorepo scaffolding). Last modified 07.07.2026.
- Adjacent artefact: `c:\Users\tvolo\dev\ai-dala\AI-Qadam\aiqadam\` (capital A, single subdir of an `AI-Qadam\` doc drop; appears to be either a doc-only mirror or stale copy). Contains `AI-CONTEXT.md` and `People.md` — NOT a git checkout, NOT the build source.
- The QA server-side repo will be cloned from the canonical lowercase source. If the ai-qadam repo is private, a `read-only` deploy key on GitHub will be required (analogous to `bilimbaga-deploy` on hetzner-prod per T-0066); if public, plain `git clone https://github.com/<owner>/aiqadam.git` suffices. **Step 04 must detect private-vs-public by reading the source's `.git/config` remote URL.**

### Stale or stub files encountered

- `landscape/hosts/pro-data-tech-qa.md` — `last_verified: 2026-07-08`, `status: populated` — fresh (same day; reflects all T-0093 / T-0094 / T-0095 / T-0097 work). No staleness.
- `landscape/services.md` — `last_verified: 2026-07-08`, `status: populated` — fresh; has the pro-data-tech-qa section. No staleness.
- `landscape/cloudflare.md` — `last_verified: 2026-05-26`, `status: populated` — **24-day-old** but covers the immutable basis (zone IDs, tokens, SSL posture); the only new content needed for T-0090 is a 1-record DNS addition. Acceptable for T-0090 without re-discovery. **Step 08 must update `last_verified` and add the new record to the table.**
- `landscape/domains.md` — `last_verified: 2026-05-15` — **37-day-old**, but only the registry counts (`landscape/cloudflare.md` is the per-zone detail). Step 08 should re-stamp this too if there's any in-scope change; for the bare `qadam-test.ai-dala.com` A record, `landscape/cloudflare.md` is the primary key.
- `shared/app-registry.md` — `last_updated: 2026-06-08` — intentional; registry is only updated when entries change, not on discovery cadence.
- `tasks/_index.md` — generated from `tasks/` on every step 08; current as of 2026-07-08 entries (T-0093/94/95/97 `done`, T-0090 `pending`).

### Gaps requiring live discovery

- **None blocking step 04.** All facts needed by solution-design are already in landscape or were probed live this step:
  - confirmed `/var/www/ai-qadam/docker-compose.yml` shape on hetzner-prod ✓
  - confirmed prod env keys (redacted) ✓
  - confirmed canonical local source path ✓
  - confirmed SSH config + tokens on workstation ✓
  - confirmed next free test port is `3112` ✓
- **Optional pre-execution checks (recommended; can be folded into executor step 06):**
  1. **Private-vs-public determination of `c:\Users\tvolo\dev\ai-dala\aiqadam`.** Run `git -C 'c:\Users\tvolo\dev\ai-dala\aiqadam' config --get remote.origin.url` and `git -C 'c:\Users\tvolo\dev\ai-dala\aiqadam' ls-remote --heads origin` (the latter is a non-destructive connectivity probe). If `403` → private repo → deploy-key path required (analogous to `bilimbaga-deploy` on hetzner-prod; tracked separately). If `200` → public → plain `git clone https://...` on the QA host.
  2. **Default compose project name.** The prod compose file has NO top-level `name:` field → Compose defaults to `ai-qadam` (directory basename). The QA compose file MUST set `name: ai-qadam-test` to keep containers/networks/volumes namespaced from the prod stack if/when someone later migrates the QA stack; this is the user's explicit instruction in the run prompt.
  3. **Port-allocation confirmation.** A `grep -E '127\.0\.0\.1:(311[0-9])' /etc/nginx/sites-enabled/*.conf` on pro-data-tech-qa after nginx lands would prove `3112` is unclaimed; for now the convention is unambiguous because nginx doesn't exist yet.
  4. **`/etc/ssl/cloudflare/ai-dala.pem` provenance.** If solution-designer picks option (a) — copy cert from hetzner-prod — confirm the .pem + .key are still intact and readable on hetzner-prod before drafting the copy step. (`stat /etc/ssl/cloudflare/ai-dala.pem` on hetzner-prod.)

## Issues / risks

- **UFW `DEFAULT_FORWARD_POLICY="DROP"` is the only blocking prerequisite still on the host itself**, but it's a one-line operator action (`sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw && ufw reload`) and the user has approved this approach (option a in T-0090). Executor step 06 must run it BEFORE `apt install docker.io`. A verify step (`cat /proc/sys/net/ipv4/ip_forward && iptables -L FORWARD | head`) should follow the reload. Solution-designer must sequence this explicitly as step 6a to avoid the failure mode documented in step-01 ("compose up succeeds, curl from external host times out, hard to debug").

- **Cloudflare origin cert is single-source on `hetzner-prod`.** Solution-designer must pick one of three options for TLS-at-origin and surface for user approval:
  - **(a)** Copy `/etc/ssl/cloudflare/ai-dala.{pem,key}` from hetzner-prod to pro-data-tech-qa (mode 600 root:root). Same cert, two locations — works fine (Cloudflare origin certs are not unique per origin) but creates a new file on the QA host that needs to be tracked.
  - **(b)** Issue a fresh Cloudflare origin cert in the Cloudflare console for `*.ai-qadam-test.ai-dala.com` (or reuse `*.ai-dala.com` if possible). One extra workflow step.
  - **(c)** Use `proxied: false` on the new A record (DNS-only) like `git.ai-dala.com`. No TLS-at-origin; Cloudflare edge terminates and the host serves cleartext on 80. **Loses origin-side encryption in case a future attacker bypasses Cloudflare**, but matches the `git.ai-dala.com` precedent in this project.
  - Either (a) or (c) is the lowest-friction default. User decision.

- **UFW needs new public-internet allow rules for `qadam-test.ai-dala.com` to work** (port 80 + 443 from any source, just like hetzner-prod). Currently only 22/tcp is allowed. Solution-designer should add the rules in the same step that installs nginx (otherwise the vhost will sit under a default-deny). **State-changing UFW amendment** that must be enumerated in user approval.

- **No nginx on pro-data-tech-qa yet.** T-0090's stack needs a reverse-proxy, but the host doesn't have nginx installed. Solution-designer should include `apt install nginx` + the new vhost in the same step.

- **The prod `ai-qadam-app-1` is bound to `0.0.0.0:3000` on hetzner-prod** (per `landscape/services.md`); the QA stack must bind to `127.0.0.1:3112` instead (port-range convention from `shared/app-registry.md`). Solution-designer must NOT copy the prod port mapping verbatim — must override to `127.0.0.1:3112:3000` (host → container port). The db stays internal-only, same as prod.

- **`role:` field for `pro-data-tech-qa` frontmatter** is a step-08 deliverable; the user's run prompt says "role is `ai-qadam` QA" but doesn't pick the exact string. The two natural choices:
  - `ai-qadam-qa` (matches the task id and is unambiguous)
  - `qadam-test` (matches the DNS prefix and sounds less formal)
  - Should be flagged for user decision; solution-designer can pick one and surface.

- **Source repo private-vs-public detection** must happen before drafting the `git clone` step. If private, a `qadam-deploy` SSH key analogous to `bilimbaga-deploy` is needed (out of T-0090 scope; a new task should spawn if so — solution-designer should report the finding).

- **Composer's `name:` key** must be set to `ai-qadam-test` on the QA compose (NOT `ai-qadam`, which would collide with the prod project's container/network/volume namespace if/when prod stack migrates). This is explicit in the user's run prompt: "use `ai-qadam-test` as the compose project name".

- **The compose file MUST override the `DATABASE_URL`** to point at the in-stack `db` (`postgresql://aiqadam:aiqadam_secret@db:5432/aiqadam`); do NOT copy the prod `NEXT_PUBLIC_SITE_URL` / `NEXT_PUBLIC_TELEGRAM_URL` values from hetzner-prod — generate fresh values for the QA domain. The Postgres credentials should be unique to the QA host (re-using `aiqadam`/`aiqadam_secret` from prod is fine — they're only meaningful inside the db container — but should still be documented in the QA `.env` file).

- **`/opt/apps/` and `/var/www/` are both absent on pro-data-tech-qa.** Hetzner-prod uses `/opt/apps/<app>-{test,prod}/` for new installs and `/var/www/<app>/` for legacy ones. The QA stack should follow the modern convention: **`/opt/apps/ai-qadam-test/`** for the repo checkout (mirroring `bilimbaga-test` on hetzner-prod) with `docker-compose.yml` and `.env` living there; the running containers can stay project-named `ai-qadam-test` even if the compose file lives in `/opt/apps/ai-qadam-test/deploy/`.

- **`pro-data.tech` control-plane snapshot/backup product** is unknown. Per README § Backups & storage policy, paid provider add-ons are explicitly out of scope; T-0090 should NOT attempt to configure any provider-side product.

## Open questions (optional)

- **(A)** TLS-at-origin on pro-data-tech-qa: option (a) copy cert from hetzner-prod, option (b) reissue, option (c) DNS-only mode? — solution-designer to surface.
- **(B)** Exact `role:` value for `pro-data-tech-qa` frontmatter: `ai-qadam-qa` vs `qadam-test` vs user's preference? — solution-designer to pick and surface.
- **(C)** Is `c:\Users\tvolo\dev\ai-dala\aiqadam` a private repo on GitHub? Determined by `git ls-remote` probe (executor step 06); if private, a follow-on task to register the `qadam-deploy` SSH key must be spawned.
- **(D)** Does the user want T-0062 (remove ai-qadam from hetzner-prod) to run parallel to T-0090 or after? The run prompt does not say. The T-0090 "Why" says "QA instance distinct from the Hetzner production host" (i.e., additive), so default = parallel/independent — but worth confirming.
