---
id: T-0129-stalwart-roundcube-authentik-sso
title: SSO Roundcube webmail + Stalwart admin UI via Authentik OIDC; standardize on webmail-only mail access
kind: task
status: pending
priority: P2
created: 2026-07-27
updated: 2026-07-28
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
  - landscape/secrets-inventory.md
workflow: infrastructure
blocks: []
blocked_by: []
related: [T-0128-plausible-authentik-sso-gate]
estimated_blast_radius: medium
estimated_reversibility: full
---

# SSO Roundcube webmail + Stalwart admin UI via Authentik OIDC; standardize on webmail-only mail access

## Why

Continuation of the single-username/single-password architecture
decision (see [T-0128](T-0128-plausible-authentik-sso-gate.md)'s Why
section for the full context — Authentik as the one identity source
across every AI Qadam platform module).

For Stalwart Mail, research during the 2026-07-27 conversation
(well-sourced against stalw.art's official docs and stalwartlabs GitHub,
specific to the deployed version 0.16.13) established a hard split:

| Surface | Can it use Authentik SSO? |
|---|---|
| Roundcube webmail (`webmail.aiqadam.org`) | **Yes** — Roundcube has its own OIDC login plugin (e.g. `roundcube-oidc`); Stalwart 0.16.13 supports the `OAUTHBEARER`/`XOAUTH2` SASL mechanism server-side for the IMAP/SMTP leg that follows |
| Stalwart's own admin UI (`mail.aiqadam.org`) | **Yes** — native OIDC admin login shipped in Stalwart 0.16.0 |
| Native mail clients (Outlook, Apple Mail, phone mail apps, stock Thunderbird) | **No** — these do not support third-party-IdP `OAUTHBEARER`/`XOAUTH2`; this is a mail-client-ecosystem limitation, not specific to Stalwart. The only workaround is Stalwart-issued App Passwords, which are themselves a second, non-Authentik credential — defeating the unification goal. |

**Explicit user decision (2026-07-27):** rather than accept a permanent
split (some users on SSO'd webmail, others on app-password native
clients), standardize on **webmail-only mail access**. Roundcube becomes
the one supported way to read/send `@aiqadam.org` mail; native mail
clients are not a supported configuration going forward. This makes the
"single username, single password" principle actually true for mail,
rather than partially true with an asterisk.

## What done looks like

