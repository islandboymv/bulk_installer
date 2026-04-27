# Bulk App Installer

A Windows batch script that silently installs a standard set of apps in one run:

- **Google Chrome** (via winget)
- **IdeaShare** (direct download)
- **AnyDesk** (via winget)
- **Adobe Acrobat Reader** (via winget)

## Requirements

- Windows 10 / 11
- Administrator privileges (the script self-checks and exits if not elevated)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/) — preinstalled on recent Windows 10/11. If missing, install **App Installer** from the Microsoft Store. Without winget, Chrome, AnyDesk, and Acrobat are skipped; IdeaShare still installs.

## Usage

1. Download `install_apps.bat`.
2. Right-click it and choose **Run as administrator**.
3. Wait for all four sections to finish. A log is written to `%USERPROFILE%\Desktop\install_log.txt`.

### Quick download with curl

Windows 10 (1803+) and Windows 11 ship with `curl.exe`. From an **elevated** Command Prompt:

```cmd
curl -L -o install_apps.bat https://raw.githubusercontent.com/islandboymv/bulk_installer/main/install_apps.bat
install_apps.bat
```

From an **elevated** PowerShell window, call `curl.exe` explicitly so it doesn't get aliased to `Invoke-WebRequest`:

```powershell
curl.exe -L -o install_apps.bat https://raw.githubusercontent.com/islandboymv/bulk_installer/main/install_apps.bat
.\install_apps.bat
```

One-liner (Command Prompt, elevated) — download and run:

```cmd
curl -L -o "%TEMP%\install_apps.bat" https://raw.githubusercontent.com/islandboymv/bulk_installer/main/install_apps.bat && "%TEMP%\install_apps.bat"
```

The `-L` flag follows GitHub's redirect from `raw.githubusercontent.com` to the underlying CDN.

## What the script does

1. Verifies it's running elevated.
2. Detects winget once and reports its availability.
3. For each app, prints status to the console and appends `[OK]`, `[WARN]`, `[FAIL]`, or `[SKIP]` to the log.
4. Cleans up the temp download folder (`%TEMP%\AppInstallers`) on exit.

## Log meanings

| Tag    | Meaning                                                                 |
| ------ | ----------------------------------------------------------------------- |
| `[OK]`   | Installer reported success.                                             |
| `[WARN]` | Installer returned a non-zero exit code (often "already installed").    |
| `[FAIL]` | Download failed or required tooling is missing.                         |
| `[SKIP]` | winget unavailable; the winget-based step was skipped.                  |

## Customizing

To add or remove apps:

- **winget apps** — copy one of the winget blocks (Chrome / AnyDesk / Acrobat) and swap the `--id`. Find IDs with `winget search <app name>`.
- **Direct-download apps** — copy the IdeaShare block and replace the `$url`, output filename, and silent-install flag (`/S`, `/silent`, `/quiet`, etc. — depends on the installer's framework).

## Notes

- The script enables TLS 1.2 before each `WebClient` download so it works on stock Windows where `WebClient` would otherwise default to TLS 1.0/1.1.
- IdeaShare is not in the winget repository, which is why it uses a direct download.
- AnyDesk is installed via winget with vendor defaults (desktop shortcut, start with Windows). If you need the granular AnyDesk install flags (`--start-with-win`, `--create-shortcuts`, etc.), switch its block back to a direct download from `https://download.anydesk.com/AnyDesk.exe`.
