---
run_id: 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-08T00:00:00Z
task_id: T-0090
inputs_read:
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-01-task-reader.md
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-02-landscape-reader.md
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-03-task-validator.md
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - shared/app-registry.md
  - shared/approval-protocol.md
artifacts_changed: []
---

## Summary

Design a 9-phase plan (UFW reconciliation → Docker install → source clone → compose adapt → health check → nginx vhost → UFW 443/tcp → Cloudflare DNS → HTTPS verification) to convert `pro-data-tech-qa` (95.46.211.230) into the `ai-qadam` QA instance reachable at `qadam-test.ai-dala.com` on port 3112. The plan includes a critical architectural mismatch between the prod ai-qadam stack (Next.js single-app) and the workstation monorepo (NestJS API + Astro web), and surfaces the TLS approach (self-signed origin cert + Cloudflare Full SSL mode) as a user decision. Recommendation: **split into two runs** (Phases A–E host-level; Phases F–I public-internet) so the user can validate the container stack before authorising Cloudflare changes. Verdict `NEEDS_APPROVAL` — touches Docker install, state-changing UFW, nginx install, and Cloudflare DNS.

## Details

### Splitter recommendation

**Recommend splitting T-0090 into TWO separate workflow runs:**

- **Run 1: `2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001` (this run).** Phases A–E only (host-level: UFW FORWARD rec → Docker install → source clone → compose adapt → container health). End state: containers running, `http://127.0.0.1:3112` returns 200/302 on-host.
- **Run 2: `2026-07-08-expose-qadam-test-to-public-internet-002` (new task to spawn at end of Run 1).** Phases F–I only (public-internet: nginx vhost → UFW 443/tcp → Cloudflare DNS → HTTPS verification). End state: `https://qadam-test.ai-dala.com` returns 200 from public internet.

Rationale:
- Run 1 has clear end-state on the host; Run 2 changes state on Cloudflare (a separate failure domain). Independently testable.
- User can validate the container stack end-to-end before authorising Cloudflare changes.
- Smaller blast radius per run; easier to debug if anything fails.
- If the user prefers a single-run flow, they can override — the design below covers both.

**This handoff designs Run 1 only.** Run 2 will be designed separately after Run 1 closes. If the user wants a single combined run, the same Phases F–I steps still apply.

### Critical design decisions surfaced for user approval

