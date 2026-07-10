---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 05
agent: user-approval
verdict: APPROVED
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-04-solution-designer.md
artifacts_changed: []
approved_by: user (delegation: "just go")
---

## Summary

User pre-approved the T-0093 sshd-hardening design via full delegation ("just go") before the discovery findings were even complete. The orchestrator surfaced this delegation as soon as the 4 decisions (root login kept, AllowGroups sshusers, no UFW source restrictions, host-id unchanged) were captured. Step 04's `NEEDS_APPROVAL` is auto-routed to APPROVED with the user's verbatim response captured below.

## Details

User verbatim response (current turn): "just go"

User decisions captured earlier in the session (2026-07-08) which the design reflects verbatim:

1. **Root login**: kept permanently via `PermitRootLogin prohibit-password` — root reachable by the provider key in `/root/.ssh/authorized_keys` (break-glass); no future transition to `no`.
2. **AllowGroups**: `sshusers` — operators `tvolodi`, `viktor_d`, `binali_r` join in T-0097 (sibling task).
3. **UFW source restrictions**: none (T-0094 — out of scope for T-0093 but referenced).
4. **Host-id**: remains `pro-data-tech-qa`.

These 4 decisions are reflected in:
- [tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md](tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md) § Notes ("PermitRootLogin policy (user decision 2026-07-08)").
- [landscape/hosts/pro-data-tech-qa.md](landscape/hosts/pro-data-tech-qa.md) § Open questions + Change log row 2026-07-08.

## Issues / risks

Locked-in constraints the executor must respect:

- **`AllowGroups sshusers` sequencing**: pre-create the `sshusers` group and add `root` to it BEFORE applying the drop-in (Option B from the design). One-shot rollout. The provider-key break-glass path depends on `root` being in `sshusers` so the new `AllowGroups` directive does not silently lock out the management workstation's recovery vector.
- **First-wins drop-in semantics**: drop-ins use `40-` prefix to beat cloud-init's `60-cloudimg-settings.conf`. Two drop-ins (`40-disable-password.conf` and `40-ai-dala-infra.conf`), mirroring the `hetzner-prod` pattern.
- **Live SSH verification is non-negotiable**: the executor must run a fresh-session SSH probe after restart and confirm `root ... groups=0(root),999(sshusers)` + `SUDO_OK` before declaring success. If the probe fails, halt and emit `BLOCKED` — the user must be alerted immediately to use pro-data.tech console-based recovery.
- **Backup before destructive change**: `/etc/ssh/sshd_config.d` is snapshotted to `/tmp/sshd_config.d.pre-T0093.<UTC>.bak` before any modification.
- **Idempotent re-runs**: `groupadd -f sshusers`, `usermod -aG sshusers root` are idempotent; existing drop-in files are overwritten with the canonical content.

## Open questions

None. The design resolves the only sequencing concern (T-0093 ↔ T-0097 circular dependency on `AllowGroups sshusers`) via Option B. The orchestrator advances to step 06 (`executor-infra`).
