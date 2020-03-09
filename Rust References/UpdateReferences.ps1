#!/usr/bin/env pwsh

using namespace System.IO

[CmdletBinding()]
param(
    [Alias('p', 'targetdir')]
    [ValidateNotNullOrEmpty()]
    [string]$Path = (Join-Path $PSScriptRoot '../References'),
    [Alias('d', 'downloader')]
    [ValidateNotNullOrEmpty()]
    [string]$DepotDownloader = (Join-Path $PSScriptRoot 'DepotDownloader'),
    [Alias('f', 'files')]
    [ValidateNotNullOrEmpty()]
    [string]$FileList = (Join-Path $PSScriptRoot '.references')
)

if (!(Get-Command -Name 'dotnet')) {
    Write-Error ".NET is not installed!"
    exit 1
}

if (!(Test-Path -Path $FileList)) {
    Write-Error "Could not find filelist to download!"
    exit 1
}

if (!(Test-Path -Path $DepotDownloader)) {
    Write-Error "Could not find DepotDownloader directory!"
    exit 1
}

$depot_bin = Join-Path -Path $DepotDownloader -ChildPath 'DepotDownloader.dll'

if (!(Test-Path -Path $depot_bin)) {
    Write-Error "Could not find DepotDownloader binary!"
    exit 1
}

$depot_bin = Resolve-Path -Path $depot_bin

New-Item $Path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$Path = Resolve-Path $Path

$Path_Original = Join-Path $Path 'Original'

$Path_Modded = Join-Path $Path 'Modded'

New-Item $Path_Original, $Path_Modded -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$temp = Join-Path $PSScriptRoot 'temp'
$downloads = Join-Path $temp 'downloads'
$oxide = Join-Path $temp 'Oxide'
$oxide_archive = Join-Path $temp 'oxide-latest.zip'

New-Item $temp, $downloads, $oxide -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

try {
    Write-Output "Using DepotDownloader to download latest game libraries..."

    Start-Process -FilePath 'dotnet' -ArgumentList "$depot_bin -dir $downloads -app 258550 -filelist $FileList -validate" -NoNewWindow -Wait

    Write-Output "Downloading latest Oxide build..."

    Invoke-WebRequest -Uri 'https://umod.org/games/rust/download' -OutFile $oxide_archive

    Expand-Archive -Path $oxide_archive -DestinationPath $oxide -Force

    $orig_files = Get-ChildItem (Join-Path -path $downloads -childpath 'RustDedicated_Data' -AdditionalChildPath 'Managed') | Where-Object { $_.Extension -eq '.dll' }
    $mod_files = Get-ChildItem (Join-Path -path $oxide -childpath 'RustDedicated_Data' -AdditionalChildPath 'Managed') | Where-Object { $_.Extension -eq '.dll' }

    $file_count = $orig_files.Length + $mod_files.Length

    $complete_count = 0

    function Get-CompletePercentage {
        return [int]($complete_count / $file_count * 100)
    }

    Write-Output "Copying files..."

    foreach ($file in $orig_files) {
        $perc = Get-CompletePercentage

        $target_path = Join-Path $Path_Original $file.Name
        Write-Progress -Activity 'Copying files' -PercentComplete $perc -Status "[$perc%] Copying original file $($file.Name) to $target_path"
        $file.CopyTo($target_path, $true) | Out-Null

        $target_path = Join-Path $Path_Modded $file.Name
        Write-Progress -Activity 'Copying files' -PercentComplete $perc -Status "[$perc%] Copying original file $($file.Name) to $target_path"
        $file.CopyTo($target_path, $true) | Out-Null
        $complete_count++
    }

    foreach ($file in $mod_files) {
        $perc = Get-CompletePercentage
        $target_path = Join-Path $Path_Modded $file.Name
        Write-Progress -Activity 'Copying files' -PercentComplete $perc -Status "[$perc%] Copying modded file $($file.Name) to $target_path"

        $file.CopyTo($target_path, $true) | Out-Null
        $complete_count++
    }

    Write-Progress -Activity 'Copying files' -PercentComplete 100 -Completed
} catch {
    Write-Error 'Could not finish update process:'
    Write-Error $_
}

try {
    Write-Output "Removing temp files..."

    Remove-Item $temp -Force -Recurse
} catch {
    Write-Warning 'Could not delete temp files:'
    Write-Warning $_.Exception.Message
}

Write-Output 'Successfully updated references!'
