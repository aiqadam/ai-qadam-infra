---
run_id: 2026-07-13-setup-aiqadam-prod-infra-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-13T00:00:00Z
task_id: T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod
inputs_read:
  - tasks/T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod.md
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-prod.md, landscape/services.md, landscape/cloudflare.md, landscape/domains.md, and shared/app-registry.md (QA section, for precedent on compose shape/secrets pattern).
---

## Summary
Set up AiQadam production deploy infrastructure on `pro-data-tech-prod` (95.46.211.224) — clone the app at a reviewed/tagged git ref, stand up a dedicated prod Postgres and app container(s), add an additive nginx vhost + Cloudflare DNS + TLS cert for the bare domain `aiqadam.org`, and update the landscape registry — all without disrupting the host's existing live Penpot deployment.

## Details

- **Workflow:** infrastructure (confirmed: `workflows/infrastructure.md` exists)
- **Task ID:** T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod
- **Title:** Set up AiQadam prod deploy infra on pro-data-tech-prod (app container, nginx, Cloudflare DNS for aiqadam.org)
- **Priority:** P1
- **Status at read time:** in-progress (transitioned by orchestrator this run; `executed_by_runs` includes `2026-07-13-setup-aiqadam-prod-infra-001`)
- **blocked_by:** [T-0110] — T-0110 status is `done` (outcome: succeeded, closed 2026-07-13) — dependency satisfied, no unmet blockers.
- **blocks:** [T-0112, T-0115]

### Why (quoted verbatim from task file)
> Mirrors [T-0110](../../tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md) but for the production environment. `pro-data-tech-prod` (95.46.211.224) already hosts Penpot (7-container Docker Compose stack under `/opt/penpot/`, nginx vhost for `penpot.aiqadam.org`) — this task adds the AiQadam app alongside it, on the bare domain `aiqadam.org`, without disturbing the existing Penpot deployment.
>
> Sequenced after T-0110 so the QA setup (simpler, lower blast radius) validates the app's deployable shape (Dockerfile, compose file, env vars) before touching the prod host.

### Target scope (landscape files, from `affects:`)
- [landscape/hosts/pro-data-tech-prod.md](../../landscape/hosts/pro-data-tech-prod.md)
- [landscape/services.md](../../landscape/services.md)
- [landscape/cloudflare.md](../../landscape/cloudflare.md)
- [landscape/domains.md](../../landscape/domains.md)
- [shared/app-registry.md](../../shared/app-registry.md)

