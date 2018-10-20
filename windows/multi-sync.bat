@echo off
setlocal

rem From https://stackoverflow.com/questions/3551888/pausing-a-batch-file-when-double-clicked-but-not-when-run-from-a-console-window 2017-08-16 JMS (see below)
echo %CMDCMDLINE% | findstr /i /c:"%~nx0" && set standalone=1

pushd %~dp0
set MS_COMPUTERNAME=%COMPUTERNAME%
set MS_USERNAME=%USERNAME%
set MS_APPDATA=%LOCALAPPDATA%
set MS_EDITOR=notepad
lua %~n0.lua %*
set rc=%errorlevel%
popd

rem From https://stackoverflow.com/questions/3551888/pausing-a-batch-file-when-double-clicked-but-not-when-run-from-a-console-window 2017-08-16 JMS (see above)
if defined standalone pause
exit /b %rc%
