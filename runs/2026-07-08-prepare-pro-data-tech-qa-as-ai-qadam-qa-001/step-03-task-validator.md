---
run_id: 2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001
step: 03
agent: task-validator
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0090
inputs_read:
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-01-task-reader.md
  - runs/2026-07-08-prepare-pro-data-tech-qa-as-ai-qadam-qa-001/step-02-landscape-reader.md
  - tasks/T-0090-prepare-pro-data-tech-server-as-ai-qadam-qa-instance.md
  - tasks/_index.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/cloudflare.md
  - shared/app-registry.md
artifacts_changed: []
next_step_hint: Send to solution-designer (step 04) — task is well-formed and ready for the design phase.
---

## Summary

T-0090 passes validation. The task is well-formed (kind/status/priority/dependencies all correct), the user's stated acceptance criteria are non-conflicting, no running task overlaps T-0090's resources, and all four `blocked_by` / `related` blockers that were open when T-0090 was re-promoted to `pending` are now `done`. Eight de-duplicated acceptance criteria are listed below; they're consistent with the run-prompt's clarifications (port-3112 test slot, `qadam-test.ai-dala.com` DNS name, `ai-qadam-test` compose project name, host-id stays `pro-data-tech-qa`, role-`ai-qadam`-QA).

## Validation matrix

### Frontmatter

| Field | Expected | Actual | Status |
|---|---|---|---|
| `kind` | `task` | `task` | PASS |
| `status` | `pending` | `pending` | PASS |
| `priority` | `P1` | `P1` | PASS |
| `blocked_by` | `[T-0093, T-0094]` | `[T-0093-harden-sshd-on-pro-data-tech-qa, T-0094-install-local-baseline-firewall-on-pro-data-tech-qa]` | PASS — **both done 2026-07-08**; T-0093 (21/21 PASSED), T-0094 (10/10 PASSED); unblock confirmed by `tasks/_index.md` |
| `related` | (info, not gating) | includes T-0093, T-0094, T-0095, T-0096, T-0097, T-0098 — all 5 done + 2 deferred (T-0096, T-0098) | PASS — matches the discovery-run followed by hardening/firewall/fail2ban/operator-users lineage; nothing stale |
| `workflow` | `infrastructure` | `infrastructure` | PASS |
| `created` / `updated` | 2026-07-08 | 2026-07-08 / 2026-07-08 | PASS — consistent with the discovery → promotion history in `## History` |
| `estimated_blast_radius` | high or medium (multi-container, multi-service) | `high` | PASS — Docker install + firewall rec + public DNS + new vhost + new compose stack — blast radius correctly characterised |
| `estimated_reversibility` | full or partial (state, not data, is involved) | `full` | PASS — no data committed, port allocations reversible, cert copies reversible, rollback via `systemctl disable docker` + delete compose project + delete nginx vhost + delete DNS record |
| `affects` | pro-data-tech-qa + services | `landscape/hosts/pro-data-tech-qa.md`, `landscape/services.md` | PASS — covers host facts + service tables; **missing from the frontmatter but in scope per the run-prompt and step-01**: `landscape/cloudflare.md` (new DNS record), `shared/app-registry.md` (new `ai-qadam` test entry). Step 08 will need to update all four. Recommendation: append to `affects:` post-approval (trivial edit, not gating). |
| `blocks` | none expected | `[]` | PASS — T-0090 is not a blocker for any other task |
| `source_runs` | discovery run | `[2026-07-08-discovery-pro-data-tech-qa-001]` | PASS |
| `executed_by_runs` | empty (this run will populate) | `[]` | PASS |
| `created_by` | discovery run | `2026-07-08-discovery-pro-data-tech-qa-001` | PASS |

### Acceptance criteria — de-duplicated (8 items)

The task's "What done looks like" list contains 10 checkboxes; two duplicate existing items. The validator should treat the following 8-item de-duplicated set as the acceptance matrix (re-stated, with the dedup noted for each):

