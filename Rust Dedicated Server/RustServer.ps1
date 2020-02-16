param (
    [Alias('p', 'path')][Parameter(Position = 1)][string]$ServerPath,
    [Alias('i')][switch]$Interactive,
    [Alias('start', 's')][switch]$StartServer,
    [switch]$UpdateOxide,
    [switch]$UpdateServer,
    [switch]$Force,
    [Alias('c')][switch]$ClearManaged,
    [Alias('u')][switch]$FullUpdate,
    [switch]$ServerCFG,
    [string]$SteamCMDPath,
    [switch]$SteamCMDRepo
)

$oxide_dl = @{
    windows = 'https://umod.org/games/rust/download'
    linux   = 'https://umod.org/games/rust/download/develop'
    api     = 'https://umod.org/games/rust.json'
}

$root = $PSScriptRoot
$temp = "$root/temp"
$cfg_path = "$root/rustserver-config.json"

$script_version = @{
    major = 2
    minor = 0
    patch = 0
}

$script_version_formatted = "v$($script_version.major).$($script_version.minor).$($script_version.patch)"

$source_repository = '<placeholder>'

Write-Host "RustServer handler $script_version_formatted by " -NoNewline
Write-Host '2CHEVSKII' -ForegroundColor Magenta
Write-Host 'Licensed under MIT License: ' -NoNewline
Write-Host 'https://www.tldrlegal.com/l/mit' -ForegroundColor Blue
Write-Host 'Source repository: ' -NoNewline
Write-Host $source_repository -ForegroundColor DarkBlue

if (!$ServerPath) {
    $ServerPath = "./rust-ds"
}

$cfg_default = @{
    'server path' = $ServerPath
    commandline   = @{
        hostname    = 'My Rust Server'
        maxplayers  = 200
        description = "Created with 2CHEVSKII's RustServer handler script -> $source_repository"
        ip          = ''
        port        = 28015
        map         = 'Procedural Map'
        worldsize   = 4000
        seed        = 506772698683757373
        logfile     = 'logs/server.log'
        pve         = $false
        radiation   = $true
        globalchat  = $true
        url         = $source_repository
        headerimage = 'https://i.imgur.com/hmQ6Q8e.png'
        rcon        = @{
            port     = 28016
            password = '0000'
        }
    }
    'server.cfg'  = @(
        'aimanager.nav_wait 1',
        'fps.limit 90'
    )
}

$cfg

function Update-Server {
    param (
        [string]$path,
        [string]$steamcmd_path,
        [switch]$reset
    )

    if (!(Test-Path -Path "$root/SteamCMD.ps1")) {
        Write-Error 'Could not find SteamCMD.ps1 script! Make sure it is located at the same directory with this script'
        return $false
    }

    if ($reset) {
        Remove-Item -Recurse -Path "$path/RustDedicated_Data/Managed" -Force -ErrorAction SilentlyContinue
        Write-Host 'Removed Managed directory' -ForegroundColor DarkYellow
    }

    Write-Host 'Updating the rust server (this may take a while)...' -NoNewline

    if ($steamcmd_path) {
        &.\SteamCMD.ps1 -AppID 258550 -AppDir $path -Validate -SCMDPath $steamcmd_path | Out-Null
    }
    else {
        &.\SteamCMD.ps1 -AppID 258550 -AppDir $path -Validate -RepoInstall | Out-Null
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host 'success' -ForegroundColor Green
        Write-Host 'Rust server was fully updated!'
        return $true
    }
    else {
        Write-Host 'fail' -ForegroundColor Red
        Write-Error 'Failed to update Rust server, steamcmd script exited with non-zero exit code!'
        return $false
    }
}

function Update-Oxide {
    param (
        [string]$path,
        [switch]$force
    )

    $version = Get-OxideVersion -path $path

    $dl_link = if ($IsWindows) { $oxide_dl.windows } else { $oxide_dl.linux }

    if ($version.installed -eq 'NOT_INSTALLED') {
        Write-Host 'Oxide is not installed' -ForegroundColor Red
    }
    else {
        Write-Host "Current Oxide version: " -NoNewline
        Write-Host $version.installed -ForegroundColor DarkYellow
    }

    Write-Host "Latest Oxide version: " -NoNewline
    Write-Host $version.latest -ForegroundColor DarkGreen

    if ($version.installed -eq $version.latest -and !$force) {
        Write-Host 'Oxide update is not required' -ForegroundColor Green
        return $true
    }

    if ($IsWindows) {
        Write-Host "Updating OxideMod (Windows build $version)..."
    }
    else {
        Write-Host "Updating OxideMod (Linux build $version)..."
    }

    try {
        Write-Host 'Downloading build...' -NoNewline
        Invoke-WebRequest -Uri $dl_link -OutFile "$temp/oxide.latest.zip"
        Write-Host 'success' -ForegroundColor Green
    }
    catch {
        Write-Host 'fail' -ForegroundColor Red
        Write-Error 'Could not download latest Oxide build! Check if you are experiencing connection problems'
        return $false
    }

    try {
        Write-Host 'Extracting the archive...' -NoNewline
        Expand-Archive -Path "$temp/oxide.latest.zip" -DestinationPath $path
        Write-Host 'success' -ForegroundColor Green
    }
    catch {
        Write-Host 'fail' -ForegroundColor Red
        Write-Error 'Could not extract Oxide build to the target directory! Check if PowerShell has access to the folder'
        return $false
    }

    Remove-Item -Path "$temp/oxide.latest.zip", "$temp/oxide.latest.json" -Force

    Write-Host 'Oxide updated successfully to version ' + $version + '!' -ForegroundColor Green

    return $true
}

function Get-OxideVersion {
    param (
        [string]$path
    )

    $version = @{
        latest    = $null
        installed = $null
    }

    try {
        Invoke-WebRequest -Uri $oxide_dl.api -OutFile "$temp/oxide.latest.json"

        $version.latest = (Get-Content -Path "$temp/oxide.latest.json" -ErrorAction Stop -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop).latest_release_version_formatted

        Remove-Item "$temp/oxide.latest.json" -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning 'Could not retrieve latest Oxide version!'
    }

    if (Test-Path -Path "$path/RustDedicated_Data/Managed/Oxide.Rust.dll") {
        try {
            $version.installed = 'v' + [System.Reflection.Assembly]::LoadFile("$path/RustDedicated_Data/Managed/Oxide.Core.dll").GetName().Version.ToString("3")
        }
        catch {
            Write-Warning 'Could not retrieve installed Oxide version!'
        }
    }
    else {
        $version.latest = 'NOT_INSTALLED'
    }

    return $version
}

function Get-Config {
    $cfg_local

    try {
        if (!(Test-Path -Path $cfg_path)) {
            throw 'NOT_FOUND'
        }

        $cfg_local = Get-Content -Path $cfg_path -Raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        $cfg_local = $cfg_default
    }

    return $cfg_local
}

