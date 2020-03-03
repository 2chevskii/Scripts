#!/usr/bin/env pwsh

using namespace System
using namespace System.Text.RegularExpressions

#region Script parameters

<#
.SYNOPSIS
    Invokes steamcmd actions
.DESCRIPTION
    You can install steamcmd and apps using this script
.EXAMPLE
    SteamCMD.ps1 258550 ./rust-ds ./steamcmdfolder -validate
    Install Rust dedicated server into rust-ds/ folder using steamcmd executable from steamcmdfolder/
.LINK
    https://github.com/2chevskii/Scripts/blob/master/SteamCMD.ps1
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "password")]
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "branchpassword")]
[CmdLetBinding(DefaultParameterSetName = 'LocalInstall', PositionalBinding)]
param (
    ## App
    [Parameter(Position = 0)]
    [Alias('id')]
    [int]$AppID,
    [Parameter(Position = 1)]
    [Alias('dir')]
    [string]$AppInstallPath,
    [switch]$Validate,

    ## Steamcmd executable
    [Parameter(ParameterSetName = 'LocalInstall', Position = 2)]
    [string]$InstallPath,
    [Parameter(ParameterSetName = 'GlobalInstall', Mandatory = $true)]
    [Alias('g')]
    [ValidateScript( { $IsLinux }, ErrorMessage = "GlobalInstall option is only available while using Linux-based OS!")]
    [switch]$GlobalInstall,

    ## Alternative branches
    [Alias('b')]
    [string]$Branch,
    [string]$BranchPassword,

    ## Logging in
    [Parameter(Position = 3)]
    [ValidatePattern('^(?!^anonymous$).*$')]
    [Alias('username', 'user', 'l')]
    [ValidateNotNullOrEmpty()]
    [string]$Login,
    [Parameter(Position = 4)]
    [ValidateNotNullOrEmpty()]
    [Alias('p', 'pass')]
    [string]$Password,
    [Parameter(Position = 5)]
    [ValidateNotNullOrEmpty()]
    [string]$SteamGuard
)

#endregion

#region Constants

$script_name = 'SteamCMD HELPER'
$script_author = '2CHEVSKII'
$script_version = @{
    major = 2
    minor = 2
    patch = 0
}
$script_version_formatted = "v$($script_version.major).$($script_version.minor).$($script_version.patch)"
$script_license_name = 'MIT LICENSE'
$script_license_link = 'https://www.tldrlegal.com/l/mit'
$script_repository = 'https://github.com/2chevskii/Scripts'

$steamcmd_installpath_default = Join-Path -Path $PWD -ChildPath 'steamcmd'
$steamcmd_downloadlink = @{
    windows = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'
    linux   = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
    macos   = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz'
}

$is64bit = [System.Environment]::Is64BitOperatingSystem

enum OSVer {
    WINDOWS
    MACOS
    DEBIAN_UBUNTU
    REDHAT_CENTOS
    ARCH
    NOT_SUPPORTED
}

#endregion

#region Main functions

function Install-Global {
    param(
        [Parameter(ValueFromPipeline)]
        [OSVer]$os
    )

    if (!$IsLinux) {
        throw 'Repository install is only available in Linux systems!'
    }

    if (!(Get-Command -Name 'steamcmd')) {
        Write-Console '<yellow>Installing steamcmd globally</yellow>'

        switch ($os) {
            [OSVer]::DEBIAN_UBUNTU {
                if ($is64bit) {
                    &sudo add-apt-repository multiverse
                    &sudo dpkg --add-architecture i386
                    &sudo apt update
                    &sudo apt install lib32gcc1 steamcmd
                }
                else {
                    &sudo apt install steamcmd
                }
            }
            [OSVer]::REDHAT_CENTOS {
                &yum install steamcmd
            }
            [OSVer]::ARCH {
                &git clone https://aur.archlinux.org/steamcmd.git
                Set-Location steamcmd
                &makepkg -si
                &ln -s /usr/games/steamcmd steamcmd
            }
            default {
                throw 'Your OS does not support repository installation, try another options!'
            }
        }
    }
}

