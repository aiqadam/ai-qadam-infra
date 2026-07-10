---
id: T-0100-harden-ai-qadam-test-db-container-pro-data-tech-qa
title: Harden ai-qadam-test-db-1 container (User/CapDrop/SecurityOpt/ReadonlyRootfs) on pro-data-tech-qa
kind: observation
status: observation
priority: P2
created: 2026-07-10
updated: 2026-07-10
closed:
outcome:
created_by: 2026-07-10-audit-host-pro-data-tech-qa-001
source_runs:
  - 2026-07-10-audit-host-pro-data-tech-qa-001
executed_by_runs: []
affects:
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
workflow: infrastructure
blocks: []
blocked_by: []
related:
  - T-0044-docker-cap-drop-all
  - T-0045-docker-no-new-privileges
estimated_blast_radius: low
estimated_reversibility: full
---

# Harden ai-qadam-test-db-1 container security flags on pro-data-tech-qa

## Why
Audit run [2026-07-10-audit-host-pro-data-tech-qa-001](../runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-06-executor-discovery.md) (probe H) found the `ai-qadam-test-db-1` container (`pgvector/pgvector:pg16`, on host `pro-data-tech-qa`) runs with only Docker daemon-level defaults (`SecurityOpt=[name=apparmor name=seccomp,profile=builtin name=cgroupns]`) and no container-level hardening: `User:` empty (runs as image default/root inside the container), `CapAdd: []`, `CapDrop: []`, `SecurityOpt: []` (no explicit override), `ReadonlyRootfs: false`. The container is not privileged and is loopback-only (`127.0.0.1:3112`→`5432`), so this is not an actively-exploited exposure — but it is a hardening gap.

Per [runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-07-execution-validator.md](../runs/2026-07-10-audit-host-pro-data-tech-qa-001/step-07-execution-validator.md) Findings table (probe H row): assigned **P2** — "not privileged/root-with-`Privileged:true`, which would be P1 — this is the 'container hardening gap' tier, same class as T-0044/T-0045 on hetzner-prod, which are both P2." [T-0044](T-0044-docker-cap-drop-all.md) (`cap_drop: [ALL]`) and [T-0045](T-0045-docker-no-new-privileges.md) (`no-new-privileges`) are the established precedent pattern on `hetzner-prod`, but their `affects:` scope is `landscape/services.md` limited to hetzner-prod Compose files — they do not cover `pro-data-tech-qa`/`ai-qadam-test`, so this is a parallel observation for a different host, not a duplicate.

## What done looks like
- [ ] `/var/www/ai-qadam-test/docker-compose.yml` adds `cap_drop: [ALL]` (+ selective `cap_add` only if the container fails to start without a specific capability) for the `db` service.
- [ ] Add `security_opt: ["no-new-privileges:true"]` explicitly for the `db` service.
- [ ] Evaluate whether the `pgvector/pgvector:pg16` image supports running as a non-root `User:` (the official postgres-family images typically drop privilege internally via `gosu` at entrypoint but start as root — verify whether an explicit non-root `user:` in Compose is compatible with the entrypoint's `initdb`/permission-fixup logic before setting it).
- [ ] Evaluate `read_only: true` (`ReadonlyRootfs`) feasibility — Postgres needs a writable data directory (already on a named volume) and writable `/tmp`/`/var/run/postgresql`; may require `tmpfs` mounts for those paths if `read_only` is enabled.
- [ ] Recreate the container; verify it comes back healthy (`docker ps` shows `Up ... (healthy)`, loopback `SELECT 1` succeeds).
- [ ] Verify via `docker inspect ai-qadam-test-db-1 --format '{{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} {{.Config.User}} {{.HostConfig.ReadonlyRootfs}}'`.

## Notes
- This is the same class of gap as T-0044/T-0045 (hetzner-prod, both P2) — use those tasks' Compose-edit pattern as a template.
- The container already has a healthchecks and is loopback-only, not privileged, and not `CapAdd`-augmented — so the residual risk is contained; this is a defense-in-depth improvement, not an active exposure.

## History
- 2026-07-10: created as kind: observation by 2026-07-10-audit-host-pro-data-tech-qa-001 (probe H — container hardening gap)
