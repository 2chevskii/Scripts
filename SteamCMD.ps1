param (
    [int]$AppID,
    [string]$AppDir,
    [string]$Branch,
    [string]$BranchPass,
    [string]$Login = "anonymous",
    [string]$Password,
    [string]$SteamGuardCode,
    [string]$SCMDPath,
    [switch]$RepoInstall,
    [switch]$Validate
)

$root = $PSScriptRoot

$steamcmd_dl_win = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip'
$steamcmd_dl_macos = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz'
$steamcmd_dl_linux = 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'

$is64bit = [System.Environment]::Is64BitOperatingSystem

enum OSVer {
    WINDOWS
    MACOS
    DEBIAN_UBUNTU
    REDHAT_CENTOS
    ARCH
    NOT_SUPPORTED
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

function Install-Repository {
    if ($os_release -eq [OSVer]::NOT_SUPPORTED) {
        Write-Host 'Your OS does not support repository installation, try another options!'
        return $false
    }

    $os_release = Get-OsRelease

    switch ($os_release) {
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
    }
}

function Install-Manual {
    param(
        [string]$path
    )

    if (($IsWindows -and (Test-Path -Path "$path/steamcmd.exe")) -or ($IsLinux -and (Test-Path -Path "$path/linux32/steamcmd")) -or ($IsMacOS -and (Test-Path -Path "$path/osx32/steamcmd"))) {
        return $true
    }

    New-Item -Path $path -ItemType Directory -ErrorAction SilentlyContinue

    try {
        if ($IsWindows) {
            Invoke-WebRequest -Uri $steamcmd_dl_win -OutFile "$path/steamcmd.zip"
        }
        elseif ($IsLinux) {
            Invoke-WebRequest -Uri $steamcmd_dl_linux -OutFile "$path/steamcmd.tar.gz"  
        }
        else {
            Invoke-WebRequest -Uri $steamcmd_dl_macos -OutFile "$path/steamcmd.tar.gz"
        }
    }
    catch {
        Write-Host 'Could not download steamcmd archive!' -ForegroundColor Red
        return $false
    }

    if (!(Test-Path "$path/steamcmd.*")) {
        Write-Host 'Cannot find steamcmd archive!' -ForegroundColor Red
        return $false
    }

    try {
        if ($IsWindows) {
            Expand-Archive -Path "$path/steamcmd.zip" -DestinationPath $path -Force
        }
        else {
            &tar -C $path -xvzf "$path/steamcmd.tar.gz"
        }
    }
    catch {
        Write-Host 'Could not expand steamcmd archive!' -ForegroundColor Red
        return $false
    }

    if ($IsLinux) {
        $os_ver = Get-OsRelease

        if ($os_ver -eq [OSVer]::DEBIAN_UBUNTU -and $is64bit) {
            &sudo apt-get install lib32gcc1
        }
        elseif ($os_ver -eq [OSVer]::REDHAT_CENTOS) {
            if ($is64bit) {
                &yum install glibc.i686 libstdc++.i686
            }
            else {
                &yum install glibc libstdc++
            }
        }
    }

    try {
        if ($IsWindows) {
            Remove-Item -Path "$path/steamcmd.zip" -Force
        }
        else {
            Remove-Item -Path "$path/steamcmd.tar.gz" -Force
        }
    }
    catch {
        Write-Warning 'Error occured while removing temp files'
    }

    if ($IsWindows) {
        return Test-Path -Path "$path/steamcmd.exe"
    }
    elseif ($IsLinux) {
        return Test-Path -Path "$path/linux32/steamcmd"
    }
    else {
        return Test-Path -Path "$path/osx32/steamcmd"
    }

}

function Get-LoginCredentials {
    $creds = "+login $Login"

    if ($Password) {
        $creds += " $Password"
    }

    if ($SteamGuardCode -and $Password) {
        $creds += " $SteamGuardCode"
    }

    return $creds
}

function Update-App {
    $cmdlineargs = "$(Get-LoginCredentials) +force_install_dir $AppDir +app_update $AppID"

    if ($Branch) {
        $cmdlineargs += " -beta $Branch"
    }

    if ($BranchPass -and $Branch) {
        $cmdlineargs += " -betapassword $BranchPass"
    }

    if ($Validate) {
        $cmdlineargs += ' validate'
    }

    $cmdlineargs += ' +quit'

    if ($RepoInstall) {
        Write-Warning 'placeholder'
    }
    elseif ($IsMacOS) {
        Write-Warning 'placeholder'
    }
    else {
        Start-Process -FilePath "$SCMDPath/steamcmd.exe" -ArgumentList "$cmdlineargs" -NoNewWindow -Wait
    }
}

if ($RepoInstall -and !$IsLinux) {
    Write-Error '-RepoInstall is only available on Linux!'
    exit 1
}

if (!$SCMDPath) {
    $SCMDPath = "$root/steamcmd"
}

if ($AppDir) {
    New-Item -Path $AppDir -ItemType Directory -ErrorAction SilentlyContinue
    $AppDir = Resolve-Path $AppDir
}
elseif (!$AppDir -and $AppID) {
    $AppDir = "$root/app-$AppID"
}

if ($IsWindows -or $IsMacOS) {
    Write-Host 'Checking installation of steamcmd...' -NoNewline
    $success = Install-Manual -path $SCMDPath

    if ($success) {
        Write-Host 'success' -ForegroundColor Green
    }
    else {
        Write-Host 'Could not install SteamCMD!' -ForegroundColor Red
        exit 1
    }
}

if ($AppID) {
    Write-Host "Installing $AppID into $AppDir"
    Update-App
}
else {
    Write-Host 'No AppID specified, exiting' -ForegroundColor Yellow
}