function Install-Local {
    param(
        [Parameter(ValueFromPipeline)]
        [OSVer]$os,
        [string]$path
    )

    if ($os -eq [OSVer]::NOT_SUPPORTED) {
        throw 'This OS version is not supported'
    }

    if ($os -ne [OSVer]::WINDOWS -and !(Get-Command tar.exe -ErrorAction SilentlyContinue)) {
        throw 'Tar not found'
    }

    switch ($os) {
        WINDOWS {
            $archive_path = Join-Path -Path $path -ChildPath 'steamcmd.zip'
            $dl_link = $steamcmd_downloadlink.windows
            $exec_path = Join-Path -Path $path -ChildPath 'steamcmd.exe'
        }
        MACOS {
            $archive_path = Join-Path -Path $path -ChildPath 'steamcmd.tar.gz'
            $dl_link = $steamcmd_downloadlink.macos
            $exec_path = Join-Path -Path $path -ChildPath 'steamcmd'
        }
        Default {
            $archive_path = Join-Path -Path $path -ChildPath 'steamcmd.tar.gz'
            $dl_link = $steamcmd_downloadlink.linux
            $exec_path = Join-Path -Path $path -ChildPath 'steamcmd'
        }
    }

    # Test if steamcmd exists already
    if (Test-Path $exec_path) {
        return
    }

    # Prepare installation folder 
    New-Item -Path $path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

    try {
        Write-Output '[10%] Downloading steamcmd...'
        Invoke-WebRequest -Uri $dl_link -OutFile $archive_path
    }
    catch {
        throw 'Could not download steamcmd archive'
    }

    if (!(Test-Path $archive_path)) {
        throw 'Steamcmd archive was not downloaded for some reason'
    }

    try {
        Write-Output '[50%] Extracting archive...'
        if ($os -eq [OSVer]::WINDOWS) {
            
            Expand-Archive -Path $archive_path -DestinationPath $path -Force -ErrorAction Stop
        }
        else {
            &tar -C $path -xvzf $archive_path
        }
    }
    catch {
        throw 'Could not extract steamcmd archive'
    }

    try {
        Write-Output '[75%] Installing dependencies...'
        if ($os -eq [OSVer]::DEBIAN_UBUNTU -and $is64bit) {
            &sudo apt-get install lib32gcc1
        }
        elseif ($os -eq [OSVer]::REDHAT_CENTOS -and !$is64bit) {
            &yum install glibc libstdc++
        }
        elseif ($os -eq [OSVer]::REDHAT_CENTOS -and $is64bit) {
            &yum install glibc.i686 libstdc++.i686
        }
    }
    catch {
        throw 'Could not install dependencies'
    }

    try {
        Write-Output '[95%] Cleaning up...'
        Remove-Item -Path $archive_path -Force
    }
    catch {
        Write-Warning 'Error occured while cleaning up temp files'
    }

    if (!(Test-Path -Path $exec_path)) {
        throw 'Cannot find steamcmd executable'
    }

    if ($os -ne [OSVer]::WINDOWS) {
        try {
            Write-Output '[99%] Setting executable mode...'
            &sudo chmod +x $exec_path
        }
        catch {
            Write-Warning 'Could not set steamcmd as executable'
        }
    }
}

function Install-App {

    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$id,
        [Parameter(Position = 1, Mandatory)]
        [string]$dir,
        [string]$branch,
        [string]$branchpass,
        [string]$login,
        [string]$password,
        [string]$steamguard,
        [Parameter(Position = 2)]
        [string]$steamcmdpath,
        [Parameter(Position = 3)]
        [switch]$validate
    )

    $dir = New-Item -ItemType Directory -Path $dir -ErrorAction SilentlyContinue

    write-host "dir: $dir"

    $launchargs = "$(Get-Login $login $password $steamguard) +force_install_dir `"$dir`" +app_update $id"

    if ($branch) {
        $launchargs += " -beta $branch"
    }

    if ($branchpass) {
        $launchargs += " -betapassword $branchpass"
    }

    if ($validate) {
        $launchargs += ' -validate'
    }

    $launchargs += ' +quit'
    $os = Get-OsRelease

    if ($os -eq [OSVer]::NOT_SUPPORTED) {
        throw 'OS is not supported'
    }

    $exec_path = if (!$steamcmdpath) { 'steamcmd' } elseif ($os -eq [OSVer]::WINDOWS) { Join-Path -Path $steamcmdpath -ChildPath 'steamcmd.exe' } else { Join-Path -Path $steamcmdpath -ChildPath 'steamcmd' }

    try {
        Write-Console "App <yellow>$id</yellow> installation requested"

        Start-Process -FilePath $exec_path -ArgumentList "$launchargs" -NoNewWindow -Wait -ErrorAction Stop -PassThru
        
        Write-Console  "App <green>$id</green> installation process finished: <blue>$LASTEXITCODE</blue>"
    }
    catch {
        Write-Console "<red>App $id installation process failed:`n$($_.Exception)</red>"
    }
}

