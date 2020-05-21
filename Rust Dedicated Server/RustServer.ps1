#!/usr/bin/env bash
#requires -modules 'PSColorizer'

using namespace System.Globalization

[CmdletBinding()]
param (
    [switch]$Start,

    [switch]$Update,

    [switch]$UpdateServer,

    [switch]$UpdateUmod,

    [switch]$Force,

    [switch]$Clean,

    [string[]]$ScriptConfig,

    [string[]]$ServerConfig
)

class Configuration {
    [string]$server_path
    [string]$steamcmd_script_path
    [string]$steamcmd_installation_path

    [string]$server_hostname
    [string]$server_identity
    [string]$server_ip
    [string]$server_port

    [string]$rcon_ip
    [string]$rcon_port
    [string]$rcon_password

    [string]$server_level
    [string]$server_worldsize
    [string]$server_levelurl

    [string]$server_window_title

    [string]GetManagedFolderPath() {
        return Resolve-PathNoFail  (Join-Path -Path $this.server_path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed')
    }

    [string]GetServerIdentityFolderPath() {
        return Resolve-PathNoFail (Join-Path -Path $this.server_path -ChildPath 'server' -AdditionalChildPath $this.server_identity)
    }

    [string]GetServerCfgFolderPath() {
        return Resolve-PathNoFail (Join-Path -Path $this.GetServerIdentityFolderPath() -ChildPath 'cfg')
    }

    [string]GetServerAutoFilePath() {
        return Resolve-PathNoFail (Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'serverauto.cfg')
    }

    [string]GetServerCfgFilePath() {
        return Resolve-PathNoFail (Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'server.cfg')
    }

    [string]GetServerUsersFilePath() {
        return Resolve-PathNoFail (Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'users.cfg')
    }

    [string]GetServerBansFilePath() {
        return Resolve-PathNoFail (Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'bans.cfg')
    }
}

[Configuration]$settings = [Configuration]::new()

$script_info = @{
    name           = 'RustServer HELPER'
    author         = '2CHEVSKII'
    version        = @{
        major = 2
        minor = 0
        patch = 0
    }
    license        = 'MIT LICENSE'
    'license-link' = 'https://www.tldrlegal.com/l/mit'
    repository     = 'https://github.com/2chevskii/Automation'
}

$appID = 258550

$umod_dl = @{ # this is a lie - actually its oxide download links :-P might be changed in the future
    master  = 'https://umod.org/games/rust/download'
    develop = 'https://umod.org/games/rust/download/develop'
}

$umod_api_link = 'https://umod.org/games/rust.json'

$umod_game_lib_name = 'Oxide.Rust.dll' # will be changed in the future with umod release

$default_window_title = $Host.UI.RawUI.WindowTitle

$serverauto_allowed_vars = @{
    'fps.limit'                           = @{
        type    = [System.Double]
        default = 256
    }
    'global.perf'                         = @{
        type    = [System.Boolean]
        default = 0
    }
    'server.ceilinglightgrowablerange'    = @{
        type    = [System.Double]
        default = 3
    }
    'server.nonplanterdeathchancepertick' = @{
        type    = [System.Double]
        default = 0.005
    }
    'server.arrowarmor'                   = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.meleedamage'                  = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.meleearmor'                   = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.bleedingdamage'               = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.bulletarmor'                  = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.showholstereditems'           = @{
        type    = [System.Boolean]
        default = $true
    }
    'server.arrowdamage'                  = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.sprinklereyeheightoffset'     = @{
        type    = [System.Double]
        default = 3
    }
    'server.bulletdamage'                 = @{
        type    = [System.Boolean]
        default = 1
    }
    'server.motd'                         = @{
        type    = [System.String]
        default = ''
    }
    'server.ceilinglightheightoffset'     = @{
        type    = [System.Double]
        default = 3
    }
    'server.woundingenabled'              = @{
        type    = [System.Boolean]
        default = $false
    }
    'server.playerserverfall'             = @{
        type    = [System.Boolean]
        default = $true
    }
    'server.sprinklerradius'              = @{
        type    = [System.Double]
        default = 3
    }
    'server.bleedingarmor'                = @{
        type    = [System.Boolean]
        default = 1
    }
}

