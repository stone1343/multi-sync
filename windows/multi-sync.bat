@echo off
rem multi-sync.bat v2.5 2019-10-05

setlocal

rem From https://stackoverflow.com/questions/3551888/pausing-a-batch-file-when-double-clicked-but-not-when-run-from-a-console-window 2017-08-16 JMS (see below)
echo %CMDCMDLINE% | findstr /i /c:"%~nx0" && set standalone=1

pushd %~dp0

rem e.g. C:\Users\jeff\AppData\Local (no trailing backslash)
set CONFIGDIR=%LOCALAPPDATA%

set EDITOR=notepad
set LUA_PATH=./?.lua
set LUA_CPATH=./?.dll

if not exist %CONFIGDIR%\multi-sync.sqlite3 (
  copy multi-sync.sqlite3 %CONFIGDIR%
)
if not exist %CONFIGDIR%\multi-sync-config.lua (
  copy multi-sync-config.lua %CONFIGDIR%
)

lua multi-sync.lua %*
set rc=%errorlevel%

popd

rem From https://stackoverflow.com/questions/3551888/pausing-a-batch-file-when-double-clicked-but-not-when-run-from-a-console-window 2017-08-16 JMS (see above)
if defined standalone pause
exit /b %rc%
