$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-apply-hetzner-firewall-001'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$headers = @{ Authorization = "Bearer $tok" }

Write-Output "=== List firewalls in project 15130993 ==="
$r = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers $headers -Method GET -TimeoutSec 30 -UseBasicParsing
Write-Output "STATUS=$($r.StatusCode)"
Write-Output "BODY=$($r.Content)"
$r.Content | Set-Content -Path 'final-firewalls-list.json' -NoNewline

Write-Output ""
Write-Output "=== GET firewall 11204449 ==="
$r = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls/11204449' -Headers $headers -Method GET -TimeoutSec 30 -UseBasicParsing
Write-Output "STATUS=$($r.StatusCode)"
Write-Output "BODY=$($r.Content)"
$r.Content | Set-Content -Path 'final-firewall-11204449.json' -NoNewline

Write-Output ""
Write-Output "=== GET server 145542849 ==="
$r = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 30 -UseBasicParsing
Write-Output "STATUS=$($r.StatusCode)"
Write-Output "BODY=$($r.Content)"
$r.Content | Set-Content -Path 'final-server-145542849.json' -NoNewline