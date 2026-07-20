@echo off
setlocal
cd /d "%~dp0"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=%JAVELLE_MODE%"
if "%MODE%"=="" set "MODE=web"
if "%MODE%"=="spa" set "MODE=web"

set "PORT=%~2"
if "%PORT%"=="" set "PORT=%JAVELLE_PORT%"
if "%PORT%"=="" set "PORT=8080"

set "JAVELLE=%JAVELLE_CLI%"
if "%JAVELLE%"=="" set "JAVELLE=javelle"
set "MAVEN_WARNING_OPTION=--sun-misc-unsafe-memory-access=allow"
set "MAVEN_WARNING_JAVA=java"
if not "%JAVA_HOME%"=="" if exist "%JAVA_HOME%\bin\java.exe" set "MAVEN_WARNING_JAVA=%JAVA_HOME%\bin\java.exe"

if "%JAVELLE_DISABLE_MAVEN_WARNING_FLAGS%"=="" (
  "%MAVEN_WARNING_JAVA%" %MAVEN_WARNING_OPTION% -version >nul 2>nul
  if not errorlevel 1 (
    echo %MAVEN_OPTS% | findstr /C:"%MAVEN_WARNING_OPTION%" >nul
    if errorlevel 1 set "MAVEN_OPTS=%MAVEN_OPTS% %MAVEN_WARNING_OPTION%"
  )
)

if not "%MODE%"=="web" if exist add.bat call add.bat "%MODE%"
if errorlevel 1 exit /b %errorlevel%

echo Packaging Javelle app...
call mvn package
if errorlevel 1 exit /b %errorlevel%

echo Starting Javelle dev server: mode=%MODE% port=%PORT%
"%JAVELLE%" dev --mode "%MODE%" --port "%PORT%"
