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
    winget install -e --id Google.Chrome --silent --accept-package-agreements --accept-source-agreements
    call :ReportWinget "Chrome" !errorLevel!
) else (
    call :DirectDownload "https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe" "chrome_installer.exe" "/silent /install" "Chrome"
)
echo.

:: -----------------------------------------
::  2. IdeaShare (direct download - not in winget)
:: -----------------------------------------
echo [2/4] Installing IdeaShare...
echo [2/4] IdeaShare - install started >> "%LOG_FILE%"

call :DirectDownload "https://www.ideashare.us/download/IdeaShareSetup.exe" "IdeaShareSetup.exe" "/S" "IdeaShare"
echo.

:: -----------------------------------------
::  3. AnyDesk
:: -----------------------------------------
echo [3/4] Installing AnyDesk...
echo [3/4] AnyDesk - install started >> "%LOG_FILE%"

if "%HAS_WINGET%"=="1" (
    winget install -e --id AnyDeskSoftwareGmbH.AnyDesk --silent --accept-package-agreements --accept-source-agreements
    call :ReportWinget "AnyDesk" !errorLevel!
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
    winget install -e --id Adobe.Acrobat.Reader.64-bit --silent --accept-package-agreements --accept-source-agreements
    call :ReportWinget "Adobe Acrobat Reader" !errorLevel!
) else (
    :: Adobe rotates this URL roughly quarterly. If it 404s, find the latest at
    :: https://www.adobe.com/devnet-docs/acrobatetk/tools/ReleaseNotesDC/index.html
    :: and update the version segments below (both occurrences).
    call :DirectDownload "https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2400520320/AcroRdrDC2400520320_en_US.exe" "AcrobatReader.exe" "/sAll /rs /msi EULA_ACCEPT=YES" "Adobe Acrobat Reader"
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

:: ReportWinget AppName ExitCode
:ReportWinget
set "_APP=%~1"
set "_EC=%~2"
if "!_EC!"=="0" (
    echo [OK] !_APP! done.
    echo [OK] !_APP! installed >> "%LOG_FILE%"
) else if "!_EC!"=="-1978335135" (
    echo [OK] !_APP! already installed.
    echo [OK] !_APP! already installed >> "%LOG_FILE%"
) else if "!_EC!"=="-1978335189" (
    echo [OK] !_APP! already up to date.
    echo [OK] !_APP! already up to date >> "%LOG_FILE%"
) else (
    echo [WARN] winget !_APP! exited with code !_EC!.
    echo [WARN] winget !_APP! exit code !_EC! >> "%LOG_FILE%"
)
exit /b 0


:: DirectDownload URL OutFile InstallerArgs AppName
:DirectDownload
set "_URL=%~1"
set "_OUT=%TEMP_DIR%\%~2"
set "_ARGS=%~3"
set "_APP=%~4"

echo Downloading !_APP!...
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; try{(New-Object System.Net.WebClient).DownloadFile('!_URL!','!_OUT!'); exit 0}catch{Write-Host ('  ERROR: ' + $_.Exception.Message); exit 1}"
if !errorLevel! neq 0 (
    echo [FAIL] !_APP! download failed.
    echo [FAIL] !_APP! download failed >> "%LOG_FILE%"
    exit /b 1
)

if not exist "!_OUT!" (
    echo [FAIL] !_APP! download failed ^(file missing^).
    echo [FAIL] !_APP! download missing >> "%LOG_FILE%"
    exit /b 1
)

:: Verify the download is a valid Windows PE executable (starts with MZ).
:: Catches the common case of an HTML error page being saved with a .exe name.
powershell -NoProfile -Command "try{$b=[IO.File]::ReadAllBytes('!_OUT!'); if($b.Length -lt 2 -or $b[0] -ne 0x4D -or $b[1] -ne 0x5A){exit 1}else{exit 0}}catch{exit 1}"
if !errorLevel! neq 0 (
    echo [FAIL] !_APP! download is not a valid Windows executable.
    echo         The URL may have returned an HTML error page. Check the URL or your network.
    echo [FAIL] !_APP! download not a valid PE >> "%LOG_FILE%"
    exit /b 1
)

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