| # | Decision | Recommendation | Alternative |
|---|---|---|---|
| **D1** | TLS-at-origin on `pro-data-tech-qa` | **(a) Self-signed cert + Cloudflare Full SSL mode** (not Full-Strict). Fastest, no cross-host secret copy needed. | (b) Copy `/etc/ssl/cloudflare/ai-dala.{pem,key}` from hetzner-prod via `scp`. (c) DNS-only mode (`proxied:false`) like `git.ai-dala.com`. |
| **D2** | `role:` frontmatter value for `landscape/hosts/pro-data-tech-qa.md` | **`ai-qadam-qa`** (matches T-0090 task id; unambiguous in inventory) | `qadam-test` (matches DNS prefix) |
| **D3** | Clone source: prod-style Next.js standalone OR workstation monorepo | **Workstation monorepo (`c:\Users\tvolo\dev\ai-dala\aiqadam`) per user instruction** — but flag architectural mismatch (see D4) | Clone from the same Feb-2026 snapshot that prod uses (not currently in this repo) |
| **D4** | Handle prod/workstation stack divergence | **Defer to discovery sub-step**: Run 0 of executor will probe `c:\Users\tvolo\dev\ai-dala\aiqadam\apps\`, identify deployable target (`apps/web-next` is Astro; `apps/api` is NestJS), and choose to (a) build combined image from the API + web-next, (b) deploy only one as a 2-container shape, or (c) use the same Feb-2026 prod pattern (out of scope — would require user to locate the prod source). **Default: option (b) deploy `apps/api` as the "app" container** (NestJS, Postgres-backed, matches the prod ai-qadam "API + Postgres" intent). Flag this as a follow-up task if user wants the full web+API+db mirror. | (c) Hunt for a Feb-2026 snapshot of the prod Next.js source in backups |
| **D5** | Compose project name | **`ai-qadam-test`** (explicit user instruction; namespaces from prod's `ai-qadam` so containers/networks/volumes don't collide during future T-0062) | `qadam-test` (matches DNS prefix) |
| **D6** | Postgres password for QA | **Generate fresh strong random** (24+ chars) — DO NOT reuse prod's `aiqadam_secret`. Stored only in `/var/www/ai-qadam-test/.env` on host (mode 600 root:root), referenced by name in `landscape/secrets-inventory.md`. | Reuse prod values (less secure; rejected) |
| **D7** | Storage path on host | **`/var/www/ai-qadam-test/`** (matches prod `/var/www/ai-qadam/`; legacy convention). The modern convention `/opt/apps/<app>-test/` from `bilimbaga-test` precedent is acceptable too — but `pro-data-tech-qa` host's `/var/www/` is absent today and creating it under `/var/www/` mirrors prod exactly, reducing cognitive load. | `/opt/apps/ai-qadam-test/` (modern convention) |

### Plan (9 phases — combined Run 1 + Run 2)

> **Run 1 (host-only) is Phases A–E. Run 2 (public-internet) is Phases F–I.** All commands below are written assuming both runs are executed; the orchestrator may split into two approvals and skip Phases F–I in Run 1.

#### Phase A — UFW FORWARD reconciliation (must precede Docker install)

| # | Step | Command | Verification |
|---|---|---|---|
| A1 | Backup `/etc/default/ufw` (T-0094 left `/etc/default/ufw.bak`; add another timestamped copy for T-0090 audit trail) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo cp /etc/default/ufw /etc/default/ufw.pre-T0090.$(date -u +%Y%m%dT%H%M%SZ).bak && sudo ls -la /etc/default/ufw.pre-T0090.*.bak'` | file exists, mode 644, owner root:root, size matches `wc -c /etc/default/ufw` |
| A2 | Flip `DEFAULT_FORWARD_POLICY="DROP"` → `"ACCEPT"` | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo sed -i "s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/" /etc/default/ufw && sudo grep DEFAULT_FORWARD_POLICY /etc/default/ufw'` | output line reads `DEFAULT_FORWARD_POLICY="ACCEPT"` |
| A3 | Reload UFW | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo ufw reload && sudo ufw status verbose | head -8'` | `Status: active`; 22/tcp still allowed; defaults `deny (incoming), allow (outgoing), disabled (routed)` (FORWARD shows `disabled (routed)` until IP forwarding is enabled — that's expected) |
| A4 | Verify SSH still works (loopback smoke test via existing session, not new connection — to avoid breaking the run if reload mishandles) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo true && echo SSH_OK'` | prints `SSH_OK` |
| A5 | Document UFW FORWARD change in `landscape/hosts/pro-data-tech-qa.md` (done at step 08) | (no command — landscape edit) | n/a |

**Rationale (AC4 / T-0090 § "What done looks like" item 4):** T-0094 deliberately set `FORWARD=DROP` because Docker was not yet installed. Docker enables `/proc/sys/net/ipv4/ip_forward=1` at install time, which makes the FORWARD chain live. With policy `DROP`, all bridged container traffic would be silently dropped → `docker compose up` succeeds, but the app's outbound DB connection to `db:5432` times out. Flipping to `ACCEPT` matches the sibling-host pattern (`hetzner-prod`, `ubuntu-16gb-nbg1-1` both use `ACCEPT`). Option (b) (`"iptables": false` in `/etc/docker/daemon.json`) was considered but rejected — it requires handcrafting every iptables rule that Docker would otherwise auto-create, and breaks Compose networking defaults.

#### Phase B — Docker install (engine + compose plugin)

