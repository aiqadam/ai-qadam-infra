$tokenPath = 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token'
$tok = [System.IO.File]::ReadAllText($tokenPath).Trim()
Write-Host "===_PROBE_B_FIREWALLS_PROJECT_ID_==="
try {
    $resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project_id=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
    Write-Host "STATUS=$($resp.StatusCode)"
    Write-Host "BODY=$($resp.Content)"
} catch {
    Write-Host "EXCEPTION=$($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "ERR_BODY=$($reader.ReadToEnd())"
    }
}
Write-Host "===_END_B_==="
Write-Host ""
Write-Host "===_PROBE_B_ALT_PROJECT_==="
try {
    $resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls?project=15130993' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
    Write-Host "STATUS=$($resp.StatusCode)"
    Write-Host "BODY=$($resp.Content)"
} catch {
    Write-Host "EXCEPTION=$($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "ERR_BODY=$($reader.ReadToEnd())"
    }
}
Write-Host "===_END_B_ALT_==="
Write-Host ""
Write-Host "===_PROBE_B_PLAIN_==="
try {
    $resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/firewalls' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
    Write-Host "STATUS=$($resp.StatusCode)"
    Write-Host "BODY=$($resp.Content)"
} catch {
    Write-Host "EXCEPTION=$($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host "ERR_BODY=$($reader.ReadToEnd())"
    }
}
Write-Host "===_END_B_PLAIN_==="