- [ ] **Authentik OIDC provider created for Roundcube**, following the
      same one-provider-per-app pattern already used for the AI Qadam
      app and Twenty CRM (see `docs/03-requirements/FR-CRM-001.md` in
      `aiqadam/ai-qadam-platform` for the Twenty precedent's shape:
      dedicated provider, registered redirect URI, `sub_mode` chosen to
      match by email against Stalwart's existing mailbox identities).
- [ ] **Stalwart's directory config updated** to add (not replace,
      unless the design decides otherwise — see Open questions) an
      `Oidc`-type directory backend pointed at Authentik's discovery
      document, so IMAP/SMTP auth issued via Roundcube's OAuth token pass-
      through actually validates against Authentik. Confirm the exact
      config surface live against the running 0.16.13 WebUI/API — 0.16
      replaced the old flat-TOML config model with a JMAP-object model,
      and the one real-world example found during research used
      possibly-stale TOML dot-notation; do not trust either format
      blindly without checking Settings → Authentication → Directories
      on the live instance first (same "verify live, don't trust
      narrative" discipline as T-0126's Phase 0).
- [ ] **Roundcube configured with an OIDC login plugin** (e.g.
      `roundcube-oidc` per the research) pointed at the new Authentik
      provider, added to the existing `roundcube/docker-compose.yml`
      stack at `/opt/roundcube/` (per `landscape/hosts/pro-data-tech-prod.md`'s
      Roundcube section) — likely via a plugin volume mount or a config
      file addition, confirm the plugin's actual installation mechanism
      for the `roundcube/roundcubemail:1.6.17-apache` image at design
      time.
- [ ] **Stalwart's own admin UI OIDC login enabled**, pointed at the same
      or a separate Authentik provider (design decision — see Open
      questions), scoped to `aiqadam-super-admin` group membership only
      (admin UI access should not be available to all members).
- [ ] **Live verification, two-place per workflow rule:**
      - Sign in to `https://webmail.aiqadam.org` via Authentik SSO
        (no separate Roundcube password prompt) and confirm the inbox
        loads for a real mailbox.
      - Sign in to `https://mail.aiqadam.org` (Stalwart admin UI) via
        Authentik SSO, confirm restricted to super-admins.
      - Confirm existing IMAP/SMTP functionality is NOT broken for
        whatever currently authenticates that way (e.g. Roundcube's own
        backend IMAP connection, any SMTP relay usage) — this is an
        additive directory backend, but Stalwart's own docs note
        per-protocol directory-selection nuances (SMTP can pick among
        multiple directories via expressions; IMAP/JMAP reportedly
        cannot per a stalwartlabs maintainer's GitHub comment found
        during research) — confirm this doesn't silently break existing
        non-OIDC auth paths before considering this done.
- [ ] **Document the "webmail-only" policy** somewhere durable and
      user-facing — likely a short addition to
      `shared/mail-provisioning-protocol.md` in this repo, and/or a note
      in `aiqadam/ai-qadam-platform`'s member-facing
      `docs/02-business-processes/operations/member-password-reset.md`
      or equivalent — so future mailbox requests/onboarding correctly
      set the expectation (webmail URL + Authentik sign-in, not "here's
      your IMAP/SMTP settings for Outlook").
- [ ] `landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md`
      updated to record the new Authentik provider(s), Stalwart directory
      config change, and Roundcube plugin addition.
- [ ] **Pre-existing manually-provisioned mailboxes migrated to SSO,
      old local passwords retired.** `vladimir.titenko@aiqadam.org` and
      `binali.rustamov@aiqadam.org` are confirmed (per
      `shared/mail-provisioning-protocol.md`'s own naming-collision note)
      pre-existing Stalwart-local accounts created before T-0123's
      automated flow existed — each still has its own standalone Stalwart
      password today. Once the OIDC directory is live and each person
      confirms they can sign into `webmail.aiqadam.org` via Authentik,
      rotate/invalidate their old local Stalwart passwords (do not leave
      two valid, unused credentials per account) — this is the concrete
      instance of the "retire old app passwords" cleanup, not just a
      hypothetical.

## Confirmed answers (from 2026-07-27/28 conversation, no longer open)

- **No known native-mail-client users to migrate.** Neither
  `vladimir.titenko` nor `binali.rustamov` (the only two pre-existing
  manually-provisioned mailboxes) were confirmed as active native-client
  users during this conversation — treat this as "no migration/rollout
  communication needed" unless someone surfaces a native-client use case
  at execution time. Re-confirm live before executing, since this wasn't
  exhaustively verified (e.g. via IMAP connection logs), just not raised
  as a concern by the user.
- **Native mail clients and social (e.g. Google) sign-in are NOT
  foreclosed by this task.** Discussed and confirmed additive, not
  mutually exclusive with webmail-only-for-now:
  - Native clients can be added later via Stalwart App Passwords
    (independent per-account setting) or, for Thunderbird specifically,
    the unofficial `thunderbird-custom-idp` add-on — neither requires
    undoing anything in this task.
  - Social sign-in (Google, Microsoft, etc.) is a pure Authentik-layer
    addition (a new federated identity **source** in Authentik) — zero
    changes needed in Stalwart, Roundcube, or any other app that already
    trusts Authentik. Already noted as a known extension point in
    `docs/04-development/architecture/auth-architecture.md` §6.3 in
    `aiqadam/ai-qadam-platform`.
  Neither was requested for this task — recorded here so a future reader
  doesn't mistake "webmail-only, Authentik-only for now" as a permanent
  architectural ceiling.

## Result

<empty until closed>

## Notes

- Sourced from a well-cited research pass (2026-07-27) against
  stalw.art's official docs (`/docs/auth/backend/oidc/`,
  `/docs/auth/oauth/interoperability/`, `/docs/ref/object/directory/`,
  the v0.16 announcement blog) and a real-world Stalwart+Authentik OIDC
  config gist — treat the gist's exact config syntax as unverified/
  possibly-stale (older TOML-style dot notation vs. 0.16's newer JMAP-
  object config model) rather than copy-pasteable.
- Confirmed via the same research: Stalwart "learns about an account
  only after the first time that account authenticates" via the OIDC
  directory — pre-provisioning mailboxes (so mail can be received before
  first login) still needs the admin API/CLI (`stalwart-cli`,
  per this host's existing documented pattern in
  `landscape/hosts/pro-data-tech-prod.md`'s Stalwart section), not the
  OIDC directory path. This interacts with T-0123 (automated
  `@aiqadam.org` mailbox provisioning on platform user registration,
  currently `pending`) — worth checking whether that task's design
  already accounts for this, or needs a note added once this task's
  design phase clarifies the provisioning-vs-auth split.
- No changes to `aiqadam/ai-qadam-platform` application code are
  anticipated — this is infra/config-only (Authentik provider config,
  Stalwart directory config, Roundcube plugin), consistent with the
  "Plausible is not first-class, keep changes infra-side" precedent set
  in T-0128, though Stalwart/Roundcube are a more core module than
  Plausible so the same "not first class" framing doesn't necessarily
  apply — this task is worth doing properly, just still infra-scoped.

## Open questions (for design/solution-designer, not resolved yet)

- Should Stalwart's admin UI OIDC and Roundcube's OIDC use the SAME
  Authentik provider (simpler, one redirect URI list) or two SEPARATE
  providers (cleaner separation between "admin access to mail server
  config" and "any user's webmail access")? Given the super-admin-only
  scoping requirement on the admin UI, two separate providers with
  different Authentik group-based access policies is probably cleaner —
  confirm with the user if not obvious at design time.
- Does adding the `Oidc` directory backend need to fully replace
  Stalwart's `Internal` directory, or can both coexist (OIDC for new
  SSO'd logins, Internal retained for any existing local-password
  accounts, e.g. `postmaster@aiqadam.org`'s mailbox-request intake
  role per `shared/mail-provisioning-protocol.md`)? Given the
  maintainer's GitHub comment found during research ("merging LDAP
  metadata over OIDC identity is explicitly unsupported"), verify
  whether multiple simultaneous directories is even a supported pattern
  before designing around it — may need to pick one directory backend
  per protocol/purpose rather than layering them.
- (Resolved — see "Confirmed answers" above: no known native-mail-client
  users. Re-verify live at execution time rather than treating this as
  a permanent guarantee.)
