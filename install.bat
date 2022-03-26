@echo off

if "%1"=="" (
  echo %~n0 dest
  goto :eof
)
if not exist "%1" (
  mkdir "%1"
)
xcopy /d /y /s windows\* "%1"
xcopy /d /y multi-sync.lua "%1"