### Full acceptance criteria ("What done looks like" checklist, verbatim)
1. App repo cloned on `pro-data-tech-prod` at a project-standard path (e.g. `/opt/apps/aiqadam-prod/`) from `https://github.com/aiqadam/ai-qadam-platform.git`, **pinned to a specific tagged/reviewed ref** (never `HEAD` of a moving branch for a first prod deploy)
2. Production `docker-compose.yml` for prod (same shape validated in T-0110, adjusted for prod env vars/secrets/scaling as needed)
3. `.env` file on host (mode 600) with PRODUCTION secrets — distinct from QA secrets, values never committed to any repo
4. Dedicated postgres for prod (do NOT reuse QA's database) — new Docker volume, new container, per this host's existing conventions (cf. Penpot's `penpot_penpot_postgres_v15` naming pattern)
5. Free host port chosen (prod host currently only has 9001 bound for Penpot's frontend) — avoid collision
6. App container(s) built and running, healthy
7. nginx vhost added for the bare domain `aiqadam.org` (and `www.aiqadam.org` if desired — confirm with user), proxying to the app's host port — added as a NEW vhost file alongside the existing `penpot.aiqadam.org` vhost, not replacing it
8. UFW: 80/tcp and 443/tcp already allowed on this host (from T-0103) — confirm no change needed
9. Cloudflare DNS: A record `aiqadam.org` (root/apex) → `95.46.211.224` in the `aiqadam.org` zone
10. Let's Encrypt TLS cert obtained via certbot for `aiqadam.org` (separate cert from `penpot.aiqadam.org`'s, or a SAN cert covering both — executor's judgment, document choice)
11. `curl -I https://aiqadam.org` returns 200 from an external workstation, AND `curl -I https://penpot.aiqadam.org` still returns 200 (no regression to existing Penpot service)
12. `shared/app-registry.md` updated: prod environment section filled in
13. `landscape/hosts/pro-data-tech-prod.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` updated

### Blast radius / reversibility
- **estimated_blast_radius: HIGH** — unlike T-0110 (medium), because this host runs a live, working Penpot instance. Per the task's Notes: the solution-designer must explicitly verify the plan cannot disrupt the existing `penpot` Docker Compose project, its nginx vhost, or its TLS cert — e.g. use a distinct Compose project name (not `penpot`), a distinct `/opt/apps/...` directory (not `/opt/penpot/`), and additive nginx config (new `sites-available` file, not editing the existing one).
- **estimated_reversibility: full** — despite high blast radius, the task asserts the change is fully reversible (new containers/vhost/DNS record can be torn down without touching Penpot's existing artifacts), provided the designer honors the additive/non-destructive constraints above.

### Explicit git-ref requirement (flagged per orchestrator instruction)
The task's Notes section states explicitly: **"First production deploy should use a reviewed/tagged git ref, not an arbitrary branch tip — confirm the exact ref with the user at plan-approval time (step 05)."** This is reinforced in acceptance criterion 1 ("pinned to a specific tagged/reviewed ref (never `HEAD` of a moving branch for a first prod deploy)"). Given `estimated_blast_radius: high`, this task is very unlikely to auto-approve at step 04 (PASS) — a `NEEDS_APPROVAL` verdict with an explicit ref confirmation ask is the expected path, and the solution-designer (step 04) must surface this as a specific approval question rather than picking a ref unilaterally.

### Constraints stated by user / task file
- Do not disturb the existing Penpot deployment (containers, nginx vhost, TLS cert) in any way.
- Distinct Compose project name and directory from `/opt/penpot/`.
- Additive nginx config only (new vhost file, not edits to the existing one).
- Dedicated prod Postgres — must NOT reuse QA's database (T-0110's `aiqadam_qa` reuse pattern does not apply here).
- Prod `.env` secrets must be distinct from QA secrets and never committed to any repo.
- First prod deploy must pin to a specific tagged/reviewed git ref — confirm exact ref with user before execution (plan-approval time).
- Free host port must avoid collision with Penpot's existing `9001` binding.

### Information gaps for downstream steps
- **`www.aiqadam.org` scope:** open question in the task — bare domain only, or bare + `www`? Must be confirmed with the user before the Cloudflare DNS step (acceptance criterion 7 explicitly says "confirm with user").
- **Prod database provisioning:** fresh empty DB assumed unless the user says otherwise — no migrated-data source has been identified.
- **Resource contention with Penpot:** host specs (16 vCPU / 31 GiB RAM / 339 GB disk, per task Notes) suggest headroom is not a concern, but current utilization has not yet been measured — landscape-reader/solution-designer should check current utilization on `pro-data-tech-prod` before finalizing the plan.
- **Exact git ref for first prod deploy:** not yet chosen — must be confirmed with the user at plan-approval time (step 05), per the task's explicit Notes requirement. This is distinct from T-0110's QA deploy, which used `HEAD` (`dfd2a7c`) of the default branch — that precedent does NOT apply here.
- **TLS cert strategy for `aiqadam.org` vs `penpot.aiqadam.org`:** separate cert or SAN cert covering both — left to executor's judgment, to be documented once decided (mirrors T-0110's certbot-direct precedent, but scope differs: this task must not touch the existing Penpot cert).
- **App slice scope:** T-0110 resolved (user-approved) to deploy `apps/api` only for QA. Whether prod needs the same minimal slice (API only) or a broader set of services (e.g. `apps/web`) is not explicitly stated in T-0111 and should be confirmed by the landscape-reader/solution-designer by checking the app registry and, if ambiguous, asking the user — do not assume parity with QA without confirming.

## Issues / risks
- High blast radius on a host with a live production service (Penpot) is the primary risk; any executor action must be additive-only and independently verifiable to not regress `penpot.aiqadam.org`.
- The unresolved git-ref choice is a hard gate: the task file explicitly forbids proceeding with an arbitrary branch tip for this first prod deploy. Downstream steps (especially step 04/05) must not skip this confirmation even if step 04's other risk factors would otherwise qualify for auto-approval — the explicit user-confirmation requirement should push this task to `NEEDS_APPROVAL` regardless.
- Task well-formedness check: task file has a non-empty Why section, a full "What done looks like" checklist (13 items), `workflow: infrastructure` matches an existing workflow file (`workflows/infrastructure.md`, confirmed present), and `blocked_by: [T-0110]` is satisfied (T-0110 status `done`, outcome `succeeded`). No structural defects found — task is well-formed and ready to proceed to step 02.

## Open questions (optional)
- **`www.aiqadam.org` too, or bare domain only?** Confirm with user before the Cloudflare DNS step (already flagged in task file; carried forward here for downstream visibility).
- **Prod database provisioning:** fresh empty DB, or migrated data from somewhere? Assume fresh unless the user says otherwise (already flagged in task file).
- **Resource contention with Penpot:** solution-designer should note current utilization on the prod host before adding the app stack (already flagged in task file).
- **Exact tagged/reviewed git ref for the first prod deploy:** not resolved in the task file — must be confirmed with the user at plan-approval time (step 05), per the task's explicit Notes requirement.
