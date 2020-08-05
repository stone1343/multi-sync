@echo off
rem install.bat v3.0 2020-08-05

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
