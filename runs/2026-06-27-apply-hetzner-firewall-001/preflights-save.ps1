$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-apply-hetzner-firewall-001'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$headers = @{ Authorization = "Bearer $tok" }

# Save preflight 1
$ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 15).Content.Trim()
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
"timestamp_utc=$ts`noutbound_ip=$ip`nexpected=178.89.57.135`nmatch=$($ip -eq '178.89.57.135')" | Set-Content -Path 'preflight-1-outbound-ip.txt' -NoNewline

# Save preflight 2
$r = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers $headers -Method GET -TimeoutSec 30 -UseBasicParsing
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
"timestamp_utc=$ts`nstatus=$($r.StatusCode)`nbody=$($r.Content)" | Set-Content -Path 'preflight-2-firewalls-list.json' -NoNewline

# Save preflight 3
$r = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers $headers -Method GET -TimeoutSec 30 -UseBasicParsing
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
"timestamp_utc=$ts`nstatus=$($r.StatusCode)`nbody=$($r.Content)" | Set-Content -Path 'preflight-3-server-get.json' -NoNewline

# Save preflight 4
$tnc = Test-NetConnection 46.225.239.60 -Port 22
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
"timestamp_utc=$ts`nRemoteAddress=$($tnc.RemoteAddress)`nRemotePort=$($tnc.RemotePort)`nTcpTestSucceeded=$($tnc.TcpTestSucceeded)" | Set-Content -Path 'preflight-4-ssh-baseline.txt' -NoNewline

Write-Output "All 4 preflight artifacts saved"
Get-ChildItem -Path . -Filter 'preflight-*' | ForEach-Object { Write-Output "$($_.Name) ($($_.Length) bytes)" }