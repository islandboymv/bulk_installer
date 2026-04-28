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

call :DirectDownload "https://res-static.hc-cdn.cn/cloudbu-site/china/zh-cn/prudout/ec/share/V7.06.1.71/IdeaShare_Setup.exe" "IdeaShare_Setup.exe" "/S" "IdeaShare" "https://www.ideashare.us/download/IdeaShareSetup.exe"
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
if "!ANY_FAIL!"=="1" (
    echo NOTE: One or more installs failed. Files kept in %TEMP_DIR% for manual retry.
    echo NOTE: temp dir kept at %TEMP_DIR% for manual retry >> "%LOG_FILE%"
) else (
    echo Cleaning up temp files...
    rmdir /s /q "%TEMP_DIR%" >nul 2>&1
)

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

rem WingetInstall PackageId AppName
rem Retries once with `source reset --force` if winget returns an unrecognized exit code
rem (e.g. stale-source code 9020).
:WingetInstall
set "_APP=%~2"

call :WingetTryOnce "%~1"
set "_WEC=!errorLevel!"
if "!_WEC!"=="0" goto WIDone
if "!_WEC!"=="-1978335135" goto WIDone
if "!_WEC!"=="-1978335189" goto WIDone

if "!WINGET_RESET_DONE!"=="1" goto WIDone
echo [INFO] !_APP! winget exit !_WEC! is unrecognized - resetting winget source and retrying...
echo [INFO] !_APP! winget exit !_WEC! - source reset and retry >> "%LOG_FILE%"
winget source reset --force
winget source update
set "WINGET_RESET_DONE=1"
call :WingetTryOnce "%~1"
set "_WEC=!errorLevel!"

:WIDone
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


rem WingetTryOnce PackageId
:WingetTryOnce
winget install -e --id %~1 --silent --accept-package-agreements --accept-source-agreements
exit /b !errorLevel!


rem DirectDownload URL OutFile InstallerArgs AppName [FallbackURL]
:DirectDownload
set "_URL=%~1"
set "_OUT=%TEMP_DIR%\%~2"
set "_ARGS=%~3"
set "_APP=%~4"
set "_URL2=%~5"

call :TryDownload "!_URL!" "!_OUT!" "!_APP!" && goto DDInstall
if not "!_URL2!"=="" (
    echo Retrying !_APP! from fallback URL...
    echo [INFO] !_APP! retrying from fallback >> "%LOG_FILE%"
    call :TryDownload "!_URL2!" "!_OUT!" "!_APP!" && goto DDInstall
)
echo [FAIL] !_APP! download failed.
echo [FAIL] !_APP! download failed >> "%LOG_FILE%"
exit /b 1

:DDInstall
echo Installing !_APP!...
start /wait "" "!_OUT!" !_ARGS!
set "_IEC=!errorLevel!"
if "!_IEC!"=="0" (
    echo [OK] !_APP! done.
    echo [OK] !_APP! installed >> "%LOG_FILE%"
) else (
    echo [WARN] !_APP! installer exited with code !_IEC!.
    echo         To retry manually, run: "!_OUT!"
    echo [WARN] !_APP! installer exit code !_IEC! - kept at !_OUT! >> "%LOG_FILE%"
    set "ANY_FAIL=1"
)
exit /b 0


rem TryDownload URL OutFile AppName  -- exit 0 on success, 1 on any failure
:TryDownload
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
rem Verify download starts with PE 'MZ' header to catch HTML error pages.
powershell -NoProfile -Command "try{$b=[IO.File]::ReadAllBytes('!_TO!'); if($b.Length -lt 2 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A){exit 1}else{exit 0}}catch{exit 1}"
if !errorLevel! neq 0 (
    echo [WARN] !_TA! download is not a valid Windows executable.
    exit /b 1
)
rem Log size + PE machine type so we can spot truncated downloads or arch mismatches.
for %%S in ("!_TO!") do (
    echo [INFO] !_TA! downloaded ^(%%~zS bytes^).
    echo [INFO] !_TA! downloaded %%~zS bytes >> "%LOG_FILE%"
)
for /f "delims=" %%A in ('powershell -NoProfile -Command "try{$b=[IO.File]::ReadAllBytes('!_TO!'); $o=[BitConverter]::ToInt32($b,0x3C); $m=[BitConverter]::ToUInt16($b,$o+4); switch($m){0x8664{'x64'}0x14c{'x86'}0xAA64{'arm64'}default{'unknown(0x{0:X})' -f $m}}}catch{'unknown'}" 2^>nul') do (
    echo [INFO] !_TA! arch=%%A, OS arch=%PROCESSOR_ARCHITECTURE%
    echo [INFO] !_TA! arch=%%A, OS arch=%PROCESSOR_ARCHITECTURE% >> "%LOG_FILE%"
)
exit /b 0
