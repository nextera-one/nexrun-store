param(
  [string[]]$Mode = @()
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
$Javelle = if ($env:JAVELLE_CLI) { $env:JAVELLE_CLI } else { 'javelle' }
$MavenWarningOption = "--sun-misc-unsafe-memory-access=allow"
$MavenWarningJava = "java"
if ($env:JAVA_HOME) {
  $JavaHomeCandidate = Join-Path $env:JAVA_HOME "bin/java"
  if (Test-Path "$JavaHomeCandidate.exe") {
    $MavenWarningJava = "$JavaHomeCandidate.exe"
  } elseif (Test-Path $JavaHomeCandidate) {
    $MavenWarningJava = $JavaHomeCandidate
  }
}

if ($Mode -contains "-h" -or $Mode -contains "--help") {
  Write-Host "Usage: ./build.ps1 [mode ...]"
  Write-Host ""
  Write-Host "Build one or more Javelle target modes."
  Write-Host "Examples:"
  Write-Host "  ./build.ps1"
  Write-Host "  ./build.ps1 spa"
  Write-Host "  ./build.ps1 ssr pwa"
  Write-Host "  ./build.ps1 android ios desktop"
  Write-Host "  ./build.ps1 all"
  Write-Host ""
  Write-Host "Notes:"
  Write-Host "  spa is an alias for web."
  Write-Host "  non-web modes are added automatically before build."
  exit 0
}

if (-not $env:JAVELLE_DISABLE_MAVEN_WARNING_FLAGS) {
  $SupportsMavenWarningOption = $false
  try {
    & $MavenWarningJava $MavenWarningOption -version *> $null
    $SupportsMavenWarningOption = ($LASTEXITCODE -eq 0)
  } catch {
    $SupportsMavenWarningOption = $false
  }

  if ($SupportsMavenWarningOption -and (($env:MAVEN_OPTS -split " ") -notcontains $MavenWarningOption)) {
    $env:MAVEN_OPTS = (($env:MAVEN_OPTS, $MavenWarningOption) | Where-Object { $_ }) -join " "
  }
}

if ($Mode.Count -eq 0) {
  $Mode = @($(if ($env:JAVELLE_MODE) { $env:JAVELLE_MODE } else { "web" }))
}

foreach ($Name in $Mode) {
  if ($Name -eq "spa") {
    $Name = "web"
  }
  if ($Name -eq "all") {
    if (Test-Path "./add.ps1") {
      & ./add.ps1 all
    }
    Write-Host "Building Javelle app in all enabled modes..."
    & $Javelle build --mode all
    continue
  }
  if ($Name -ne "web" -and (Test-Path "./add.ps1")) {
    & ./add.ps1 $Name
  }
  Write-Host "Building Javelle app in $Name mode..."
  & $Javelle build --mode $Name
}
