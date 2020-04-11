#!/usr/bin/env pwsh
#requires -modules 'PSColorizer'

#region Parameters

[CmdletBinding(DefaultParameterSetName = 'AllParameterSets')]
param (
    [Parameter(Position = 0)]
    [Alias('id')]
    [int]$AppID,

    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { $AppID }, ErrorMessage = 'Cannot set installation directory without AppID provided.')]
    [Alias('dir')]
    [string]$InstallDir,

    [ValidateNotNullOrEmpty()]
    [Alias('bn')]
    [string]$BranchName,

    [ValidateNotNullOrEmpty()]
    [ValidateScript( { $BranchName }, ErrorMessage = 'Cannot set branch password without BranchName provided.')]
    [Alias('bp')]
    [string]$BranchPass,

    [switch]$Validate,

    [Parameter(Position = 2)]
    [ValidateNotNullOrEmpty()]
    [Alias('cmddir')]
    [string]$SteamcmdDir,

    [switch]$Cleanup,

    [Parameter(ParameterSetName = 'Auth', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Alias('username')]
    [string]$Login,

    [Parameter(ParameterSetName = 'Auth')]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [Parameter(ParameterSetName = 'Auth')]
    [ValidateNotNullOrEmpty()]
    [Alias('sgc', 'guard')]
    [string]$SteamGuard
)

#endregion

#region Globals

$script_info = @{
    name           = 'SteamCMD HELPER'
    author         = '2CHEVSKII'
    version        = @{
        major = 3
        minor = 0
        patch = 1
    }
    license        = 'MIT LICENSE'
    'license-link' = 'https://www.tldrlegal.com/l/mit'
    repository     = 'https://github.com/2chevskii/Automation'
}

$steamcmd_download_link = @{
    windows = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'
    linux   = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
    macos   = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz'
}

$steamcmd_exit_codes = @{
    0  = ($true, 'SUCCESS')
    1  = ($false, 'UNKNOWN ERROR')
    2  = ($false, 'ALREADY LOGGED IN')
    3  = ($false, 'NO CONNECTION')
    5  = ($false, 'INVALID PASSWORD')
    7  = ($true, 'INITIALIZED')
    8  = ($false, 'FAILED TO INSTALL')
    63 = ($false, 'STEAM GUARD REQUIRED')
}

$default_window_title = $Host.UI.RawUI.WindowTitle

$steamcmd_executable_name = $IsWindows ? 'steamcmd.exe' : 'steamcmd.sh'

$current_exit_code = 0

#endregion

#region Script info

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
        [switch]$unset
    )

    if ($unset) {
        $Host.ui.RawUI.WindowTitle = $default_window_title
    } else {
        $Host.UI.RawUI.WindowTitle = $script_info.name
    }
}

#endregion

#region Core

function Install-Steamcmd {
    Write-Colorized "[<yellow>WAIT</yellow>] Installing steamcmd into: <blue>$env:STEAMCMD_HOME</blue> ..."

    New-Item -ItemType Directory -Path $env:STEAMCMD_HOME -ErrorAction SilentlyContinue | Out-Null

    $link = $IsWindows ? $steamcmd_download_link.windows : $IsLinux ? $steamcmd_download_link.linux : $steamcmd_download_link.macos

    $download_path = Join-Path $env:STEAMCMD_HOME (Split-Path -Path $link -Leaf)

    if (Test-Path $download_path) {
        Write-Colorized "[<green> OK </green>] Found steamcmd archive on disk ..."
    } else {
        try {
            Write-Colorized "[<yellow>WAIT</yellow>] Downloading steamcmd ..."
            Write-Colorized "[----] Download link: <blue>$link</blue>"
            Write-Colorized "[----] Download path: <blue>$download_path</blue>"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $link -OutFile $download_path
            $ProgressPreference = 'Continue'
            Write-Colorized "[<green> OK </green>] Steamcmd downloaded."
        } catch {
            Write-Colorized "[<red>FAIL</red>] Could not download steamcmd: <red>$_</red>"
            return 1111
        }
    }

    try {
        Write-Colorized "[<yellow>WAIT</yellow>] Extracting steamcmd archive ..."
        if ($IsWindows) {
            Expand-Archive -Path $download_path -DestinationPath $env:STEAMCMD_HOME -Force -ErrorAction Stop | Out-Null
        } elseif (!(Get-Command 'tar' -ErrorAction SilentlyContinue)) {
            throw 'Tar not found.'
        } else {
            $process = Start-Process -FilePath 'tar' -ArgumentList "-C $env:STEAMCMD_HOME -xvzf $download_path" -PassThru -Wait -NoNewWindow
            if ($process.ExitCode -ne 0) {
                throw "Tar returned $($process.ExitCode)."
            }
        }
    } catch {
        Write-Colorized "[<red>FAIL</red>] Could not extract steamcmd archive: <red>$_</red>"
        return 1112
    }

    $deps_code = Install-Dependencies

    if ($deps_code -ne 0) {
        return $deps_code
    }

    if ($Cleanup) {
        try {
            Write-Colorized "[<yellow>WAIT</yellow>] Cleaning up steamcmd archive ..."
            Remove-Item -Path $download_path -ErrorAction Stop
            Write-Colorized "[<green> OK </green>] Archive removed."
        } catch {
            Write-Colorized "[<red>FAIL</red>] Could not delete steamcmd archive: <red>$_</red>"
        }
    }

    Write-Colorized "[<green> OK </green>] Steamcmd installed."

    return 0
}

