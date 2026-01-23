@echo off

echo Disabling GPU...
pnputil /disable-device "PCI\VEN_1002&DEV_1638&SUBSYS_D0001458&REV_C8\4&3B1E1872&0&000D" 
pnputil /disable-device "HDAUDIO\FUNC_01&VEN_1002&DEV_AA01&SUBSYS_00AA0100&REV_1007\5&26B3C50D&0&0001"

echo GPU disabled.

timeout /t 5 /nobreak >nul

echo Enabling GPU...
pnputil /enable-device "PCI\VEN_1002&DEV_1638&SUBSYS_D0001458&REV_C8\4&3B1E1872&0&000D" 
pnputil /enable-device "HDAUDIO\FUNC_01&VEN_1002&DEV_AA01&SUBSYS_00AA0100&REV_1007\5&26B3C50D&0&0001"
echo GPU enabled.
echo GPU totally reset.
pause
