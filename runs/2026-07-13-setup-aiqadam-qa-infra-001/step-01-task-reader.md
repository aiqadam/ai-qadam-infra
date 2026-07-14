---
run_id: 2026-07-13-setup-aiqadam-qa-infra-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-13T00:00:00Z
task_id: T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa
inputs_read:
  - tasks/T-0110-setup-aiqadam-qa-deploy-infra-pro-data-tech-qa.md
artifacts_changed: []
next_step_hint: landscape-reader should load landscape/hosts/pro-data-tech-qa.md, landscape/services.md, landscape/cloudflare.md, landscape/domains.md, and shared/app-registry.md; also confirm the ai-qadam-platform GitHub remote assumption if a working checkout is available to check against.
---

## Summary
Set up complete QA deployment infrastructure on `pro-data-tech-qa` (95.46.211.230) — app checkout, production-shape Docker Compose stack, nginx vhost, UFW rules, Cloudflare DNS, and TLS — so that `qa.aiqadam.org` serves the AiQadam app over HTTPS and the host is ready to receive CI-driven deploys.

## Details

- **Title:** Set up AiQadam QA deploy infra on pro-data-tech-qa (app container, nginx, Cloudflare DNS for qa.aiqadam.org)
- **Workflow:** infrastructure (confirmed: `workflows/infrastructure.md` exists)
- **Priority:** P1
- **Blast radius / reversibility:** `estimated_blast_radius: medium`, `estimated_reversibility: full` (per task frontmatter)
- **Blocks:** T-0112, T-0114 (downstream tasks cannot proceed until this is `done`)
- **Related:** T-0090a (this task supersedes T-0090a's app-container portion; T-0090a targeted `qadam-test.ai-dala.com` in a different repo's zone, this task targets `qa.aiqadam.org` in the `aiqadam.org` zone this repo owns)

### Why (quoted verbatim from task file)
> The user wants a pipeline: local code change → push to `https://github.com/aiqadam/ai-qadam-platform.git` → GitHub Actions CI build → auto-deploy to `pro-data-tech-qa` as the QA instance → manual promotion to `pro-data-tech-prod`. Before GitHub Actions can deploy anything, the QA host needs the app checkout, a deployable container, an nginx vhost, and a public HTTPS endpoint. This supersedes the app-container portion of [T-0090a](../../tasks/T-0090a-prepare-qadam-test-public-https-endpoint.md) (that task targeted `qadam-test.ai-dala.com` in the `ai-dala-infra`-owned zone; this task targets `qa.aiqadam.org` in the `aiqadam.org` zone this repo already owns, avoiding cross-repo Cloudflare coordination).
>
> Per [workflows/deploy-app.md](../../workflows/deploy-app.md), a `deploy-app` workflow run cannot execute until this setup task is `status: done`.

### Full acceptance criteria ("What done looks like")
1. App repo cloned on `pro-data-tech-qa` at a project-standard path (e.g. `/opt/apps/aiqadam-qa/`) from `https://github.com/aiqadam/ai-qadam-platform.git`
2. Production-shape `docker-compose.yml` (NOT `infrastructure/docker-compose.yml`, explicitly local-dev-only per its own header) exists for QA — either committed to the app repo under `deploy/` or written by this task, containing the app's actual deployable services (API, web, etc.), pointed at either the existing `ai-qadam-test-db-1` postgres (`127.0.0.1:3112`) or a new QA-scoped postgres, per executor's judgment
3. `.env` file on host (mode 600) with QA secrets — values never committed to any repo
4. Free host port chosen from the `127.0.0.1:3110-3119` test-app range reserved in `shared/app-registry.md` (3112 taken by postgres; next free is 3113)
5. App container(s) built and running, healthy
6. nginx installed on `pro-data-tech-qa`, vhost for `qa.aiqadam.org` proxying to the app's host port
7. UFW: `80/tcp` and `443/tcp` allowed (currently only `22/tcp` open on this host)
8. Cloudflare DNS: A record `qa.aiqadam.org` → `95.46.211.230` in the `aiqadam.org` zone (Zone ID in `landscape/secrets-inventory.md`)
9. Let's Encrypt TLS cert via certbot (matches `penpot.aiqadam.org` pattern on prod) OR Cloudflare-proxied + origin cert, per executor's judgment; choice must be documented
10. `curl -I https://qa.aiqadam.org` returns 200 from an external workstation
11. `shared/app-registry.md` updated: QA environment section filled in (host port, container names, compose path, health endpoint)
12. `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md`, `landscape/cloudflare.md`, `landscape/domains.md` updated

