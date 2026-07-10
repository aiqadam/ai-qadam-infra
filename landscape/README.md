# Landscape

The landscape is the project's source of truth about *what exists* in the systems we manage. Every workflow reads from it at step 02 and writes back to it at step 08.

## Files

| File | Scope |
|---|---|
| [`hosts/ubuntu-16gb-nbg1-1.md`](./hosts/ubuntu-16gb-nbg1-1.md) | The Hetzner ai-qadam server (46.225.239.60) — Hetzner project "ai-qadam" (15130993). Populated by discovery run `2026-06-27-discovery-host-001`. |
| [`hosts/pro-data-tech-qa.md`](./hosts/pro-data-tech-qa.md) | The pro-data.tech server (95.46.211.230) — ai-qadam QA instance. Populated by discovery run `2026-07-08-discovery-pro-data-tech-qa-001`. |
| [`services.md`](./services.md) | What runs on each host: containers, nginx vhosts, systemd units, ports. |
| [`cloudflare.md`](./cloudflare.md) | Stub — no Cloudflare zones are currently managed by this repo. See file for cross-repo coordination note on T-0090a. |
| [`domains.md`](./domains.md) | Stub — no domains are currently owned by this repo. |
| [`secrets-inventory.md`](./secrets-inventory.md) | What secrets exist and where, **not the values**. Git-ignored — never committed. Operators must create this file locally. |

## Backups & storage policy

**Policy:** all backups live on the local host disk. No off-site backup targets, no paid provider snapshots, no Hetzner Storage Box, no S3/B2/R2/Google Drive/NFS. Backups stay on the local host disk only.

## Editing rules

1. **Landscape files are authoritative.** If a workflow's executor changes the system, the landscape-updater (step 08) must update the relevant landscape file in the same run. Drift between landscape and reality is a bug.
2. **Never put secret values here.** Only what secrets exist, what they're for, and where the values live. The values themselves stay in an external store.
3. **Each file has a `last_verified:` field in frontmatter** — the date its content was last confirmed against the real system. The landscape-reader uses this to decide whether to flag stale data.
4. **Edits are made through the landscape-updater subagent** during a workflow run, OR manually by a human when bootstrapping or correcting drift. Manual edits should update `last_verified:`.

## Bootstrap note

This repo was spun off from `ai-dala-infra` on 2026-07-10 (T-0101, run `2026-07-10-spinoff-ai-qadam-infra-001`). Pre-migration run audit trail lives in `runs/` (copied from source). `secrets-inventory.md` is git-ignored and was never committed — operators must recreate it locally.
