#!/usr/bin/env pwsh

using namespace System
using namespace System.Text.RegularExpressions

[CmdletBinding()]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "password")]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "branchpassword")]
param (
    [Parameter(Position = 0)]
    [Alias('i', 'id', 'app')]
    [int]$AppID,
    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( { $AppID })]
    [Alias('d', 'dir', 'location')]
    [string]$AppDir,

    [Parameter(Position = 6)]
    [ValidateNotNullOrEmpty()]
    [Alias('b', 'branch')]
    [string]$BranchName,
    [Parameter(Position = 7)]
    [ValidateScript( { $BranchName }, ErrorMessage = 'BranchName parameter must be specified when using BranchPassword')]
    [Alias('bp', 'bpass', 'branchpass')]
    [string]$BranchPassword,

    [Alias('v')]
    [switch]$Validate,

    [Parameter(Position = 2)]
    [ValidateNotNullOrEmpty()]
    [Alias('cmd', 'cmddir', 'steamcmd')]
    [string]$SteamcmdDir,
    [switch]$CleanArchive,

    [Parameter(ParameterSetName = 'Authorized', Position = 3)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(?!^anonymous$).*$', ErrorMessage = 'If you want to login as anonymous - just leave this parameter blank')]
    [Alias('l', 'u', 'user', 'username')]
    [string]$Login,
    [Parameter(ParameterSetName = 'Authorized', Position = 4)]
    [ValidateNotNullOrEmpty()]
    [Alias('p', 'pass')]
    [string]$Password,
    [Parameter(ParameterSetName = 'Authorized', Position = 5)]
    [ValidateNotNullOrEmpty()]
    [Alias('guard', 'code')]
    [string]$SteamGuardCode
)

#region Fields

