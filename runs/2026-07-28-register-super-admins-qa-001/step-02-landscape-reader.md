---
run_id: 2026-07-28-register-super-admins-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-28T00:00:00Z
task_id: T-0130-register-super-admins-qa
inputs_read:
  - runs/2026-07-28-register-super-admins-qa-001/step-01-task-reader.md
  - tasks/T-0130-register-super-admins-qa.md
  - tasks/T-0126-fix-authentik-scope-mappings-on-qa.md
  - tasks/T-0127-verify-authentik-qa-fix-live-browser-round-trip.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/secrets-inventory.md
  - landscape/services.md
  - landscape/README.md
artifacts_changed: []
next_step_hint: task-validator should treat "does aiqadam-super-admin group exist" and "do the 3 emails already have QA user rows" as unresolved, must-discover-live facts — landscape has zero record either way. No blocker to proceeding to validation/design; the task file's own Phase 0 already anticipates and is designed to handle both unknowns.
---

## Summary
`landscape/hosts/pro-data-tech-qa.md` (last_verified 2026-07-27, status populated, not stale) documents QA's Authentik deployment in detail as of T-0126's run: `aiqadam-qa-authentik-server-1` (image `ghcr.io/goauthentik/server:2024.12.3`, network_mode host, no published ports, admin/API reachable externally via nginx at `https://auth.qa.aiqadam.org`) and its sibling `aiqadam-qa-authentik-worker-1`, both part of the 7-container `aiqadam-qa` Compose project on `pro-data-tech-qa`. T-0126 fixed the OAuth2 provider's (`aiqadam-qa-provider`, pk=1) scope mappings (openid/email/profile) — an entirely different Authentik object type from RBAC groups. The landscape contains **no record whatsoever** of any Authentik RBAC group (not `aiqadam-super-admin`, not any other group name) ever having been created, queried, or inspected on QA — T-0126's discovery scope never touched the groups object type. Likewise, there is **no record** of whether `vladimir.titenko@aiqadam.org`, `viktor.drukker@aiqadam.org`, or `binali.rustamov@aiqadam.org` have ever signed into `qa.aiqadam.org` — the only related landscape/task evidence is that the literal browser registration/OIDC-sign-in round trip for QA (for *any* user, named or otherwise) is still unverified end-to-end: follow-up task T-0127 (filed by T-0126's own closure) remains open/unclosed, blocked by a pre-existing external rate limiter, and was never subsequently completed as of this reading. The access mechanism T-0126 used and validated — SSH to `pro-data-tech-qa` (`root@95.46.211.230` or the operator accounts `tvolodi`/`viktor_d`/`binali_r`) then `docker exec -i aiqadam-qa-authentik-server-1 ak shell` — is explicitly documented as the container's stated admin-access mechanism ("no persisted Authentik admin credential exists in secrets-inventory.md for QA") and nothing in the landscape indicates this has changed since T-0126 (same run, one day old, most recent host state). `secrets-inventory.md` confirms no QA Authentik API token exists (only JWT-signing-secret, internal-api-token, and deploy-ssh-key are recorded for QA), corroborating that `ak shell` remains the only usable path, not a REST bearer-token session.

## Details
### Relevant facts (sourced from landscape)
- QA Authentik server container: `aiqadam-qa-authentik-server-1`, image `ghcr.io/goauthentik/server:2024.12.3`, `network_mode: host`, no published ports, admin/API reachable externally only via nginx at `https://auth.qa.aiqadam.org`; confirmed running (up 9 days as of the 2026-07-27 discovery) — _source: `landscape/hosts/pro-data-tech-qa.md`_
- QA Authentik worker container: `aiqadam-qa-authentik-worker-1`, same image, same network mode, no published ports — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Admin access mechanism explicitly documented: `docker exec -i aiqadam-qa-authentik-server-1 ak shell` (Django management shell) as an operator in the `docker` group; "no persisted Authentik admin credential exists in secrets-inventory.md for QA" — _source: `landscape/hosts/pro-data-tech-qa.md`, container table row for `aiqadam-qa-authentik-server-1`_
- T-0126's scope was limited to the OAuth2 provider object (`aiqadam-qa-provider`, pk=1) and its `property_mappings` (openid/email/profile scope mappings) — a distinct Authentik object type from RBAC `Group` objects; T-0126 never queried, listed, or touched any group — _source: `tasks/T-0126-fix-authentik-scope-mappings-on-qa.md`_
- No group name (`aiqadam-super-admin` or otherwise) appears anywhere in `landscape/hosts/pro-data-tech-qa.md` or `landscape/services.md` — _source: repo-wide grep across `landscape/`_
- SSH access to `pro-data-tech-qa` (95.46.211.230): break-glass `root` (provider key), plus operator accounts `tvolodi` (uid 1001, live-verified), `viktor_d` (uid 1002), `binali_r` (uid 1003) — all in `sshusers` + `docker` groups, NOPASSWD sudo. This is the same access path (docker-group membership → `docker exec`) T-0126 used one day prior; nothing in the landscape indicates any change since — _source: `landscape/hosts/pro-data-tech-qa.md`, "Access" and "Operator users" sections_
- `secrets-inventory.md`'s "AiQadam QA — pro-data-tech-qa" section lists only `aiqadam-qa-jwt-signing-secret`, `aiqadam-qa-internal-api-token`, and `aiqadam-qa-deploy-ssh-key` — no Authentik admin/API token of any kind for QA is recorded, consistent with the task file's stated assumption that `ak shell` (not a bearer-token REST session) is the only available path — _source: `landscape/secrets-inventory.md`_
- QA's live vhost is `qa.aiqadam.org` (not `qa-uz.aiqadam.org`, which was retired out-of-band and confirmed stale as of T-0126) — relevant since T-0130's functional verification step targets `/admin` on `qa.aiqadam.org` — _source: `landscape/hosts/pro-data-tech-qa.md`_
- Follow-up task T-0127 ("Complete the deferred live browser registration/sign-in round trip for QA's Authentik fix"), filed by T-0126's own closure, remains `status: observation` (unclosed, unexecuted) as of this reading — meaning no landscape-recorded evidence exists of *any* successful browser-level OIDC registration/sign-in against QA post-fix, let alone by the three named individuals — _source: `tasks/T-0127-verify-authentik-qa-fix-live-browser-round-trip.md`_
- No mention of `vladimir.titenko@aiqadam.org`, `viktor.drukker@aiqadam.org`, or `binali.rustamov@aiqadam.org` anywhere in `landscape/` or prior `runs/` artifacts in connection with QA/Authentik sign-in; the only repo-wide hits for these emails are T-0122/T-0123/T-0128/T-0129/T-0130 themselves, which concern prod-side mailbox provisioning (Stalwart/Roundcube) and the SSO-architecture decision, not QA Authentik user records — _source: repo-wide grep across `landscape/`, `runs/`, `tasks/`_

### Stale or stub files encountered
None. `landscape/hosts/pro-data-tech-qa.md` — last_verified 2026-07-27 (1 day old), status `populated`. `landscape/secrets-inventory.md` has no frontmatter/date field (it's a git-ignored, manually-maintained inventory per `landscape/README.md`) but its QA section content is internally consistent with the host file's access-mechanism narrative and shows no signs of drift. `landscape/services.md` cross-checked (no frontmatter date read directly, but its QA-relevant content matches `pro-data-tech-qa.md` verbatim/consistently — same source run).

### Gaps requiring live discovery
- Whether the `aiqadam-super-admin` group exists on QA Authentik at all — zero landscape record either way (T-0126 never touched RBAC groups; this is an entirely separate Authentik object type). Must be checked live via `ak shell` (e.g. `Group.objects.filter(name="aiqadam-super-admin")`) before any assignment step.
- Whether `vladimir.titenko@aiqadam.org`, `viktor.drukker@aiqadam.org`, and `binali.rustamov@aiqadam.org` already have QA Authentik user rows (i.e., have signed in via OIDC at least once) — zero landscape record either way. Must be checked live via `ak shell` (e.g. `User.objects.filter(email__in=[...])`) per the task's Phase 0 requirement.
- Whether the QA Authentik container set (`aiqadam-qa-authentik-server-1` / `-worker-1`) is still running today, 2026-07-28 — the landscape's most recent confirmation is 2026-07-27 (T-0126, "up 9 days" at that time). The task file itself flags this: "do not assume T-0126's prior session state still holds without a fresh `docker ps` check." One day's drift risk is low but unconfirmed by landscape alone.
- No evidence of a completed literal browser-level OIDC sign-in round trip against QA for any user (T-0127 still open) — relevant context for the task's own functional-verification step (reaching `/admin` on `qa.aiqadam.org`), since this would be the first landscape-recorded confirmation that OIDC sign-in works end-to-end on QA post-T-0126, for any account.

## Issues / risks
- The task's Phase 0 (live discovery of group existence + user existence) is not optional groundwork — it is filling a genuine, total landscape blank, not a formality. Step 03/04 should treat both facts as fully unknown, not "probably exists/probably doesn't."
- If any of the 3 emails turn out to have no QA user row, the task file's own instruction is to STOP and escalate for that person rather than pre-create a row — landscape offers no basis to predict which (if any) will hit this case.
- T-0127 (browser-level QA sign-in verification) being still open is a mild corroborating signal that QA's OIDC login flow may not have been exercised successfully end-to-end by anyone yet post-fix — worth flagging to the designer as context for how confidently to expect Phase 0's user-existence check to succeed, though it is not proof either way (a user could have signed in before T-0126's fix, or via the local dev/OIDC-stub path documented separately for `aiqadam-qa-oidc-stub-1`, or the rate-limiter may have since cleared without a landscape update).
- Access mechanism confidence is otherwise high: SSH + `docker exec ... ak shell` is well-documented, one day old, and used successfully by T-0126 for a structurally similar on-host Authentik ORM operation (property_mappings vs. group membership — same `ak shell` pattern, same container, same operator-access path).

## Open questions (optional)
none — landscape read is complete; the identified gaps are exactly the ones the task file already scopes into its mandatory Phase 0 live-discovery step, not a reason to block this run.