### Target scope (landscape files, from `affects:`)
- landscape/hosts/pro-data-tech-qa.md
- landscape/services.md
- landscape/cloudflare.md
- landscape/domains.md
- shared/app-registry.md

### Constraints stated by user
- Direct SSH + Docker Compose deploy model has already been chosen over Coolify for this pipeline — this is a closed decision, not open for re-litigation by solution-designer. The local dev compose file (`c:\Users\tvolo\dev\ai-dala\aiqadam\infrastructure\docker-compose.yml`) states "Production runs on Coolify on the platform host; this file does not apply there" and runs apps on the host, not in containers — solution-designer must design a QA-appropriate compose file/Dockerfile from the app's actual source layout, not reuse the local-dev file verbatim.
- This task does NOT create the GitHub Actions workflow file — that is T-0113. Scope is limited to making the QA host ready to receive a deploy (manual or CI-driven).
- No off-site/external storage (repo-wide hard rule) — not directly implicated here but applies if backup/storage decisions arise during compose design.
- Secrets never committed to any repo; `.env` on host must be mode 600.

### Information gaps for downstream steps
- **Unverified GitHub remote assumption:** the task file explicitly flags that `https://github.com/aiqadam/ai-qadam-platform.git` is assumed to be the checkout target, and instructs: "confirm this matches `c:\Users\tvolo\dev\ai-dala\aiqadam`'s current `origin` remote during step 02/04 (landscape-reader / solution-designer); if it doesn't match, halt and ask the user before proceeding (do not assume)." This verification has NOT yet been performed — it is explicitly deferred to step 02 (landscape-reader) and/or step 04 (solution-designer).
- **Which app services need containers for QA:** `shared/app-registry.md` lists "Next.js (legacy prod) + Astro web-next + NestJS api (new monorepo)" — solution-designer must read the actual app repo structure (`apps/api`, `apps/web`, etc.) to determine what needs to run in QA, and ask the user if ambiguous rather than guessing.
- **Database reuse vs fresh provision:** reuse existing `ai-qadam-test-db-1` (127.0.0.1:3112, db `aiqadam_test`) or provision a new QA-scoped postgres. Task notes recommend reuse unless schema/migration state is incompatible — this is a judgment call for solution-designer, not yet decided.
- **TLS approach:** certbot direct (matches T-0109/prod Penpot pattern) vs Cloudflare-proxied with origin cert. Task notes recommend certbot direct unless the user wants Cloudflare proxying — not yet decided, executor's/designer's judgment call, must be documented either way.

## Issues / risks
- The Coolify-vs-SSH decision and the GitHub remote target are the two highest-leverage open items: if the GitHub remote assumption is wrong, the entire checkout step (criterion 1) targets the wrong repo. This must be verified before step 04 finalizes a plan, not discovered during execution.
- Medium blast radius: this task opens two new firewall ports (80/443) and stands up a new public HTTPS endpoint on a host that currently only exposes SSH. Full reversibility is claimed but nginx/UFW/DNS changes should still be reviewed carefully by task-validator and solution-designer.
- Task blocks two downstream tasks (T-0112, T-0114) — delays or a BLOCKED verdict here has a compounding schedule effect the orchestrator should flag to the user if it occurs.

## Open questions
none — task is well-formed and unambiguous enough to proceed to step 02. The information gaps above are explicitly assigned to downstream steps (02/04) by the task file itself, not blockers for step 01.
