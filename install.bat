@echo off
setlocal

if "%1"=="" (
  echo %~n0 dest
  goto :eof
)
if not exist %1\ (
  mkdir %1
)
xcopy /s /y windows\*.* %1
xcopy /y multi-sync.lua %1
