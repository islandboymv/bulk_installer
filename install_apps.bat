@echo off
setlocal EnableDelayedExpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Please run this script as Administrator.
    echo Right-click the .bat file and select "Run as administrator".
    pause
    exit /b 1
)

set "TEMP_DIR=%TEMP%\AppInstallers"
set "LOG_FILE=%USERPROFILE%\Desktop\install_log.txt"

if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
type nul > "%LOG_FILE%"

:: Detect winget once up-front
set "HAS_WINGET=0"
where winget >nul 2>&1
if %errorLevel% equ 0 set "HAS_WINGET=1"

echo ============================================================
echo   Bulk App Installer
echo   Chrome, IdeaShare, AnyDesk, Adobe Acrobat Reader
echo   Log: %LOG_FILE%
if "%HAS_WINGET%"=="1" (
    echo   winget: available
) else (
    echo   winget: NOT available - falling back to direct downloads.
)
echo ============================================================
echo.

:: -----------------------------------------
::  1. Google Chrome
:: -----------------------------------------
echo [1/4] Installing Google Chrome...
echo [1/4] Google Chrome - install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    call :WingetInstall "Google.Chrome" "Chrome"
) else (
    call :DirectDownload "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe" "chrome_installer.exe" "/silent /install" "Chrome"
)
echo.

:: -----------------------------------------
::  2. IdeaShare (direct download - not in winget)
:: -----------------------------------------
echo [2/4] Installing IdeaShare...
echo [2/4] IdeaShare - install started >> "%LOG_FILE%"

:: Silent /S requires 64-bit Windows 10 2004 (build 19041) or later per Huawei's docs.
:: On older or 32-bit Windows the installer ignores /S and pops a UI, hanging the script.
set "_OS_BUILD=0"
for /f "tokens=6 delims=[]. " %%i in ('ver') do set "_OS_BUILD=%%i"
set "_IDS_OK=0"
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" if !_OS_BUILD! geq 19041 set "_IDS_OK=1"

if "!_IDS_OK!"=="1" (
    call :DirectDownload "https://res-static.hc-cdn.cn/cloudbu-site/china/zh-cn/prudout/ec/share/V7.06.1.71/IdeaShare_Setup.exe" "IdeaShare_Setup.exe" "/S" "IdeaShare" "https://www.ideashare.us/download/IdeaShareSetup.exe"
) else (
    echo [SKIP] IdeaShare silent install needs 64-bit Windows 10 2004+. Skipping.
    echo [SKIP] IdeaShare needs Win10 2004+ x64 - skipped >> "%LOG_FILE%"
)
echo.

:: -----------------------------------------
::  3. AnyDesk
:: -----------------------------------------
echo [3/4] Installing AnyDesk...
echo [3/4] AnyDesk - install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    call :WingetInstall "AnyDesk.AnyDesk" "AnyDesk"
) else (
    call :DirectDownload "https://download.anydesk.com/AnyDesk.exe" "AnyDesk.exe" "--install ""C:\Program Files (x86)\AnyDesk"" --start-with-win --create-shortcuts --create-desktop-icon --silent" "AnyDesk"
)
echo.

:: -----------------------------------------
::  4. Adobe Acrobat Reader
:: -----------------------------------------
echo [4/4] Installing Adobe Acrobat Reader...
echo [4/4] Adobe Acrobat Reader - install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    call :WingetInstall "Adobe.Acrobat.Reader.64-bit" "Adobe Acrobat Reader"
) else (
    :: Adobe rotates this URL roughly quarterly. If it 404s, find the latest version at
    :: https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/Adobe/Acrobat/Reader/64-bit
    :: pick the highest version folder, open the installer.yaml, and copy the InstallerUrl + Silent switches.
    call :DirectDownload "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600121483/AcroRdrDCx642600121483_MUI.exe" "AcrobatReader.exe" "-sfx_nu /sAll /rs /msi" "Adobe Acrobat Reader"
)
echo.

:: -----------------------------------------
::  Cleanup
:: -----------------------------------------
echo Cleaning up temp files...
rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================================
echo   All done^^! Log saved to: %LOG_FILE%
echo ============================================================
echo.
pause
endlocal
exit /b 0


:: =============================================
::   Subroutines
:: =============================================

