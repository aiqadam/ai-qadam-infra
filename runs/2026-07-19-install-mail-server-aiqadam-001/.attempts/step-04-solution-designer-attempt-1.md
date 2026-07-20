---
run_id: 2026-07-19-install-mail-server-aiqadam-001
step: 04
agent: solution-designer
verdict: NEEDS_APPROVAL
created: 2026-07-19T00:20:00Z
task_id: T-0117-install-mail-server-aiqadam
inputs_read:
  - tasks/T-0117-install-mail-server-aiqadam.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-01-task-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-02-landscape-reader.md
  - runs/2026-07-19-install-mail-server-aiqadam-001/step-03-task-validator.md
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/cloudflare.md
  - landscape/domains.md
  - landscape/secrets-inventory.md
  - landscape/services.md
  - workflows/infrastructure.md
  - workflows/_common-operations.md
  - shared/approval-protocol.md
  - shared/app-registry.md
artifacts_changed: []
next_step_hint: step-05 must present the five resolved decisions (host, software, hostname, DMARC policy, outbound relay) explicitly for user confirmation, plus the DNSBL pre-flight and MX-cutover moment as separate, named approval checkpoints per the task's own Notes section.
---

## Summary
Install Stalwart Mail Server (Docker Compose, isolated project `stalwart-mail`) on `pro-data-tech-prod`, reusing hostname `mail.aiqadam.org`, with a `p=none` DMARC soak period and direct-send outbound from day one; provision one test mailbox; then cut `aiqadam.org` MX/SPF/DKIM/DMARC over from the dead third-party host in a separately-flagged, single-record-at-a-time DNS operation — end state is a working, repo-owned, TLS-secured, firewalled mail server with the old dead records fully retired and no orphaned DNS.

## Details

### Decisions resolved (per task's open questions)

**1. Host placement: `pro-data-tech-prod`.**
Reasoning: `ubuntu-16gb-nbg1-1` is currently unhardened at the sshd layer (`PasswordAuthentication yes`, `PermitRootLogin yes`, no `AllowGroups`). Putting an internet-facing mail server (4 new inbound ports, guaranteed to attract scanning/abuse traffic once MX is live) on a host with password-auth SSH still enabled is a categorically worse risk than the alternative — it is a general host-security prerequisite, not something mail-specific mitigates. Hardening `ubuntu-16gb-nbg1-1` first would either (a) silently expand this task's scope into a full sshd-hardening sub-project, or (b) ship mail on a known-weak host. `pro-data-tech-prod` is already hardened (sshd key-only, UFW active, fail2ban active, operator users provisioned) and has ample spare capacity (28 GiB free RAM, 336 GB free disk — mail for dozens of mailboxes is small relative to this). The known risk on `pro-data-tech-prod` — Docker's demonstrated ability to bind `0.0.0.0` and bypass UFW's chain (seen with Penpot port 9001 and aiqadam-prod postgres 3114) — is already-documented and directly mitigable in this plan: mail ports are *supposed* to be internet-reachable (that's the point of a mail server), so the UFW-bypass behavior is not a leak here, provided UFW rules are added explicitly anyway for defense-in-depth and for consistency with the existing convention on this host. Residual risk: this task adds meaningful new blast-radius surface (spam/abuse exposure, cold-IP reputation) to the same host that runs Penpot and AiQadam prod — flagged in Issues/risks below, this is the primary reason for `NEEDS_APPROVAL`.

**2. Software: Stalwart Mail Server.**
Matches the dead server's proven record shape for this domain (existing DNS already has JMAP/CalDAV/CardDAV/IMAPS/POP3S/submission SRV records, MTA-STS, TLS-RPT — all Stalwart-pattern records). Single container, lean resource footprint, built-in JMAP + IMAP + SMTP + webadmin, suitable for dozens of mailboxes.