$kv_regex_pattern = @"
^\s*(?:('|")?(?<key>[a-z._\s]+?)\1)(?:\s+('|")?(?<value>.*[^\s])\3)\s*$
"@


#region Helpers

function ConvertTo-Type {
    param (
        [type]$type,
        [string]$value
    )

    switch ($type) {
        ([bool]) {
            if ($value -eq '0') {
                return $false
            } elseif ($value -eq '1') {
                return $true
            } elseif ($value -like 't*') {
                return $true
            } elseif ($Value -like 'f*') {
                return $false
            }
        }
        ([double]) {
            $double = 0
            if ([double]::TryParse($value.Replace(',', '.'), [NumberStyles]::Number, [cultureinfo]::InvariantCulture, [ref]$double)) {
                return $double
            }
        }
        ([string]) {
            return $value
        }
        Default {
            throw "Unknown type '$type'"
        }
    }

    throw "Cannot convert string '$value' to the type of '$type'"
}

function Remove-Quotes {
    param (
        [string]$string
    )

    function Test-String {
        param (
            [string]$testChar
        )

        return $string.StartsWith($testChar) -and $string.EndsWith($testChar)
    }

    if (Test-string -testChar '"') {
        return $string.Trim('"')
    }

    if (Test-String -testChar "'") {
        return $string.Trim("'")
    }

    return $string
}

function Test-NeedOxideUpdate {
    Write-Colorized "[<yellow>WAIT</yellow>] Checking currently installed uMod version ..."
    $assembly_path = Join-Path $settings.GetManagedFolderPath() $umod_game_lib_name

    try {
        $assembly = [System.Reflection.Assembly]::LoadFrom($assembly_path)
    } catch {
        Write-Colorized "[<red>FAIL</red>] Failed to load existing assembly: <red>$_</red>"
        return $true
    }

    $current_version = $assembly.GetName().Version

    try {
        $json = Invoke-WebRequest -Uri $umod_api_link | Select-Object -ExpandProperty Content
    } catch {
        Write-Colorized "[<red>FAIL</red>] Failed get data from uMod api: <red>$_</red>"
        return $true
    }

    $latest_version = [version]::new(($json | ConvertFrom-Json -AsHashtable).latest_release_version)

    Write-Colorized "[----] Current uMod.Rust version: $current_version"
    Write-Colorized "[----] Latest uMod.Rust version: $latest_version"

    $comparison_result = $current_version.CompareTo($latest_version)

    if ($comparison_result -eq -1) {
        Write-Colorized "[<red>XXXX</red>] "
        return $true
    } elseif ($comparison_result -eq 0) {
        Write-Colorized "[ <green>OK</green> ] Versions are equal, update is not necessary."
    } else {
        Write-Colorized "[ <green>OK</green> ] Current version is newer than the latest one published. Are you Wulf or what?"
    }
    return $false
}

function Get-ExternalIP {
    try {
        return (Invoke-WebRequest -Uri 'http://icanhazip.com').Content
    } catch {
        Write-Colorized "[<red>FAIL</red>] Failed to get external IP address."
        return $null
    }
}

function Resolve-PathNoFail {
    <#
    .SYNOPSIS
        Resolve-Path that works for non-existent locations
    .REMARKS
        From http://devhawk.net/blog/2010/1/22/fixing-powershells-busted-resolve-path-cmdlet
    #>
    param (
        [string]$Destination
    )

    $Destination = Resolve-Path -Path $Destination -ErrorAction SilentlyContinue -ErrorVariable resolve_error

    if (!$Destination) {
        $Destination = $resolve_error[0].TargetObject
    }

    return $Destination
}

function Write-ScriptInfo {
    $request_uri = "http://artii.herokuapp.com/make?text=$($script_info.name.Replace(' ', '+'))"

    Invoke-WebRequest -Uri $request_uri | Select-Object -ExpandProperty Content | Out-String

    Write-Colorized "Author                         -> <magenta>$($script_info['author'])</magenta>"
    Write-Colorized "Version                        -> <darkyellow>$($script_info.version.major).$($script_info.version.minor).$($script_info.version.patch)</darkyellow>"
    Write-Colorized "Licensed under the <darkred>$($script_info['license'])</darkred> -> <blue>$($script_info['license-link'])</blue>"
    Write-Colorized "Repository                     -> <blue>$($script_info['repository'])</blue>"
}

function Set-WindowTitle {
    param (
        [switch]$server,
        [switch]$default
    )

    if ($server) {
        $title = $settings.server_window_title.
        Replace("{hostname}", $settings.server_hostname).
        Replace("{identity}", $settings.server_identity).
        Replace("{level}", $settings.server_level).
        Replace("{worldsize}", $settings.server_worldsize).
        Replace("{levelurl}", $settings.server_levelurl).
        Replace("{ext-ip}", (Get-ExternalIP) ?? 'localhost').
        Replace("{port}", $settings.server_port)
    } elseif ($default) {
        $title = $default_window_title
    } else {
        $title = $script_info.name
    }

    $Host.UI.RawUI.WindowTitle = $title
}

#endregion

Set-WindowTitle
Write-ScriptInfo

if ($Update) {
    $UpdateServer = $true
    $UpdateUmod = $true
}

if (!$Start -and !$UpdateServer -and !$UpdateUmod) {
    ## interactive mode
} else {
    ## non-interactive mode
}

ConvertTo-Type -type ([bool]) -value "false" | Out-Host

Set-WindowTitle -default








# #region Core

# function Install-UMod {
#     Write-Colorized "[----] Preparing to update uMod ..."

#     if ($IsWindows) {
#         # this is just a temp solution for now. oxide/umod builds might be united again
#         $download_link = $umod_dl.master
#     } elseif ($IsLinux) {
#         $download_link = $umod_dl.develop
#     } else {
#         Write-Colorized "[<red>FAIL</red>] Your platform is unsupported."
#         return $false
#     }

#     $managed_folder_path = $settings.GetManagedFolderPath()
#     $oxide_rust_path = Resolve-PathNoFail -Destination (Join-Path $managed_folder_path $umod_game_lib_name)

#     $lib_exists = Test-Path $oxide_rust_path

#     if (!$lib_exists) {
#         Write-Colorized "[<red>XXXX</red>] uMod is not installed, installing now ..."
#     } elseif (Test-NeedOxideUpdate) {
#         Write-Colorized "[<red>XXXX</red>] uMod is outdated, updating ..."
#     } elseif ($Force) {
#         Write-Colorized "[<red>XXXX</red>] Force update enabled, updating ..."
#     } else {
#         Write-Colorized "[ <green>OK</green> ] uMod update is unnecessary."
#         return $true
#     }

#     $download_path = Split-Path -Path $download_link -Leaf

#     Write-Colorized "[----] Download link: <blue>$download_link</blue>"
#     Write-Colorized "[----] Download path: <blue>$download_path</blue>"

#     try {
#         Write-Colorized "[<yellow>WAIT</yellow>] Downloading uMod archive ..."
#         $ProgressPreference = 'SilentlyContinue'
#         Invoke-WebRequest -Uri $download_link -OutFile $download_path
#         Write-Colorized "[ <green>OK</green> ] uMod build downloaded successfully."
#     } catch {
#         Write-Colorized "[<red>FAIL</red>] Could not download uMod archive: <red>$_</red>"
#         return $false
#     } finally {
#         $ProgressPreference = 'Continue'
#     }

#     try {
#         Write-Colorized "[<yellow>WAIT</yellow>] Extracting uMod files ..."
#         Expand-Archive -Path $download_path -DestinationPath = $settings.server_path -Force
#         Write-Colorized "[ <green>OK</green> ] Files were extracted successfully."
#     } catch {
#         Write-Colorized "[<red>FAIL</red>] Could not extract uMod files from archive: <red>$_</red>"
#         return $false
#     }

#     Write-Colorized "[ <green>OK</green> ] uMod was successfully updated."
#     return $true
# }

# function Install-Server {
#     Write-Colorized "[----] Preparing for server update ..."
#     $installation_path = Resolve-PathNoFail $settings.server_path
#     $steamcmd_script_path = Resolve-PathNoFail $settings.steamcmd_script_path
#     $steamcmd_installation_path = Resolve-PathNoFail $settings.steamcmd_installation_path
#     Write-Colorized "[----] Server installation folder: <blue>$installation_path</blue>"
#     Write-Colorized "[----] SteamcmdHelper script path: <blue>$steamcmd_script_path</blue>"
#     Write-Colorized "[----] Steamcmd installation path: <blue>$steamcmd_installation_path</blue>"

#     if (!(Test-Path $steamcmd_script_path)) {
#         Write-Colorized "[<red>FAIL</red>] Could not find steamcmdHelper script, make sure it's located at: $steamcmd_script_path"
#         return $false
#     }

#     try {
#         Write-Colorized "[<yellow>WAIT</yellow>] Updating server files ..."
#         Start-Process -FilePath $steamcmd_script_path -ArgumentList "-AppID $appID -InstallDir $installation_path -SteamcmdDir $steamcmd_installation_path -Validate !$Force" -NoNewWindow -Wait -ErrorAction Stop -PassThru
#         if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 7) {
#             throw "Script returned code $LASTEXITCODE."
#         }
#         Write-Colorized "[ <green>OK</green> ] Server updated successfully."
#         return $true
#     } catch {
#         Write-Colorized "[<red>FAIL</red>] Could not update server using SteamcmdHelper: <red>$_</red>"
#         return $false
#     }
# }

# #endregion
