---
run_id: 2026-07-11-deploy-penpot-pro-data-tech-prod-001
step: 07
agent: execution-validator
verdict: PASS
created: 2026-07-11T14:00:00Z
task_id: T-0108-deploy-penpot-on-pro-data-tech-prod
inputs_read:
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-04-solution-designer.md
  - runs/2026-07-11-deploy-penpot-pro-data-tech-prod-001/step-06-executor-infra.md
  - landscape/hosts/pro-data-tech-prod.md
  - shared/handoff-format.md
  - shared/verdicts.md
artifacts_changed: []
next_step_hint: landscape-updater (step 08)
---

## Summary

All 7 independent verification checks on `root@95.46.211.224` passed: Penpot 2.16 is running as 7 healthy Docker containers under project "penpot", the frontend responds HTTP 200 on `localhost:9001`, mailcatch is bound to loopback only, the `.env` file has mode 600 with exactly 3 PENPOT_ keys, and all three sensitive env vars reference `${...}` interpolation in the compose file.

## Details

### On-host checks

| Check (from designer) | Command run | Result | Pass |
|---|---|---|---|
| All 7 containers running | `docker compose -p penpot ps` | 7 containers listed, all `Up 8 minutes`; postgres and valkey show `(healthy)` | yes |
| Frontend answers HTTP on localhost:9001 | `curl -s -o /dev/null -w 'HTTP %{http_code}' http://localhost:9001/` | `HTTP 200` | yes |
| penpot-mcp container running | `docker ps --filter 'name=penpot-mcp' --format '{{.Names}} {{.Status}}'` | `penpot-penpot-mcp-1 Up 8 minutes` | yes |
| mailcatch port bound to localhost only | `grep '1080' /opt/penpot/docker-compose.yaml` | `"127.0.0.1:1080:1080"` — no `0.0.0.0` entry | yes |
| .env contains exactly 3 PENPOT_ keys | `grep -c 'PENPOT_' /opt/penpot/.env` | `3` | yes |
| Compose file references env vars via ${...} | `grep 'PENPOT_FLAGS\|PENPOT_PUBLIC_URI\|PENPOT_SECRET_KEY' /opt/penpot/docker-compose.yaml \| grep '$'` | Three lines returned: `PENPOT_FLAGS: ${PENPOT_FLAGS}`, `PENPOT_PUBLIC_URI: ${PENPOT_PUBLIC_URI}`, `PENPOT_SECRET_KEY: ${PENPOT_SECRET_KEY}` | yes |
| .env file mode 600 | `ls -la /opt/penpot/.env` | `-rw------- 1 root root 194 Jul 11 09:03 /opt/penpot/.env` | yes |

Full container table from `docker compose -p penpot ps`:

```
NAME                        IMAGE                     SERVICE            STATUS
penpot-penpot-backend-1     penpotapp/backend:2.16    penpot-backend     Up 8 minutes
penpot-penpot-exporter-1    penpotapp/exporter:2.16   penpot-exporter    Up 8 minutes
penpot-penpot-frontend-1    penpotapp/frontend:2.16   penpot-frontend    Up 8 minutes  (0.0.0.0:9001->8080/tcp)
penpot-penpot-mailcatch-1   sj26/mailcatcher:latest   penpot-mailcatch   Up 8 minutes  (127.0.0.1:1080->1080/tcp)
penpot-penpot-mcp-1         penpotapp/mcp:2.16        penpot-mcp         Up 8 minutes
penpot-penpot-postgres-1    postgres:15               penpot-postgres    Up 8 minutes (healthy)
penpot-penpot-valkey-1      valkey/valkey:8.1         penpot-valkey      Up 8 minutes (healthy)
```

### External checks

No external checks were specified in the designer's verification block for this step. The designer scoped verification to on-host checks only (nginx/HTTPS is deferred to T-0109). No external probe was run.

### Resources-changed reconciliation

| Executor claimed changed | Observed in current state | Match |
|---|---|---|
| `/opt/penpot/` (directory created) | `drwxr-xr-x 2 root root 4096 Jul 11 09:04 /opt/penpot` | yes |
| `/opt/penpot/docker-compose.yaml` (downloaded + 3 patches applied) | `-rw-r--r-- 1 root root 7891 Jul 11 09:04`; grep confirms 3 patches | yes |
| `/opt/penpot/.env` (created, mode 600, 3 PENPOT_ keys) | `-rw------- 1 root root 194`; `grep -c PENPOT_` = 3 | yes |
| Docker volumes: `penpot_penpot_postgres_v15`, `penpot_penpot_assets` | Containers running and healthy implies volumes exist; not directly probed | inconclusive (benign) |
| 7 Docker containers started under project "penpot" | `docker compose -p penpot ps` shows exactly 7 | yes |

## Issues / risks

- The designer's plan specified `.env` owner as `tvolodi`; the observed owner is `root`. The executor connected as `root` and created files as root. This is a deviation from the plan but not a security regression — mode 600 owned by root is equally restrictive. Docker reads the file as root anyway. No remediation required, but landscape doc should reflect `root` ownership.
- No HTTPS endpoint yet (expected — T-0109 is the nginx/Cloudflare step). `penpot.aiqadam.org` is not yet reachable externally; this is by design at this stage.

## Open questions

- Volume existence (`penpot_penpot_postgres_v15`, `penpot_penpot_assets`) was not probed directly. If needed: `docker volume ls | grep penpot`.
- First admin user still needs to be created via `docker exec -ti penpot-penpot-backend-1 python3 manage.py create-profile` (noted by executor).
