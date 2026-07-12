---
id: T-0105-create-operator-users-on-pro-data-tech-prod
title: Create non-root operator users on pro-data-tech-prod (tvolodi + optionally viktor_d, binali_r) with NOPASSWD sudo; isolate root SSH to break-glass
kind: task
status: done
priority: P1
created: 2026-07-11
updated: 2026-07-11
closed: 2026-07-11
outcome: succeeded
created_by: manual
source_runs: []
executed_by_runs: [2026-07-11-create-operator-users-pro-data-tech-prod-001]
affects:
  - landscape/hosts/pro-data-tech-prod.md
workflow: infrastructure
blocks: []
blocked_by: [T-0101, T-0102]
related: [T-0097]
estimated_blast_radius: medium
estimated_reversibility: full
---

# Create non-root operator users on pro-data-tech-prod

## Why
Running day-to-day operations as root is a security anti-pattern. Non-root operator accounts with passwordless sudo provide equivalent capability while adding an audit trail and preventing accidental privilege escalation. The QA instance was configured identically via T-0097. This task creates the same operator user set on the production host.

## What done looks like
- [ ] `sshusers` group created
- [ ] User `tvolodi` created with home dir, added to `sshusers` group and `sudo` group
- [ ] `/etc/sudoers.d/90-tvolodi` created: `tvolodi ALL=(ALL) NOPASSWD: ALL` (mode 0440)
- [ ] `tvolodi` authorized_keys populated with ed25519 operator public key
- [ ] Users `viktor_d` and `binali_r` created with same pattern (SSH key from their own workstations when available)
- [ ] `root` added to `sshusers` group (required for AllowGroups sshusers to keep root break-glass access)
- [ ] SSH login verified as `tvolodi@95.46.211.224` from management workstation
- [ ] All `visudo -c` checks pass for all drop-in files
- [ ] 16/16 verification checks passed (matching T-0097 acceptance criteria)

## Result

All 16 designer acceptance-criteria checks passed (run `2026-07-11-create-operator-users-pro-data-tech-prod-001`, step-07 PASS). Three operator accounts created on `pro-data-tech-prod` (95.46.211.224):

- `tvolodi` (uid 1000) — ed25519 key `ai-dala-infra-mgmt@tvolodi-2026-05-12`, groups `sudo`+`sshusers`, sudoers drop-in `/etc/sudoers.d/90-tvolodi` (0440). SSH login + `sudo true` verified from management workstation.
- `viktor_d` (uid 1001) — ed25519 key `viktor_d@ai-dala-infra-2026-06-27`, groups `sudo`+`sshusers`, sudoers drop-in `/etc/sudoers.d/90-viktor_d` (0440).
- `binali_r` (uid 1002) — ed25519 key `binali_r@ai-dala-infra-2026-06-27`, groups `sudo`+`sshusers`, sudoers drop-in `/etc/sudoers.d/90-binali_r` (0440).

Root was NOT removed from `sshusers` — it remains as a permanent break-glass member (`sshusers:x:1000:root,tvolodi,viktor_d,binali_r`). `visudo -c` full parse clean. Pre-run sudoers backup at `/etc/sudoers.d.bak.pre-T0105/`.

Primary operator access: `tvolodi@95.46.211.224` via `ai-dala-infra` key. Break-glass: `root@95.46.211.224` via prod RSA key.

Executor handoff: `runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-06-executor-infra.md`
Validator handoff: `runs/2026-07-11-create-operator-users-pro-data-tech-prod-001/step-07-execution-validator.md`

No deviations from the "What done looks like" checklist. All items checked.

## Notes
- This task must run AFTER T-0102 (sshd hardening) which sets `AllowGroups sshusers`
- Model after T-0097 / run `2026-07-08-create-operator-users-pro-data-tech-qa-001` (16/16 checks passed)
- The operator public key for `tvolodi` is the ed25519 key from the management workstation; confirm from `C:\Users\tvolo\.ssh\` (likely the same key used for QA)
- `viktor_d` and `binali_r` will need their own public keys when they first connect

## History
- 2026-07-11: created manually by orchestrator
- 2026-07-11: status → in-progress — run 2026-07-11-create-operator-users-pro-data-tech-prod-001 started
- 2026-07-11: status → done, outcome succeeded, run 2026-07-11-create-operator-users-pro-data-tech-prod-001, commit <pending>
