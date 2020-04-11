#!/usr/bin/env bash
#requires -modules 'PSColorizer'

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param (

    [Parameter(ParameterSetName = 'NonInteractive')]
    [switch]$Start,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [switch]$Update,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [switch]$UpdateServer,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [switch]$UpdateUmod,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [switch]$Clean,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [string[]]$ScriptSettings,

    [Parameter(ParameterSetName = 'NonInteractive')]
    [string[]]$ServerConfig,

    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive
)

class Settings {
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

    [string]GetManagedFolderPath() {
        return Join-Path -Path $this.server_path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed'
    }

    [string]GetServerIdentityFolderPath() {
        return Join-Path -Path $this.server_path -ChildPath 'server' -AdditionalChildPath $this.server_identity
    }

    [string]GetServerCfgFolderPath() {
        return Join-Path -Path $this.GetServerIdentityFolderPath() -ChildPath 'cfg'
    }

    [string]GetServerAutoFilePath() {
        return Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'serverauto.cfg'
    }

    [string]GetServerCfgFilePath() {
        return Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'server.cfg'
    }

    [string]GetServerUsersFilePath() {
        return Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'users.cfg'
    }

    [string]GetServerBansFilePath() {
        return Join-Path -Path $this.GetServerCfgFolderPath() -ChildPath 'bans.cfg'
    }
}

[Settings]$settings = [Settings]::new()

$appID = 258550

$umod_dl = @{ # this is a lie - actually its oxide download links :-P might be changed in the future
    master  = 'https://umod.org/games/rust/download'
    develop = 'https://umod.org/games/rust/download/develop'
}

$umod_api_link = 'https://umod.org/games/rust.json'

$umod_game_lib_name = 'Oxide.Rust.dll' # will be changed in the future with umod release

function Install-UMod {
    Write-Colorized "[----] Preparing to update uMod ..."

    if ($IsWindows) {
        # this is just a temp solution for now. oxide/umod builds might be united again
        $download_link = $umod_dl.master
    } elseif ($IsLinux) {
        $download_link = $umod_dl.develop
    } else {
        throw 'Your platform is unsupported.'
    }

    $managed_folder_path = $settings.GetManagedFolderPath()
    $oxide_rust_path = Resolve-PathNoFail -Destination (Join-Path $managed_folder_path $umod_game_lib_name)

    $lib_exists = Test-Path $oxide_rust_path

    if (!$lib_exists) {
        Write-Colorized "[<red>XXXX</red>] uMod is not installed, installing now ..."
    } elseif (!(Test-NeedOxideUpdate)) {
        Write-Colorized "[<red>XXXX</red>] uMod is outdated, updating ..."
    } else {
        Write-Colorized "[ <green>OK</green> ] uMod update is unnecessary."
        return $true
    }

    $download_path = Split-Path -Path $download_link -Leaf

    Write-Colorized "[----] Download link: <blue>$download_link</blue>"
    Write-Colorized "[----] Download path: <blue>$download_path</blue>"

    try {
        Write-Colorized "[<yellow>WAIT</yellow>] Downloading uMod archive ..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $download_link -OutFile $download_path
        Write-Colorized "[ <green>OK</green> ] uMod build downloaded successfully."
    } catch {
        Write-Colorized "[<red>FAIL</red>] Could not download uMod archive: $_"
        return $false
    } finally {
        $ProgressPreference = 'Continue'
    }

    
}

#region Helpers

function Test-NeedOxideUpdate {
    param (

    )

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

#endregion
