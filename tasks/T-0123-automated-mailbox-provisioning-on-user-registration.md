---
id: T-0123-automated-mailbox-provisioning-on-user-registration
title: Automated @aiqadam.org mailbox provisioning on platform user registration
kind: task
status: pending
priority: P2
created: 2026-07-23
updated: 2026-07-23
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: []
affects:
  - shared/mail-provisioning-protocol.md
  - landscape/secrets-inventory.md
  - landscape/hosts/pro-data-tech-prod.md
workflow: manual
blocks: []
blocked_by: []
related:
  - T-0117-install-mail-server-aiqadam.md
  - T-0122-deploy-roundcube-webmail-pro-data-tech-prod.md
estimated_blast_radius: low
estimated_reversibility: full
---

# Automated @aiqadam.org mailbox provisioning on platform user registration

## Why

Currently, getting an `@aiqadam.org` mailbox is a manual, admin-gated process: a user emails `postmaster@aiqadam.org`, the admin manually creates the mailbox via the Stalwart web panel, then notifies the user through a separate channel. This is a bottleneck as the community grows.

The agreed design integrates mailbox creation into the platform's user registration flow: when a user registers for a chapter/tenant on aiqadam.org, the NestJS `apps/api` automatically provisions a `<username>@aiqadam.org` mailbox via the Stalwart JMAP API (loopback `http://127.0.0.1:8080` — same host, no external exposure). A "set your password" link is emailed to the user's personal address.

Design decisions agreed 2026-07-23 (discussed in conversation prior to task creation):

| Decision | Choice |
|---|---|
| Mailbox local-part | Platform `username` (globally unique; enforced by the platform's own constraint) |
| Password delivery | "Set your password" link sent to user's personal (registration) email — no raw password in email |
| Transactionality | None — mailbox creation failure logs and continues; platform user registration is NOT rolled back |
| Forwarding | Optional, on-request (not automatic at registration); uses a standard Sieve script template parameterized by destination address |

## What done looks like

### Application (apps/api in aiqadam/ai-qadam-platform)

- [ ] `MailboxModule` / `MailboxService` added to `apps/api`, wrapping the Stalwart JMAP API:
  - `provision(username: string)` — creates a `<username>@aiqadam.org` account via `x:Account/set` with a system-generated, locked initial credential; domain ID `b` (Stalwart's stable internal ID for `aiqadam.org`)
  - `enableForwarding(username: string, forwardTo: string)` — uploads the standard Sieve blob and activates it for the user's account (same JMAP blob-upload + `SieveScript/set` pattern documented in `mail-provisioning-protocol.md`)
- [ ] Registration handler in `apps/api` calls `MailboxService.provision(username)` **after** the platform user record is committed; failure is caught, logged (warn level), and does NOT propagate to the HTTP response
- [ ] "Set your password" email sent to the user's personal address via Stalwart SMTP submission (`mail.aiqadam.org:587`, sender `postmaster@aiqadam.org`)
- [ ] Forwarding is NOT triggered automatically at registration — it is a separate, explicitly-triggered action (e.g. a user-profile endpoint, an admin call, or a future self-service UI)

### Sieve forwarding template

The `MailboxService` uses a single constant template — never designed per-user:

```
require ["copy", "redirect"];
redirect :copy "<FORWARD_TO>";
```

Only `<FORWARD_TO>` is substituted. All users get structurally identical scripts; the template never changes unless the forwarding behaviour itself changes.

### Infrastructure

- [ ] New named secret added to `landscape/secrets-inventory.md`: `aiqadam-prod-stalwart-admin-password` (the Stalwart recovery admin password, already exists in `credentials.md` — this task formalises it as an api-consumed secret)
- [ ] `aiqadam-prod` api env file (`/opt/apps/aiqadam-prod/deploy/.env`) updated with `STALWART_JMAP_URL=http://127.0.0.1:8080`, `STALWART_ADMIN_USER=admin`, `STALWART_ADMIN_PASSWORD=<aiqadam-prod-stalwart-admin-password>`, and `STALWART_POSTMASTER_PASSWORD=<aiqadam-prod-stalwart-postmaster-password>` (for SMTP submission)
- [ ] Same four env vars added to the QA env file (`/opt/apps/aiqadam-qa/deploy/.env`) pointing at the same prod Stalwart (QA does not run its own mail server; QA mailbox provisioning calls prod Stalwart or is stubbed in the QA compose stack — decision deferred to implementation)
- [ ] `mail-provisioning-protocol.md` updated to document the automated flow alongside the manual flow (see related protocol changes in this task)

## Notes

### Stalwart JMAP path
The `aiqadam-prod-api-1` container binds `127.0.0.1:3115` and Stalwart's JMAP endpoint is `http://127.0.0.1:8080` — both on `pro-data-tech-prod` (95.46.211.224). The call is loopback; no UFW rule changes needed. Stalwart's Docker bridge IP (`172.x.x.x`) was already whitelisted from auto-ban (T-0121); the api container uses `network_mode: host`, so its source IP is `127.0.0.1`, which was never subject to auto-ban.

### Username collision
The platform enforces `username` uniqueness within the platform. However, pre-provisioned Stalwart accounts (manually created before this feature ships, e.g. `vladimir.titenko`, `binali.rustamov`, `aigerim.kambetbayeva`) will conflict if a user registers with a matching username. `MailboxService.provision()` should detect the JMAP conflict error and log a warning (not crash registration). Resolution for pre-existing accounts is an admin action, not handled automatically.

### QA environment
The QA stack (`aiqadam-qa`) runs only `oidc-stub` + `api`; there is no Stalwart on that host. Options at implementation time:
1. Point QA env vars at prod Stalwart (real provisioning in a shared mail server — acceptable if test registrations are cleaned up)
2. Mock/stub `MailboxService` in the QA compose stack
3. Add a `MAILBOX_PROVISIONING_ENABLED=false` flag that short-circuits the JMAP call in non-prod environments

Decision deferred to implementation — not a blocker for the task.

### SMTP sending (password-reset link email)
Sending from `postmaster@aiqadam.org` via `mail.aiqadam.org:587` requires SMTP AUTH credentials for `postmaster`. These are separate from the JMAP admin credentials. A new secret `aiqadam-prod-stalwart-postmaster-password` must be added to `secrets-inventory.md` and the env files. Alternatively, use the existing NestJS outbox/notification service if one already exists in the codebase (check before adding a new SMTP client).

### Domain ID stability
Stalwart domain ID `b` for `aiqadam.org` was confirmed during T-0117 and is a stable internal JMAP opaque ID (assigned at domain creation, not expected to change unless the domain is deleted and re-added). Hard-code as a named constant, not a magic string.

## History
- 2026-07-23: created (design agreed in conversation 2026-07-23)
