<#
.SYNOPSIS
    Installs Oh My Posh and writes the PowerShell profile on a fresh Windows PC.

.DESCRIPTION
    1. Sets the CurrentUser execution policy to RemoteSigned (only if it is Restricted/Undefined).
    2. Installs Oh My Posh with winget; falls back to the official GitHub installer.
    3. Installs a Nerd Font (Meslo by default).
    4. Writes a small profile that runs `oh-my-posh init` at start-up (backs up any existing profile).

    Safe to run again: it skips the install when Oh My Posh is already present.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-OhMyPosh.ps1

.EXAMPLE
    .\Install-OhMyPosh.ps1 -Theme jandedobbeleer -IncludePwsh7
#>
[CmdletBinding()]
param(
    # Theme name (e.g. "jandedobbeleer"), local .omp.json path, or URL. Empty = Oh My Posh default theme.
    [string]$Theme = '',

    # Nerd Font asset name from https://github.com/ryanoasis/nerd-fonts/releases (Meslo -> Meslo.zip).
    [string]$Font = 'Meslo',

    [switch]$SkipFont,

    # Also write the PowerShell 7 (pwsh) profile.
    [switch]$IncludePwsh7,

    # Skip winget and use the GitHub installer directly.
    [switch]$ForceDirectDownload,

    # How long to wait for winget before falling back to the GitHub installer.
    [int]$WingetTimeoutSeconds = 300,

    # Documents folder to write profiles into (defaults to your real Documents folder, OneDrive-aware).
    [string]$DocumentsPath = [Environment]::GetFolderPath('MyDocuments'),

    # Per-user font folder and registry key (override only for testing).
    [string]$FontsDir = (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'),
    [string]$FontRegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "    $Message" -ForegroundColor Green }
function Write-Note([string]$Message) { Write-Host "    $Message" -ForegroundColor Yellow }

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Find-OhMyPosh {
    $cmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\bin\oh-my-posh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\oh-my-posh.exe'),
        (Join-Path ${env:ProgramFiles} 'oh-my-posh\bin\oh-my-posh.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    return $null
}

function Install-WithWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Note 'winget not found.'
        return $false
    }
    Write-Ok "Installing with winget (gives up after $WingetTimeoutSeconds s and uses GitHub instead)..."
    $wingetArgs = @(
        'install', '--id', 'JanDeDobbeleer.OhMyPosh', '--exact', '--source', 'winget', '--scope', 'user',
        '--accept-package-agreements', '--accept-source-agreements', '--silent', '--disable-interactivity'
    )
    $proc = Start-Process -FilePath 'winget' -ArgumentList $wingetArgs -NoNewWindow -PassThru
    $null = $proc.Handle   # cache the handle so ExitCode is available later
    if (-not $proc.WaitForExit($WingetTimeoutSeconds * 1000)) {
        Write-Note "winget did not finish within $WingetTimeoutSeconds seconds, stopping it."
        try { $proc.Kill() } catch {}
        return $false
    }
    if ($proc.ExitCode -ne 0) {
        Write-Note "winget exited with code $($proc.ExitCode)."
        return $false
    }
    return $true
}

function Install-FromGitHub {
    $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $suffix = switch ($arch) {
        'ARM64' { 'arm64' }
        'x86'   { '386' }
        default { 'amd64' }
    }
    $url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/install-$suffix.exe"
    $installer = Join-Path $env:TEMP "oh-my-posh-install-$suffix.exe"

    Write-Ok "Downloading $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster on PS 5.1
    try {
        Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
    }
    finally {
        $ProgressPreference = $oldProgress
    }

    Write-Ok 'Running installer (current user, silent)...'
    $proc = Start-Process -FilePath $installer -ArgumentList '/CURRENTUSER', '/VERYSILENT', '/NORESTART' -Wait -PassThru
    Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
    if ($proc.ExitCode -ne 0) {
        throw "Oh My Posh installer exited with code $($proc.ExitCode)."
    }
}

