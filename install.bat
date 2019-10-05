@echo off
rem install.bat v2.5 2019-10-05

setlocal

if "%1"=="" (
  goto :help
)
if not exist "%1" (
  goto :help
)
if not exist "%~1\multi-sync.bat" (
  xcopy /s /y windows\* "%1"
) else (
  copy /y windows\multi-sync.bat "%~1"
  copy /y windows\multi-sync.sqlite3 "%~1"
  copy /y windows\multi-sync-config.lua "%~1"
)
copy /y multi-sync.lua "%~1"
goto :eof

:help
echo %~n0 dest
echo  dest must exist