function Install-Application {
    Write-Colorized "[<yellow>WAIT</yellow>] Installing app <blue>$AppID</blue> ..."

    if (!$InstallDir) {
        $InstallDir = Resolve-PathNoFail "app-$AppID"
    } else {
        $InstallDir = Resolve-PathNoFail $InstallDir
    }

    Write-Colorized "[----] Installation folder: <blue>$InstallDir</blue>"

    $launch_args = (Get-AuthInfo) + " +force_install_dir `"$InstallDir`"" + " +app_update $AppID"

    if ($BranchName) {
        $launch_args += " -beta `"$BranchName`""
    }

    if ($BranchPass) {
        $launch_args += " -betapassword `"$BranchPass`""
    }

    if ($Validate) {
        $launch_args += ' -validate'
    }

    $launch_args += ' +quit'

    Write-Colorized "[<yellow>WAIT</yellow>] Launching steamcmd ..."

    $current_exit_code = (Start-Process -FilePath "$env:STEAMCMD_HOME/$steamcmd_executable_name" -ArgumentList "$launch_args" -NoNewWindow -Wait -PassThru).ExitCode

    $exit_code_meaning = $steamcmd_exit_codes[$current_exit_code]

    if ($exit_code_meaning[0]) {
        Write-Colorized "[<green> OK </green>] App <blue>$AppID</blue> installed successfully."
    } else {
        Write-Colorized "[<red>FAIL</red>] Could not properly install app <blue>$AppID</blue>`: <red>$($exit_code_meaning[1])</red>"
    }

    return $current_exit_code
}

#endregion

#region Util

function Install-Dependencies {
    if ($IsLinux) {
        Write-Colorized "[----] Installing steamcmd dependencies ..."

        $os_release = Get-Content -Path '/etc/os-release'

        $os_name = $os_release[0]

        if ($os_name -like '*ubuntu*') {
            Write-Colorized "[<yellow>WAIT</yellow>] Installing lib32gcc1 ..."
            &sudo apt-get install lib32gcc1
        } elseif ($os_name -like '*redhat*' -or $os_name -like '*centos*') {
            Write-Colorized "[<yellow>WAIT</yellow>] Installing glibc, libstdc++ ..."
            &yum install glibc libstdc++
        } elseif ($os_name -like '*arch*') {
            Write-Colorized "[<yellow>WAIT</yellow>] Installing glibc.i686, libstdc++.i686 ..."
            &yum install glibc.i686 libstdc++.i686
        } else {
            Write-Colorized "[ <green>OK</green> ] No dependencies required on this os."
            return 0
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Colorized "[<red>FAIL</red>] Failed to install steamcmd dependencies."
            return 1114
        } else {
            Write-Colorized "[ <green>OK</green> ] Steamcmd dependencies were installed successfully."
        }
    }

    return 0
}

function Get-AuthInfo {
    if (!$Login) {
        return '+login anonymous'
    }

    return "+login `"$Login`"" + ($Password ? " `"$Password`"" : [string]::Empty) + ($SteamGuard ? " `"$SteamGuard`"" : [string]::Empty)
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

function Test-SteamcmdInstallation {
    return Test-Path "$env:STEAMCMD_HOME/$steamcmd_executable_name"
}

#endregion

#region Main

Set-WindowTitle
Write-ScriptInfo

if ($SteamcmdDir) {
    $env:STEAMCMD_HOME = Resolve-PathNoFail $SteamcmdDir
} elseif ($env:STEAMCMD_HOME) {
    $env:STEAMCMD_HOME = Resolve-PathNoFail $env:STEAMCMD_HOME
} else {
    $env:STEAMCMD_HOME = Resolve-PathNoFail 'steamcmd/'
}

Write-Colorized '[----] Checking steamcmd installation ...'
$steamcmd_installed = Test-SteamcmdInstallation

if ($steamcmd_installed) {
    Write-Colorized "[ <green>OK</green> ] Steamcmd installed already."
} else {
    Write-Colorized "[<red>XXXX</red>] Steamcmd is not installed."
    $current_exit_code = Install-Steamcmd
}

if ($AppID -and $current_exit_code -eq 0) {
    $current_exit_code = Install-Application
}

Set-WindowTitle -unset

exit $current_exit_code

#endregion
    $current_exit_code = Install-Application
}

Set-WindowTitle -unset

exit $current_exit_code

#endregion
