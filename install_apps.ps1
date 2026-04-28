#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk installer for Chrome, IdeaShare, AnyDesk, and Adobe Acrobat Reader.
.DESCRIPTION
    Uses winget where available; falls back to direct download for IdeaShare
    (and others if winget is missing). Self-elevates to Administrator.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [Text.Encoding]::UTF8
    $OutputEncoding = [Text.Encoding]::UTF8
} catch {}

# ----- Admin check + auto-elevate -----------------------------------------
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($PSCommandPath) {
        Write-Host '> Requesting administrator privileges...' -ForegroundColor Yellow
        $relaunch = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $PSCommandPath + '"'))
        Start-Process -FilePath 'powershell.exe' -ArgumentList $relaunch -Verb RunAs
        exit
    }
    Write-Host ''
    Write-Host '  [ERROR] This script must run as Administrator.' -ForegroundColor Red
    Write-Host '          Open PowerShell as administrator and re-run.' -ForegroundColor Yellow
    Write-Host ''
    [void](Read-Host 'Press Enter to exit')
    exit 1
}

# ----- State --------------------------------------------------------------
$script:tempDir = Join-Path $env:TEMP 'AppInstallers'
$script:logFile = Join-Path $env:USERPROFILE 'Desktop\install_log.txt'
$null = New-Item -ItemType Directory -Force -Path $script:tempDir
Set-Content -Path $script:logFile -Value '' -Encoding UTF8

$script:hasWinget       = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$script:wingetResetDone = $false
$script:anyFail         = $false
$script:results         = [System.Collections.Generic.List[object]]::new()

try { $Host.UI.RawUI.WindowTitle = 'Bulk App Installer' } catch {}

# ----- Output helpers -----------------------------------------------------
function Write-Log { param([string]$Line) Add-Content -Path $script:logFile -Value $Line -Encoding UTF8 }

function Write-Banner {
    param([string]$Title, [string[]]$SubLines = @())
    $w = 66
    $h = ([string][char]0x2550) * $w
    Write-Host ''
    Write-Host (([char]0x2554) + $h + ([char]0x2557)) -ForegroundColor Cyan

    $row = {
        param([string]$Text, [string]$Color)
        $t = if ($Text.Length -gt ($w - 2)) { $Text.Substring(0, $w - 2) } else { $Text }
        Write-Host ([char]0x2551) -NoNewline -ForegroundColor Cyan
        Write-Host (' ' + $t.PadRight($w - 1)) -NoNewline -ForegroundColor $Color
        Write-Host ([char]0x2551) -ForegroundColor Cyan
    }
    & $row $Title 'White'
    foreach ($l in $SubLines) { & $row $l 'DarkGray' }
    Write-Host (([char]0x255A) + $h + ([char]0x255D)) -ForegroundColor Cyan
    Write-Host ''
}

function Write-Step {
    param([int]$Num, [int]$Total, [string]$Name)
    Write-Host ''
    Write-Host (' ' + [char]0x25B6 + ' ') -NoNewline -ForegroundColor Cyan
    Write-Host ('[{0}/{1}] ' -f $Num, $Total) -NoNewline -ForegroundColor DarkCyan
    Write-Host $Name -ForegroundColor White
    Write-Log ''
    Write-Log ('[{0}/{1}] {2} - install started' -f $Num, $Total, $Name)
}

function Write-Tag {
    param(
        [Parameter(Mandatory)][ValidateSet('OK','WARN','FAIL','INFO','SKIP')][string]$Tag,
        [Parameter(Mandatory)][string]$Message
    )
    $colors = @{ OK='Green'; WARN='Yellow'; FAIL='Red'; INFO='Cyan'; SKIP='DarkGray' }
    Write-Host '     ' -NoNewline
    Write-Host ('[' + $Tag.PadRight(4) + ']') -NoNewline -ForegroundColor $colors[$Tag]
    Write-Host (' ' + $Message)
    Write-Log ('  [{0}] {1}' -f $Tag, $Message)
}

function Add-Result {
    param([string]$App, [string]$Status, [bool]$IsFailure = $false)
    $script:results.Add([pscustomobject]@{ App = $App; Status = $Status })
    if ($IsFailure) { $script:anyFail = $true }
}

