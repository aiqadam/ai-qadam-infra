# Helpers for executor attempt 2.
# Load with: . .\runs\2026-06-27-apply-hetzner-firewall-001\executor-02-helpers.ps1
$ErrorActionPreference = 'Stop'

# Token loaded silently into $tok
$tok = [System.IO.File]::ReadAllText('C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token').Trim()
$hetznerHeaders = @{ Authorization = "Bearer $tok" }

function Hc-Get([string]$Path, [string]$OutFile) {
    $resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1$Path" -Headers $hetznerHeaders -Method GET -UseBasicParsing -TimeoutSec 30
    if ($OutFile) {
        $resp.Content | Out-File -FilePath $OutFile -Encoding utf8 -Force
    }
    return $resp
}

function Hc-PostJson([string]$Path, [string]$JsonBody, [string]$OutFile) {
    $headers = $hetznerHeaders.Clone()
    $headers['Content-Type'] = 'application/json'
    $resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1$Path" -Headers $headers -Method POST -Body $JsonBody -UseBasicParsing -TimeoutSec 30
    if ($OutFile) {
        $resp.Content | Out-File -FilePath $OutFile -Encoding utf8 -Force
    }
    return $resp
}

function Hc-Delete([string]$Path, [string]$OutFile) {
    $resp = Invoke-WebRequest -Uri "https://api.hetzner.cloud/v1$Path" -Headers $hetznerHeaders -Method DELETE -UseBasicParsing -TimeoutSec 30
    if ($OutFile) {
        $resp.Content | Out-File -FilePath $OutFile -Encoding utf8 -Force
    }
    return $resp
}

function Poll-ActionStatus {
    param(
        [string]$PollUri,
        [int]$MaxSeconds = 30,
        [int]$IntervalSeconds = 2
    )
    $deadline = (Get-Date).AddSeconds($MaxSeconds)
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-WebRequest -Uri $PollUri -Headers $hetznerHeaders -Method GET -UseBasicParsing -TimeoutSec 20
        $obj = $r.Content | ConvertFrom-Json
        $status = $obj.action.status
        Write-Host "  action.status=$status"
        if ($status -eq 'success') { return @{ Status = 'success'; Body = $r.Content } }
        if ($status -eq 'error')   { return @{ Status = 'error';   Body = $r.Content } }
        Start-Sleep -Seconds $IntervalSeconds
    }
    return @{ Status = 'timeout'; Body = '' }
}

Write-Host "Helpers loaded. token_len=$($tok.Length)"