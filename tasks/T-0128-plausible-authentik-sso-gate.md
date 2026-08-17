---
id: T-0128-plausible-authentik-sso-gate
title: Gate Plausible Analytics behind Authentik SSO via nginx auth_request (or deploy it fresh, already gated)
kind: task
status: pending
priority: P2
created: 2026-07-27
updated: 2026-07-27
closed:
outcome:
created_by: manual
source_runs: []
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-prod.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related: []
estimated_blast_radius: low
estimated_reversibility: full
---

# Gate Plausible Analytics behind Authentik SSO via nginx auth_request

## Why

The user (tvolodi) wants a single-username/single-password principle
across every module of the AI Qadam platform (app, Twenty CRM, Plausible
analytics, Stalwart mail) — Authentik as the one identity source, not a
pile of separately-managed passwords per tool.

Current state, audited during this conversation:

| Module | SSO via Authentik? |
|---|---|
| AI Qadam app | Yes — native OIDC |
| Twenty CRM | Yes — shipped 2026-05-18, OIDC identity provider, matches existing users by email |
| Plausible Analytics | **No** — Community Edition has no OIDC/SSO capability at all, this is a product limitation not a config gap |
| Stalwart Mail | No — separate concern, not in scope for this task |

Plausible Community Edition cannot itself speak OIDC. The user explicitly
chose (2026-07-27 conversation) to solve this at the **network/reverse-proxy
layer** rather than switching analytics tools or accepting a permanently
separate password: front `analytics.aiqadam.org` with nginx `auth_request`
against Authentik's Proxy Provider forward-auth endpoint. This is
Authentik's documented, standard mechanism for exactly this situation
(self-hosted app with no native SSO hooks, sitting behind an nginx you
already control) — Plausible's own app never needs to know Authentik
exists; a signed-in Authentik session at the browser is enough to pass
nginx's auth check before the request ever reaches Plausible.

The user explicitly framed Plausible as "not a first-class citizen in the
whole system" — this task should stay minimal/infra-only, no changes to
the app repo (`aiqadam/ai-qadam-platform`), no attempt to add OIDC
support to Plausible itself.

**Open question this task must resolve first (discovery):** is Plausible
even deployed on `pro-data-tech-prod` yet? `landscape/hosts/pro-data-tech-prod.md`
and `landscape/services.md` have **zero** mention of Plausible, an
`analytics.aiqadam.org` vhost, or a Plausible Compose project — despite
`docs/04-development/architecture/interaction-architecture.md`'s M5.0
roadmap item describing it as a Coolify stack to deploy. M5.0 is marked
`[ ]` (not yet done) in that roadmap doc as of 2026-07-27. However, an
archived runbook (`docs/04-development/infrastructure/runbooks/_archive/coolify-app-stacks.md`)
and `ai-qadam-infra`'s own `credentials.md` both reference a
`PLAUSIBLE_ADMIN_PW` secret having been provisioned at some point — this
may be stale/historical (from a prior Coolify-based deployment approach
that was later superseded — see `ISS-INFRA-003`/`ISS-INFRA-004` in
`aiqadam/ai-qadam-platform` for the Coolify-removal history) rather than
evidence of a currently-running instance. **Do not assume either way —
confirm live via `docker ps`/`docker compose ls` on the host before
designing the nginx/Authentik wiring**, same discipline as T-0126's Phase
0 (that task found a real, previously-undocumented Authentik instance on
QA this exact way — do not repeat the mistake of trusting task-file
narrative over live host state).

## What done looks like

- [ ] **Discovery phase (read-only, first):** confirm whether Plausible
      is currently running on `pro-data-tech-prod` (or anywhere). If not
      running: this task's scope expands to include a fresh deployment
      (Coolify stack per M5.0, or plain Docker Compose matching this
      host's established per-app pattern — operator's call at design
      time, given Coolify was removed from this infra per
      `ISS-INFRA-003`/`ISS-INFRA-004` in the app repo — confirm current
      Coolify status on this host before assuming it's still the
      deployment mechanism). If running: this task is gate-only, no
      redeployment.
- [ ] An Authentik **Proxy Provider** (forward-auth mode, not the
      full-proxy/outpost mode unless a dedicated outpost is judged
      necessary) is created for `analytics.aiqadam.org`, following the
      same "one provider per app, registered redirect/callback URI"
      pattern already used for the AI Qadam app and Twenty CRM providers.
- [ ] nginx's `analytics.aiqadam.org` vhost gains an `auth_request`
      directive pointing at Authentik's forward-auth endpoint, following
      this host's own established per-vhost access-control precedent
      (T-0121's `allow 127.0.0.1; deny all;` restriction on
      `mail.aiqadam.org` is the closest prior art for "gate access at the
      nginx layer for an app that can't gate itself," even though the
      mechanism differs — auth_request vs IP allowlist).
- [ ] Live verification: visiting `https://analytics.aiqadam.org` while
      NOT signed into Authentik redirects to Authentik's login page (or
      returns 401/403, per whatever the design settles on); visiting
      while already signed into Authentik (e.g. from a fresh sign-in to
      the main app) reaches Plausible's dashboard without a second,
      separate login prompt.
- [ ] Confirm only the 3 super-admins (`viktor.drukker@aiqadam.org`,
      `binali.rustamov@aiqadam.org`, `vladimir.titenko@aiqadam.org` — see
      the related, not-yet-executed super-admin-group-membership task
      this conversation also identified but deferred) are the intended
      audience — Plausible is an internal analytics dashboard, not a
      member-facing surface, so the Authentik-side access policy on the
      new Proxy Provider should probably scope to `aiqadam-super-admin`
      group membership rather than all authenticated members. Confirm
      this scoping decision with the user at design time if the task
      file doesn't already make it obvious enough to proceed without
      asking.
- [ ] `landscape/hosts/pro-data-tech-prod.md` and `landscape/services.md`
      updated to document whatever is found/built — this host's docs
      have a real gap here regardless of which branch (gate-only vs
      fresh-deploy-plus-gate) this task ends up taking.

## Result

<empty until closed>

## Notes

- This task was created directly from a chat conversation in the
  `aiqadam/ai-qadam-platform` session (not from a discovery run) — the
  user explicitly deferred running the actual workflow ("Create the task
  now, I'll run it later") while continuing to think through the
  broader SSO-unification question. No run has been started for this
  task yet.
- Related but explicitly out of scope for this task: unifying Stalwart
  Mail under the same SSO umbrella (a separate, larger integration
  project — Stalwart has some external-auth-backend capability but
  nothing as simple as a Proxy Provider gate, since mail protocols
  (IMAP/SMTP) don't speak HTTP the way a web dashboard does); and adding
  the 3 confirmed super-admins to the `aiqadam-super-admin` Authentik
  group — the user explicitly paused that ("I can't see sense to
  register our admin roles if the whole concept is not stable") pending
  this SSO architecture question being resolved first. Once this task
  (or the broader SSO decision) lands, revisit the super-admin
  group-membership task.
- `viktor.drukker@aiqadam.org` was confirmed (not `viktor@aiqadam.org`,
  which only appeared once in an ADR's illustrative JSON example) as the
  correct address per ADR-0035's documented actual provisioning record.

## History
- 2026-07-27: created as `kind: task`, `status: pending`, `priority: P2` (manual, from an aiqadam/ai-qadam-platform chat session; deliberately not executed yet per user's explicit request to create-now-run-later)
