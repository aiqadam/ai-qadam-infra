# Probe C — Server confirmation
# GET /v1/servers/145542849 — confirm ubuntu-16gb-nbg1-1 exists and report Hetzner-side config.
$ErrorActionPreference = 'Stop'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
Write-Host ("STATUS=" + $resp.StatusCode)
$j = $resp.Content | ConvertFrom-Json
$server = $j.server
Write-Host ("id=" + $server.id)
Write-Host ("name=" + $server.name)
Write-Host ("status=" + $server.status)
Write-Host ("server_type_name=" + $server.server_type.name)
Write-Host ("datacenter_name=" + $server.datacenter.name + " location=" + $server.datacenter.location.name)
Write-Host ("created=" + $server.created)
Write-Host ("protection_delete=" + $server.protection.delete)
Write-Host ("protection_rebuild=" + $server.protection.rebuild)
Write-Host ("public_ipv4=" + $server.public_net.ipv4.ip)
Write-Host ("public_ipv6=" + $server.public_net.ipv6.ip)
Write-Host ("private_net_count=" + $server.private_net.Count)
Write-Host ("backup_window=" + $server.backup_window)
Write-Host ("DONE")
