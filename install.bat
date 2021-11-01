@echo off

if "%1"=="" (
  goto :help
)
if not exist "%1" (
  goto :help
)
xcopy /d /y /s windows\* "%1"
xcopy /d /y multi-sync.lua "%1"
goto :eof

:help
echo %~n0 dest
echo  dest must exist