# ----- winget -------------------------------------------------------------
function Invoke-WingetTry {
    param([string]$PackageId)
    & winget install -e --id $PackageId --silent --accept-package-agreements --accept-source-agreements 2>&1 |
        ForEach-Object { Write-Host ('       ' + $_) -ForegroundColor DarkGray }
    return $LASTEXITCODE
}

function Install-WingetApp {
    param([string]$PackageId, [string]$AppName)

    $okCodes = @(0, -1978335135, -1978335189)
    $code = Invoke-WingetTry -PackageId $PackageId

    if ($code -notin $okCodes -and -not $script:wingetResetDone) {
        Write-Tag INFO "$AppName winget exit $code unrecognized - resetting source and retrying"
        & winget source reset --force *> $null
        & winget source update *> $null
        $script:wingetResetDone = $true
        $code = Invoke-WingetTry -PackageId $PackageId
    }

    switch ($code) {
        0           { Write-Tag OK   "$AppName installed.";              Add-Result $AppName 'Installed' }
        -1978335135 { Write-Tag OK   "$AppName already installed.";      Add-Result $AppName 'Already installed' }
        -1978335189 { Write-Tag OK   "$AppName already up to date.";     Add-Result $AppName 'Up to date' }
        default     { Write-Tag WARN "winget $AppName exited code $code."; Add-Result $AppName "winget exit $code" $true }
    }
}

# ----- Direct download ---------------------------------------------------
function Test-PEArch {
    param([string]$Path)
    try {
        $stream = [IO.File]::OpenRead($Path)
        try {
            $br = [IO.BinaryReader]::new($stream)
            if ($stream.Length -lt 64) { return $null }
            $sig = $br.ReadBytes(2)
            if ($sig[0] -ne 0x4D -or $sig[1] -ne 0x5A) { return $null }
            $stream.Position = 0x3C
            $peOffset = $br.ReadInt32()
            $stream.Position = $peOffset + 4
            $machine = $br.ReadUInt16()
            return $(switch ($machine) {
                0x8664  { 'x64' }
                0x14c   { 'x86' }
                0xAA64  { 'arm64' }
                default { 'unknown(0x{0:X})' -f $machine }
            })
        } finally { $stream.Dispose() }
    } catch { return $null }
}

function Get-Download {
    param([string]$Url, [string]$Path, [string]$AppName)
    Write-Tag INFO "Downloading $AppName..."
    $progBefore = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing -TimeoutSec 600
        return $true
    } catch {
        Write-Tag WARN "$AppName download failed: $($_.Exception.Message)"
        return $false
    } finally {
        $ProgressPreference = $progBefore
    }
}

function Install-Direct {
    param(
        [string[]]$Urls,
        [string]$FileName,
        [string[]]$InstallArgs,
        [string]$AppName
    )
    $outFile = Join-Path $script:tempDir $FileName
    $arch = $null

    foreach ($url in $Urls) {
        if (-not (Get-Download -Url $url -Path $outFile -AppName $AppName)) { continue }
        $arch = Test-PEArch -Path $outFile
        if (-not $arch) {
            Write-Tag WARN "$AppName download is not a valid Windows executable."
            continue
        }
        $sizeMb = [math]::Round((Get-Item $outFile).Length / 1MB, 2)
        Write-Tag INFO ("$AppName downloaded ({0} MB, arch={1}, OS={2})" -f $sizeMb, $arch, $env:PROCESSOR_ARCHITECTURE)
        break
    }

    if (-not $arch) {
        Write-Tag FAIL "$AppName all download attempts failed."
        Add-Result $AppName 'Download failed' $true
        return
    }

    Write-Tag INFO "Installing $AppName..."
    try {
        $proc = if ($InstallArgs -and $InstallArgs.Count -gt 0) {
            Start-Process -FilePath $outFile -ArgumentList $InstallArgs -Wait -PassThru
        } else {
            Start-Process -FilePath $outFile -Wait -PassThru
        }
        $code = $proc.ExitCode
    } catch {
        Write-Tag FAIL "$AppName failed to launch: $($_.Exception.Message)"
        Write-Tag INFO "Retry manually: $outFile"
        Add-Result $AppName 'Launch failed' $true
        return
    }

    if ($code -eq 0) {
        Write-Tag OK "$AppName installed."
        Add-Result $AppName 'Installed'
    } else {
        Write-Tag WARN "$AppName installer exited with code $code."
        Write-Tag INFO "Retry manually: $outFile"
        Add-Result $AppName "exit $code" $true
    }
}

