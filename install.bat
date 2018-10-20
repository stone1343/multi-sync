@echo off
setlocal

if "%1"=="" (
  echo %~n0 dest
  goto :eof
)
if not exist %1\ (
  mkdir %1
)
rem Copy executables and multi-sync-config.lua
xcopy /s /d /y windows\*.* %1
