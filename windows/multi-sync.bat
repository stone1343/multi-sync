@echo off
setlocal
echo %CMDCMDLINE% | findstr /i /c:"%~nx0" && set standalone=1
pushd %~dp0

set CONFIGDIR=%LOCALAPPDATA%
set LUA_PATH=./?.lua
set LUA_CPATH=./?.dll
if not exist %CONFIGDIR%\multi-sync.sqlite3 (
  copy multi-sync.sqlite3 %CONFIGDIR%
)
if not exist %CONFIGDIR%\multi-sync-config.lua (
  copy multi-sync-config.lua %CONFIGDIR%
)
lua multi-sync.lua %*

popd
if defined standalone pause
endlocal
