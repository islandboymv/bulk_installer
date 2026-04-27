@echo on
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
    echo   winget: NOT available - Chrome/AnyDesk/Acrobat will be skipped
    echo   Install "App Installer" from the Microsoft Store to enable winget.
)
echo ============================================================
echo.

:: -----------------------------------------
::  1. Google Chrome (winget)
:: -----------------------------------------
echo [1/4] Installing Google Chrome via winget...
echo [1/4] Google Chrome - winget install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    winget install -e --id Google.Chrome --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        echo [OK] Chrome done.
        echo [OK] Chrome installed >> "%LOG_FILE%"
    ) else (
        echo [WARN] winget exited with code !errorLevel! ^(may already be installed^).
        echo [WARN] winget Chrome exit code !errorLevel! >> "%LOG_FILE%"
    )
) else (
    echo [SKIP] winget not available. Download from https://www.google.com/chrome/
    echo [SKIP] Chrome - winget unavailable >> "%LOG_FILE%"
)
echo.

:: -----------------------------------------
::  2. IdeaShare (direct download - not in winget)
:: -----------------------------------------
echo [2/4] Downloading IdeaShare...
echo [2/4] IdeaShare - Download started >> "%LOG_FILE%"

powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $url='https://www.ideashare.us/download/IdeaShareSetup.exe'; $out='%TEMP_DIR%\IdeaShareSetup.exe'; $wc=New-Object System.Net.WebClient; Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {Write-Host ('  ' + $EventArgs.ProgressPercentage + '%% - ' + [math]::Round($EventArgs.BytesReceived/1KB) + ' KB')} | Out-Null; Register-ObjectEvent -InputObject $wc -EventName DownloadFileCompleted -Action {Write-Host 'Download complete.'} | Out-Null; $wc.DownloadFileAsync([uri]$url,$out); while($wc.IsBusy){Start-Sleep -Milliseconds 200}"

if exist "%TEMP_DIR%\IdeaShareSetup.exe" (
    echo Installing IdeaShare...
    start /wait "" "%TEMP_DIR%\IdeaShareSetup.exe" /S
    if !errorLevel! equ 0 (
        echo [OK] IdeaShare done.
        echo [OK] IdeaShare installed >> "%LOG_FILE%"
    ) else (
        echo [WARN] IdeaShare installer exited with code !errorLevel!.
        echo [WARN] IdeaShare installer exit code !errorLevel! >> "%LOG_FILE%"
    )
) else (
    echo [FAIL] IdeaShare download failed. Visit https://www.ideashare.us
    echo [FAIL] IdeaShare download failed >> "%LOG_FILE%"
)
echo.

:: -----------------------------------------
::  3. AnyDesk (winget)
:: -----------------------------------------
echo [3/4] Installing AnyDesk via winget...
echo [3/4] AnyDesk - winget install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    winget install -e --id AnyDeskSoftwareGmbH.AnyDesk --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        echo [OK] AnyDesk done.
        echo [OK] AnyDesk installed >> "%LOG_FILE%"
    ) else (
        echo [WARN] winget exited with code !errorLevel! ^(may already be installed^).
        echo [WARN] winget AnyDesk exit code !errorLevel! >> "%LOG_FILE%"
    )
) else (
    echo [SKIP] winget not available. Download from https://anydesk.com
    echo [SKIP] AnyDesk - winget unavailable >> "%LOG_FILE%"
)
echo.

:: -----------------------------------------
::  4. Adobe Acrobat Reader (winget)
:: -----------------------------------------
echo [4/4] Installing Adobe Acrobat Reader via winget...
echo [4/4] Adobe Acrobat Reader - winget install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    winget install -e --id Adobe.Acrobat.Reader.64-bit --silent --accept-package-agreements --accept-source-agreements
    if !errorLevel! equ 0 (
        echo [OK] Adobe Acrobat Reader done.
        echo [OK] Adobe Acrobat Reader installed >> "%LOG_FILE%"
    ) else (
        echo [WARN] winget exited with code !errorLevel! ^(may already be installed^).
        echo [WARN] winget Acrobat exit code !errorLevel! >> "%LOG_FILE%"
    )
) else (
    echo [SKIP] winget not available. Download from https://get.adobe.com/reader
    echo [SKIP] Acrobat - winget unavailable >> "%LOG_FILE%"
)
echo.

:: -----------------------------------------
::  Cleanup
:: -----------------------------------------
echo Cleaning up temp files...
rmdir /s /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================================
echo   All done! Log saved to: %LOG_FILE%
echo ============================================================
echo.
pause
endlocal