function Install-NerdFont {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FontsDir,
        [Parameter(Mandatory)][string]$RegistryKey
    )

    $url  = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$Name.zip"
    $work = Join-Path $env:TEMP "nerd-font-$([guid]::NewGuid().ToString('N'))"
    $zip  = Join-Path $work "$Name.zip"
    $out  = Join-Path $work 'extracted'

    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        Write-Ok "Downloading $url"
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $oldProgress = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
            Expand-Archive -LiteralPath $zip -DestinationPath $out -Force
        }
        finally {
            $ProgressPreference = $oldProgress
        }

        $files = Get-ChildItem -LiteralPath $out -Recurse -File |
            Where-Object { $_.Extension -in @('.ttf', '.otf') }
        if (-not $files) { throw "No .ttf/.otf files found in $Name.zip." }

        if (-not (Test-Path -LiteralPath $FontsDir))    { New-Item -ItemType Directory -Path $FontsDir -Force | Out-Null }
        if (-not (Test-Path -LiteralPath $RegistryKey)) { New-Item -Path $RegistryKey -Force | Out-Null }

        # AddFontResource makes a font usable right away, without signing out.
        if (-not ('NerdFontNative' -as [type])) {
            Add-Type -Namespace '' -Name 'NerdFontNative' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("gdi32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int AddFontResource(string lpFileName);
'@
        }

        $registered = Get-ItemProperty -LiteralPath $RegistryKey
        $installed = 0; $skipped = 0
        foreach ($file in $files) {
            $target  = Join-Path $FontsDir $file.Name
            $kind    = if ($file.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
            $regName = "$($file.BaseName) ($kind)"

            if ((Test-Path -LiteralPath $target) -and $registered.PSObject.Properties[$regName]) {
                $skipped++
                continue
            }

            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
            New-ItemProperty -LiteralPath $RegistryKey -Name $regName -Value $target -PropertyType String -Force | Out-Null
            if ($RegistryKey -eq 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts') {
                [void][NerdFontNative]::AddFontResource($target)
            }
            $installed++
        }
        Write-Ok "Fonts installed: $installed, already present: $skipped (in $FontsDir)"
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-ThemeConfig([string]$Name) {
    if (-not $Name) { return '' }
    if ($Name -match '^https?://') { return $Name }
    if (Test-Path -LiteralPath $Name) { return (Resolve-Path -LiteralPath $Name).Path }

    $fileName = if ($Name -like '*.omp.*') { $Name } else { "$Name.omp.json" }
    if ($env:POSH_THEMES_PATH) {
        $local = Join-Path $env:POSH_THEMES_PATH $fileName
        if (Test-Path -LiteralPath $local) { return $local }
    }
    # Newer releases don't always ship themes locally; Oh My Posh can load a config from a URL.
    return "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$fileName"
}

function New-ProfileContent([string]$Shell, [string]$Config) {
    $configArg = if ($Config) { " --config '$($Config -replace "'", "''")'" } else { '' }
@"
# Oh My Posh (generated by Install-OhMyPosh.ps1)
# Disable Python virtual-env prompts, Oh My Posh shows them instead.
`$env:VIRTUAL_ENV_DISABLE_PROMPT = 1
`$env:PYENV_VIRTUALENV_DISABLE_PROMPT = 1

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init $Shell$configArg | Invoke-Expression
}
else {
    Write-Warning 'oh-my-posh not found on PATH. Run Install-OhMyPosh.ps1 again.'
}
"@
}

function Write-ProfileFile([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $backup = $null
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $Path -Destination $backup -Force
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
    [pscustomobject]@{ Profile = $Path; Backup = $backup }
}

# ---------------------------------------------------------------------------
# 1. Execution policy
# ---------------------------------------------------------------------------
Write-Step 'Checking execution policy'
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Restricted', 'Undefined')) {
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
    }
    catch [System.Security.SecurityException] {
        # Thrown when the value WAS saved but a more specific scope (e.g. -ExecutionPolicy Bypass
        # for this run) overrides it. Not a real failure; verified below.
    }
    catch {
        Write-Note "Could not set execution policy: $_"
    }

    if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'RemoteSigned') {
        Write-Ok 'CurrentUser policy set to RemoteSigned.'
    }
    else {
        Write-Note 'CurrentUser policy is still not set. Run manually: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser'
    }
}
else {
    Write-Ok "CurrentUser policy is $policy, leaving it as is."
}
$gpo = @('MachinePolicy', 'UserPolicy') | ForEach-Object { Get-ExecutionPolicy -Scope $_ } | Where-Object { $_ -ne 'Undefined' }
if ($gpo) {
    Write-Note "Group Policy enforces execution policy '$($gpo | Select-Object -First 1)'. The profile may not load if it is Restricted or AllSigned."
}