:: WingetInstall PackageId AppName
:: Wraps `winget install`. If winget returns an unrecognized exit code (typically a stale
:: source index — observed code 9020 in the wild), runs `source reset --force` and
:: `source update` once per script run, then retries the install.
:WingetInstall
set "_APP=%~2"

call :_WingetTry "%~1"
set "_WEC=!errorLevel!"
if "!_WEC!"=="0" goto :_WI_Done
if "!_WEC!"=="-1978335135" goto :_WI_Done
if "!_WEC!"=="-1978335189" goto :_WI_Done

if "!WINGET_RESET_DONE!"=="1" goto :_WI_Done
echo [INFO] !_APP! winget exit !_WEC! is unrecognized - resetting winget source and retrying...
echo [INFO] !_APP! winget exit !_WEC! - source reset and retry >> "%LOG_FILE%"
winget source reset --force
winget source update
set "WINGET_RESET_DONE=1"
call :_WingetTry "%~1"
set "_WEC=!errorLevel!"

:_WI_Done
if "!_WEC!"=="0" (
    echo [OK] !_APP! done.
    echo [OK] !_APP! installed >> "%LOG_FILE%"
) else if "!_WEC!"=="-1978335135" (
    echo [OK] !_APP! already installed.
    echo [OK] !_APP! already installed >> "%LOG_FILE%"
) else if "!_WEC!"=="-1978335189" (
    echo [OK] !_APP! already up to date.
    echo [OK] !_APP! already up to date >> "%LOG_FILE%"
) else (
    echo [WARN] winget !_APP! exited with code !_WEC!.
    echo [WARN] winget !_APP! exit code !_WEC! >> "%LOG_FILE%"
)
exit /b 0


:: _WingetTry PackageId
:_WingetTry
winget install -e --id %~1 --silent --accept-package-agreements --accept-source-agreements
exit /b !errorLevel!


:: DirectDownload URL OutFile InstallerArgs AppName [FallbackURL]
:DirectDownload
set "_URL=%~1"
set "_OUT=%TEMP_DIR%\%~2"
set "_ARGS=%~3"
set "_APP=%~4"
set "_URL2=%~5"

call :_TryDownload "!_URL!" "!_OUT!" "!_APP!" && goto :_DD_Install
if not "!_URL2!"=="" (
    echo Retrying !_APP! from fallback URL...
    echo [INFO] !_APP! retrying from fallback >> "%LOG_FILE%"
    call :_TryDownload "!_URL2!" "!_OUT!" "!_APP!" && goto :_DD_Install
)
echo [FAIL] !_APP! download failed.
echo [FAIL] !_APP! download failed >> "%LOG_FILE%"
exit /b 1

:_DD_Install
echo Installing !_APP!...
start /wait "" "!_OUT!" !_ARGS!
set "_IEC=!errorLevel!"
if "!_IEC!"=="0" (
    echo [OK] !_APP! done.
    echo [OK] !_APP! installed >> "%LOG_FILE%"
) else (
    echo [WARN] !_APP! installer exited with code !_IEC!.
    echo [WARN] !_APP! installer exit code !_IEC! >> "%LOG_FILE%"
)
exit /b 0


:: _TryDownload URL OutFile AppName  -> exit 0 on success, 1 on any failure
:_TryDownload
set "_TU=%~1"
set "_TO=%~2"
set "_TA=%~3"
echo Downloading !_TA!...
curl.exe -L --progress-bar --connect-timeout 30 --max-time 600 --speed-limit 1 --speed-time 60 -o "!_TO!" "!_TU!"
set "_DLEC=!errorLevel!"
if !_DLEC! neq 0 (
    if !_DLEC! equ 28 (
        echo [WARN] !_TA! download timed out.
    ) else (
        echo [WARN] !_TA! download failed ^(curl exit code !_DLEC!^).
    )
    exit /b 1
)
if not exist "!_TO!" (
    echo [WARN] !_TA! download missing.
    exit /b 1
)
:: Verify the download is a valid Windows PE executable (starts with MZ).
:: Catches the common case of an HTML error page being saved with a .exe name.
powershell -NoProfile -Command "try{$b=[IO.File]::ReadAllBytes('!_TO!'); if($b.Length -lt 2 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A){exit 1}else{exit 0}}catch{exit 1}"
if !errorLevel! neq 0 (
    echo [WARN] !_TA! download is not a valid Windows executable.
    exit /b 1
)
exit /b 0
