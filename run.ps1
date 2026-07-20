param(
  [string]$Mode = $(if ($env:JAVELLE_MODE) { $env:JAVELLE_MODE } else { "web" }),
  [int]$Port = $(if ($env:JAVELLE_PORT) { [int]$env:JAVELLE_PORT } else { 8080 })
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
if ($Mode -eq "spa") {
  $Mode = "web"
}
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

if ($Mode -ne "web" -and (Test-Path "./add.ps1")) {
  & ./add.ps1 $Mode
}

Write-Host "Packaging Javelle app..."
mvn package

Write-Host "Starting Javelle dev server: mode=$Mode port=$Port"
& $Javelle dev --mode $Mode --port $Port