# ----- Main flow ----------------------------------------------------------
Clear-Host

$wingetText = if ($script:hasWinget) { 'available' } else { 'NOT available - falling back to direct downloads' }
Write-Banner -Title 'Bulk App Installer' -SubLines @(
    'Chrome  |  IdeaShare  |  AnyDesk  |  Adobe Acrobat Reader',
    "winget: $wingetText",
    "log:    $script:logFile"
)

# 1. Chrome
Write-Step 1 4 'Google Chrome'
if ($script:hasWinget) {
    Install-WingetApp -PackageId 'Google.Chrome' -AppName 'Chrome'
} else {
    Install-Direct -Urls @('https://dl.google.com/chrome/install/ChromeStandaloneSetup64.exe') `
        -FileName 'chrome_installer.exe' -InstallArgs @('/silent','/install') -AppName 'Chrome'
}

# 2. IdeaShare
Write-Step 2 4 'IdeaShare'
Install-Direct -Urls @(
    'https://www.ideashare.us/download/IdeaShareSetup.exe',
    'https://res-static.hc-cdn.cn/cloudbu-site/china/zh-cn/prudout/ec/share/V7.06.1.71/IdeaShare_Setup.exe'
) -FileName 'IdeaShareSetup.exe' -InstallArgs @('/S') -AppName 'IdeaShare'

# 3. AnyDesk
Write-Step 3 4 'AnyDesk'
if ($script:hasWinget) {
    Install-WingetApp -PackageId 'AnyDesk.AnyDesk' -AppName 'AnyDesk'
} else {
    Install-Direct -Urls @('https://download.anydesk.com/AnyDesk.exe') `
        -FileName 'AnyDesk.exe' `
        -InstallArgs @('--install','C:\Program Files (x86)\AnyDesk','--start-with-win','--create-shortcuts','--create-desktop-icon','--silent') `
        -AppName 'AnyDesk'
}

# 4. Adobe Acrobat Reader
Write-Step 4 4 'Adobe Acrobat Reader'
if ($script:hasWinget) {
    Install-WingetApp -PackageId 'Adobe.Acrobat.Reader.64-bit' -AppName 'Adobe Acrobat Reader'
} else {
    Install-Direct -Urls @('https://ardownload2.adobe.com/pub/adobe/acrobat/win/AcrobatDC/2600121483/AcroRdrDCx642600121483_MUI.exe') `
        -FileName 'AcrobatReader.exe' -InstallArgs @('-sfx_nu','/sAll','/rs','/msi') `
        -AppName 'Adobe Acrobat Reader'
}

# ----- Cleanup + summary --------------------------------------------------
Write-Host ''
if ($script:anyFail) {
    Write-Tag INFO "Some installs failed - files kept in $script:tempDir for manual retry."
} else {
    Write-Tag INFO 'Cleaning up temp files...'
    Remove-Item -Recurse -Force -Path $script:tempDir -ErrorAction SilentlyContinue
}

Write-Banner -Title 'Summary'

$pad = ($script:results | ForEach-Object { $_.App.Length } | Measure-Object -Maximum).Maximum + 2
foreach ($r in $script:results) {
    $statusColor = switch -Wildcard ($r.Status) {
        'Installed'         { 'Green' }
        'Already installed' { 'Green' }
        'Up to date'        { 'Green' }
        'Download failed'   { 'Red' }
        'Launch failed'     { 'Red' }
        'exit *'            { 'Yellow' }
        'winget exit *'     { 'Yellow' }
        default             { 'Gray' }
    }
    Write-Host ('  ' + $r.App.PadRight($pad)) -NoNewline -ForegroundColor White
    Write-Host $r.Status -ForegroundColor $statusColor
}

Write-Host ''
Write-Host "  Log saved to: $script:logFile" -ForegroundColor DarkGray
Write-Host ''
[void](Read-Host 'Press Enter to exit')