| # | Step | Command | Verification |
|---|---|---|---|
| B1 | Pre-flight: confirm OS codename + arch | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra '. /etc/os-release && echo "$VERSION_CODENAME $(dpkg --print-architecture)"'` | e.g. `resolute amd64` |
| B2 | Install prerequisites | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg'` | exit 0; `which curl` returns `/usr/bin/curl` |
| B3 | Add Docker GPG key + repo (Docker's official install script; idempotent: re-running is a no-op if already present) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo install -m 0755 -d /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg && sudo chmod a+r /etc/apt/keyrings/docker.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'` | `/etc/apt/keyrings/docker.gpg` exists (mode 644); `/etc/apt/sources.list.d/docker.list` exists with the expected `deb [arch=…]` line |
| B4 | apt update + install Docker | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'` | exit 0; packages installed |
| B5 | Verify versions | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'docker --version && docker compose version'` | e.g. `Docker version 29.x.y, build …` and `Docker Compose version v2.x.y` |
| B6 | Enable + start systemd unit | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo systemctl enable --now docker && sudo systemctl is-active docker'` | `active` |
| B7 | Add operator users to `docker` group (for socket access; **NOT** SSH — `sshusers` group already governs SSH) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo usermod -aG docker tvolodi viktor_d binali_r && getent group docker'` | `docker:x:<gid>:<members>` includes tvolodi, viktor_d, binali_r |
| B8 | Live verify (without sudo) — note: existing SSH sessions need to be re-established for new group membership to take effect | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'id | grep docker && docker ps --format "{{.Names}}\t{{.Status}}"'` (executor must `exit` then re-login first) | group `docker(d)` shows in `id`; `docker ps` prints the column header (no containers expected yet) |

**Idempotency note:** B1–B6 are idempotent. Re-running `apt-get install` on an already-installed package is a no-op (`0 newly installed`). B7 (`usermod -aG`) is idempotent (group appends are deduplicated).

**Ubuntu 26.04 "resolute" risk:** `download.docker.com/linux/ubuntu` may not have a `resolute` pool yet. Mitigation: if `apt-get update` after B3 fails with `404 Not Found` on the Docker repo, the executor must **fall back to Ubuntu's stock `docker.io` package**: `sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io docker-compose-v2` (Ubuntu 26.04 backports both into `universe`). Document the fallback in the executor's handoff.

**Backup before destructive changes:** none required — `apt-get install` does not modify existing config.

#### Phase C — Clone ai-qadam source onto host

| # | Step | Command | Verification |
|---|---|---|---|
| C0 | **Pre-execution discovery (resolves design decision D4)** — from management workstation, probe the monorepo to determine the deployable target | `cd C:\Users\tvolo\dev\ai-dala\aiqadam; git remote -v; git log -1 --oneline; Get-ChildItem apps -Directory | Select Name` | confirms repo origin (`https://github.com/tvolodi/aiqadam.git`, **public**); lists apps |
| C1 | Verify workstation source exists | `Test-Path 'c:\Users\tvolo\dev\ai-dala\aiqadam'` | `True` |
| C2 | Verify repo is publicly readable (no PAT/SSH key needed on host) | `git ls-remote https://github.com/tvolodi/aiqadam.git HEAD` (run from workstation) | prints a SHA hash and `refs/heads/main` (not `403 Forbidden`) |
| C3 | On QA host: ensure `/var/www` exists and is owned by `tvolodi:tvolodi` | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo mkdir -p /var/www && sudo chown tvolodi:tvolodi /var/www'` | `/var/www` exists, owner tvolodi |
| C4 | Clone the public repo on host | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'git clone https://github.com/tvolodi/aiqadam.git /var/www/ai-qadam-test'` | exit 0; `/var/www/ai-qadam-test/` populated |
| C5 | Verify clone integrity | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'cd /var/www/ai-qadam-test && git log -1 --oneline && ls apps/ && ls deploy/ 2>/dev/null || echo "no deploy/ subdir (expected for monorepo)"'` | shows commit SHA + apps/ dir |

**C0 discovery finding (already confirmed during this design step):** the workstation monorepo is a **pnpm/turbo monorepo with Astro web frontend + NestJS API + bot + workers** — fundamentally different from the prod ai-qadam's Next.js single-app. The plan does NOT clone the prod pattern verbatim; instead, it adapts the compose layout for the monorepo. **Specific implementation choice deferred to executor substep D4-1 below.**

**Backup before destructive changes:** none — `/var/www` does not yet exist; clone creates the directory fresh.

#### Phase D — Adapt docker-compose for QA + write `.env`

| # | Step | Command | Verification |
|---|---|---|---|
| D0 | **(D4 resolution substep)** executor examines `/var/www/ai-qadam-test/apps/` and decides: (a) deploy `apps/api` as the "app" container (NestJS + Postgres), (b) deploy `apps/web-next` (Astro, no db), (c) deploy combined image. **Default per D4 = (a) deploy `apps/api`**. Document the choice in executor handoff. | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'ls /var/www/ai-qadam-test/apps/api && cat /var/www/ai-qadam-test/apps/api/package.json | head -30'` | confirms NestJS app is deployable |
| D1 | Read prod compose for reference shape | (already in landscape — `landscape/hosts/hetzner-prod.md` documents the prod compose) | n/a |
| D2 | Write QA compose file at `/var/www/ai-qadam-test/deploy/docker-compose.qa.yml` on host via heredoc | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'mkdir -p /var/www/ai-qadam-test/deploy'` then write compose (see "Compose file content" section below) | file exists; `docker compose -p ai-qadam-test -f /var/www/ai-qadam-test/deploy/docker-compose.qa.yml config --quiet` exits 0 |
| D3 | Generate a fresh strong random Postgres password (24-char base64, saved into a host-side `~/.config/qadam-test-db-password` file referenced by name only) | (executor generates via `openssl rand -base64 24`, stores in host file `~/.config/qadam-test-db-password` mode 600 owned by root:root; reference by name in `.env`) | file exists; `wc -c` ≥ 32 |
| D4 | Write `.env` at `/var/www/ai-qadam-test/.env` (mode 600 root:root) with QA-specific secrets; `DATABASE_URL` points at in-stack `db:5432`; the host-side password file is referenced by path | (write `.env`; see ".env file content" section below) | `ls -la /var/www/ai-qadam-test/.env` shows mode `600 root root`; `docker compose -p ai-qadam-test -f deploy/docker-compose.qa.yml --env-file /var/www/ai-qadam-test/.env config | head -40` resolves DATABASE_URL |
| D5 | Pull/build images (for first deploy, this is `docker compose build` since the app is local) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'cd /var/www/ai-qadam-test && docker compose -p ai-qadam-test -f deploy/docker-compose.qa.yml --env-file .env build --pull'` | exit 0; images created |
| D6 | Start the stack detached | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'cd /var/www/ai-qadam-test && docker compose -p ai-qadam-test -f deploy/docker-compose.qa.yml --env-file .env up -d'` | exit 0; containers created |
| D7 | Verify both containers are `Up` | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'docker ps --filter "name=ai-qadam-test" --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'` | 2 rows: `ai-qadam-test-app-1` + `ai-qadam-test-db-1`, both `Up`, app port `127.0.0.1:3112→3000`, db internal |

**Compose file content** (`/var/www/ai-qadam-test/deploy/docker-compose.qa.yml`):

```yaml
# filepath: /var/www/ai-qadam-test/deploy/docker-compose.qa.yml
name: ai-qadam-test

services:
  app:
    build:
      context: ../apps/api          # mirrors D4 default; switch to apps/web-next if executor picks (b)
      dockerfile: Dockerfile        # assume api/Dockerfile exists or create minimal Node-22-alpine multi-stage
    image: ai-qadam-test-app:qa
    ports:
      - "127.0.0.1:3112:3000"       # next free test slot per shared/app-registry.md
    environment:
      - DATABASE_URL=postgresql://aiqadam:${POSTGRES_PASSWORD}@db:5432/aiqadam_test
      - NODE_ENV=development        # QA ≠ prod; use development to surface more verbose errors
      - PORT=3000
    env_file:
      - path: ../.env               # project-root .env (resolves relative to compose file's parent, per app-registry pattern)
        required: false
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=aiqadam
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=aiqadam_test
    volumes:
      - ai_qadam_test_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U aiqadam -d aiqadam_test"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    # NO ports mapping — internal only

volumes:
  ai_qadam_test_pgdata:
```

**.env file content** (`/var/www/ai-qadam-test/.env`):

```bash
# filepath: /var/www/ai-qadam-test/.env
# QA instance secrets — DO NOT COMMIT; mode 600 root:root on host.
# Reference by name in landscape/secrets-inventory.md once step 08 runs.

POSTGRES_PASSWORD=<freshly-generated-24-char-base64>
DATABASE_URL=postgresql://aiqadam:<same-as-above>@db:5432/aiqadam_test
NEXT_PUBLIC_SITE_URL=https://qadam-test.ai-dala.com
NEXT_PUBLIC_TELEGRAM_URL=https://t.me/aiqadam_test
NODE_ENV=development
```

The executor generates `<freshly-generated-24-char-base64>` via `openssl rand -base64 24` on the host, writes it into both `POSTGRES_PASSWORD` and the `DATABASE_URL` line, then registers the file at `/var/www/ai-qadam-test/.env` with `chmod 600 root:root`. The literal value never appears in this repo; the executor's handoff references the file by path only.

**Backup before destructive changes:** none — fresh files; the existing `/var/www/` is absent.

#### Phase E — Health check (host-side)

| # | Step | Command | Verification |
|---|---|---|---|
| E1 | Hit `http://127.0.0.1:3112/` from host (Next.js / NestJS default response) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'curl -sI http://127.0.0.1:3112/ 2>&1 | head -10'` | returns 200 or 302 (Next.js / NestJS default response on `/`); NOT a timeout |
| E2 | Hit `/api/health` if defined (per app-registry convention for `bilimbaga-test`) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'curl -sI http://127.0.0.1:3112/api/health 2>&1 | head -5'` | returns 200 (or 404 if not implemented in this app — acceptable per "best-effort") |
| E3 | Verify db container is healthy | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'docker inspect --format "{{.State.Health.Status}}" ai-qadam-test-db-1'` | `healthy` |

**End of Run 1** (host-only). If splitting: stop here; user validates Phases A–E succeeded before Run 2.

#### Phase F — Install nginx + write vhost

| # | Step | Command | Verification |
|---|---|---|---|
| F1 | Install nginx | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx'` | exit 0; `which nginx` returns `/usr/sbin/nginx` |
| F2 | Generate self-signed cert + key (per design decision D1 = self-signed + CF Full mode) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo mkdir -p /etc/ssl/cloudflare && sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/cloudflare/ai-dala.key -out /etc/ssl/cloudflare/ai-dala.pem -subj "/CN=*.ai-dala.com" -addext "subjectAltName=DNS:*.ai-dala.com,DNS:ai-dala.com" && sudo chmod 600 /etc/ssl/cloudflare/ai-dala.key && sudo chmod 644 /etc/ssl/cloudflare/ai-dala.pem'` | both files exist; `openssl x509 -in /etc/ssl/cloudflare/ai-dala.pem -noout -subject -dates` prints `subject=CN=*.ai-dala.com` and a `notAfter=` date 10 years out |
| F3 | Write vhost at `/etc/nginx/sites-available/qadam-test.conf` via heredoc (content below) | (write vhost) | file exists |
| F4 | Symlink into `sites-enabled` | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo ln -sf /etc/nginx/sites-available/qadam-test.conf /etc/nginx/sites-enabled/qadam-test.conf && ls -la /etc/nginx/sites-enabled/qadam-test.conf'` | symlink exists, target resolves |
| F5 | Test nginx config | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo nginx -t'` | exit 0; "syntax is ok" |
| F6 | Reload nginx | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo systemctl reload nginx && sudo systemctl is-active nginx'` | `active` |

**Vhost content** (`/etc/nginx/sites-available/qadam-test.conf`):

```nginx
# filepath: /etc/nginx/sites-available/qadam-test.conf
server {
    listen 443 ssl;
    server_name qadam-test.ai-dala.com;

    ssl_certificate /etc/ssl/cloudflare/ai-dala.pem;
    ssl_certificate_key /etc/ssl/cloudflare/ai-dala.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:3112;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
    }

    location ~ /\. {
        deny all;
    }
}
```

**Backup before destructive changes:** F2 creates fresh files at `/etc/ssl/cloudflare/` (dir did not exist before). F3-F4 do not touch the default vhost.

#### Phase G — UFW allow 443/tcp

| # | Step | Command | Verification |
|---|---|---|---|
| G1 | Allow 443/tcp (Cloudflare-proxied traffic to nginx) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo ufw allow 443/tcp comment "nginx - Cloudflare proxy (qadam-test) T-0090"'` | exit 0 |
| G2 | Verify | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo ufw status | grep -E "22/tcp|443/tcp"'` | 2 rows: 22/tcp ALLOW IN Anywhere; 443/tcp ALLOW IN Anywhere |

**Idempotency note:** `ufw allow 443/tcp` re-run is idempotent (UFW deduplicates; the comment may differ on second run — that's a minor cosmetic issue, not a correctness one).

#### Phase H — Cloudflare DNS record

| # | Step | Command | Verification |
|---|---|---|---|
| H1 | Read the Cloudflare write token from workstation | `Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token'` (executor-only — value never appears in repo) | non-empty token |
| H2 | POST A record to Cloudflare zone `ai-dala.com` (zone ID `4a2748e92ef7ddaac7fddf375be2da53`) | `curl -sS -X POST 'https://api.cloudflare.com/client/v4/zones/4a2748e92ef7ddaac7fddf375be2da53/dns_records' -H "Authorization: Bearer $(Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token')" -H 'Content-Type: application/json' --data '{"type":"A","name":"qadam-test","content":"95.46.211.230","ttl":1,"proxied":true,"comment":"T-0090 qadam-test QA instance"}' | response JSON `success:true`, contains `result.id` (record ID) |
| H3 | Confirm DNS propagation from workstation | `nslookup qadam-test.ai-dala.com 1.1.1.1` | `Address: 95.46.211.230` |

**Idempotency note:** re-running POST would 409-conflict if the record exists. Executor should check first: `GET .../dns_records?type=A&name=qadam-test.ai-dala.com` and skip the POST if already present.

**Risk mitigation:** if the API returns a rate-limit error, executor backs off for 60s and retries once. Two retries max.

#### Phase I — DNS + HTTPS verification (end-to-end)

| # | Step | Command | Verification |
|---|---|---|---|
| I1 | From workstation, TCP probe port 443 | `Test-NetConnection qadam-test.ai-dala.com -Port 443` | `TcpTestSucceeded: True` |
| I2 | From workstation, HTTP HEAD with cert bypass (because self-signed) | `curl -kI https://qadam-test.ai-dala.com 2>&1 | head -10` | exit 0; HTTP/1.1 200 OK (or 301/302 redirect — accept either) |
| I3 | Confirm Cloudflare's edge cert is the one Cloudflare shows (not the self-signed origin cert) — sanity check the proxy mode is `proxied:true` | `curl -sI https://qadam-test.ai-dala.com 2>&1 | grep -i server` | `server: cloudflare` header present |
| I4 | End-to-end: hit `https://qadam-test.ai-dala.com/api/health` | `curl -kI https://qadam-test.ai-dala.com/api/health 2>&1 | head -5` | exit 0; response 200 or 404 (acceptable — depends on whether api/app implements `/api/health`) |

### Rollback (Run 1 — host-only)

| # | Step | Command |
|---|---|---|
| R1 | Stop + remove the ai-qadam-test compose project | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'cd /var/www/ai-qadam-test 2>/dev/null && docker compose -p ai-qadam-test -f deploy/docker-compose.qa.yml --env-file .env down --remove-orphans || true'` |
| R2 | Remove cloned repo | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo rm -rf /var/www/ai-qadam-test'` |
| R3 | Disable + remove Docker (if Run 2 should also revert) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo systemctl disable --now docker && sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.gpg 2>/dev/null; sudo rm -rf /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg /var/lib/docker'` |
| R4 | Restore UFW FORWARD policy to `DROP` (revert T-0090 work item) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo sed -i "s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"DROP\"/" /etc/default/ufw && sudo ufw reload'` |
| R5 | Remove operator docker-group membership (revert B7) | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo gpasswd -d tvolodi docker; sudo gpasswd -d viktor_d docker; sudo gpasswd -d binali_r docker'` |

### Rollback (Run 2 — public-internet)

| # | Step | Command |
|---|---|---|
| R6 | Delete the Cloudflare DNS record (use the `result.id` from H2) | `curl -sS -X DELETE "https://api.cloudflare.com/client/v4/zones/4a2748e92ef7ddaac7fddf375be2da53/dns_records/<record-id>" -H "Authorization: Bearer $(Get-Content 'C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token')"` |
| R7 | Remove UFW 443/tcp rule | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo ufw delete allow 443/tcp'` |
| R8 | Disable nginx vhost | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo rm -f /etc/nginx/sites-enabled/qadam-test.conf /etc/nginx/sites-available/qadam-test.conf && sudo systemctl reload nginx'` |
| R9 | (optional) remove nginx + self-signed cert entirely | `ssh 95.46.211.230 -l tvolodi -i C:\Users\tvolo\.ssh\ai-dala-infra 'sudo apt-get purge -y nginx nginx-common && sudo rm -rf /etc/nginx /etc/ssl/cloudflare'` |

### Verification (for step 07 execution-validator)

**On-host checks:**

- V01 — `/etc/default/ufw` line reads `DEFAULT_FORWARD_POLICY="ACCEPT"`.
- V02 — `docker --version && docker compose version` returns non-empty version strings; `docker compose version` reports v2.x.
- V03 — `systemctl is-active docker` returns `active`.
- V04 — `id tvolodi` shows `docker` group; `getent group docker` lists tvolodi, viktor_d, binali_r as members.
- V05 — `/var/www/ai-qadam-test/` exists; contains `apps/`, `deploy/docker-compose.qa.yml`, `.env` (mode 600 root:root).
- V06 — `docker ps --filter "name=ai-qadam-test"` returns 2 containers: `ai-qadam-test-app-1` + `ai-qadam-test-db-1`, both `Up`, app port `127.0.0.1:3112→3000`, db internal.
- V07 — `curl -sI http://127.0.0.1:3112/` returns HTTP/1.1 200 (or 302); NOT a connection-refused error.
- V08 — `nginx -t` exits 0 with "syntax is ok".
- V09 — `systemctl is-active nginx` returns `active`.
- V10 — `/etc/nginx/sites-enabled/qadam-test.conf` is a symlink resolving to `/etc/nginx/sites-available/qadam-test.conf`.
- V11 — `sudo ufw status | grep -E "22/tcp|443/tcp"` shows both rules ALLOW IN.

**External checks:**

- V12 — From workstation: `nslookup qadam-test.ai-dala.com 1.1.1.1` returns `95.46.211.230`.
- V13 — From workstation: `Test-NetConnection qadam-test.ai-dala.com -Port 443` returns `TcpTestSucceeded: True`.
- V14 — From workstation: `curl -kI https://qadam-test.ai-dala.com` returns HTTP/1.1 200 (or appropriate non-error response) with `server: cloudflare` header present.

### Resources used

- **Secrets (by name):**
  - `cloudflare-api-token:ai-dala-infra:ai-dala-write` (Cloudflare zone DNS edit on `ai-dala.com`) — value at `C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token`.
  - Fresh Postgres password generated on host (24-char base64) — stored at `/var/www/ai-qadam-test/.env` (mode 600 root:root); executor will register this file path in `landscape/secrets-inventory.md` at step 08.
  - Operator SSH keys (already installed by T-0097): `ai-dala-infra` (tvolodi), `ai-dala-infra-viktor-d` (viktor_d), `ai-dala-infra-binali-r` (binali_r) — referenced by path only.
- **Files modified on host (`pro-data-tech-qa`):**
  - `/etc/default/ufw` (FORWARD policy flip)
  - `/etc/default/ufw.pre-T0090.<timestamp>.bak` (new — backup)
  - `/etc/apt/keyrings/docker.gpg` (new)
  - `/etc/apt/sources.list.d/docker.list` (new)
  - `/etc/systemd/system/multi-user.target.wants/docker.service` (new symlink via `systemctl enable`)
  - `/etc/group` (`docker` group updated)
  - `/var/www/ai-qadam-test/` (new directory tree from clone)
  - `/var/www/ai-qadam-test/deploy/docker-compose.qa.yml` (new)
  - `/var/www/ai-qadam-test/.env` (new, mode 600)
  - `/etc/nginx/` (new — package install)
  - `/etc/nginx/sites-available/qadam-test.conf` (new)
  - `/etc/nginx/sites-enabled/qadam-test.conf` (new symlink)
  - `/etc/ssl/cloudflare/ai-dala.pem` (new — self-signed)
  - `/etc/ssl/cloudflare/ai-dala.key` (new — self-signed, mode 600)
- **Files modified in this repo (landscape/):**
  - `landscape/hosts/pro-data-tech-qa.md` — update `role: ai-qadam-qa`, add Docker + nginx + app sections, update `last_verified` (step 08).
  - `landscape/services.md` — add Docker + nginx tables for `pro-data-tech-qa` (step 08).
  - `landscape/cloudflare.md` — add `qadam-test.ai-dala.com` row to DNS records table; bump DNS-records count 13 → 14; update `last_verified` (step 08).
  - `landscape/domains.md` — add `qadam-test` to "Notable subdomains in DNS" and "Subdomains actually served by nginx" lists (step 08).
  - `shared/app-registry.md` — add new `ai-qadam` section (test environment only — prod stays on hetzner-prod until T-0062) (step 08).
  - `tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md` — append History entry; update `affects:` to include `landscape/cloudflare.md`, `landscape/domains.md`, `shared/app-registry.md`; set `status: done` + `outcome: succeeded` (step 08).
  - `landscape/secrets-inventory.md` — add new secret entry referencing `/var/www/ai-qadam-test/.env` (file path only, never values).
- **External APIs called:**
  - Cloudflare API: `POST /zones/{id}/dns_records` (one DNS A record creation).

### Estimated impact

- **Downtime:** none for prod (`ai-qadam.ai-dala.com` on hetzner-prod untouched). QA stack startup ~30s (db healthcheck + image pulls on first build).
- **Affected services:**
  - `pro-data-tech-qa` host — UFW, Docker, nginx, ai-qadam-test compose stack (additive).
  - Cloudflare zone `ai-dala.com` — one new DNS A record (additive; DNS-records 13 → 14).
- **Reversibility:** **fully reversible** — see Rollback section. R1–R5 undo Run 1; R6–R9 undo Run 2. The fresh Postgres password is single-use; on rollback, the `.env` file is removed, so the password is forgotten by the host.

### Plan structure summary

| Phase | Action | Idempotent? | State-changing? | Blast |
|---|---|---|---|---|
| A | UFW FORWARD rec | yes (sed is idempotent) | yes (firewall policy) | low |
| B | Docker install + group | yes | yes (apt + systemd + group) | medium |
| C | Clone monorepo | no (would 409 if dir exists — add `test -d` check) | yes (filesystem) | low |
| D | Compose + .env + start | partially (D5/D6 not idempotent) | yes (containers, secrets on disk) | medium |
| E | Health check | n/a | no (read-only) | none |
| F | nginx install + vhost + self-signed cert | yes | yes (apt + nginx config + cert files) | medium |
| G | UFW 443/tcp allow | yes | yes (firewall) | low |
| H | Cloudflare DNS POST | partially (would 409; check first) | yes (Cloudflare zone) | medium |
| I | Verification | n/a | no (read-only) | none |

## Issues / risks

1. **Architectural mismatch (medium severity).** The workstation ai-qadam monorepo (`apps/api` NestJS, `apps/web-next` Astro) is structurally different from the prod ai-qadam stack (Next.js single-app, Feb 2026 standalone clone). The plan defaults to deploying `apps/api` as the "app" container (matches the prod "API + Postgres" intent and the 2-container shape). If the user wants the full web+API+db mirror, that's a larger refactor — surfaced as a follow-up task. **Mitigation:** D0 sub-step probes the monorepo before writing compose; executor documents the choice in its handoff.

2. **Ubuntu 26.04 "resolute" Docker repo availability (medium severity).** `download.docker.com/linux/ubuntu` may not have a `resolute` pool yet (Ubuntu 26.04 is brand new). **Mitigation:** explicit fallback in B4 to Ubuntu stock `docker.io` package from `universe`. Documented in the executor's prompt.

3. **Cloudflare Full SSL mode with self-signed origin cert (low severity).** Cloudflare will accept a self-signed cert in `Full` mode but reject it in `Full (Strict)` mode. **Mitigation:** D1 surfaces this; executor must explicitly set SSL mode to `Full` (not `Full (Strict)`) for the new DNS record's zone (or confirm the zone's current `ssl` setting is `full` or `full_strict`; per landscape/cloudflare.md, the zone is currently `strict`). **Action:** before H2, executor should check the zone SSL mode and either (a) set the per-record SSL mode override or (b) explicitly request user to flip zone SSL mode to `full` (broader blast). Default = (a) per-record override; deferred to executor decision.

4. **Cloudflare origin cert reuse (low severity).** The Cloudflare-origin cert at `/etc/ssl/cloudflare/ai-dala.{pem,key}` on hetzner-prod was issued by Cloudflare for `*.ai-dala.com` and is valid for up to 15 years. The plan generates a self-signed cert instead because (a) Cloudflare origin certs are tied to the issuing account, not portable across hosts cleanly, and (b) cross-host secret copy (option b) requires `scp` from hetzner-prod which is an additional dependency. **Mitigation:** if self-signed cert + CF Full mode fails, follow-up task can copy the Cloudflare origin cert from hetzner-prod.

5. **Bounded blast radius (low severity).** Phases A–E touch only `pro-data-tech-qa` and the Docker daemon; Phases F–G touch only `pro-data-tech-qa` (nginx + UFW); Phase H touches Cloudflare zone `ai-dala.com` (one A record add); Phase I is read-only. No changes to `hetzner-prod`, no changes to any other host, no changes to `*.ai-dala.com` traffic. The prod ai-qadam stack stays running.

6. **Postgres data persistence (informational).** The QA db uses a named Docker volume `ai_qadam_test_pgdata`. This survives `docker compose down` (which by default does NOT remove volumes). If the user later wants to wipe QA data, they must explicitly `docker volume rm ai_qadam-test_ai_qadam_test_pgdata`. **Backup before destructive changes:** not required (QA data is throwaway by design).

7. **Run length (low severity).** This is a 9-phase plan. The splitter recommendation puts Phases A–E in Run 1 and Phases F–I in Run 2, so each run has ~5 phases. The orchestrator should be aware: if the user prefers a single combined run, both halves execute in sequence with one approval.

8. **Operator-group docker membership (informational).** Adding tvolodi/viktor_d/binali_r to the `docker` group grants them full control of the Docker daemon — equivalent to root on the host. **Mitigation:** standard docker pattern; matches `hetzner-prod` precedent (pre-T-0097). Documented as informational, not a blocker.

## Open questions (optional)

None blocking. All five design decisions (D1–D5) are surfaced above with recommendations; the user can override any of them at approval time. The splitter recommendation is also a user-decision point.