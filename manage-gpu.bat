@echo off
setlocal enabledelayedexpansion

rem THIS IS A GPU RESET SCRIPT
rem can enable and disable a gpu and the coresponding hdmi device
rem you just need to set the GPU_ID and AUDIO_ID variables
rem === Parameter Check ===
if /i "%~1"=="/enable" (
    set "ACTION=enable"
    set "ACTION_VERB=Enabling"
    set "PNP_CMD=enable-device"
) else if /i "%~1"=="/disable" (
    set "ACTION=disable"
    set "ACTION_VERB=Disabling"
    set "PNP_CMD=disable-device"
) else if /i "%~1"=="/reset" (
    echo Resetting devices...
    echo.
    echo Disabling devices...
    call "%~f0" /disable
    echo.
    echo Waiting for 5 seconds...
    timeout /t 5 /nobreak >nul
    echo.
    echo Enabling devices...
    call "%~f0" /enable
    echo.
    echo Reset complete.
    goto :EOF
) else (
    echo Invalid or missing parameter.
    echo.
    echo Usage: %~n0 [/enable ^| /disable ^| /reset]
    goto :EOF
)

rem === Config ===
set "LOG=C:\gpu_%ACTION%_log.txt"
set "GPU_ID=PCI\VEN_1002&DEV_1638&SUBSYS_D0001458&REV_C8"
set "AUDIO_ID=HDAUDIO\FUNC_01&VEN_1002&DEV_AA01&SUBSYS_00AA0100&REV_1007"
set "TIMEOUT_SEC=3"

rem === Start log ===
> "%LOG%" echo ===== GPU %ACTION% script started =====
echo Date: %DATE% >> "%LOG%"
echo Time: %TIME% >> "%LOG%"
echo Running as: %USERNAME% >> "%LOG%"
whoami >> "%LOG%" 2>&1
echo. >> "%LOG%"

rem === Sanity checks ===
echo Checking pnputil presence... >> "%LOG%"
where pnputil >> "%LOG%" 2>&1
if errorlevel 1 (
  echo ERROR: pnputil not found. Aborting. >> "%LOG%"
  goto :END
)

rem CORRECTED: Use !delayed! expansion to safely echo variables with special characters
echo GPU_ID: !GPU_ID! >> "%LOG%"
echo AUDIO_ID: !AUDIO_ID! >> "%LOG%"
echo Parameter: %1 >> "%LOG%"
echo Action: %ACTION% >> "%LOG%"
echo. >> "%LOG%"

rem === Main Action ===
echo [1/2] %ACTION_VERB% GPU... >> "%LOG%"
echo Executing: pnputil /%PNP_CMD% /deviceid "%GPU_ID%" >> "%LOG%"
pnputil /%PNP_CMD% /deviceid "%GPU_ID%" >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo pnputil exit code: !RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo WARN: GPU %ACTION% returned non-zero. Continuing... >> "%LOG%"
)

rem Settle a bit
echo Sleeping %TIMEOUT_SEC%s... >> "%LOG%"
timeout /t %TIMEOUT_SEC% /nobreak >nul

echo [2/2] %ACTION_VERB% HDMI Audio... >> "%LOG%"
echo Executing: pnputil /%PNP_CMD% /deviceid "%AUDIO_ID%" >> "%LOG%"
pnputil /%PNP_CMD% /deviceid "%AUDIO_ID%" >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo pnputil exit code: !RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo WARN: AUDIO %ACTION% returned non-zero. Continuing... >> "%LOG%"
)

rem Final settle
echo Sleeping %TIMEOUT_SEC%s... >> "%LOG%"
timeout /t %TIMEOUT_SEC% /nobreak >nul

:END
echo ===== Script finished ===== >> "%LOG%"

:EOF
endlocal
exit /b 0
