---
run_id: 2026-07-08-harden-sshd-pro-data-tech-qa-001
step: 02
agent: landscape-reader
verdict: PASS
created: 2026-07-08T00:00:00Z
task_id: T-0093-harden-sshd-on-pro-data-tech-qa
inputs_read:
  - runs/2026-07-08-harden-sshd-pro-data-tech-qa-001/step-01-task-reader.md
  - landscape/hosts/pro-data-tech-qa.md
  - landscape/services.md
  - landscape/README.md
  - landscape/hosts/ubuntu-16gb-nbg1-1.md
  - landscape/hosts/hetzner-prod.md
  - tasks/_index.md
  - shared/handoff-format.md
artifacts_changed: []
next_step_hint: Pass to task-validator (step 03).
---

## Summary

The landscape is in a good state for T-0093. `landscape/hosts/pro-data-tech-qa.md` exists and is `status: populated` with `last_verified: 2026-07-08`, populated today by the discovery run `2026-07-08-discovery-pro-data-tech-qa-001`. It documents the host's current cloud-init sshd defaults (`PermitRootLogin yes`, `PasswordAuthentication yes`, `X11Forwarding yes`, `MaxAuthTries 6`, `LoginGraceTime 120`, `ClientAliveInterval 0`) and lists T-0093 as item #3 in `## What needs to happen`. `landscape/services.md` has a new `## pro-data-tech-qa` top-level section populated by the same discovery run. The two sibling hosts `hetzner-prod` (T-0007 done 2026-05-12) and `ubuntu-16gb-nbg1-1` (T-0082 done 2026-06-27, with sshd hardening still pending as item #4 in its `## What needs to happen`) provide well-established precedent for the same drop-in pattern. No landscape gaps block the design step.

## Details

### Relevant facts (sourced from landscape)

- **Target file exists and is fresh.** `landscape/hosts/pro-data-tech-qa.md` — `host_id: pro-data-tech-qa`, `provider: pro-data.tech`, `role: unassigned`, `last_verified: 2026-07-08`, `status: populated`. Created by discovery run `2026-07-08-discovery-pro-data-tech-qa-001`. — _source: `landscape/hosts/pro-data-tech-qa.md` (frontmatter)_

- **Current sshd effective config on the host (from `sshd -T` 2026-07-08):** `Port 22`, `PermitRootLogin yes`, `PasswordAuthentication yes` (cloud-init default, explicit), `PubkeyAuthentication yes`, `PermitEmptyPasswords no`, `UseDNS no`, `X11Forwarding yes`, `MaxAuthTries 6`, `LoginGraceTime 120`, `ClientAliveInterval 0`. **No `AllowUsers` / `AllowGroups` directives.** Cloud-init defaults — hardening required (T-0093). — _source: `landscape/hosts/pro-data-tech-qa.md` (`## Access` → "SSH daemon config (sshd -T effective, 2026-07-08)")_

- **Existing sshd drop-ins on the host (one file, will compete on first-wins semantics):** `60-cloudimg-settings.conf` (27 bytes, single line `PasswordAuthentication yes`). First-wins semantics: the drop-in sets `PasswordAuthentication yes` redundantly with the compiled-in default. No project-managed drop-ins installed yet. — _source: `landscape/hosts/pro-data-tech-qa.md` (`## Access` → "sshd drop-in files (`/etc/ssh/sshd_config.d/`)")_

  > **Important variance from `hetzner-prod`**: on prod the cloud-init drop-in is named `50-cloud-init.conf`, on pro-data-tech-qa it is `60-cloudimg-settings.conf`. The new `40-disable-password.conf` will sort before either cloud-init file (lexicographically `40-` < `50-` < `60-`), so first-wins still gives the project drop-in the win. The validator / designer should still check live at execution time, but this is the expected behavior on every modern Ubuntu cloud image. — _observed across `landscape/hosts/hetzner-prod.md` and `landscape/hosts/pro-data-tech-qa.md`_

- **Security posture bullet about sshd (verbatim):** "**sshd:** cloud-init defaults — `PermitRootLogin yes`, `PasswordAuthentication yes` (explicit via `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`), `MaxAuthTries 6`, `LoginGraceTime 120`, `X11Forwarding yes`. **Hardening required (T-0093).**" — _source: `landscape/hosts/pro-data-tech-qa.md` (`## Security posture`, first bullet)_

- **`## What needs to happen` item #3 (verbatim):** "⏳ **[T-0093](../../tasks/T-0093-harden-sshd-on-pro-data-tech-qa.md) — sshd hardening.** Disable `PasswordAuthentication`, set `PermitRootLogin prohibit-password`, add `AllowGroups`, drop SHA-1 MACs. **Must precede T-0097, T-0094, T-0095** (all depend on a stable sshd config)." — _source: `landscape/hosts/pro-data-tech-qa.md` (`## What needs to happen` item 3)_