**3. Mail hostname: reuse `mail.aiqadam.org`.**
Recommended by the task, contingent on the DNSBL check (Plan step 1) not surfacing a blocklisting tied to the hostname itself (blocklists key off IP, not hostname, so reuse is safe regardless — the new IP `95.46.211.224` is what's being checked, and it is already sending legitimate HTTPS traffic for Penpot/AiQadam prod with no observed abuse history). Reduces confusion for anyone with the old hostname cached and avoids inventing a new "mail2"-style name.

**4. DMARC day-one policy: `p=none` with `rua` reporting, tighten later.**
The task's own Notes flag deliverability as the dominant risk on a cold IP; starting at `p=reject` risks silently dropping legitimate outbound mail if SPF/DKIM alignment has any misconfiguration during the initial soak period, with no visibility into failures beyond the `rua` reports. `p=none` still enables full DMARC reporting (aggregate reports to `postmaster@aiqadam.org`) so misconfigurations are visible without live mail loss. Tightening to `p=quarantine` then `p=reject` is a follow-on task once `rua` reports confirm clean alignment (recommend after ~2 weeks of clean reports — flagged as a follow-on, not built into this plan).

**5. Outbound relay: direct-send from the new host's IP (not relayed through SES).**
Reasoning: relaying outbound through the existing `send.aiqadam.org` SES integration was raised by the task as worth considering, but this plan does not adopt it, for three reasons: (a) no credentials or configuration detail for that SES integration exist anywhere in this repo's secrets inventory — landscape-reader confirmed this is a live gap, so relaying through it would require either live-discovering AWS credentials that aren't documented, or the user supplying new ones, either of which is a second live-discovery dependency this plan should not silently assume; (b) mixing relayed-outbound with self-hosted-inbound on the same domain is a more complex mail-flow topology (SPF must authorize both the new host's IP *and* `include:amazonses.com`, DKIM signing would need to happen correctly at whichever hop actually sends) that adds failure surface without a corresponding must-have benefit — dozens of mailboxes is a modest volume where a cold IP's reputation will recover in the normal days-to-weeks window the task's Notes already expect and explicitly say not to treat as a plan failure; (c) it can be adopted later as a pure follow-on (add SES `include:` to SPF, configure Stalwart's outbound relay for specific traffic classes) without any rework of the inbound self-hosted stack designed here. This is flagged as an explicit decision for the user to override at approval time if they'd rather start with SES relay.

### Plan

**Phase 0 — Pre-flight discovery (read-only, must run and be recorded before any state change)**

1. Re-probe the dead host's mail ports live (task-validator flagged this as unverified by landscape, only asserted in the task file) — command: `Test-NetConnection 212.20.151.29 -Port 25` and `Test-NetConnection 212.20.151.29 -Port 993` (run from management workstation, PowerShell) — verification: both show `TcpTestSucceeded: False`, confirming the old host is still dead before any DNS is touched. If either succeeds, STOP and re-escalate to the user — the premise of this whole task (old server is dead) would be invalidated.
2. DNSBL check of `95.46.211.224` (the chosen host's public IP) — command (from management workstation, using a DNSBL-checking tool or manual PTR-style lookups against major lists): `nslookup 224.211.46.95.zen.spamhaus.org` and `nslookup 224.211.46.95.bl.spamcop.net` and `nslookup 224.211.46.95.b.barracudacentral.org` — verification: all three return `NXDOMAIN` (not listed). If any returns an address (listed), STOP — do not proceed with this host; report to the user before continuing (would force re-opening the host-placement decision).
3. Confirm no listener currently on the mail ports on `pro-data-tech-prod` — command: `ssh -i "C:\Users\tvolo\.ssh\ai-dala-infra" -o IdentitiesOnly=yes tvolodi@95.46.211.224 "sudo ss -tlnp | grep -E ':(25|465|587|993|443|8080)\b'"` — verification: no output referencing ports 25/465/587/993 (443/8080 expected already, from nginx/Penpot — not a conflict since Stalwart's admin/JMAP will run on a distinct internal port, proxied if needed).

**Phase 1 — Install Stalwart via Docker Compose (isolated project)**

4. Create the Compose directory — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /opt/stalwart-mail && sudo chown tvolodi:tvolodi /opt/stalwart-mail"` — verification: `ls -la /opt/stalwart-mail` shows the directory owned `tvolodi:tvolodi`.
5. Write `/opt/stalwart-mail/docker-compose.yml` (project name `stalwart-mail`, explicit `name:` key to avoid any directory-basename collision with `penpot`/`aiqadam-prod`):

   ```yaml
   name: stalwart-mail
   services:
     stalwart:
       image: stalwartlabs/mail-server:latest
       container_name: stalwart-mail-server-1
       restart: unless-stopped
       ports:
         - "25:25"
         - "465:465"
         - "587:587"
         - "993:993"
         - "127.0.0.1:8080:8080"
       volumes:
         - stalwart_data:/opt/stalwart
         - /etc/letsencrypt/live/mail.aiqadam.org:/opt/stalwart/certs:ro
       environment:
         - STALWART_HOSTNAME=mail.aiqadam.org
   volumes:
     stalwart_data:
   ```

   Notes: JMAP/webadmin (port 8080) bound to `127.0.0.1` only — deliberately not internet-facing; exposed externally only later via an nginx reverse-proxy vhost with its own TLS, mirroring the existing Penpot/AiQadam-prod pattern rather than a raw Docker port publish, so it inherits the same UFW-plus-nginx posture and does not repeat the Docker-bypass exposure already seen with Penpot 9001. SMTP/submission/IMAPS ports (25/465/587/993) are bound `0.0.0.0` deliberately — these must be internet-reachable for mail to function, this is not an accidental exposure.
   Command to write the file: use `Write`/`scp`-equivalent (heredoc over SSH) — exact form: `ssh ... tvolodi@95.46.211.224 "cat > /opt/stalwart-mail/docker-compose.yml"` with the content above piped in, or `scp` a locally-authored file to `/opt/stalwart-mail/docker-compose.yml`.
   Verification: `cat /opt/stalwart-mail/docker-compose.yml` on host matches the authored content exactly (diff check).

6. Obtain TLS certificate for `mail.aiqadam.org` BEFORE starting Stalwart (Stalwart's compose mounts the cert path read-only) — command: `ssh ... tvolodi@95.46.211.224 "sudo certbot certonly --nginx -d mail.aiqadam.org --non-interactive --agree-tos -m postmaster@aiqadam.org"` — this requires the `mail.aiqadam.org` DNS A record to already point at `95.46.211.224` for HTTP-01 validation to succeed, so this step is **sequenced after** DNS Phase 3 step 12 (the A record), not before — reorder note: execute Phase 3 steps 12–13 (A record + freshness check) before this step 6, then return to Compose bring-up. Verification: `sudo certbot certificates -d mail.aiqadam.org` shows a valid, non-expired cert; `ls /etc/letsencrypt/live/mail.aiqadam.org/` shows `fullchain.pem`/`privkey.pem`.
7. Bring up the Compose project — command: `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose up -d"` — verification: `docker compose -p stalwart-mail ps` shows `stalwart-mail-server-1` state `Up`/`running`; `docker logs stalwart-mail-server-1 --tail 50` shows no fatal startup errors.
8. Confirm Penpot and AiQadam-prod unregressed (mandatory no-regression checkpoint, matching T-0111/T-0112/T-0113 precedent on this host) — command: `ssh ... tvolodi@95.46.211.224 "docker ps --filter label=com.docker.compose.project=penpot --format '{{.Names}}: {{.Status}}'"` and `"docker ps --filter label=com.docker.compose.project=aiqadam-prod --format '{{.Names}}: {{.Status}}'"` and external `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` / `https://aiqadam.org/health` — verification: all 7 Penpot containers `Up`, all 3 aiqadam-prod containers `Up`, both external checks return 200.

**Phase 2 — Firewall rules (UFW)**

9. Add UFW rules for the 4 new inbound mail ports — command: `ssh ... tvolodi@95.46.211.224 "sudo ufw allow 25/tcp && sudo ufw allow 465/tcp && sudo ufw allow 587/tcp && sudo ufw allow 993/tcp"` — verification: `sudo ufw status verbose` lists all four as `ALLOW IN` (v4+v6), in addition to the existing 22/80/443. No other ports added.
10. Confirm JMAP/webadmin (8080) is NOT exposed by UFW and NOT reachable externally — command (from management workstation): `Test-NetConnection 95.46.211.224 -Port 8080` — verification: `TcpTestSucceeded: False` (loopback-bound, no UFW rule, and no Docker bypass risk since it's bound to `127.0.0.1` not `0.0.0.0`).

**Phase 3 — DNS cutover (Cloudflare `aiqadam.org` zone — single named-record operations only, freshness-check immediately before each write, matching T-0110/T-0111 precedent)**

All Cloudflare API calls use `cloudflare-ai-qadam-api-token` (secrets-inventory name only). Zone ID `bec8854d698d56ff17cf917367634100`. Every step: `GET` the specific record immediately before mutating it to confirm it still matches the value documented in `landscape/cloudflare.md`; abort that step and escalate if it has drifted.

11. Freshness-check + generate DKIM keypair inside Stalwart (via its admin API/CLI, selector `mail`) — command: `ssh ... tvolodi@95.46.211.224 "docker exec stalwart-mail-server-1 stalwart-cli ... dkim generate --domain aiqadam.org --selector mail"` (exact CLI invocation to be confirmed against Stalwart's actual admin-API/CLI surface at execution time — Stalwart's DKIM key generation is typically driven via its webadmin UI or a REST call to `/api/dkim`; executor must consult the installed version's actual documented mechanism at execution time rather than assume this exact command works verbatim) — verification: DKIM public key text captured for the DNS TXT record in step 16.
12. Freshness-check the current `mail.aiqadam.org` A record (`212.20.151.29`, unproxied, TTL 300) via `GET /zones/bec8854d698d56ff17cf917367634100/dns_records?name=mail.aiqadam.org&type=A`, then `PATCH` its `content` to `95.46.211.224` (leave `proxied: false`, same record ID, same TTL) — verification: `GET` the record again, confirm `content: 95.46.211.224`, `modified_on` updated.
13. Run certbot (Plan step 6) now that the A record resolves correctly.
14. Freshness-check + `PATCH` the `aiqadam.org` MX record (`mail.aiqadam.org`, prio 10) — content unchanged (still points at `mail.aiqadam.org`, which now resolves correctly per step 12) — **this record technically needs no value change since it already names `mail.aiqadam.org` and only the A record target changed.** No-op confirmed by `GET`; if truly unchanged, skip the `PATCH` entirely (idempotent — nothing to do). **This is the cutover moment per the task's Notes — flagged for explicit separate confirmation at step 05, even though the DNS payload itself is unchanged, because this is the point at which the record starts resolving to a live, repo-owned mail server instead of a dead host.**
15. Freshness-check + `PATCH` the apex `aiqadam.org` SPF TXT record (`v=spf1 ip4:212.20.151.29 mx -all` → `v=spf1 ip4:95.46.211.224 mx -all`) — verification: `GET` confirms new content.
16. Freshness-check + `PATCH` the `mail._domainkey.aiqadam.org` TXT record with the new DKIM public key generated in step 11 (replacing the old RSA key) — verification: `GET` confirms new content; `dig TXT mail._domainkey.aiqadam.org` from an external resolver returns the new key.
17. Freshness-check + `PATCH` the `_dmarc.aiqadam.org` TXT record: `v=DMARC1; p=reject; rua=mailto:postmaster@aiqadam.org` → `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org` (per Decision 4) — verification: `GET` confirms new content.
18. Freshness-check + `PATCH` the `mail.aiqadam.org` A record's sibling TXT (`mail.aiqadam.org` TXT = `v=spf1 a -all`) — leave as-is; it is a secondary SPF record scoped to the `mail.` name itself (not the apex) and remains correct once the A record points at the new host (an `a -all` SPF policy authorizes whatever the `mail.aiqadam.org` A record resolves to, which is now `95.46.211.224` — no change needed, confirmed by `GET` only, no `PATCH`).
19. Freshness-check + `PATCH` `webmail.aiqadam.org` A record → `95.46.211.224` if a webmail UI is stood up (Stalwart's built-in webadmin does not include end-user webmail; if no webmail product is deployed in this pass, instead **delete** this record rather than leave it pointing at the dead host — decision: delete, since this plan does not stand up a separate webmail product; flag as a follow-on if the user wants a Snappymail-equivalent later). Command: `DELETE /zones/.../dns_records/<webmail-record-id>` — verification: `GET` on that record ID returns 404.
20. Freshness-check + update or delete the 4 stale CNAMEs (`autoconfig`, `autodiscover`, `mta-sts`, `ua-auto-config` — all CNAME to `mail.aiqadam.org`): since they CNAME to `mail.aiqadam.org` (not to the dead IP directly), and that name now resolves correctly (step 12), **`autoconfig`/`autodiscover` require no change** (Thunderbird/Outlook autoconfig will now hit the new Stalwart host — verify Stalwart actually serves valid autoconfig/autodiscover responses at that hostname; if not, these should be deleted rather than left dangling-but-resolving-wrong). `mta-sts` and `ua-auto-config` are tied to MTA-STS, which this plan does NOT implement in this pass (out of scope decision below) — **delete** `mta-sts.aiqadam.org` CNAME, `_mta-sts.aiqadam.org` TXT, and `_ua-auto-config.aiqadam.org`/`ua-auto-config.aiqadam.org` records (Stalwart is not configured to serve an MTA-STS policy file in this plan, so leaving these records live would advertise a policy this host doesn't actually serve — actively misleading, worse than absent). Verification: `GET` on each deleted record ID returns 404; `GET` on `autoconfig`/`autodiscover` CNAMEs confirms unchanged content, and a live HTTP probe to `https://autoconfig.aiqadam.org/mail/config-v1.1.xml` is run post-cutover to confirm Stalwart actually answers there (if not, follow-on task to fix or remove).
21. Freshness-check + `PATCH` the 6 stale SRV records (`_caldavs`, `_carddavs`, `_imaps`, `_jmap`, `_pop3s`, `_submissions`, all targeting `mail.aiqadam.org`) — since Stalwart serves IMAPS (993) and JMAP, and the new A record now resolves correctly, `_imaps._tcp` and `_jmap._tcp` need **no content change** (same target name, now correctly resolving). `_caldavs`/`_carddavs` (CalDAV/CardDAV, port 443) and `_pop3s` (POP3S, 995) are **not implemented by this plan** (Stalwart is being deployed for SMTP/IMAP/JMAP only, per Plan step 5's port list — no 443 CalDAV/CardDAV service, no POP3 service) — **delete** these 3 SRV records rather than leave them advertising unimplemented protocols. `_submissions._tcp` (465, matches the deployed submission port) needs no change. Verification: `GET` on the 3 deleted record IDs returns 404; `GET` on `_imaps`/`_jmap`/`_submissions` confirms unchanged.
22. Freshness-check + `PATCH` `_smtp._tls.aiqadam.org` TXT (TLS-RPT, `v=TLSRPTv1; rua=mailto:postmaster@aiqadam.org`) — **no change needed**, this record is host-independent (just declares a reporting address) and remains valid; confirmed via `GET` only, no `PATCH`.
23. **Explicitly out of scope for this pass, confirmed unchanged, not touched:** `resend._domainkey.aiqadam.org` (separate transactional integration, per landscape-reader's flag — do not touch), `send.aiqadam.org` MX/TXT (SES integration, per Decision 5 — not adopted as outbound relay in this pass, left fully alone), the wildcard `*.aiqadam.org`, and all 5 tunnel/GitHub-Pages records. Verification: post-cutover full zone dump (33 → net count after this plan's deletions, see reconciliation below) confirms these records are byte-for-byte unchanged.

**Phase 4 — Mailbox provisioning**

24. Create one test mailbox via Stalwart's admin CLI/API — command: `ssh ... tvolodi@95.46.211.224 "docker exec stalwart-mail-server-1 stalwart-cli account create test@aiqadam.org --password <generated>"` (exact command per Stalwart's actual installed-version CLI surface — confirm at execution time) — verification: `stalwart-cli account list` shows `test@aiqadam.org`; a generated password is stored as a new secrets-inventory entry (name only, e.g. `stalwart-mail-test-account-password`), not the value.
25. Document the mailbox provisioning mechanism (CLI command shape, or webadmin UI reachable at `https://mail.aiqadam.org/admin` once nginx-proxied) in `landscape/hosts/pro-data-tech-prod.md` at step 08.

**Phase 5 — nginx vhost for Stalwart webadmin (optional but recommended for admin usability)**

26. Add nginx vhost proxying `https://mail.aiqadam.org/admin` (or a dedicated path) to `127.0.0.1:8080`, TLS via the same cert obtained in step 6, following the existing Penpot/AiQadam-prod vhost pattern exactly — command: write `/etc/nginx/sites-available/mail.aiqadam.org`, symlink to `sites-enabled`, `sudo nginx -t && sudo systemctl reload nginx` — verification: `https://mail.aiqadam.org/admin` returns Stalwart's login page (200), external probe from management workstation.

**Phase 6 — Verification / deliverability testing**

27. Internal SMTP/IMAP/JMAP reachability — command (from management workstation): `Test-NetConnection mail.aiqadam.org -Port 25`, `-Port 465`, `-Port 587`, `-Port 993` — verification: all `TcpTestSucceeded: True`.
28. TLS validity — command: `openssl s_client -connect mail.aiqadam.org:993 -servername mail.aiqadam.org </dev/null 2>/dev/null | openssl x509 -noout -dates -subject` (via Bash tool, or equivalent) — verification: cert subject `mail.aiqadam.org`, not expired, issued by Let's Encrypt.
29. DNS propagation checks — command: `nslookup mail.aiqadam.org 1.1.1.1`, `nslookup -type=MX aiqadam.org 1.1.1.1`, `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1`, `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` — verification: each resolves to the new values from an external resolver (not just locally-cached).
30. External send/receive test: send a message from an external Gmail (or equivalent) address to `test@aiqadam.org`; confirm receipt via IMAP (e.g., `openssl s_client` IMAPS session or a mail client). Send a reply from `test@aiqadam.org` to the external address; confirm arrival (inbox or spam — record which, per task's Notes, spam-landing on a cold IP is expected and NOT a plan failure).
31. mail-tester.com score: send a message from `test@aiqadam.org` to the mail-tester.com-provided address, capture the resulting score as the deliverability baseline — recorded in `landscape/hosts/pro-data-tech-prod.md` and in the task file's close-out notes.

**Phase 7 — Backups**

32. Local-disk-only backup of the Stalwart data volume (per this repo's no-off-site-storage rule) — command: `ssh ... tvolodi@95.46.211.224 "sudo mkdir -p /var/backups/stalwart-mail && sudo docker run --rm -v stalwart-mail_stalwart_data:/data -v /var/backups/stalwart-mail:/backup alpine tar czf /backup/stalwart-data-$(date +%Y%m%dT%H%M%SZ).tar.gz -C /data ."` — verification: `ls -la /var/backups/stalwart-mail/` shows the new tarball, non-zero size. Recommend a daily cron/systemd-timer follow-on (not built in this pass — flagged as follow-on, matching the "no automated backup strategy yet" pattern already accepted for Penpot on this same host) with a 14-day local retention (rotate older files) — retention approach to be confirmed with the user at step 05.

### Rollback

Rollback is phase-scoped; DNS and host-install rollback are independent (host install failing does not require DNS rollback, and vice versa, except for the MX/A-record step which is the one true point of no return once real mail starts flowing to the new host).

1. **Compose install rollback (Phases 0–1, steps 4–8):** `ssh ... tvolodi@95.46.211.224 "cd /opt/stalwart-mail && docker compose down -v"` then `sudo rm -rf /opt/stalwart-mail` — fully reversible, no external state touched yet at this point (DNS still points at the dead host until Phase 3).
2. **UFW rules rollback (Phase 2, step 9):** `ssh ... tvolodi@95.46.211.224 "sudo ufw delete allow 25/tcp && sudo ufw delete allow 465/tcp && sudo ufw delete allow 587/tcp && sudo ufw delete allow 993/tcp"` — fully reversible.
3. **DNS rollback (Phase 3, steps 12, 15, 16, 17):** re-`PATCH` each specific record back to its pre-change documented value (A record → `212.20.151.29`/proxied false; SPF → `v=spf1 ip4:212.20.151.29 mx -all`; DKIM TXT → prior RSA key value, captured verbatim from `landscape/cloudflare.md` before this run's changes; DMARC → `v=DMARC1; p=reject; rua=mailto:postmaster@aiqadam.org`). **Caveat, matching the task's own Notes on reversibility:** this DNS-level rollback is a clean no-op ONLY before real mail starts flowing and before any external party (client autoconfig, other senders' SPF caches) has picked up the new records. Once mailboxes are in active use, "rollback" the DNS layer is technically simple but operationally means abruptly cutting live mail service to real users — not a true no-op recovery, exactly as the task's Notes already state. This plan's rollback restores DNS to point at a host that is confirmed dead (Phase 0 step 1) — i.e., rollback returns the domain to a **non-functional** state for mail, not to a working prior state. This should be understood as an emergency-stop, not a safe revert.
4. **Deleted-record rollback (Phase 3, steps 19, 20, 21 — `webmail`, `mta-sts`/`ua-auto-config`, `_caldavs`/`_carddavs`/`_pop3s`):** re-`CREATE` each deleted record with its exact pre-deletion name/type/content/TTL, captured verbatim from `landscape/cloudflare.md` before this run executes (executor must snapshot the full pre-change record set for these specific records before deleting, not just rely on the landscape file, per freshness-check discipline). Recreatable but record IDs will differ (Cloudflare assigns new IDs on create) — update landscape accordingly at step 08 either way.
5. **Mailbox/data rollback (Phase 4):** delete the test account (`stalwart-cli account delete test@aiqadam.org`); no real user data exists yet in this plan's scope (test mailbox only), so no data-loss risk from rollback at this stage.
6. **No rollback needed for Phase 6 (verification, read-only) or Phase 7 (backup, additive-only).**

### Verification (for step 07)

- **On-host:**
  - `docker compose -p stalwart-mail ps` → `stalwart-mail-server-1` `Up`/`healthy`.
  - `docker logs stalwart-mail-server-1 --tail 100` → no fatal errors, no repeated crash-loop restarts.
  - `sudo ufw status verbose` → 22/80/443/25/465/587/993 all `ALLOW IN`, no other new rules.
  - `sudo ss -tlnp` → confirms 25/465/587/993 bound `0.0.0.0`, 8080 bound `127.0.0.1` only.
  - Penpot: `docker ps --filter label=com.docker.compose.project=penpot` → 7/7 `Up`.
  - AiQadam prod: `docker ps --filter label=com.docker.compose.project=aiqadam-prod` → 3/3 `Up`.
  - `/etc/letsencrypt/live/mail.aiqadam.org/` cert files present, not expired.
  - `/var/backups/stalwart-mail/` contains at least one non-zero-size tarball.
  - `stalwart-cli account list` → `test@aiqadam.org` present.
- **External:**
  - `Test-NetConnection mail.aiqadam.org -Port 25/465/587/993` → all `TcpTestSucceeded: True`.
  - `Invoke-WebRequest https://penpot.aiqadam.org -Method Head` → 200 (no regression).
  - `Invoke-WebRequest https://aiqadam.org/health` → 200 (no regression).
  - `Invoke-WebRequest https://mail.aiqadam.org/admin` → 200 (Stalwart webadmin reachable, if Phase 5 done).
  - `nslookup mail.aiqadam.org 1.1.1.1` → `95.46.211.224`.
  - `nslookup -type=MX aiqadam.org 1.1.1.1` → `mail.aiqadam.org` prio 10 (unchanged target, now resolving correctly).
  - `nslookup -type=TXT aiqadam.org 1.1.1.1` (SPF) → `v=spf1 ip4:95.46.211.224 mx -all`.
  - `nslookup -type=TXT _dmarc.aiqadam.org 1.1.1.1` → `v=DMARC1; p=none; rua=mailto:postmaster@aiqadam.org`.
  - `nslookup -type=TXT mail._domainkey.aiqadam.org 1.1.1.1` → new DKIM key present.
  - External send test to `test@aiqadam.org` from Gmail → delivered (confirm via IMAP fetch).
  - External send test from `test@aiqadam.org` to Gmail → arrives (inbox or spam, both acceptable — record which).
  - mail-tester.com score captured and recorded (any score acceptable as a baseline — this is not a pass/fail gate).
  - Full 33-minus-N-record Cloudflare zone dump (post-cutover) diffed against the pre-run snapshot: confirms `resend._domainkey`, `send.aiqadam.org` MX/TXT, wildcard, and all 5 tunnel/pages records are byte-for-byte unchanged, and that no record outside this plan's explicitly-named list was touched.

### Resources used
- **Secrets (by name):** `cloudflare-ai-qadam-api-token` (existing); new entries to be added at step 08: `stalwart-mail-dkim-private-key` (selector `mail`, generated in-container, private key never leaves the host), `stalwart-mail-test-account-password`, `stalwart-mail-admin-password` (if webadmin auth is set up with a dedicated admin credential distinct from the test account).
- **Files modified on host (`pro-data-tech-prod`):** new `/opt/stalwart-mail/docker-compose.yml` + Docker volume `stalwart-mail_stalwart_data`; new `/etc/nginx/sites-available/mail.aiqadam.org` (+ symlink); new `/etc/letsencrypt/live/mail.aiqadam.org/`; UFW rules (4 new `allow` entries); new `/var/backups/stalwart-mail/`.
- **Files modified in this repo (`landscape/`) — to be applied at step 08:**
  - `landscape/hosts/pro-data-tech-prod.md` (new "Stalwart Mail" section, new UFW rules, new Compose project, new nginx vhost, new cert)
  - `landscape/services.md` (new Compose project row under `pro-data-tech-prod`)
  - `landscape/cloudflare.md` (A/MX/SPF/DKIM/DMARC record changes, 5-ish record deletions, updated "mail records" table — reclassify from "NOT managed by this repo" to "managed by this repo")
  - `landscape/domains.md` (new `mail.aiqadam.org` subdomain + TLS cert entry)
  - `landscape/secrets-inventory.md` (new mail-related secret names)
  - `shared/app-registry.md` optionally, if the team treats mail as an "app" worth a registry entry (not required, at designer's discretion — recommend a short mention for discoverability)
- **External APIs called:** Cloudflare DNS API (`GET`/`PATCH`/`DELETE` on named records only, zone `bec8854d698d56ff17cf917367634100`).

### Estimated impact
- **Downtime:** none for Penpot/AiQadam prod (additive changes only, verified unregressed at every checkpoint). For mail itself: none in the "outage" sense, since the old mail service is already confirmed dead (nothing currently works) — but the MX/A-record cutover (Phase 3, steps 12/14) is the moment mail routing for `aiqadam.org` becomes live and real for the first time on infrastructure this repo controls; any misconfiguration discovered after this point affects real inbound mail attempts, not a rollback-costless staging step.
- **Affected services:** New: Stalwart mail (SMTP/IMAP/JMAP) on `pro-data-tech-prod`. Unaffected (verified at every checkpoint): Penpot, AiQadam prod. Affected indirectly: the `aiqadam.org` Cloudflare zone (shared with third parties who do not depend on the mail records being touched, per landscape's own analysis — the mail records are exclusively about the dead third-party mail platform, not shared with the Coolify/tunnel/pages records).
- **Reversibility:** Host install and UFW rules — fully reversible, no data loss. DNS changes — technically reversible at the record level (rollback commands exist for every mutated/deleted record) but, per the task's own Notes and echoed in this plan's Rollback section, reverting after real mail traffic begins is an operational migration-away-from-service event, not a safe no-op — **partially reversible in the practical sense**, fully reversible in the narrow technical sense.

## Issues / risks

- **HIGH — shared-host blast radius.** Placing mail on `pro-data-tech-prod` adds spam/abuse exposure and cold-IP reputation risk to the same host that serves Penpot and AiQadam prod. A future IP-reputation problem (e.g., the host's IP getting blocklisted due to mail abuse) could, in the worst case, affect the shared IP's reputation for the web-facing services too (different protocols/ports, but same IP — DNSBL listings are typically SMTP-specific, so cross-contamination to HTTPS is unlikely but not zero). This is the primary driver of `NEEDS_APPROVAL`.
- **HIGH — DNS is shared, partially-owned zone surgery.** Per the task's own Notes, this is the same class of operation as T-0111's apex repoint, but broader (multiple record types, several deletions). Even with single-named-record-at-a-time discipline and freshness checks, this remains irreversible-in-practice once mail traffic begins, and touches a zone with 30 records this repo does not own.
- **MEDIUM — MTA-STS/TLS-RPT records are being deleted, not replaced.** This plan does not implement MTA-STS in this pass (would require serving a policy file at `https://mta-sts.aiqadam.org/.well-known/mta-sts.txt`, not built here). Deleting rather than leaving stale is the safer choice (a stale-but-resolving MTA-STS record advertising an unenforced policy is worse than no record), but this is itself a judgment call the user should confirm rather than assume.
- **MEDIUM — CalDAV/CardDAV/POP3 SRV records are being deleted.** This plan deploys Stalwart for SMTP/IMAP/JMAP only. If community members expect calendar/contacts sync or POP3 access (the old server apparently offered these, per the SRV record inventory), this is a functional regression from the old (dead) service's apparent feature set, not just a DNS cleanup. Flagging so the user can decide if CalDAV/CardDAV support should be in scope before cutover.
- **MEDIUM — exact Stalwart CLI/API commands for DKIM generation and account creation (Plan steps 11, 24) are approximate.** Landscape does not include a live Stalwart install to confirm exact command syntax for the specific image version pulled at execution time (`stalwartlabs/mail-server:latest`). Executor must consult the container's actual admin interface (webadmin UI is the more likely primary interface for current Stalwart versions, not a bare CLI) at execution time and adapt; this is normal execution-time discovery, not a design gap, but flagged since the exact commands in this plan are illustrative rather than guaranteed-correct.
- **LOW — autoconfig/autodiscover records are left pointing at `mail.aiqadam.org` on the assumption Stalwart serves valid responses there.** Not verified in this design pass (no live Stalwart instance yet) — Phase 6 step 20's post-cutover probe is the actual verification; if Stalwart doesn't serve these paths, a follow-on fix or record deletion is needed.
- **LOW — resource contention.** Mail for "dozens of mailboxes" is a small workload relative to this host's 28 GiB free RAM / 336 GB free disk; no capacity concern, noted only for completeness.

## Open questions (optional)
None blocking — the five decisions the task explicitly deferred to solution-design time have been resolved with reasoning above. The following should be surfaced to the user at step 05 for confirmation/override, not because the plan cannot proceed without them, but because the task's Notes call for explicit confirmation on several of these specifically:
- Confirm host placement (`pro-data-tech-prod`, accepting the shared-blast-radius tradeoff) vs. investing first in hardening `ubuntu-16gb-nbg1-1`.
- Confirm DMARC `p=none` day-one (vs. immediate `p=reject`).
- Confirm direct-send outbound (vs. building SES relay now).
- Confirm deletion (not preservation) of MTA-STS/TLS-RPT-related records and CalDAV/CardDAV/POP3 SRV records, given the old server apparently offered these.
- Confirm the MX/A-record cutover moment itself as a distinct, named go/no-go, separate from the rest of plan approval, per the task's Notes requirement.