# ---------------------------------------------------------------------------
# 2. Install Oh My Posh
# ---------------------------------------------------------------------------
Write-Step 'Installing Oh My Posh'
$exe = Find-OhMyPosh
if ($exe) {
    Write-Ok "Already installed: $exe"
}
else {
    $installed = $false
    if (-not $ForceDirectDownload) {
        $installed = Install-WithWinget
    }
    if (-not $installed) {
        Write-Note 'Falling back to the GitHub installer.'
        Install-FromGitHub
    }
    Update-SessionPath
    $exe = Find-OhMyPosh
    if (-not $exe) {
        throw 'Oh My Posh was installed but oh-my-posh.exe could not be found. Open a new terminal and run this script again.'
    }
    Write-Ok "Installed: $exe"
}

# Make sure the exe folder is on PATH for the rest of this session.
$exeDir = Split-Path -Parent $exe
if (($env:Path -split ';') -notcontains $exeDir) { $env:Path = "$exeDir;$env:Path" }

# ---------------------------------------------------------------------------
# 3. Nerd Font
# ---------------------------------------------------------------------------
if (-not $SkipFont) {
    Write-Step "Installing Nerd Font '$Font' from github.com/ryanoasis/nerd-fonts"
    try {
        Install-NerdFont -Name $Font -FontsDir $FontsDir -RegistryKey $FontRegistryKey
        Write-Ok "Select the font (e.g. 'MesloLGM Nerd Font') in Windows Terminal > Settings > Defaults > Appearance > Font face."
    }
    catch {
        Write-Note "Font install failed: $($_.Exception.Message)"
        Write-Note 'Oh My Posh still works; icons may show as boxes until a Nerd Font is installed.'
    }
}

# ---------------------------------------------------------------------------
# 4. Profiles
# ---------------------------------------------------------------------------
Write-Step 'Writing PowerShell profile(s)'
$config = Resolve-ThemeConfig $Theme
if ($config) { Write-Ok "Theme: $config" } else { Write-Ok 'Theme: Oh My Posh default' }

$targets = @(
    @{ Path = Join-Path $DocumentsPath 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'; Shell = 'powershell' }
)
if ($IncludePwsh7) {
    $targets += @{ Path = Join-Path $DocumentsPath 'PowerShell\Microsoft.PowerShell_profile.ps1'; Shell = 'pwsh' }
}

$results = foreach ($t in $targets) {
    Write-ProfileFile -Path $t.Path -Content (New-ProfileContent -Shell $t.Shell -Config $config)
}

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
Write-Step 'Done'
Write-Ok "Oh My Posh version: $(& $exe version)"
foreach ($r in $results) {
    Write-Ok "Profile written: $($r.Profile)"
    if ($r.Backup) { Write-Ok "Backup:          $($r.Backup)" }
}
Write-Host ''
Write-Host 'Restart your terminal to see the new prompt.' -ForegroundColor Magenta
