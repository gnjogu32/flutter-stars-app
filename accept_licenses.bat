@echo off
setlocal enabledelayedexpansion

REM Create a file with y's to pipe to sdkmanager
(
echo y
echo y
echo y
echo y
echo y
echo y
echo y
) > temp_responses.txt

REM Accept licenses
"%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --licenses < temp_responses.txt

REM Cleanup
del temp_responses.txt

REM Verify
flutter doctor

pause
