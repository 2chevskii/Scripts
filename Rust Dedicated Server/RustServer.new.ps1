#!/usr/bin/env pwsh

#using namespace System.Linq

[CmdletBinding(PositionalBinding, DefaultParameterSetName = "NotInteractive")]
param (
    [Parameter(Mandatory, ParameterSetName = "Interactive")]
    [Alias('i')]
    [switch]$Interactive,
    
    [Parameter(Position = 0)]
    [Alias('p', 'path')]
    [ValidateNotNullOrEmpty()]
    [string]$ServerPath = "$PSScriptRoot/rust-ds",

    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$SteamCMDPath = "$PSScriptRoot/steamcmd",
    
    [Parameter(ParameterSetName = "NotInteractive")]
    [Alias('s')]
    [switch]$Start,

    [Parameter(ParameterSetName = "NotInteractive")]
    [switch]$UpdateServer,
    [Parameter(ParameterSetName = "NotInteractive")]
    [switch]$UpdateOxide,

    [Parameter(ParameterSetName = "NotInteractive")]
    [Alias('u')]
    [switch]$Update,

    [Parameter(ParameterSetName = "NotInteractive")]
    [ValidateScript( { return ($Update -or $UpdateServer) }, ErrorMessage = 'Clear option can only be specified while issuing a server update')]
    [switch]$Clear,

    [Parameter(ParameterSetName = "NotInteractive")]
    [switch]$Wipe,

    [Parameter(ParameterSetName = "NotInteractive")]
    [switch]$NoConfig,

    [Parameter(ParameterSetName = "NotInteractive")]
    [string[]]$Config,

    [Parameter(ParameterSetName = "NotInteractive")]
    [string[]]$ServerCFG
)

#region WELCOME SCREEN

$script_name = 'Rust dedicated server helper'
$script_author = '2CHEVSKII'
$script_version = @{
    major = 2
    minor = 1
    patch = 0
}
$script_version_formatted = "v$($script_version.major).$($script_version.minor).$($script_version.patch)"
$script_license_link = 'https://www.tldrlegal.com/l/mit'
$script_repository = 'https://github.com/2chevskii/Scripts'

Write-Host "$script_name " -NoNewline
Write-Host "$script_version_formatted " -NoNewline -ForegroundColor DarkYellow
Write-Host 'by ' -NoNewline
Write-Host $script_author -ForegroundColor Magenta
Write-Host 'Licensed under the MIT License: ' -NoNewline
Write-Host $script_license_link -ForegroundColor Blue
Write-Host 'Source repository: ' -NoNewline
Write-Host $script_repository -ForegroundColor DarkBlue

#endregion



$temp = "$PSScriptRoot/temp"
$config_path = "$PSScriptRoot/rustserver-config.json"

function Get-OxideLink {
    $oxide_downloadlinks = @{
        windows = 'https://umod.org/games/rust/download'
        linux   = 'https://umod.org/games/rust/download/develop'
    }

    if ($IsWindows) {
        return $oxide_downloadlinks.windows
    }
    elseif ($IsLinux) {
        return $oxide_downloadlinks.linux
    }
    else {
        throw 'Your OS is invalid, only Linux or Windows are supported!'
    }
}

function Write-ServerCfg {
    param (
        [System.Collections.Generic.List[string]]$values,
        [string]$servercfg_path
    )

    if (!(Test-Path -Path $servercfg_path)) {
        foreach ($value in $values) {
            Out-File -FilePath $servercfg_path -Append -Encoding utf8 -Force -InputObject ($value + "`n")
        }
        return
    }

    $content = New-Object -TypeName System.Collections.Generic.List[string] -ArgumentList @((Get-Content $servercfg_path))

    foreach ($value in $values) {
        $cmd = $value.Split(' ')[0].Trim()

        $index = $content.FindIndex([System.Predicate[string]] {
                param($str)

                $k = $str.split(' ')[0]

                return ($k -eq $cmd) -or ($k.split(' ')[1] -eq $cmd)
            })

        if ($index -eq -1) {
            $content.Add($value)
            continue
        }

        $content[$index] = $value
    }

    foreach ($value in $content) {
        Out-File -FilePath $servercfg_path -Append -Encoding utf8 -Force -InputObject ($value + "`n")
    }
}

function Get-ConfigOptions {
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]]$options
    )

    $dictionary = @{ }

    foreach ($opt in $options) {
        $eqindex = $opt.indexof('=')

        if ($eqindex -eq -1) {
            Write-Warning "Could ont resolve argument: $opt"
            continue
        }

        $k = $opt.Substring(0, $eqindex).trim()

        $v = $opt.Substring($eqindex + 1).trim()

        $dictionary[$k] = $v
    }

    return $dictionary
}

