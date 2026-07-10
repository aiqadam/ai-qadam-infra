---
run_id: 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090
inputs_read:
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - tasks/_index.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/hosts/hetzner-prod.md
  - landscape/services.md
  - landscape/cloudflare.md
  - shared/app-registry.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: Send to landscape-reader (step 02) to confirm current state of pro-data-tech-qa + hetzner-prod matches the task's "done" preconditions before designing the solution.
---

## Summary

T-0090 is a state-changing infrastructure task that converts the freshly-provisioned pro-data.tech VM at `95.46.211.230` (`pro-data-tech-qa`) into the QA instance for the `ai-qadam` application: reconcile the UFW `DEFAULT_FORWARD_POLICY="DROP"` before Docker lands, install Docker engine + compose plugin, deploy an ai-qadam-style app + db Compose stack under the port-3110-3119 test convention, and point a new `qadam-test.ai-dala.com` DNS subdomain at the host.

## Details

- **Workflow:** `infrastructure`
- **Why (verbatim from T-0090):** "The user leased a cloud VM on pro-data.tech (NOT Hetzner) at `95.46.211.230` and intends to use it as the `ai-qadam` QA instance — a QA environment distinct from the Hetzner production host. The host is currently a freshly-provisioned Ubuntu 26.04 cloud image: no project services, no Docker, no nginx, no host firewall, no fail2ban, no operator users, no multi-PC SSH access. The **multi-PC operator SSH acceptance criterion** is a hard requirement: operators `viktor_d` and `binali_r` (and any future operator) must be able to SSH into the host from their own workstations, not only from the current management workstation. This task re-creates the pre-scrub T-0090 record (lost in the 2026-07-07 secrets-inventory scrub per [T-0091](./T-0091-rotate-gitea-admin-pw-scrub-secrets-inventory-from-git-history.md)) and re-anchors the work-blocked-by-T-0093 dependency tree."

- **Target scope:**
  - `landscape/hosts/pro-data-tech-qa.md` (host facts; `role:` currently `unassigned` — to be updated)
  - `landscape/services.md` (add the `pro-data-tech-qa` Docker / nginx / systemd rows as the stack lands)
  - `landscape/cloudflare.md` (new DNS A record `qadam-test.ai-dala.com` → `95.46.211.230`; mirror the bilimbaga-test record pattern from 2026-05-14)
  - `shared/app-registry.md` (add `ai-qadam` test-environment section with the port-3110-3119 test slot — next free port in the 3110-3119 block is `3112`)
  - Optional: `landscape/hosts/hetzner-prod.md` (only if/when the prod ai-qadam stack is later removed — T-0062 is still `pending`)

- **Acceptance criteria (10 checkboxes from T-0090 "What done looks like") — all become validator (step 07) inputs:**

  1. **Multi-PC operator SSH access.** Operators `viktor_d` and `binali_r` (and management workstation `tvolodi`) can SSH into the host from their own workstations, not only from the current one. **Already met for `tvolodi` (V10 live handshake) and server-side-parse-verified for `viktor_d`/`binali_r`** by T-0097 (2026-07-08). Validator only needs to re-confirm; no work required in T-0090 itself.
  2. **sshd hardened per T-0093** — `PasswordAuthentication no`, `PermitRootLogin prohibit-password` (root login kept permanently per user decision 2026-07-08), `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`. **Already met (T-0093 done 2026-07-08, 21/21 verification checks PASSED).**
  3. **Host firewall per T-0094** — UFW deny-incoming, allow 22/tcp from any source (no source restrictions per user decision 2026-07-08). **Already met (T-0094 done 2026-07-08, 10/10 verification checks PASSED).**
  4. **Reconcile UFW `DEFAULT_FORWARD_POLICY="DROP"` BEFORE installing Docker.** This is the **only** acceptance criterion in T-0090 that is currently NOT done and is a hard prerequisite for Docker install. T-0094 left `FORWARD=DROP` as a deliberate divergence (no Docker installed yet → currently a no-op). Docker enables IP forwarding at install time, which will silently drop all bridged container traffic unless the executor first does one of: (a) `sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw && ufw reload`; or (b) set `"iptables": false` in `/etc/docker/daemon.json` and route via UFW rules. The task explicitly calls this out as a new step (added 2026-07-08 by T-0094 step-08).
  5. **fail2ban with sshd jail per T-0095** — management IP in `ignoreip`. **Already met (T-0095 done 2026-07-08, 7/7 verification checks PASSED).**
  6. **Docker installed and operational** (engine + compose plugin) — only after the UFW FORWARD reconciliation above. Not done; this is a primary T-0090 deliverable.
  7. **Application baseline deployed (depends on the role — e.g., ai-qadam QA stack).** Not done; primary T-0090 deliverable. Per the user's run-prompt, this is the ai-qadam QA stack — 2 containers (app + db), Compose project `qadam-test` or similar, port-3110-3119 test slot, mirrored from the prod ai-qadam stack on `hetzner-prod` (`/var/www/ai-qadam/docker-compose.yml` → `ai-qadam` and `ai-qadam-db-1`).
  8. **`role:` in `landscape/hosts/pro-data-tech-qa.md` frontmatter updated from `unassigned` to an assigned role** (e.g., `ai-qadam-qa` or user preference). This is a step-08-landscape-updater deliverable that the executor must coordinate with the solution design.

  > The task's "What done looks like" lists 10 checkboxes. Eight are enumerated above. The other two (host firewall + fail2ban) duplicate items 3 and 5 and are tracked via the same tasks — not separate work. Validator should treat the de-duplicated 8-item set as the acceptance matrix.