$script_info = @{
    name           = 'SteamCMD HELPER'
    author         = '2CHEVSKII'
    version        = @{
        major = 2
        minor = 3
        patch = 0
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

#endregion

#region Core

function Install-SteamCMD {
    param(
        [string]$installation_path
    )

    $exec_path = Join-Path $installation_path ($IsWindows ? 'steamcmd.exe' : 'steamcmd')

    if (Test-Path $exec_path) {
        Write-Console '<darkgray>Steamcmd installed already</darkgray>'
        return
    }

    New-Item -ItemType Directory -Path $installation_path -ErrorAction SilentlyContinue | Out-Null

    $dl_link = if ($IsWindows) {
        $steamcmd_download_link.windows
    } elseif ($IsLinux) {
        $steamcmd_download_link.linux
    } else {
        $steamcmd_download_link.macos
    }

    $arch_name = [System.Linq.Enumerable]::Last([object[]]$dl_link.Split('/'))

    $arch_path = Join-Path $installation_path $arch_name

    if (Test-Path $arch_path) {
        Write-Console '<darkgray>Found an existing steamcmd archive</darkgray>'
    } else {
        Write-Console "[---] Downloading $arch_name"
        Invoke-WebRequest -Uri $dl_link -OutFile $arch_path
    }

    Write-Console "[---] Extracting steamcmd archive"

    try {
        if ($IsWindows) {
            Expand-Archive -Path $arch_path -DestinationPath $installation_path -Force -ErrorAction Stop
        } else {
            &tar -C $installation_path -xvzf $arch_path
        }
    } catch {
        Write-Console '<red>FAIL! Could not extract steamcmd archive. Will retry in a second</red>'
        if (Wait-WithPrompt -msg 'Press any key to cancel and exit' -seconds 3) {
            Remove-Item $arch_path -Force
            Install-SteamCMD -installation_path $installation_path
            return
        }
    }

    if ($IsLinux) {
        Write-Console '[---] Installing dependencies'
        Install-Dependencies
    }

    if ($CleanArchive) {
        Write-Console '[---] Deleting downloaded archive'
        Remove-Item $arch_path -Force
    }
}

function Install-Application {
    param (
        $dir,
        $id,
        $branch_name,
        $branch_pass,
        $username,
        $pass,
        $steamguard,
        $steamcmd_dir,
        $val
    )

    $launchargs = Get-AuthInfo -username $username -userpass $pass -steamgrd $steamguard
    $launchargs += " +force_install_dir $((Force-Resolve-Path -FileName $dir)) +app_update $id"

    if ($branch_name) {
        $launchargs += " -beta $branch_name"

        if ($branch_pass) {
            $launchargs += " -betapassword $branch_pass"
        }
    }

    if ($val) {
        $launchargs += " -validate"
    }

    $launchargs += ' +quit'

    $executable = if ($IsWindows) {
        'steamcmd.exe'
    } else {
        'steamcmd'
    }

    $process_path = Join-Path $steamcmd_dir $executable

    return (Start-Process -FilePath $process_path -ArgumentList $launchargs -NoNewWindow -Wait -PassThru)
}

#endregion

#region Helpers

function Install-Dependencies {
    $os_release = Get-Content -Path '/etc/os-release'

    $os_name = $os_release[0]

    if ($os_name -like '*ubuntu*') {
        &sudo apt-get install lib32gcc1
    } elseif ($os_name -like '*redhat*' -or $os_name -like '*centos*') {
        &yum install glibc libstdc++
    } elseif ($os_name -like '*arch*') {
        &yum install glibc.i686 libstdc++.i686
    }
}

function Get-AuthInfo {
    param(
        [string]$username,
        [string]$userpass,
        [string]$steamgrd
    )

    $arguments = '+login'

    if (!$username) {
        return $arguments + ' anonymous'
    }

    $arguments += " $username $userpass"

    if ($steamgrd) {
        $arguments += " $steamgrd"
    }

    return $arguments
}

function Get-ASCIIBanner {
    param(
        [string]$text
    )

    $request_uri = "http://artii.herokuapp.com/make?text=$($text.Replace(' ', '+'))"

    Invoke-WebRequest -Uri $request_uri | Select-Object -ExpandProperty Content | Out-String
}

function Wait-WithPrompt {
    param (
        [string]$msg,
        [float]$seconds
    )

    $dt = [datetime]::Now
    $pressed = $false
    [int]$lastseconds = 0

    while ($true) {
        $lastseconds = ([timespan]([datetime]::Now - $dt)).TotalSeconds
        $diff = $seconds - $lastseconds
        if ($diff -eq 0) {
            break
        }

        if ($Host.ui.RawUI.KeyAvailable) {
            $pressed = $true
            break
        }


        Write-Host "`r$msg ($diff s)" -NoNewline

        Start-Sleep -Milliseconds 200
    }

    Write-Host "`r"

    return $pressed
}

function Write-Console {
    param(
        [Alias('m', 'msg', 'text')]
        [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
        [string]$message
    )

    $default_color = [Console]::ForegroundColor

    $color_regex_pattern = '(?:<([a-z]+)>((?:(?!<\/\1>).)*)<\/\1>)|((?:(?!<([a-z]+)>.*<\/\4>).)+)'

    $color_regex = [regex]::new($color_regex_pattern, [RegexOptions]::IgnoreCase)

    $mtchs = $color_regex.Matches($message)

    if ($mtchs.Count -gt 0) {

        $colored = @()

        foreach ($match in $mtchs) {
            $color = $default_color
            $msg = $null
            if ($match.Groups[3].Length -gt 0) {
                $msg = $match.Groups[3].Value
            } else {
                $color = $match.Groups[1].Value
                $msg = $match.Groups[2].Value
            }

            $colored += @{
                color   = $color
                message = $msg
            }
        }

        foreach ($colored_message in $colored) {
            if ($colored_message.color) {
                [Console]::ForegroundColor = $colored_message.color
            }

            [Console]::Write($colored_message.message)

            [Console]::ForegroundColor = $default_color
        }

        [Console]::Write("`n")
    } else {
        [Console]::WriteLine($message)
    }
}

function Force-Resolve-Path {
    <#
    .SYNOPSIS
        Calls Resolve-Path but works for files that don't exist.
    .REMARKS
        From http://devhawk.net/blog/2010/1/22/fixing-powershells-busted-resolve-path-cmdlet
    #>
    param (
        [string] $FileName
    )

    $FileName = Resolve-Path $FileName -ErrorAction SilentlyContinue `
        -ErrorVariable _frperror
    if (-not($FileName)) {
        $FileName = $_frperror[0].TargetObject
    }

    return $FileName
}

#endregion

#### WELCOME SCREEN

Get-ASCIIBanner -text $script_info['name']
Write-Console "Author                         -> <magenta>$($script_info['author'])</magenta>"
Write-Console "Version                        -> <darkyellow>$($script_info.version.major).$($script_info.version.minor).$($script_info.version.patch)</darkyellow>"
Write-Console "Licensed under the <darkred>$($script_info['license'])</darkred> -> <blue>$($script_info['license-link'])</blue>"
Write-Console "Repository                     -> <blue>$($script_info['repository'])</blue>"

###################

#### CHECKS

if ($PSVersionTable.PSEdition -ne 'Core') {
    Write-Warning 'This script might or might not work correctly on old PS editions. Consider updating to PowerShell Core if you are experiencing issues'
}

if (!$SteamcmdDir) {
    $SteamcmdDir = Join-Path $PWD 'steamcmd'

    Write-Warning "Steamcmd installation path was set to default ($SteamcmdDir)"
}

if ($AppID -and !$AppDir) {
    $AppDir = Join-Path $PWD "app-$AppID"

    Write-Warning "App $AppID installation path was set to default ($AppDir)"
}

###################

#### CHECK/INSTALL STEAMCMD

Write-Console '<yellow>[   ] Steamcmd installation check</yellow>'
Install-SteamCMD -installation_path $SteamcmdDir
Write-Console '<green>[ x ] Steamcmd installed</green>'

###################

#### INSTALL APP

if ($AppID) {
    Write-Console "<yellow>[   ] Installing app $AppID into $AppDir</yellow>"
    $exitcode = (Install-Application -dir $AppDir -id $AppID -branch_name $BranchName -branch_pass $BranchPassword -username $Login -pass $Password -steamguard $SteamGuardCode -steamcmd_dir $SteamcmdDir -val $Validate).exitcode
    Write-Console "<green>[ x ] App $AppID installation finished with code: $exitcode</green>"
}
