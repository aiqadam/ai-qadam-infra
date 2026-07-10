$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-apply-hetzner-firewall-001'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$headers = @{ Authorization = "Bearer $tok"; 'Content-Type' = 'application/json' }

$body = @{
    name = 'ai-qadam-mgmt-ssh'
    labels = @{ 'managed-by' = 'ai-dala-infra'; purpose = 'ssh-management-only'; host = 'ubuntu-16gb-nbg1-1' }
    rules = @(
        @{
            direction    = 'in'
            protocol     = 'tcp'
            port         = '22'
            source_ips   = @('178.89.57.135/32')
            description  = 'SSH from management workstation'
        }
    )
} | ConvertTo-Json -Depth 10

Write-Output "REQUEST_BODY=$body"
try {
    $resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls' -Headers $headers -Method POST -Body $body -TimeoutSec 30 -UseBasicParsing
    Write-Output "STATUS=$($resp.StatusCode)"
    Write-Output "BODY=$($resp.Content)"
    $resp.Content | Set-Content -Path 'step-a-create-firewall-response.json' -NoNewline
    if ($resp.StatusCode -eq 201) {
        $fwId = ($resp.Content | ConvertFrom-Json).firewall.id
        $fwId | Set-Content -Path 'step-a-firewall-id.txt' -NoNewline
        Write-Output "FIREWALL_ID=$fwId"
    }
} catch {
    $code = [int]$_.Exception.Response.StatusCode
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $errBody = $reader.ReadToEnd()
    $reader.Close()
    Write-Output "STATUS=$code"
    Write-Output "BODY=$errBody"
    "{`"status`":$code,`"body`":$($errBody | ConvertTo-Json -Compress)}" | Set-Content -Path 'step-a-create-firewall-response.json' -NoNewline
    Write-Output "Step A retry with corrected body shape failed (status=$code): $errBody"
    exit 2
}