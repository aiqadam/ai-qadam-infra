$tokenPath = 'C:\Users\tvolo\.config\ai-dala-infra\hetzner.ai-qadam.token'
$tok = [System.IO.File]::ReadAllText($tokenPath).Trim()
Write-Host "tok_len=$($tok.Length)"
$sha = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($tok))
$fingerprint = [System.BitConverter]::ToString($sha).Replace('-','').ToLower()
Write-Host "Computed fingerprint: $fingerprint"
Write-Host "Expected fingerprint: FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153"
if ($fingerprint -eq 'FBF81B3A1AB2F3A9BE3D3F30C47F32668EA25AE4FCD7363002A54C013CF03153') {
    Write-Host "MATCH=YES"
} else {
    Write-Host "MATCH=NO"
}
