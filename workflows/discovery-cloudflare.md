---
name: workflow-discovery-cloudflare
version: 1
description: Read-only enumeration of Cloudflare zones via the API. Populates landscape/cloudflare.md and landscape/domains.md with zone settings, DNS records, page rules, WAF rules, and SSL config.
extends: workflows/_common-operations.md
state_changing: false
skip_design_step: true
---

# Discovery: Cloudflare

Read-only enumeration of the two Cloudflare zones (`ai-dala.com`, `bizdala.com`) using the read-only token referenced in `landscape/secrets-inventory.md`.

## Step bindings

| Step | Agent | Status |
|---|---|---|
| 01 | `task-reader` | required |
| 02 | `landscape-reader` | required |
| 03 | `task-validator` | required |
| 04 | `solution-designer` | **skipped** |
| 05 | user-approval | **skipped** |
| 06 | **`executor-discovery`** | required |
| 07 | `execution-validator` | required |
| 08 | `landscape-updater` | required |

## Landscape files in scope

Read:
- `landscape/cloudflare.md`
- `landscape/domains.md`
- `landscape/secrets-inventory.md`

Write (at step 08):
- `landscape/cloudflare.md`
- `landscape/domains.md`

## Probe checklist for executor-discovery

All probes are HTTP GET against `https://api.cloudflare.com/client/v4`. The executor reads the token from `C:\Users\tvolo\.config\ai-dala-infra\cloudflare-readonly.token` into a shell variable `$CFTOK` and references it via `-H "Authorization: Bearer $CFTOK"`. The token value is NEVER written into the handoff.

### A. Token verify (sanity)
```bash
curl -sS "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CFTOK" | python -m json.tool
```

### B. Zones (both)
```bash
curl -sS "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer $CFTOK" \
| python -c "import sys,json; d=json.load(sys.stdin); [print(json.dumps({k:z[k] for k in ('id','name','status','paused','type','plan','name_servers','original_name_servers','development_mode','created_on','modified_on')}, indent=2, default=str)) for z in d['result']]"
```

### C. Per-zone settings (run for each zone id)
For each `ZID` in (`4a2748e92ef7ddaac7fddf375be2da53`, `b68d8369ab0f91dfee7740ccaa2d5e77`):
```bash
echo "=== zone $ZID settings ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/settings" \
  -H "Authorization: Bearer $CFTOK" \
| python -c "import sys,json; d=json.load(sys.stdin); [print(f\"{s['id']}: {s['value']}\") for s in d.get('result',[])]"
```

### D. DNS records per zone
For each zone id:
```bash
echo "=== zone $ZID DNS records ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/dns_records?per_page=200" \
  -H "Authorization: Bearer $CFTOK" \
| python -c "import sys,json; d=json.load(sys.stdin); [print(f\"{r['type']:7s} {r['name']:40s} -> {r.get('content',''):50s} proxied={r.get('proxied','')} ttl={r['ttl']}\") for r in d.get('result',[])]"
```

### E. Page rules per zone
```bash
echo "=== zone $ZID page rules ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/pagerules?status=active" \
  -H "Authorization: Bearer $CFTOK" | python -m json.tool | head -200
```

### F. Rulesets (WAF, redirect, transform)
```bash
echo "=== zone $ZID rulesets ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/rulesets" \
  -H "Authorization: Bearer $CFTOK" \
| python -c "import sys,json; d=json.load(sys.stdin); [print(f\"{r['id']} phase={r['phase']} kind={r['kind']} name='{r.get('name','')}'\") for r in d.get('result',[])]"
```

### G. SSL/TLS posture
```bash
echo "=== zone $ZID ssl settings ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/settings/ssl" \
  -H "Authorization: Bearer $CFTOK" | python -m json.tool
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/settings/always_use_https" \
  -H "Authorization: Bearer $CFTOK" | python -m json.tool
echo "=== zone $ZID certificate packs ==="
curl -sS "https://api.cloudflare.com/client/v4/zones/$ZID/ssl/certificate_packs" \
  -H "Authorization: Bearer $CFTOK" \
| python -c "import sys,json; d=json.load(sys.stdin); [print(f\"{c['id']} type={c['type']} status={c['status']} hosts={c.get('hosts',[])}\") for c in d.get('result',[])]"
```

## Validation criteria for step 07

- Probe A returned `status: active`.
- Probes B–G ran successfully for BOTH zones.
- Findings summary mentions both zones explicitly.

## Landscape-update guidance for step 08

The landscape-updater should write:
- `landscape/cloudflare.md` — for each zone, populate DNS records table (notable records: A/AAAA pointing to the host's IP, MX, TXT/SPF/DKIM/DMARC, anything proxied), page rules, ruleset summary, SSL/TLS mode, certificate pack types.
- `landscape/domains.md` — confirm registrar (if discoverable from name servers), point-of-record summaries for each domain, certificate strategy in plain language.
- Add a Change log entry to each updated file with `(run_id, "Initial Cloudflare discovery run")`.
- **Do NOT write the token value or any header containing `Authorization` into the landscape files.**
