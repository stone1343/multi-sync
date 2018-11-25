@echo off
setlocal

if "%1"=="" (
  echo %~n0 dest
  goto :eof
)
if not exist %1\ (
  mkdir %1
)
xcopy /s /y windows\* %1
xcopy /y argparse.lua %1
if not exist %1\pl\ (
  mkdir %1\pl
)
xcopy /s /y pl\* %1\pl
xcopy /y multi-sync.lua %1
