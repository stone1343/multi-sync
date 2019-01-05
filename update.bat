@echo off
setlocal

if "%~1"=="" (
  goto :help
)
if not exist "%~1\multi-sync.bat" (
  goto :help
)
xcopy /y windows\multi-sync.bat "%~1"
xcopy /y windows\multi-sync-config.lua "%~1"
xcopy /y multi-sync.lua "%~1"
goto :eof

:help
echo %~n0 dest
echo multi-sync.bat must already exist in "%~1"
goto :eof
