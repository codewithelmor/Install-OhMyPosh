# Install-OhMyPosh

A single PowerShell script that sets up [Oh My Posh](https://ohmyposh.dev) on a new Windows PC: it installs the program, installs a Nerd Font, and writes your PowerShell profile. No admin rights are needed.

Run it once on a freshly formatted PC and your prompt is ready. You don't have to find the `.exe`, copy profile files or install fonts by hand.

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Parameters](#parameters)
  - [Examples](#examples)
- [What the script does](#what-the-script-does)
- [The generated profile](#the-generated-profile)
- [After installing](#after-installing)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [FAQ](#faq)

---

## Features

- **Installs Oh My Posh for your user only.** It uses `winget` first and falls back to the official installer from GitHub releases if winget is missing, fails, or hangs.
- **Installs a Nerd Font.** It downloads `Meslo.zip` (or any other font you choose) from [ryanoasis/nerd-fonts releases](https://github.com/ryanoasis/nerd-fonts/releases), extracts it and installs it for your user.
- **Writes a small profile that keeps working.** The profile doesn't hardcode where `oh-my-posh.exe` lives, so updates and new PCs don't break it.
- **Backs up your existing profile** as `*.bak-yyyyMMdd-HHmmss` before writing a new one.
- **Safe to run again.** It skips steps that are already done, such as the install and fonts that are already present.
- **Works with Windows PowerShell 5.1 and PowerShell 7.** It also works when your Documents folder is moved to OneDrive.

## Requirements

| Requirement | Notes |
| --- | --- |
| Windows 10 1809+ / Windows 11 | Needed for installing fonts per user |
| Windows PowerShell 5.1 or PowerShell 7+ | 5.1 ships with Windows |
| Internet access | To reach `github.com` and the winget source |
| `winget` (optional) | Comes with App Installer. The script falls back to GitHub if it's missing |

## Quick start

1. Copy `Install-OhMyPosh.ps1` to the new PC, for example from a USB stick, OneDrive or a gist.
2. Open **Windows PowerShell** in the folder that contains the script.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1
   ```

4. Restart your terminal and select **MesloLGM Nerd Font** as the font. See [After installing](#after-installing).

> **Note:** `-ExecutionPolicy Bypass` applies only to this one run. The script also sets your user's execution policy to `RemoteSigned`, if it isn't set yet, so the profile can load in every new window.

## Usage

```powershell
.\Install-OhMyPosh.ps1 [-Theme <string>] [-Font <string>] [-SkipFont] [-IncludePwsh7]
                       [-ForceDirectDownload] [-WingetTimeoutSeconds <int>]
                       [-DocumentsPath <string>] [-FontsDir <string>] [-FontRegistryKey <string>]
```

Built-in help:

```powershell
Get-Help .\Install-OhMyPosh.ps1 -Detailed
```

### Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Theme` | *(empty = Oh My Posh default theme)* | A theme name (e.g. `jandedobbeleer`, `paradox`), a local `.omp.json` path, or a URL. Names are looked up in `$env:POSH_THEMES_PATH` first, then on GitHub. See the [theme gallery](https://ohmyposh.dev/docs/themes). |
| `-Font` | `Meslo` | Name of the Nerd Font asset from [nerd-fonts releases](https://github.com/ryanoasis/nerd-fonts/releases), without `.zip` (e.g. `CascadiaCode`, `FiraCode`, `JetBrainsMono`). |
| `-SkipFont` | off | Don't install a font. |
| `-IncludePwsh7` | off | Also write the PowerShell 7 profile (`Documents\PowerShell\...`). |
| `-ForceDirectDownload` | off | Skip winget and use the GitHub installer straight away. |
| `-WingetTimeoutSeconds` | `300` | How long to wait for winget before stopping it and using GitHub instead. |
| `-DocumentsPath` | your Documents folder | Where the profile folders are created. Change this only for testing. |
| `-FontsDir` | `%LOCALAPPDATA%\Microsoft\Windows\Fonts` | Where font files are copied. Change this only for testing. |
| `-FontRegistryKey` | `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts` | Where fonts are registered. Change this only for testing. |

### Examples

Default setup: default theme, Meslo font, Windows PowerShell profile.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1
```

Use a theme and set up PowerShell 7 too:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1 -Theme jandedobbeleer -IncludePwsh7
```

Use your own theme file (keep it next to the script):

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1 -Theme .\my-theme.omp.json
```

Use a different Nerd Font:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1 -Font CascadiaCode
```

Skip winget, for example when it hangs on a fresh install:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1 -ForceDirectDownload
```

Only rewrite the profile (Oh My Posh and the font are already installed):

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1 -SkipFont
```

## What the script does

| Step | Action |
| --- | --- |
| 1. Execution policy | Sets the `CurrentUser` policy to `RemoteSigned` if it's `Restricted` or `Undefined`. Warns if Group Policy enforces a policy. |
| 2. Install Oh My Posh | Skips this if `oh-my-posh` is already installed. Otherwise runs `winget install JanDeDobbeleer.OhMyPosh --scope user`. If that fails or times out, downloads `install-<arch>.exe` from the [latest GitHub release](https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest) and runs it silently for the current user. |
| 3. Nerd Font | Downloads `https://github.com/ryanoasis/nerd-fonts/releases/latest/download/<Font>.zip` and extracts it to a temporary folder. Copies each `.ttf`/`.otf` to your user font folder, registers it under `HKCU`, and loads it so it works without signing out. Deletes the temporary files afterwards. |
| 4. Profile | Backs up any existing profile, then writes the new profile (see below). |
| 5. Summary | Shows the Oh My Posh version, the profile paths written and the backup paths. |

## The generated profile

Written to `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`. With `-IncludePwsh7`, a copy using `pwsh` instead of `powershell` is also written to `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`.

```powershell
# Oh My Posh (generated by Install-OhMyPosh.ps1)
# Disable Python virtual-env prompts, Oh My Posh shows them instead.
$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
$env:PYENV_VIRTUALENV_DISABLE_PROMPT = 1

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init powershell | Invoke-Expression
}
else {
    Write-Warning 'oh-my-posh not found on PATH. Run Install-OhMyPosh.ps1 again.'
}
```

When you pass `-Theme`, the profile adds `--config '<theme>'` to the `init` line.

> **Why not copy the old profile?** If you saved the *output* of `oh-my-posh init` (a long script with `$global:_ompExecutable = 'C:/Users/.../oh-my-posh.exe'`), that copy is tied to one user, one install path and one version. Running `oh-my-posh init` each time PowerShell starts avoids all three problems.

To add your own settings (aliases, modules, functions), put them **below** the Oh My Posh block in the profile. Running the script again replaces the profile, but your previous version is kept as a `.bak-*` file.

## After installing

1. **Restart the terminal.** Close all PowerShell windows and open a new one.
2. **Select the font** so icons show up instead of empty boxes:
   - **Windows Terminal:** Settings → Defaults → Appearance → Font face → `MesloLGM Nerd Font`
   - **VS Code:** set `"terminal.integrated.fontFamily": "MesloLGM Nerd Font"` in `settings.json`
3. **Check the setup:**

   ```powershell
   Get-Content $PROFILE      # shows the short Oh My Posh profile
   oh-my-posh version        # shows the installed version
   ```

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `Could not set execution policy: Security error.` (older script versions) | Harmless. The policy **was** saved, but `-ExecutionPolicy Bypass` overrides it for that one run. Check with `Get-ExecutionPolicy -List`. |
| Stuck at `Installing with winget...` | winget is updating its sources on its first run. Wait for the timeout (default 5 minutes) or rerun with `-ForceDirectDownload`. |
| Icons show as `□` or `?` | The terminal isn't using a Nerd Font. Select `MesloLGM Nerd Font` (see [After installing](#after-installing)). |
| `oh-my-posh not found on PATH` warning | Open a new terminal so it picks up the updated PATH, or run the script again. |
| Profile doesn't load: "running scripts is disabled" | Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`. If Group Policy enforces `Restricted`/`AllSigned`, ask your IT admin. |
| Font download fails | Check that you can reach `github.com` (proxy or firewall). Oh My Posh still works without the font, but icons will show as boxes. |

## Uninstall

```powershell
# 1. Remove Oh My Posh
winget uninstall JanDeDobbeleer.OhMyPosh
#    (or Settings > Apps > Installed apps > Oh My Posh > Uninstall)

# 2. Restore your previous profile (pick the backup you want), or delete the profile
Get-ChildItem (Split-Path $PROFILE) -Filter '*.bak-*'
Copy-Item '<backup file>' $PROFILE -Force

# 3. (Optional) Remove the Meslo fonts
#    Settings > Personalization > Fonts > search "Meslo" > Uninstall
```

## FAQ

**Do I need admin rights?**
No. Oh My Posh, the fonts and the profile are all installed for your user only.

**Is it safe to run again?**
Yes. It skips the install if Oh My Posh is already there, skips fonts that are already installed, and backs up the profile before rewriting it.

**How do I update Oh My Posh later?**
Run `winget upgrade JanDeDobbeleer.OhMyPosh` (or `oh-my-posh upgrade`). The profile doesn't need to change.

**Can I use a different font or theme?**
Yes. Use `-Font <NerdFontName>` and `-Theme <name|path|url>`. Browse the [Nerd Fonts](https://www.nerdfonts.com/font-downloads) and [Oh My Posh themes](https://ohmyposh.dev/docs/themes).
