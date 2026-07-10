# Probe A — Token verify (sanity)
# The Hetzner Cloud API does not expose a "list projects" route visible to a
# project-scoped token. Instead, verify token validity by hitting two known
# token-scoped resources under project 15130993: /v1/firewalls and /v1/servers/145542849.
$ErrorActionPreference = 'Continue'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$tokLen = $tok.Length
Write-Host ("tok_len=" + $tokLen)
$tokPrefix = $tok.Substring(0,4)
$tokSuffix = $tok.Substring($tokLen-4)
Write-Host ("tok_prefix=" + $tokPrefix + " tok_suffix=" + $tokSuffix)

try {
  $r1 = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  Write-Host ("FIREWALLS_LIST_STATUS=" + $r1.StatusCode)
  $j1 = $r1.Content | ConvertFrom-Json
  Write-Host ("FIREWALLS_LIST_COUNT=" + $j1.firewalls.Count)
} catch {
  Write-Host ("FIREWALLS_LIST_ERROR=" + $_.Exception.Message)
}

try {
  $r2 = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
  Write-Host ("SERVER_GET_STATUS=" + $r2.StatusCode)
} catch {
  Write-Host ("SERVER_GET_ERROR=" + $_.Exception.Message)
}

Write-Host "DONE"
