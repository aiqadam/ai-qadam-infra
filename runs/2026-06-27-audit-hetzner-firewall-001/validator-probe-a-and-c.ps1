$tokenPath = 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token'
$tok = [System.IO.File]::ReadAllText($tokenPath).Trim()
Write-Host "tok_len=$($tok.Length)"
Write-Host "tok_prefix=$($tok.Substring(0,4))"
Write-Host "tok_suffix=$($tok.Substring($tok.Length-4))"
Write-Host "===_PROBE_A_TOKEN_VERIFY_VIA_SERVER_==="
$resp = Invoke-WebRequest -Uri 'https://api.hetzner.cloud/v1/servers/145542849' -Headers @{Authorization = "Bearer $tok"} -UseBasicParsing -TimeoutSec 30
Write-Host "STATUS=$($resp.StatusCode)"
$body = $resp.Content | ConvertFrom-Json
$srv = $body.server
Write-Host "id=$($srv.id)"
Write-Host "name=$($srv.name)"
Write-Host "status=$($srv.status)"
Write-Host "server_type_name=$($srv.server_type.name)"
Write-Host "datacenter=$($srv.datacenter.name) location=$($srv.datacenter.location.name)"
Write-Host "created=$($srv.created)"
Write-Host "protection_delete=$($srv.protection.delete)"
Write-Host "protection_rebuild=$($srv.protection.rebuild)"
Write-Host "public_ipv4=$($srv.public_net.ipv4.ip)"
Write-Host "public_ipv6=$($srv.public_net.ipv6.ip)"
Write-Host "private_net_count=$($srv.private_net.Count)"
Write-Host "backup_window=$($srv.backup_window)"
Write-Host "===_END_A_==="
