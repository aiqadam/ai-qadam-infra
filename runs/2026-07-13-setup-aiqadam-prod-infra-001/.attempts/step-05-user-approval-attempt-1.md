---
run_id: 2026-07-13-setup-aiqadam-prod-infra-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-13T09:30:00Z
task_id: T-0111-setup-aiqadam-prod-deploy-infra-pro-data-tech-prod
inputs_read:
  - runs/2026-07-13-setup-aiqadam-prod-infra-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user
---

## Summary
User approved the full T-0111 plan as-is, resolving all three explicit open questions.

## Details
Three questions were put to the user per the solution-designer's explicit request:

1. **Git ref for first prod deploy** — "Use dfd2a7c (Recommended)": the same commit already validated end-to-end on QA via T-0110 earlier today. Resolves the placeholder `<APPROVED_REF>` in Phase A step 6 to `dfd2a7c`.
2. **www.aiqadam.org scope** — "Bare apex only (Recommended)": skip the conditional `www.aiqadam.org` DNS record, nginx server_name entry, and cert SAN (Phase E step 22, Phase F steps 27-28, Phase G step 30, Phase H step 36 all take their bare-apex-only branch).
3. **DNS repoint confirmation** — "Yes, repoint it now (Recommended)": proceed with Phase F's repoint of the live `aiqadam.org` apex A record from `212.20.151.29` (confirmed-dead Coolify host) to `95.46.211.224`, including the `proxied: true → false` flip needed for certbot HTTP-01.

Final plan approval — "Approve as-is (Recommended)": proceed exactly per `runs/2026-07-13-setup-aiqadam-prod-infra-001/step-04-solution-designer.md` with git ref `dfd2a7c` and bare-apex-only scope. No modifications requested.

Executor-infra should execute Phases 0 through H exactly as written, using `dfd2a7c` wherever `<APPROVED_REF>` appears, and skipping every `www.aiqadam.org`-conditional step (Phase E step 22's `www` server_name line, Phase F steps 27-28, Phase G's `-d www.aiqadam.org` flag, Phase H step 36).

## Issues / risks
None — user approved the designer's full recommended plan on all three open items, including the highest-risk step (the shared-zone DNS repoint of a confirmed-dead host).