| # | Criterion | Source / status | Validator note |
|---|---|---|---|
| **AC1** | Multi-PC operator SSH access (operators `viktor_d`, `binali_r`, and management workstation `tvolodi`) — already **met** for `tvolodi` (V10 live handshake); server-side `ssh-keygen -lf` parse verified for `viktor_d` / `binali_r` — their live handshakes are correctly deferred to each operator's own workstation. | T-0097 done 2026-07-08 (16/16 PASSED); T-0090 must NOT regress | **No work**; validator should re-confirm operator pubkeys still in place and `sshusers` group still includes the three operators. |
| **AC2** | sshd hardened per T-0093 — `PasswordAuthentication no`, `PermitRootLogin prohibit-password` (permanent), `AllowGroups sshusers`, `MaxAuthTries 3`, `LoginGraceTime 30`. | T-0093 done 2026-07-08 (21/21 PASSED); explicit 2026-07-08 user decision to keep `PermitRootLogin prohibit-password` permanently | **No work**; validator should `sshd -T` and re-verify the 21 verification checks. |
| **AC3** | Host firewall per T-0094 — UFW deny-in / allow-out / `DEFAULT_FORWARD_POLICY="DROP"` (deliberate; the only DROP-related work item in T-0090). | T-0094 done 2026-07-08 (10/10 PASSED) | **The single DROP work item is AC4 below.** Validator confirms AC3 already passing. |
| **AC4** | **Reconcile UFW `DEFAULT_FORWARD_POLICY="DROP"` BEFORE installing Docker** (added 2026-07-08 by T-0094 step-08). T-0094 installed UFW with `FORWARD=DROP` as a deliberate divergence (no Docker installed yet → currently a no-op). Docker enables IP forwarding at install time → bridged container traffic will be silently dropped unless one of: (a) flip to `ACCEPT` via `sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw && ufw reload`; or (b) Docker `"iptables": false` in `/etc/docker/daemon.json`. | T-0090 primary work item — option (a) recommended (matches hetzner-prod / ubuntu-16gb-nbg1-1 pattern); user's run-prompt aligns with (a). | Validator should confirm `grep DEFAULT_FORWARD_POLICY /etc/default/ufw` reads `"ACCEPT"` AND `iptables -L FORWARD | head` shows the `ufw-before-forward` chain active with policy ACCEPT. |
| **AC5** | fail2ban with sshd jail per T-0095 — management IP in `ignoreip`. | T-0095 done 2026-07-08 (7/7 PASSED) | **No work**; validator re-confirms. |
| **AC6** | **Docker installed and operational** (engine + compose plugin) — only after AC4 (the UFW FORWARD reconciliation). | T-0090 primary work item | Validator should confirm `docker --version` ≥ 27.x (compose plugin built-in), `docker compose version`, `systemctl is-active docker`, and `docker run --rm hello-world` (or equivalent) succeeds. |
| **AC7** | **Application baseline deployed (the ai-qadam QA stack — 2 containers: app + db; Compose project `ai-qadam-test`; port `127.0.0.1:3112`).** Per the run-prompt: source cloned from `c:\Users\tvolo\dev\ai-dala\aiqadam`; nginx vhost `qadam-test.ai-dala.com → http://127.0.0.1:3112`; new Cloudflare A record `qadam-test.ai-dala.com` → `95.46.211.230` (proxied). | T-0090 primary work item; mirrors `/var/www/ai-qadam/docker-compose.yml` on hetzner-prod (Next.js app + Postgres 16 db) | Validator should confirm: 2 containers running under the `ai-qadam-test` Compose project (`docker compose ls -a`); app port published `127.0.0.1:3112:3000`; db internal-only; nginx vhost active; HTTPS endpoint `https://qadam-test.ai-dala.com` returns HTTP 200 (or the equivalent health-check response). |
| **AC8** | `role:` in `landscape/hosts/pro-data-tech-qa.md` frontmatter updated from `unassigned` to an assigned role (user's preference: `ai-qadam-qa` is the natural default). `landscape/services.md` Docker + nginx tables populated; `landscape/cloudflare.md` DNS table updated with the new A record; `shared/app-registry.md` gains an `ai-qadam` test-environment entry. | Step 08 deliverable | Validator cross-references all four files. |

### User decisions — captured

| Decision | Value (from T-0090 + run-prompt + landscape) | Conflicting? |
|---|---|---|
| Host-id | **`pro-data-tech-qa`** (already in landscape frontmatter; 2026-07-08 user decision resolved earlier "keep pro-data-tech-qa, not pro-data-1") | No |
| Role | **`ai-qadam` QA** (exact frontmatter value pending user pick between `ai-qadam-qa` and `qadam-test`; flagged in step-02 "Open questions" item B) | No — both candidates are consistent with the user's intent |
| Provider | **pro-data.tech, NOT Hetzner** — no Cloud Firewall API, no `firewall-1` analogue; all network changes are host-local UFW + nginx | No |
| `PermitRootLogin` | **prohibit-password permanently** (2026-07-08 user decision recorded in T-0093 result) — T-0090 will NOT change this | No |
| UFW source-restrictions on 22/tcp | **none** (2026-07-08 user decision; UFW only-22 + sshusers AllowGroups + fail2ban = defense-in-depth) | No |
| Stack base pattern | **Mirror `/var/www/ai-qadam/docker-compose.yml`** (Next.js app + Postgres 16 db, 2 containers) — NOT a 3-container split, NOT nginx-in-container (host nginx handles TLS/reverse-proxy), NOT a 12-factor-redesign | No — matches user's run-prompt explicitly |
| Test port | **`127.0.0.1:3112`** (next free test slot per `shared/app-registry.md` convention; `3110` and `3111` already claimed by pf-test and bilimbaga-test) | No |
| Test DNS subdomain | **`qadam-test.ai-dala.com`** | No |
| Compose project name | **`ai-qadam-test`** (distinct from prod's `ai-qadam` so container/network/volume namespaces don't collide during future T-0062 migration) | No |
| Backups | Out of scope for T-0090; T-0098 follow-on (local-disk only, no off-site per project hard rule) | No |
| Off-site storage | None permitted (per project hard rule & README § Backups & storage policy) | No |

### Conflicts with running or scheduled tasks

| Task | Status | Overlap with T-0090? |
|---|---|---|
| T-0093 (sshd hardening) | done 2026-07-08 | None — dependency satisfied; T-0090 inherits the hardened sshd, doesn't change it. |
| T-0094 (UFW) | done 2026-07-08 | None — dependency satisfied; T-0090 inherits the DROP and reconciles it. |
| T-0095 (fail2ban) | done 2026-07-08 | None — T-0090 inherits, doesn't change fail2ban. |
| T-0097 (operator users) | done 2026-07-08 | None — operator users are in `sshusers`; QA stack's compose runs as non-root db user (postgres) + container-internal app user, no overlap with operator accounts. |
| T-0096 (auditd) | observation, P3, deferrable per T-0088 | None. Auditd is independent of Docker install. Operator MAY choose to defer past T-0090 as well. |
| T-0098 (host backup) | observation, P3 | None — T-0090 finishes, T-0098 starts (the QA role-landing is the trigger). |
| T-0062 (remove ai-qadam from hetzner-prod) | pending, P0 | **None** — T-0062 is the future removal of `/var/www/ai-qadam/` on hetzner-prod. T-0090 is additive (adds a parallel test stack on pro-data-tech-qa). They can run in any order. T-0062 is NOT in T-0090's scope. The run-prompt and task body both confirm "QA instance distinct from the Hetzner production host." |
| T-0078 (Gitea on hetzner-prod) | done 2026-05-26 | None — different host, different app. |
| T-0075 (Immich on hetzner-prod) | done 2026-05-21 | None. |
| T-0077 (protect-my-fab main) | pending, P1 | None — that's about the My-Fab Git repo, not ai-qadam infra. |
| T-0056 (GitHub PAT scrub) | pending, P0 | None — historical, not infra. |
| T-0063 (remove WMS stack) | pending, P0 | None. |

**No conflicts found.** T-0090 owns the full pro-data-tech-qa primary state during execution and shares no other task's blocking dependency.

### Status / workflow integrity check

- T-0090 is `kind: task, status: pending` — eligible for the `infrastructure` workflow, which the step-01 handoff identified.
- All required preconditions for promotion to `pending` are met (T-0093, T-0094, T-0095, T-0097 all `done`).
- The 2026-07-08 promotion from `observation` → `pending` is consistent with the T-0090 `## History` block (last entry: "2026-07-08: promoted observation -> pending — T-0093, T-0097, T-0094, T-0095 dependencies all done; ready for execution").
- `outcome` field is empty — correct for a not-yet-executed task. Will be populated by step 08 (or step 07 if closed).
- `executed_by_runs` is empty — correct; this run will populate it.

### Edge-case checks (rejected only if real risk)

- ✓ **Idempotency:** T-0090 can be re-run safely; Docker install + UFW reload + DNS record add are idempotent. The main non-idempotent step is the cert-copy (if option-a chosen); the executor should `test -f` before copying.
- ✓ **No silent overwrites:** executor must back up `/etc/default/ufw`, `/etc/nginx/sites-available/default`, the `/etc/ssh/sshd_config.d/` drop-ins (already done T-0093), and any pre-existing `app-backup.timer` file. Step 04 solution-designer should enumerate these.
- ✓ **No paid provider add-ons:** the task respects the README § Backups & storage policy (no paid Hetzner add-ons; no off-site storage); by extension, no paid pro-data.tech add-ons. Executor must not attempt any provider-side config.
- ✓ **No secret values in this repo:** T-0090 body does not contain any secret values; the QA `.env` will live on the QA host only (mode 600, root:root) per the project's editing rules.
- ✓ **No false dependency on T-0062:** T-0062 is pending but not in T-0090's `blocked_by`. The run-prompt and "Why" both confirm parallel or independent sequencing is fine.

### Risks watched (passed through to step 04, not failing this step)

- **UFW FORWARD reconciliation MUST come before Docker install** — sequence this explicitly in solution-designer (step 4) to avoid the "compose up succeeds, curl times out" failure mode noted in step-01.
- **TLS-at-origin needs a user decision** (copy from hetzner-prod vs reissue vs DNS-only mode) — flagged in step-02 Open Questions (A).
- **`role:` frontmatter value** — flagged in step-02 Open Questions (B).
- **Source repo private-vs-public check** — flagged in step-02 Gaps item 1.
- **The Compose `name:` field** must be `ai-qadam-test` (not `ai-qadam`) — explicit in run-prompt; solution-designer must enforce.

## Issues / risks

None blocking. Three small landscape-coverage gaps:

1. `affects:` frontmatter is missing `landscape/cloudflare.md` and `shared/app-registry.md` (which step 08 will need to update). Cosmetic; can be appended in a 1-line frontmatter edit before step 04 if the user wants, otherwise step 08 will update regardless.
2. `tasks/_index.md` will be regenerated by step 08 (which is correct), but the `updated:` column for T-0090 might not auto-bump when T-0090 closes; step 08 should re-stamp `updated: 2026-07-08` to close.
3. Step 01 (task-reader) listed 5 information gaps; step 02 (landscape-reader) closed 4 of them via live probing. The remaining 1 gap (the optional pre-execution probe in step 02 § Gaps "Optional pre-execution checks") is a non-gating recommendation for the executor, not a blocker.

## Open questions (optional)

- None blocking T-0090 validation. The 4 open questions in step-02's handoff (TLS-at-origin, role-name, repo-private, parallel-with-T-0062) are decision-points that solution-design will surface — they do not affect this validation.
