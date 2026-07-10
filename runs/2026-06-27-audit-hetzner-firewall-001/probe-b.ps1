# Probe B — Firewalls for project 15130993
# GET /v1/firewalls?project_id=15130993 — enumerate all Cloud Firewalls in the ai-qadam project.
$ErrorActionPreference = 'Stop'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
Write-Host ("STATUS=" + $resp.StatusCode)
$j = $resp.Content | ConvertFrom-Json
Write-Host ("firewalls_count=" + $j.firewalls.Count)
$j.firewalls | ForEach-Object {
  Write-Host ("===")
  Write-Host ("id=" + $_.id + " name=" + $_.name)
  Write-Host ("inbound_rules_count=" + $_.rules.inbound.Count)
  Write-Host ("outbound_rules_count=" + $_.rules.outbound.Count)
  Write-Host ("applied_to_count=" + $_.applied_to.Count)
  $_.applied_to | ForEach-Object {
    Write-Host ("  applied_to: type=" + $_.type + " server_id=" + $_.server.id + " server_name=" + $_.server.name)
  }
}
Write-Host "DONE"