- **Provider key + root break-glass is explicit and decided.** Landscape records: "`/root/.ssh/authorized_keys` has only 1 line (provider key, comment `rsa-key-20260707`)." The user's 2026-07-08 decision recorded under "Open questions" is: "root login kept permanently (`PermitRootLogin prohibit-password` — root reachable by key via the provider key in `/root/.ssh/authorized_keys`, which is the break-glass anchor). Everyday operators get dedicated accounts: `tvolodi`, `viktor_d`, `binali_r` — all in the `sshusers` group with NOPASSWD sudo. The provider key is **not** in `sshusers`." T-0090 will **never** finalize `PermitRootLogin no`. — _source: `landscape/hosts/pro-data-tech-qa.md` (`## Open questions` → "Single-user vs. multi-user, and root login policy")_

- **`landscape/services.md` confirms a top-level `## pro-data-tech-qa` section exists.** The section is populated by `2026-07-08-discovery-pro-data-tech-qa-001` and explicitly notes for the `ssh.service` row: "sshd — cloud-init defaults (`PermitRootLogin yes`, `PasswordAuthentication yes`); hardening pending T-0093". The scheduled-tasks sub-section records no operator users yet ("No `tvolodi` user exists yet — see T-0097"). — _source: `landscape/services.md` (`## pro-data-tech-qa`)_

- **Sshd-related downstream tasks (all blocked by T-0093):** T-0094 (UFW, P2), T-0095 (fail2ban, P2), T-0097 (operator users `tvolodi` + `viktor_d` + `binali_r` in `sshusers`, P2). T-0090 (full prep, P1) is `blocked_by: T-0093`. T-0096 (auditd, P3) and T-0098 (backup strategy, P3) are deferred. The T-0093 acceptance checklist references the multi-PC operator SSH acceptance criterion that T-0097 will satisfy. — _source: `tasks/_index.md` rows for T-0090, T-0093, T-0094, T-0095, T-0096, T-0097, T-0098; cross-checked against `landscape/hosts/pro-data-tech-qa.md` `## Open tasks affecting this host`_

### Sibling precedents

- **`hetzner-prod` — T-0007 done 2026-05-12 via run `2026-05-12-disable-ssh-password-auth-001`.** Drop-in `/etc/ssh/sshd_config.d/40-disable-password.conf` (verbatim from executor log step-04):
  ```
  # Managed by ai-dala-infra
  # Run: 2026-05-12-disable-ssh-password-auth-001 (attempt 3)
  # sshd_config.d on this host uses FIRST-WINS semantics (lexicographic order).
  # This file sorts before 50-cloud-init.conf and therefore wins the PasswordAuthentication directive.
  # Do not edit directly. To revert: sudo rm /etc/ssh/sshd_config.d/40-disable-password.conf && sudo systemctl reload ssh
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  ```
  Mode 0644 (the executor created it via `sudo tee`, which produced mode 0644 root:root — not 0600; this is a known characteristic of `tee`, not a bug). `sshd -T | grep -iE 'passwordauthentication|kbdinteractiveauthentication'` post-reload returned `passwordauthentication no` / `kbdinteractiveauthentication no`. **Known lesson from this run:** the host uses FIRST-WINS (not last-wins as the man page sometimes suggests); the `40-` prefix sorts before `50-cloud-init.conf` and therefore wins. T-0009 follow-ups (T-0040 SHA-1 MACs, T-0049 X11Forwarding, T-0050 ClientAliveInterval) remain open against this host. — _source: `landscape/hosts/hetzner-prod.md` (`## Access` sshd drop-in list + Change log entry for 2026-05-12 `2026-05-12-disable-ssh-password-auth-001`); canonical drop-in contents from `runs/2026-05-12-disable-ssh-password-auth-001/step-06-executor-infra.md` (step 4 verification block)_

- **`ubuntu-16gb-nbg1-1` — same hardening pattern PENDING.** The host's landscape explicitly records: "**No project hardening yet** (no `40-disable-password.conf`; no `AllowUsers` / `AllowGroups` filters)." Drop-in dir currently contains only `50-cloud-init.conf`. "What needs to happen" item #4 calls out: "**sshd hardening** for parity with `hetzner-prod`: disable `PasswordAuthentication`, disable `PermitRootLogin`, drop SHA-1 MACs, set explicit KexAlgorithms/Ciphers, add a project-managed `40-disable-password.conf` drop-in. **Follow-on state-changing workflow** (not yet a task; independent of role assignment)." This sibling is **less hardened than pro-data-tech-qa will be after T-0093** — `ubuntu-16gb-ngb1-1` should not block T-0093, but it is the closest analog. — _source: `landscape/hosts/ubuntu-16gb-nbg1-1.md` (`## Access` → "SSH daemon config" + "sshd drop-in files"; `## What needs to happen` item 4)_

### Stale or stub files encountered

