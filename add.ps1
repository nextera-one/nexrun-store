param(
  [string[]]$Mode = @()
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
$Javelle = if ($env:JAVELLE_CLI) { $env:JAVELLE_CLI } else { 'javelle' }

if ($Mode -contains "-h" -or $Mode -contains "--help") {
  Write-Host "Usage: ./add.ps1 [mode ...]"
  Write-Host ""
  Write-Host "Enable Javelle target modes for this app."
  Write-Host "Examples:"
  Write-Host "  ./add.ps1 mobile"
  Write-Host "  ./add.ps1 ssr pwa"
  Write-Host "  ./add.ps1 all"
  Write-Host ""
  Write-Host "When no mode is passed, this script enables all built-in modes."
  exit 0
}

if ($Mode.Count -eq 0) {
  $Mode = @("all")
}

foreach ($Name in $Mode) {
  Write-Host "Adding Javelle mode: $Name"
  & $Javelle mode add $Name
}

Write-Host "Enabled modes:"
& $Javelle mode list
