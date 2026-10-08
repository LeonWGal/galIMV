param(
    [string]$ReleaseDir = "dist-release"
)

$targetDir = (Resolve-Path $ReleaseDir).Path
$hashFile = Join-Path $targetDir "SHA256SUMS.txt"

$hashes = Get-ChildItem -Path $targetDir -File |
    Where-Object { $_.FullName -ne $hashFile } |
    Get-FileHash -Algorithm SHA256 |
    ForEach-Object { "$($_.Hash)  $($_.Path | Split-Path -Leaf)" }

$hashes | Set-Content -Path $hashFile -Encoding utf8

Write-Host "Updated SHA256SUMS.txt in $targetDir"
Get-Content $hashFile