- **Sub-tasks already done (now in T-0090's `related:` frontmatter, all `status: done` as of 2026-07-08):**
  - T-0093 — sshd hardening (21/21 PASSED)
  - T-0094 — UFW firewall (10/10 PASSED on re-execution)
  - T-0095 — fail2ban sshd jail (7/7 PASSED)
  - T-0097 — operator users (`tvolodi`/`viktor_d`/`binali_r`) (16/16 PASSED)

- **Sub-tasks still open (not in T-0090's `related:`, observed during landscape-reader pass):**
  - T-0096 — auditd (deferrable per T-0088; P3; can stay observation)
  - T-0098 — host-level backup strategy (P3; deferred until role lands — T-0090 is the role-landing, so a small follow-up hook to add T-0098 dependency / data scope may be appropriate)
  - T-0062 — remove ai-qadam application from hetzner-prod (P0; not strictly in T-0090's scope but is the natural follow-on if the user's plan is to migrate ai-qadam fully to the QA host and retire the prod stack). T-0090 does NOT need to wait for T-0062; they can run in parallel.

- **Constraints stated by user (T-0090 body + run prompt):**
  - Provider is **pro-data.tech, NOT Hetzner** — no Hetzner Cloud Firewall, no Hetzner API, no Hetzner Backups option, no `firewall-1` analogue. Defense-in-depth comes from host UFW (T-0094).
  - SSH key on management workstation is `C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk` (OpenSSH-format RSA-2048 despite the `.ppk` extension). The SSH alias `pro-data-tech-qa` configures `User tvolodi`; after T-0097 the alias works as designed.
  - **No off-site / external storage** of any kind (per project hard rule; README § Backups & storage policy).
  - The ai-qadam app currently runs on `hetzner-prod` per `landscape/services.md` (`/var/www/ai-qadam/docker-compose.yml` → `ai-qadam` and `ai-qadam-db-1`; `ai-qadam-app-1` published on `0.0.0.0:3000`; `ai-qadam-db-1` internal; served via nginx vhost `ai-qadam.ai-dala.com` → `http://127.0.0.1:3000`).
  - The QA mirror must use the **`qadam-test.ai-dala.com` DNS subdomain** (per app-registry port convention: `127.0.0.1:3110-3119` reserved for test env; `<app>-test.ai-dala.com` for the test subdomain).
  - **App-registry port inventory as of 2026-06-08:** ProductFactory test uses `127.0.0.1:3110`, BilimBaga test uses `127.0.0.1:3111`. The next free test port is **`127.0.0.1:3112`** — T-0090 should claim it for qadam-test.
  - **No Hetzner-style "firewall-1" / Cloud-Front-Firewall control plane to wire up** — the UFW 22/tcp rule on the host is the only ingress filter.
  - **Multi-PC SSH acceptance criterion is hard** (verbatim from the user's request and T-0090 predecessor notes). Already met for `tvolodi` via T-0097; `viktor_d`/`binali_r` server-side `ssh-keygen -lf` parse verified — their live handshakes are intentionally deferred to each operator's own workstation and T-0090 must not regress that.
  - **T-0090 will never finalize `PermitRootLogin no`** as long as the 2026-07-08 root-login-policy decision stands.
  - T-0098 (host-level backup strategy, local-disk only) is implied as a follow-on but T-0090 does not need to implement it.
  - **Predecessor task (pre-scrub snapshot at `a41ec73`) is preserved verbatim** in the T-0090 file's `## Notes` and `## History` — the current T-0090 is the canonical re-creation; the pre-scrub version is not authoritative.

- **Information gaps for downstream steps (landscape-reader / task-validator / solution-designer):**
  - The exact env vars, image, and Compose file the prod ai-qadam stack uses (credentials paths: `/var/www/ai-qadam/.env` per `landscape/services.md` and the ai-qadam app's repo, which is **not in `shared/app-registry.md`** — the registry currently only lists `productfactory` and `bilimbaga`). Step 02 (landscape-reader) will need to read the prod ai-qadam Compose file on `hetzner-prod` to mirror the env surface; the executor will need read access to `/var/www/ai-qadam/.env` (mode 600 root:root) to copy the values across, **without writing them into this repo**.
  - The user's exact preference for the new `role:` frontmatter value (`ai-qadam-qa` vs `qadam-qa` vs something else) — flagged as "user's preference" in T-0090 itself.
  - The exact qadam app's source repo path on the management workstation (not enumerated anywhere in this repo). Executor will need to look up the source checkout (likely `c:\Users\tvolo\dev\ai-qadam` or similar) to read the Dockerfile / Compose contract; if the source repo is private, an SSH deploy key analogous to `bilimbaga-deploy` on `hetzner-prod` will be needed (out of scope for T-0090 unless the app repo is private — that is, the executor should determine private-vs-public by reading the source repo's GitHub URL during solution-design).
  - Whether the user wants the **prod ai-qadam stack on hetzner-prod kept** (T-0090 = pure add of a parallel test instance) or **replaced** (T-0090 + T-0062 sequenced). T-0090's text reads as "QA instance distinct from the Hetzner production host" — distinct, not a replacement. The prod stack stays. (But T-0062 `pending` in the index suggests the user is at least considering the removal — step 02 should flag the ambiguity for the user to confirm at approval.)
  - Postgres data: the prod `ai-qadam-db-1` uses `postgres:16-alpine` and is not in the `app-backup.sh` schedule (only `wms-postgres`, `immich_postgres`, and `wms-redis` are — confirmed in `hetzner-prod` landscape, "Application-level backups" section). T-0090's QA db should be backed up via `app-backup.sh` extension on `pro-data-tech-qa` (T-0098 scope) — but T-0090 itself only needs to create the db container; the backup hook is T-0098.
  - **The UFW FORWARD-policy reconciliation needs an explicit user-approved choice** (option a: ACCEPT via `sed + ufw reload`; option b: Docker `iptables: false` in daemon.json). Both work; solution-designer should propose (a) as the simpler default since `hetzner-prod` and `ubuntu-16gb-nbg1-1` both use ACCEPT, and surface (b) as the alternative. The decision gates step 06 (executor).
  - For DNS: the new `qadam-test.ai-dala.com` A record will need a Cloudflare write token (already provisioned: `cloudflare-api-token:ai-dala-infra:ai-dala-write`, Zone DNS Edit for `ai-dala.com`). The token value lives at `C:\Users\tvolo\.config\ai-dala-infra\cloudflare-ai-dala-write.token` (referenced by name only per project hard rules; values stay external).
  - For HTTPS: the QA instance will use the existing Cloudflare edge cert (`*.ai-dala.com` Universal SSL, active). The Cloudflare origin cert `/etc/ssl/cloudflare/ai-dala.pem` lives on `hetzner-prod` only — it needs to be **copied to `pro-data-tech-qa`** so nginx on the QA host can terminate TLS. (Or QA uses the Cloudflare edge cert but loops back to `proxied: false` like `git.ai-dala.com`; that pattern is OK too and avoids the origin-cert copy. Solution-designer should pick the cleanest path and surface it for approval.)
  - The QA stack will be **public-internet-reachable** (the `qadam-test.ai-dala.com` A record is Cloudflare-proxied) — which means UFW will need an additional `allow 80/tcp` and `allow 443/tcp` rule (currently only `allow 22/tcp` is open). This is a state-changing UFW amendment that the task implies but does not enumerate. Solution-designer should surface it.
  - The QA nginx vhost will reverse-proxy `qadam-test.ai-dala.com` → `http://127.0.0.1:3112` (ai-qadam-test app port). nginx is currently **not installed** on `pro-data-tech-qa` — T-0090 deliverable.

- **Verifier preconditions (already met, recorded for step 07's reference):**
  - UFW active, deny-in / allow-out / IPv6-on / forward-DROP (T-0094; the DROP is the T-0090 work item)
  - sshd hardened (T-0093; AllowGroups sshusers, no password auth)
  - fail2ban sshd jail active with mgmt IP in ignoreip (T-0095)
  - Three operator users provisioned with NOPASSWD sudo (T-0097; multi-PC criterion met for `tvolodi`, server-side-parse verified for `viktor_d`/`binali_r`)
  - 0 pending apt upgrades as of 2026-07-07 11:20 UTC (cloud-init brought the system current at provision)
  - 8 vCPU / 15 GiB RAM / 145 GB root disk — plenty of headroom for Docker + ai-qadam test stack

## Issues / risks

- **UFW FORWARD=DROP must be reconciled before any `apt install docker.io` / `docker-ce` step.** If the executor installs Docker first and only later runs `sed + ufw reload`, the reload will succeed but any container traffic during the gap will be silently dropped — likely producing a "compose up succeeds, curl from external host times out" failure mode that is hard to debug. Solution-designer should sequence the FORWARD reconciliation as step 6a (before `apt install`), with a `verify` step (6b) that confirms `cat /proc/sys/net/ipv4/ip_forward` and `iptables -L FORWARD` show the expected state, and the compose stack itself is not started until 6c.
- **Cloudflare origin cert (`/etc/ssl/cloudflare/ai-dala.pem`) is single-source on `hetzner-prod` today.** Either the QA nginx uses `ssl.cloudflare` origin cert (requires copying the .pem + .key from hetzner-prod, mode 600) OR uses Cloudflare DNS-only mode (`proxied: false`, like `git.ai-dala.com`). The two options have different security profiles (origin cert = TLS at origin even if Cloudflare is bypassed; DNS-only = TLS is Cloudflare's job, origin is HTTP). Both work; the choice should be surfaced for user approval.
- **No app-registry entry for `ai-qadam` currently exists.** T-0090 will need to add one (the registry is the canonical source of deploy facts; downstream `deploy-app` workflows read from it). The new entry should follow the ProductFactory / BilimBaga two-environment (test / prod) pattern, but only the **test** environment is in T-0090's scope (the prod environment still lives on hetzner-prod under `/var/www/ai-qadam/`).
- **Multi-PC SSH criterion is partially-deferred for `viktor_d` / `binali_r`.** T-0090 must not regress their server-side-parse-verified status; the executor should not delete or modify their `authorized_keys` files.
- **The user's T-0090 prompt explicitly says "Docker stack with app + db containers"** — this matches the prod ai-qadam 2-container pattern (`ai-qadam-app-1` + `ai-qadam-db-1`). T-0090 should not introduce a 3rd container (no separate `nginx` for the app — the host nginx handles TLS/reverse-proxy).
- **`PermitRootLogin prohibit-password` is permanent** — T-0090 must not finalize `PermitRootLogin no` (the task text and 2026-07-08 user decision both call this out).
- **Postgres dump strategy for the new `qadam-test-db-1` is out of T-0090 scope** (T-0098 follow-on) but the executor should at least create the volume and confirm migrations apply cleanly, and should NOT remove or modify the existing `ai-qadam-db-1` on `hetzner-prod`.
- **No Hetzner Cloud Firewall API to call** — all network changes are host-local (UFW + nginx on `pro-data-tech-qa`). No `hcloud` CLI calls in this run.
- **`/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` on the host still has `PasswordAuthentication yes`** — T-0093 left it in place because `40-disable-password.conf` sorts first under first-wins semantics. T-0090 must not touch it; behavior is correct as-is.
- **The pro-data.tech control plane may or may not have a firewall / snapshot product.** Per project hard rule, the user does not provision paid provider add-ons. The UFW-on-host is sufficient and the policy is "no paid pro-data.tech add-ons." Executor should not attempt to configure any provider-side network or backup product.

## Open questions

- None blocking. The 5 information gaps above (user prefers `role:` value, source repo path, prod-keep-vs-replace, UFW FORWARD option a vs b, origin-cert vs DNS-only) are all decision-points that solution-designer should surface for user approval per the infrastructure workflow's approval gate; they do not block this step.
