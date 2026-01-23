@echo off
setlocal enabledelayedexpansion

rem === Config ===
set "LOG=C:\shutdown_log.txt"
set "GPU_ID=PCI\VEN_1002&DEV_1638&SUBSYS_D0001458&REV_C8\4&3B1E1872&0&000D"
set "AUDIO_ID=HDAUDIO\FUNC_01&VEN_1002&DEV_AA01&SUBSYS_00AA0100&REV_1007\5&26B3C50D&0&0001"
set "TIMEOUT_SEC=3"

rem === Start log ===
> "%LOG%" echo ===== Shutdown GPU disable script started =====
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

echo GPU_ID: %GPU_ID% >> "%LOG%"
echo AUDIO_ID: %AUDIO_ID% >> "%LOG%"
echo. >> "%LOG%"

rem === Disable GPU ===
echo [1/2] Disabling GPU... >> "%LOG%"
pnputil /disable-device "%GPU_ID%" >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo pnputil exit code: !RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo WARN: GPU disable returned non-zero. Continuing... >> "%LOG%"
)

rem Settle a bit
echo Sleeping %TIMEOUT_SEC%s... >> "%LOG%"
timeout /t %TIMEOUT_SEC% /nobreak >nul

rem === Disable HDMI audio ===
echo [2/2] Disabling HDMI Audio... >> "%LOG%"
pnputil /disable-device "%AUDIO_ID%" >> "%LOG%" 2>&1
set "RC=!ERRORLEVEL!"
echo pnputil exit code: !RC! >> "%LOG%"
if not "!RC!"=="0" (
  echo WARN: AUDIO disable returned non-zero. Continuing... >> "%LOG%"
)

rem Final settle
echo Sleeping %TIMEOUT_SEC%s... >> "%LOG%"
timeout /t %TIMEOUT_SEC% /nobreak >nul

:END
echo ===== Script finished ===== >> "%LOG%"
endlocal
exit /b 0d
