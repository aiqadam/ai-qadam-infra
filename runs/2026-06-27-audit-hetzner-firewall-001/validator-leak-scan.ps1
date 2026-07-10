$handoffPath = 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-audit-hetzner-firewall-001\step-06-executor-discovery.md'
$content = Get-Content -Raw $handoffPath
$matches = [regex]::Matches($content, '[A-Za-z0-9]{50,80}')
$outPath = 'C:\Users\tvolo\dev\ai-dala\ai-dala-infra\runs\2026-06-27-audit-hetzner-firewall-001\validator-leak-scan.txt'
'count=' + $matches.Count | Out-File -FilePath $outPath -Encoding utf8
foreach ($m in $matches) {
    'MATCH [len=' + $m.Length + ']: ' + $m.Value | Out-File -FilePath $outPath -Append -Encoding utf8
}
'===_END_===' | Out-File -FilePath $outPath -Append -Encoding utf8
Write-Host "wrote to $outPath"
Get-Content $outPath
