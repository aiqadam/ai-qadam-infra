---
id: T-0090a-prepare-qadam-test-public-https-endpoint
title: Add nginx + Cloudflare + HTTPS for qadam-test.ai-dala.com (Phases F–I of T-0090)
kind: observation
status: observation
priority: P2
created: 2026-07-08
updated: 2026-07-08
closed:
outcome:
created_by: 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
source_runs:
  - 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/cloudflare.md
  - landscape/domains.md
workflow: infrastructure
blocks: []
blocked_by:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
related:
  - T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance
estimated_blast_radius: medium
estimated_reversibility: full
---

# Add nginx + Cloudflare + HTTPS for qadam-test.ai-dala.com (Phases F–I of T-0090)

## Why
[T-0090](../../tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md) [Run 1] delivered Phases A–E (host-level setup): Docker installed, ai-qadam-test postgres container up on `127.0.0.1:3112`. Phases F–I were deliberately deferred to this task to keep Run 1's blast radius contained (no internet-facing changes). Phases F–I are: nginx install + vhost, self-signed/Cloudflare origin cert, UFW 443/tcp allow, Cloudflare DNS A record for `qadam-test.ai-dala.com` (proxied), and end-to-end HTTPS verification.

## What done looks like
- [ ] nginx installed on `pro-data-tech-qa`
- [ ] Self-signed origin cert at `/etc/ssl/cloudflare/ai-dala.pem` (+ `.key`) — exact path/mode to match `hetzner-prod` convention
- [ ] nginx vhost at `/etc/nginx/sites-available/qadam-test.conf` listening 443 ssl, proxying to `http://127.0.0.1:3112` (until an app container is added — then likely `:3000` or whatever the app exposes)
- [ ] vhost symlinked to `/etc/nginx/sites-enabled/qadam-test.conf`
- [ ] `nginx -t` passes, `systemctl reload nginx`
- [ ] UFW: `sudo ufw allow 443/tcp comment "nginx — Cloudflare proxy (qadam-test)"`
- [ ] Cloudflare DNS: A record `qadam-test.ai-dala.com` → `95.46.211.230`, proxied (orange cloud), SSL mode `Full`
- [ ] From workstation, `curl -kI https://qadam-test.ai-dala.com` returns 200 (or appropriate)
- [ ] `Test-NetConnection qadam-test.ai-dala.com -Port 443` returns True
- [ ] Landscape updates: nginx + Cloudflare DNS entry documented
- [ ] Optional: app source clone + `apps/api`/`web-next` build + app container alongside the postgres, depending on the open question below

## Open questions
- **TLS approach:** self-signed cert + Cloudflare SSL mode `Full` (recommended — matches existing `hetzner-prod` pattern via the shared `/etc/ssl/cloudflare/ai-dala.pem` origin cert from Cloudflare) vs CF origin cert via `acme.sh` (better long-term). Decision deferred to executor. Note that `hetzner-prod` already has `/etc/ssl/cloudflare/ai-dala.pem` populated; a new cloudflared origin cert can be minted via the Cloudflare API for this host with the same CN.
- **App container:** should this task ALSO clone the ai-qadam app source and run an app container? Or just nginx+Cloudflare against the existing postgres? Decision deferred. Phases F–I as designed only cover the network/edge layer; the app source clone + image build was Phase C of the original T-0090 plan and was already bypassed (see T-0090 `## Notes`).
- **Pro-data.tech cloud firewall vs UFW:** confirm whether pro-data.tech exposes a control-plane firewall product. If yes, must allow 443/tcp at that layer too. Same with the (TBD) `95.46.211.230` reverse path — Cloudflare proxy will reach the host on 443/tcp.

## Notes
- nginx does NOT exist on `pro-data-tech-qa` yet (per T-0088 discovery)
- Cloudflare API token already provisioned (see `landscape/cloudflare.md`)
- The Postgres container is the only thing currently running on `127.0.0.1:3112`; until an app container is added, nginx will proxy to a connection-refused / 502 from postgres, which won't speak HTTP. The end-to-end probe should be expected to fail until the app is up.
- Predecessor [T-0090](../../tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md) is `done` (2026-07-08). This observation is the explicit splitter into the network/edge layer per `runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-04-solution-designer.md`.
- The standard `port-convention` table in `shared/app-registry.md` reserves `127.0.0.1:3110–3119` for test app ports; bilimbaga-test already uses `3111`, productfactory-test uses `3110`. `3112` is currently bound by the postgres container (not by an app). When the app lands it should pick a free slot — `3113` onward.

## History
- 2026-07-08: created from run `2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001` (status `observation`, `priority: P2`, `blocked_by: T-0090` — now satisfied)

**⚠ Cross-repo Cloudflare coordination required (added 2026-07-10):** The DNS sub-step of this task registers `qadam-test.ai-dala.com` in the Cloudflare `ai-dala.com` zone. That zone is managed exclusively by the `ai-dala-infra` repository (`landscape/cloudflare.md` and `landscape/domains.md`). When executing this task from `ai-qadam-infra`, the executor must coordinate the DNS record creation with the `ai-dala-infra` repo owner / Cloudflare operator before or during the Cloudflare phase. Landscape updates for that DNS record must be committed to `ai-dala-infra`, not here.
