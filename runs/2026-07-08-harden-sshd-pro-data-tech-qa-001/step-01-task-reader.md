---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 01
agent: task-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md
  - workflows/_common-operations.md
  - workflows/infrastructure.md
  - shared/handoff-format.md
  - shared/verdicts.md
  - tasks/README.md
artifacts_changed: []
next_step_hint: Pass to landscape-reader (step 02) with workflow=infrastructure, target=landscape/hosts/pro-data-tech-qa.md.
---

## Summary

T-0093 (`Harden sshd on pro-data-tech-qa`) is a state-changing infrastructure task with `kind: task`, `status: pending`, `priority: P1`, `affects: [landscape/hosts/pro-data-tech-qa.md]`, `workflow: infrastructure`, `estimated_blast_radius: medium`, `estimated_reversibility: full`, and a clean five-item acceptance checklist. The task file is well-formed, the orchestrator-supplied run_id has no pre-existing step files, and the request parses cleanly into the standard 8-step workflow. Emit `verdict: PASS`; hand off to landscape-reader.

## Details

- **Workflow:** `infrastructure` (per the task's `workflow:` field; matches `workflows/infrastructure.md` which binds executor `executor-infra` at step 06).
- **State-changing:** yes — overrides the sshd config of a managed host. Per `shared/verdicts.md` the approval gate (step 05) MUST run if step 04 emits `NEEDS_APPROVAL`. Step 04 may still auto-approve (omit step 05) if blast radius is low AND fully reversible AND no designer doubts — T-0093's blast radius is `medium`, so step 04 is overwhelmingly likely to emit `NEEDS_APPROVAL`. Expect a step-05 file.
- **Target scope:** `landscape/hosts/pro-data-tech-qa.md` (the host's sshd hardening lives there). Adjacent landscape files may be touched at step 02 if the landscape-reader discovers them relevant (e.g. `landscape/services.md`, `landscape/secrets-inventory.md` for the provider-key inventory).
- **Constraints stated by the task body (verbatim re-statement of the 5 acceptance criteria):**
  - Create `/etc/ssh/sshd_config.d/40-disable-password.conf` with `PasswordAuthentication no`, `KbdInteractiveAuthentication no` (must sort before the cloud-init `60-cloudimg-settings.conf` drop-in per sshd's first-wins semantics).
  - Create `/etc/ssh/sshd_config.d/40-ai-dala-infra.conf` with `PermitRootLogin prohibit-password`, `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no`, `ClientAliveInterval 300`, `ClientAliveCountMax 2`, `AllowGroups sshusers`, plus dropped SHA-1 MACs (`hmac-sha1`, `hmac-sha1-etm`).
  - Re-run `sshd -T` post-change and confirm all directives show the intended values (`passwordauthentication no`, `permitrootlogin prohibit-password`, `maxauthtries 3`, `x11forwarding no`, …).
  - Verify SSH login from the management workstation post-restart (key auth, no password prompt).
  - Keep the provider key (comment `rsa-key-20260707`) in `/root/.ssh/authorized_keys` as a break-glass anchor.
  - Update `landscape/hosts/pro-data-tech-qa.md`: refresh `last_verified`, rewrite the `## Access` sshd-config block with post-hardening values, drop the `## Security posture` note about sshd, and tick off `## What needs to happen` item #3.
- **Information gaps for downstream steps:**
  - The exact current contents of `/etc/ssh/sshd_config.d/` on the host are needed at step 06; landscape-reader should also snapshot `/etc/ssh/sshd_config` and the existing drop-ins so the executor can compare lex-order.
  - Confirm the `sshusers` group exists (or document its creation as part of step 06 — `AllowGroups sshusers` will silently deny all logins if the group is missing). The task references T-0097 as the dependent task that creates the operator users; the group itself is not explicitly assigned a task. Flag for solution-designer.
  - The 6th acceptance line (landscape update) implies `landscape/hosts/pro-data-tech-qa.md` exists today; landscape-reader must verify the file exists and that `## What needs to happen` already contains an sshd item — if not, that's a pre-existing discovery-run assumption that may have drifted.

## Issues / risks

- **Medium blast radius** (per task frontmatter and per `shared/verdicts.md`): an incorrect drop-in can lock every operator out. Mitigations baked into the task: provider key retained as break-glass, drop-in contents are well-known from `hetzner-prod` siblings (T-0007/T-0040/T-0049/T-0050), `sshd -T` and a login probe verify the result before declaring success.
- **Full reversibility:** removing both drop-ins and `systemctl restart ssh` reverts to the pre-task state.
- **`AllowGroups sshusers` lockout risk:** if T-0097 (operator user creation) has not run yet, the only way in is the provider-key-as-root path. The task does not call this out explicitly; solution-designer should sequence it carefully (apply `AllowGroups sshusers` ONLY after operator users + their pubkeys are verified, or apply hardening without `AllowGroups` first and add it as a follow-up edit once T-0097 lands).
- **First-wins drop-in semantics** are easy to get wrong if a future drop-in is added with a higher prefix (e.g. `50-…`). Solution-designer should call this out in the plan.
- **No conflict** with sibling in-flight tasks: T-0094 (UFW), T-0095 (fail2ban), T-0097 (operator users), T-0090 (server prep) are explicitly listed in `blocked_by`-style notes as downstream; T-0093 is the gate. No coordination issue.

## Open questions

- None. User decisions are baked into the task body (PermitRootLogin policy decision dated 2026-07-08; drop-in prefix decision; provider-key-as-break-glass decision). Step 04 (solution-designer) may surface execution-time questions about the `AllowGroups` ordering relative to T-0097, but those are not blocking this step.