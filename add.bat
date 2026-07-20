@echo off
setlocal
cd /d "%~dp0"

set "JAVELLE=%JAVELLE_CLI%"
if "%JAVELLE%"=="" set "JAVELLE=javelle"

if "%~1"=="-h" goto help
if "%~1"=="--help" goto help

if "%~1"=="" (
  call :addMode all
  if errorlevel 1 exit /b %errorlevel%
  goto listModes
)

:modeLoop
if "%~1"=="" goto listModes
if "%~1"=="-h" goto help
if "%~1"=="--help" goto help
call :addMode "%~1"
if errorlevel 1 exit /b %errorlevel%
shift
goto modeLoop

:addMode
echo Adding Javelle mode: %~1
"%JAVELLE%" mode add "%~1"
exit /b %errorlevel%

:listModes
echo Enabled modes:
"%JAVELLE%" mode list
exit /b %errorlevel%

:help
echo Usage: add.bat [mode ...]
echo.
echo Enable Javelle target modes for this app.
echo Examples:
echo   add.bat mobile
echo   add.bat ssr pwa
echo   add.bat all
echo.
echo When no mode is passed, this script enables all built-in modes.
exit /b 0