function Start-Server {
    param (
        [string]$server_path,
        [hashtable]$arguments,
        [string]$logpath
    )

    $baseargs = "-batchmode -nographics -logfile `"$logpath`""

    $exe = if ($IsWindows) { 'RustDedicated.exe' } else { 'RustDedicated' }

    $exe_path = Join-Path -Path $server_path -ChildPath $exe

    $argstring = $baseargs

    if ($arguments.Keys.Count -gt 0) {
        
        $argstring += ' '

        foreach ($item in $arguments.Keys) {
            $val = $arguments[$item]
            
            if ($val -is [string] -and $val.Contains(' ')) {
                $val = "`"$val`""
            }

            $argstring += "+$item $val "
        }
    }

    Start-Process -FilePath $exe_path -ArgumentList $argstring -WorkingDirectory $server_path -PassThru -OutVariable 'process'

    return $process
}

function Update-Server {
    param (
        [string]$path,
        [bool]$clean
    )


}

function Get-VersionTable {
    param (
        [string]$version_string
    )

    if (!$version_string) {
        return @{
            major = 0
            minor = 0
            patch = 0
        }
    }

    $arr = $version_string.Split('.')

    $version_table = @{
        major = [int]$arr[0]
        minor = [int]$arr[1]
        patch = [int]$arr[2]
    }

    return $version_table
}

#####################################################################
# Returns 1 if first is greater, 2 if second is greater, 0 is equal #
#####################################################################
function Compare-Versions {
    param (
        [string]$ver1,
        [string]$ver2
    )

    $v1 = Get-VersionTable $ver1
    $v2 = Get-VersionTable $ver2

    if ($v1.major -ne $v2.major) {
        return ($v1.major -gt $v2.major) ? 1 : 2
    }

    if ($v1.minor -ne $v2.minor) {
        return ($v2.minor -gt $v2.minor) ? 1 : 2
    }

    if ($v1.patch -ne $v2.patch) {
        return ($v1.patch -gt $v2.patch) ? 1 : 2
    }

    return 0
}

function Get-LatestOxideVersion {
    $oxide_api_link = 'https://umod.org/games/rust.json'

    $jsonpath = Join-Path -Path $temp -ChildPath 'oxide-latest-version.json'

    Invoke-WebRequest -Uri $oxide_api_link -OutFile $jsonpath

    $oxver = Get-Content -Path $jsonpath -Raw | ConvertFrom-Json -AsHashtable

    Remove-Item $jsonpath -Force

    return $oxver['latest_release_version']
}

function Get-CurrentOxideVersion {
    param (
        [string]$path
    )

    $oxidepath = Join-Path -Path $path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed', 'Oxide.Rust.dll'

    if (!(Test-Path $oxidepath)) {
        return $null
    }

    return [System.Reflection.Assembly]::LoadFile((Resolve-Path $oxidepath)).GetName().Version.ToString('3')
}

function Update-Oxide {
    param (
        [string]$path,
        [bool]$force
    )

    Write-Host 'Checking Oxide versions...'

    $current_version = Get-CurrentOxideVersion $path

    if ($current_version -ne $null) {
        $latest_version = Get-LatestOxideVersion

        $result = Compare-Versions -ver1 $current_version -ver2 $latest_version

        if ($result -eq 0 -or $result -eq 1) {
            if (!$force) {
                Write-Host 'Oxide update is not necessary, current version is: ' -NoNewline
                Write-Host $current_version -ForegroundColor Green
                Write-Host ', latest version is: ' -NoNewline
                Write-Host $latest_version -ForegroundColor ($result -eq 0 ? 'Green' : 'Red')
                return
            }
            else {
                Write-Host "Forcefully updating Oxide from version $current_version to $latest_version" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "New Oxide version ($latest_version) detected! Updating from version $current_version..." -ForegroundColor Green
        }
    }
    else {
        Write-Output 'Oxide is not installed, installing it now...'
    }


    $archpath = Join-Path -Path $temp -ChildPath 'oxide.zip'
    $managedpath = Join-Path -Path $path -ChildPath 'RustDedicated_Data' -AdditionalChildPath 'Managed'
    $oxide_download_link = Get-OxideLink

    Invoke-WebRequest -Uri $oxide_download_link -OutFile $archpath

    Expand-Archive -Path $archpath -DestinationPath $managedpath -Force

    Remove-Item $archpath -Force

}
