@echo off
setlocal
cd /d "%~dp0"

set "JAVELLE=%JAVELLE_CLI%"
if "%JAVELLE%"=="" set "JAVELLE=javelle"
set "MAVEN_WARNING_OPTION=--sun-misc-unsafe-memory-access=allow"
set "MAVEN_WARNING_JAVA=java"
if not "%JAVA_HOME%"=="" if exist "%JAVA_HOME%\bin\java.exe" set "MAVEN_WARNING_JAVA=%JAVA_HOME%\bin\java.exe"

if "%~1"=="-h" goto help
if "%~1"=="--help" goto help

if "%JAVELLE_DISABLE_MAVEN_WARNING_FLAGS%"=="" (
  "%MAVEN_WARNING_JAVA%" %MAVEN_WARNING_OPTION% -version >nul 2>nul
  if not errorlevel 1 (
    echo %MAVEN_OPTS% | findstr /C:"%MAVEN_WARNING_OPTION%" >nul
    if errorlevel 1 set "MAVEN_OPTS=%MAVEN_OPTS% %MAVEN_WARNING_OPTION%"
  )
)

if "%~1"=="" (
  set "MODE=%JAVELLE_MODE%"
  if "%MODE%"=="" set "MODE=web"
  call :buildMode "%MODE%"
  exit /b %errorlevel%
)

:modeLoop
if "%~1"=="" exit /b 0
call :buildMode "%~1"
if errorlevel 1 exit /b %errorlevel%
shift
goto modeLoop

:buildMode
set "MODE=%~1"
if "%MODE%"=="spa" set "MODE=web"
if "%MODE%"=="all" (
  if exist add.bat call add.bat all
  if errorlevel 1 exit /b %errorlevel%
  echo Building Javelle app in all enabled modes...
  "%JAVELLE%" build --mode all
  exit /b %errorlevel%
)
if not "%MODE%"=="web" if exist add.bat call add.bat "%MODE%"
if errorlevel 1 exit /b %errorlevel%
echo Building Javelle app in %MODE% mode...
"%JAVELLE%" build --mode "%MODE%"
exit /b %errorlevel%

:help
echo Usage: build.bat [mode ...]
echo.
echo Build one or more Javelle target modes.
echo Examples:
echo   build.bat
echo   build.bat spa
echo   build.bat ssr pwa
echo   build.bat android ios desktop
echo   build.bat all
echo.
echo Notes:
echo   spa is an alias for web.
echo   non-web modes are added automatically before build.
exit /b 0
