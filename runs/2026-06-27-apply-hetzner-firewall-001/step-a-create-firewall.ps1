$ErrorActionPreference = 'Stop'
Set-Location 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-apply-hetzner-firewall-001'
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$headers = @{
    Authorization  = "Bearer $tok"
    'Content-Type' = 'application/json'
}

$body = @{
    name = 'ai-qadam-mgmt-ssh'
    labels = @{
        'managed-by' = 'ai-dala-infra'
        purpose      = 'ssh-management-only'
        host         = 'ubuntu-16gb-nbg1-1'
    }
    rules = @{
        inbound = @(
            @{
                direction    = 'in'
                protocol     = 'tcp'
                port         = '22'
                source_ips   = @('178.89.57.135/32')
                description  = 'SSH from management workstation'
            }
        )
    }
} | ConvertTo-Json -Depth 10

Write-Output "REQUEST_BODY=$body"

try {
    $resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls' -Headers $headers -Method POST -Body $body -TimeoutSec 30 -UseBasicParsing
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Write-Output "TIMESTAMP=$ts"
    Write-Output "STATUS=$($resp.StatusCode)"
    Write-Output "BODY=$($resp.Content)"
    $resp.Content | Set-Content -Path 'step-a-create-firewall-response.json' -NoNewline
    $fwId = ($resp.Content | ConvertFrom-Json).firewall.id
    Write-Output "FIREWALL_ID=$fwId"
    $fwId | Set-Content -Path 'step-a-firewall-id.txt' -NoNewline
    if ($resp.StatusCode -ne 201) {
        Write-Error "Expected 201 but got $($resp.StatusCode)"
        exit 2
    }
} catch {
    Write-Output "STATUS=ERROR"
    Write-Output "EXCEPTION=$($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $reader.ReadToEnd() | Set-Content -Path 'step-a-create-firewall-response.json' -NoNewline
    }
    Write-Error "Step A failed: $($_.Exception.Message)"
    exit 2
}