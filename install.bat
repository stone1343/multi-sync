@echo off
rem install.bat v3.2 2021-01-03

setlocal

if "%1"=="" (
  goto :help
)
if not exist "%1" (
  goto :help
)
xcopy /s /y windows\* "%1"
xcopy /d /y multi-sync.lua "%1"
goto :eof

:help
echo %~n0 dest
echo  dest must exist
