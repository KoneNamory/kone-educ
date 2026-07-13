$project = $PSScriptRoot
$backupFolder = Join-Path $project 'backups'
$stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$archive = Join-Path $backupFolder "kone-educ_$stamp.zip"

New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null
$files = Get-ChildItem -LiteralPath $project -Recurse -File | Where-Object {
  $_.FullName -notlike "$backupFolder*" -and $_.FullName -notlike "$project\.git*"
}
Compress-Archive -LiteralPath $files.FullName -DestinationPath $archive -Force
Write-Output "Données mises à jour - sauvegarde créée : $archive"

