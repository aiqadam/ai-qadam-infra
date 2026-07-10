# Execution-validator verification runner for run 2026-07-08-install-ufw-pro-data-tech-qa-001
# V01-V10 re-validation after executor re-enabled UFW with setsid group-kill fix.

$runDir = $PSScriptRoot
$key    = 'C:\Users\tvolo\.ssh\pro-data.tech-qa-instance_rsa.ppk'
$host_  = 'root@95.46.211.230'

function Invoke-SSH([string]$remoteCmd, [string]$outFile) {
    Write-Host "### $outFile  (cmd: ssh $host_ '$remoteCmd')"
    # Use cmd /c to avoid PowerShell's argument-parsing for native ssh.exe
    $output = & cmd /c "ssh -i `"$key`" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new $host_ `"$remoteCmd`"" 2>&1
    $rc = $LASTEXITCODE
    $output | Out-File -FilePath (Join-Path $runDir $outFile) -Encoding utf8
    Write-Host "### exit=$rc  lines=$($output.Count)"
    return $output
}

# V01 - ufw status verbose
Invoke-SSH 'sudo ufw status verbose' 'step-07-verify-V01-ufw-status.txt'

# V02 - ufw status numbered
Invoke-SSH 'sudo ufw status numbered' 'step-07-verify-V02-ufw-status-numbered.txt'

# V03 - /etc/default/ufw
Invoke-SSH 'cat /etc/default/ufw' 'step-07-verify-V03-default-ufw.txt'

# V04 - iptables v4
Invoke-SSH 'sudo iptables -L -n -v | head -30' 'step-07-verify-V04-iptables-v4.txt'

# V05 - ip6tables v6
Invoke-SSH 'sudo ip6tables -L -n -v | head -30' 'step-07-verify-V05-ip6tables-v6.txt'

# V06 - live SSH whoami + ufw status
Invoke-SSH 'whoami; echo ---; sudo ufw status' 'step-07-verify-V06-live-ssh.txt'

# V07 - systemctl is-enabled ufw
Invoke-SSH 'systemctl is-enabled ufw; echo ---; systemctl is-active ufw' 'step-07-verify-V07-systemd.txt'

# V09 - no rollback processes
Invoke-SSH 'echo "==pgrep sleep 300=="; pgrep -af "sleep 300" || echo NONE_SLEEP; echo "==pgrep ufw disable=="; pgrep -af "ufw disable" || echo NONE_UFWDISABLE; echo "==pgrep ufw-rollback=="; pgrep -af "ufw-rollback" || echo NONE_UFWROLLBACK; echo "==pgrep setsid=="; pgrep -af "setsid" || echo NONE_SETSID' 'step-07-verify-V09-no-rollback.txt'

# V10 - wait 15s, re-confirm Status: active
Write-Host "### Sleeping 15 seconds for V10..."
Start-Sleep -Seconds 15
Invoke-SSH 'echo "==pgrep sleep 300=="; pgrep -af "sleep 300" || echo NONE_SLEEP; echo "==pgrep ufw disable=="; pgrep -af "ufw disable" || echo NONE_UFWDISABLE; echo "==pgrep ufw-rollback=="; pgrep -af "ufw-rollback" || echo NONE_UFWROLLBACK; echo "==ufw status=="; sudo ufw status verbose' 'step-07-verify-V10-stable.txt'

# V08 - off-host TCP probe (PowerShell)
$psCmd = "Test-NetConnection -ComputerName 95.46.211.230 -Port 22 -WarningAction SilentlyContinue | Out-String; '---'; Test-NetConnection -ComputerName 95.46.211.230 -Port 80 -WarningAction SilentlyContinue | Out-String; '---'; Test-NetConnection -ComputerName 95.46.211.230 -Port 443 -WarningAction SilentlyContinue | Out-String"
Write-Host "### step-07-verify-V08-port-probe.txt"
$output = & powershell -NoProfile -Command $psCmd 2>&1
$output | Out-File -FilePath (Join-Path $runDir 'step-07-verify-V08-port-probe.txt') -Encoding utf8

Write-Host "### Done."