- None. `landscape/hosts/pro-data-tech-qa.md` was created today and verified live by the discovery run. `landscape/services.md` frontmatter is `last_verified: 2026-07-08`. `landscape/hosts/hetzner-prod.md` is `last_verified: 2026-07-08` (kept current by run `2026-07-07-scrub-secrets-inventory-001`). `landscape/hosts/ubuntu-16gb-nbg1-1.md` is `last_verified: 2026-06-27` — **40 days old** (just over the 30-day staleness threshold) but its content is accurate per the 2026-06-27 discovery run and the host has not been modified since; flag for awareness, no action needed for T-0093.

### Gaps requiring live discovery

The landscape-reader does not perform live discovery, but the following gaps must be filled by `executor-infra` at step 06 (or `solution-designer` at step 04 if it wants to pre-flight):

1. **Exact contents of `/etc/ssh/sshd_config.d/` at execution time** — needed to confirm `40-` does not collide with another project drop-in or another cloud-init file with a lower numeric prefix. The discovery run confirmed only `60-cloudimg-settings.conf` exists, but the solution-designer should re-check.
2. **Existence of the `sshusers` group** — `AllowGroups sshusers` will silently deny all logins if the group is missing. The landscape says operator users (`tvolodi`, `viktor_d`, `binali_r`) are not yet created (T-0097 is `blocked_by: T-0093`). **The executor at step 06 MUST verify the group exists (or create it) before any `AllowGroups sshusers` drop-in can take effect.** The task body says "drop both drop-ins in the same change" — the order/group-creation check should happen first.
3. **Exact contents of `/etc/ssh/sshd_config` on the host** — confirm the `Include /etc/ssh/sshd_config.d/*.conf` line is present. (This was the root cause of the attempt-1/attempt-2 failure on hetzner-prod: the designers initially chose `10-` then `60-` before settling on `40-`.)
4. **`AuthorizedKeysFile` setting** — not captured in the landscape. Default is `.ssh/authorized_keys` (relative to user home). Should be left alone; the executor just needs to verify root's `/root/.ssh/authorized_keys` still contains the provider key after the change.

## Issues / risks

- **`AllowGroups sshusers` lockout risk (medium probability, high impact).** If the `sshusers` group does not exist (likely, since no operator users are created yet — T-0097 is downstream), then `AllowGroups sshusers` will deny **every** login including the root break-glass via the provider key — because the drop-in's `AllowGroups` directive would block root if root is not in `sshusers`. The user decision (recorded in `## Open questions`) is that the **provider key stays in `/root/.ssh/authorized_keys` and is the break-glass anchor governed by `PermitRootLogin`**, not by `AllowGroups`. This needs careful sequencing at step 06:
  - Option A (safest): apply `40-disable-password.conf` + `40-ai-dala-infra.conf` *without* `AllowGroups` first; then verify sshd + key auth; then add `AllowGroups sshusers` in a follow-up edit after T-0097 has created the operator users + added them to `sshusers`.
  - Option B (acceptable if the executor pre-creates `sshusers` and adds `root` to it as the only member): include `AllowGroups sshusers` in `40-ai-dala-infra.conf` from the start, but explicitly add `root` to the `sshusers` group in the same `set -e` step. This keeps the T-0093 acceptance criteria intact in one change.
  - Either option should be called out in the solution-designer's plan. Step 04 may need a small follow-up discovery probe to determine whether `sshusers` exists.
- **First-wins vs. last-wins is host-specific.** The previous T-0007 run (run `2026-05-12-disable-ssh-password-auth-001`) lost two attempts to this gotcha on Ubuntu 24.04 (hetzner-prod). On Ubuntu 26.04 (pro-data-tech-qa) the semantics should be the same (it's the OpenSSH upstream behavior, not Ubuntu-version-specific), but the solution-designer should re-verify with `sshd -T` after `systemctl reload ssh`.
- **Cloud-init drop-in is `60-cloudimg-settings.conf`, not `50-cloud-init.conf` (as on hetzner-prod).** Does not change the plan — `40-` < `60-` still wins under first-wins — but the header comment in `40-disable-password.conf` should reference the actual cloud-init filename on the host, not the hetzner-prod name.
- **Sibling `ubuntu-16gb-nbg1-1` is less hardened.** This is informational only; does not block T-0093 but means the project will have two hardening patterns in production once T-0093 lands: hetzner-prod with `40-disable-password.conf` only, pro-data-tech-qa with `40-disable-password.conf` + `40-ai-dala-infra.conf`. Solution-designer may want to note this.

## Open questions (optional)

- None blocking for step 03/04. The user decisions baked into the landscape (root-login policy via `PermitRootLogin prohibit-password` + provider key as break-glass; `sshusers` group membership for operators; no source-IP allowlist on the eventual UFW rule) are sufficient to design T-0093. The `AllowGroups sshusers` ordering question (Option A vs. Option B above) is the only execution-time sequencing detail the solution-designer will need to address at step 04; it is not a hard open question for the landscape-reader.