#endregion

#region Helper functions

function Get-Login {
    param(
        [Parameter(Position = 0)]
        [string]$login,
        [Parameter(Position = 1)]
        [string]$password,
        [Parameter(Position = 2)]
        [string]$steamguard
    )
    $creds = '+login'

    if (!$login) {
        return $creds + ' anonymous'
    }

    $creds += " $login $password"
    
    if ($steamguard) {
        $creds += " $steamguard"
    }
    
    return $creds
}

function Get-OsRelease {
    if ($IsWindows) {
        return [OSVer]::WINDOWS
    }

    if ($IsMacOS) {
        return [OSVer]::MACOS
    }

    $os_release = Get-Content -Path '/etc/os-release' -ErrorAction SilentlyContinue

    if (!$os_release) {
        return [OSVer]::NOT_SUPPORTED
    }

    $name = $os_release[0]

    if ($name -like '*ubuntu*') {
        return [OSVer]::DEBIAN_UBUNTU
    }

    if ($name -like '*redhat*' -or $name -like '*centos*') {
        return [OSVer]::REDHAT_CENTOS
    }

    if ($name -like '*arch*') {
        return [OSVer]::ARCH
    }

    return [OSVer]::NOT_SUPPORTED
}

function Get-Distro {
    $os_release = Get-Content -Path '/etc/os-release'

    if ($os_release) {
        $name = $os_release[0]

        if (($name -like '*ubuntu*') -or ($name -like '*debian*')) {
            return 'UBUNTU'
        }

        if (($name -like '*redhat*') -or ($name -like '*centos*')) {
            return 'CENTOS'
        }

        if ($name -like '*arch*') {
            return 'ARCH'
        }
    }

    return $null
}

function Get-Banner {
    param(
        [string]$scriptname
    )

    $ascii_art_generator_link_base = "http://artii.herokuapp.com/make?text="

    $request_link = $ascii_art_generator_link_base + $scriptname.Replace(' ', '+')

    Invoke-WebRequest -uri $request_link | Select-Object -ExpandProperty Content | Out-String
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
            }
            else {
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
    }
    else {
        [Console]::WriteLine($message)
    }
}

#endregion

###################################
########### Entry point ###########
###################################

#region Welcome screen

Get-Banner -scriptname $script_name | Out-Host
Write-Console "Author                         -> <magenta>$script_author</magenta>"
Write-Console "Version                        -> <darkyellow>$script_version_formatted</darkyellow>"
Write-Console "Licensed under the <darkred>$script_license_name</darkred> -> <blue>$script_license_link</blue>"
Write-Console "Repository                     -> <blue>$script_repository</blue>"

#endregion

#region Mics checks

######## Check PS version #########
if ($PSVersionTable.PSEdition -ne 'Core') {
    Write-Warning 'This script might or might not work correctly on old PS editions. Consider updating to PowerShell Core if you are experiencing issues'
}

# Set steamcmd installation paths #
if ($GlobalInstall) {
    $InstallPath = $null
}
elseif (!$InstallPath) {
    $InstallPath = $steamcmd_installpath_default

    Write-Warning "Steamcmd install path was set automatically to '$InstallPath'"
}

### Set app installation paths ###
if ($AppID -and !$AppInstallPath) {
    $AppInstallPath = Join-Path -Path $PWD -ChildPath "app-$AppID"

    Write-Warning "Application install path was set automatically to '$AppInstallPath'"
}

#endregion

#region Install steamcmd

Write-Console "<yellow>[ ] Steamcmd installation check</yellow>"

if ($GlobalInstall) {
    Get-OsRelease | Install-Global
}
else {
    Get-OsRelease | Install-Local -path $InstallPath
}

Write-Console '<green>[x] Steamcmd installed</green>'

#endregion

#region Install application

if ($AppID) {
    Install-App -id $AppID -dir $AppInstallPath -branch $Branch -branchpass $BranchPassword -login $Login -password $Password -steamguard $SteamGuard -steamcmdpath $InstallPath $Validate
}

#endregion

