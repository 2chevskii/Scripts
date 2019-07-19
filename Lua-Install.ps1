Add-Type -AssemblyName System.IO.Compression.FileSystem;



### Variables ###

#Setup target lua version
$version = '5.3.5';

#Setup target paths
$workDir = $PSScriptRoot;
$docPath = "$workDir\doc";
$binPath = "$workDir\bin";
$includePath = "$workDir\include";

#Setup build paths
$buildDir = "$workDir\lua-$version";

###

### Functions ###

function Print-Colored {
    param (
        $message,
        $color = [System.ConsoleColor]::Blue
    )
    try {
        # Storing default color of the console text to set it back later
        $previousColor = $Host.UI.RawUI.ForegroundColor;

        # Assigning new output color
        $Host.UI.RawUI.ForegroundColor = $color;

        # Writing message
        Write-Host $message;

        # Restoring default color
        $Host.UI.RawUI.ForegroundColor = $previousColor;
    }
    catch {
        OnException $_.Exception
    }
}

function Download-Lua-Source {

    Print-Colored "Lua source download started..." ([System.ConsoleColor]::Yellow)
    try {
        $webClient = New-Object System.Net.WebClient;
    
        # Downloading lua version defined above
        $webClient.DownloadFile("http://www.lua.org/ftp/lua-$version.tar.gz", "$workDir\lua-$version.tar.gz");
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Lua source download finished." ([System.ConsoleColor]::Green)
}

function Extract-Gzip {
    param (
        $inputPath,
        $outputPath = ($inputPath -replace '\.gz$', "")
    )

    try {
        # Opening necessary streams
        $input = New-Object System.IO.FileStream $inputPath, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $output = New-Object System.IO.FileStream $outputPath, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
        $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

        $buffer = New-Object byte[](1024)

        # Reading the stream to end
        while ($true) {
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0) {
                break;
            }
            $output.Write($buffer, 0, $read)
        }

        # Closing streams
        $gzipStream.Close()
        $output.Close()
        $input.Close()
    }
    catch {
        OnException $_.Exception
    }

}

function Extract-Lua-Source {
    Print-Colored "Lua source extraction started..." ([System.ConsoleColor]::Yellow)

    try {
        # We have to deal with GZip through .Net directly
        Extract-Gzip "$workDir\lua-$version.tar.gz";

        # Download SevenZipSharp if it is not installed already
        if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
            Install-Package -Scope CurrentUser -Force 7Zip4PowerShell > $null
        }

        # SevenZipSharp will handle tar for us
        Expand-7Zip -ArchiveFileName "$workDir\lua-$version.tar" -TargetPath "$workDir";
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Lua source extraction finished." ([System.ConsoleColor]::Green)
}

function Clear-Temp-Files {
    Print-Colored "Removing temp files..." ([System.ConsoleColor]::Yellow)

    try {
        Remove-Item -Path "$workDir\lua-$version.tar.gz";
        Remove-Item -Path "$workDir\lua-$version.tar";
        Remove-Item -Path "$buildDir" -Recurse -Force
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Temp files removed." ([System.ConsoleColor]::Green)
}

function Build-Lua-Source {
    Print-Colored "Compiling Lua..." ([System.ConsoleColor]::Yellow)
    
    try {
        Set-Location -Path $buildDir
    
        cmd.exe /C "mingw32-make mingw"

        Set-Location -Path $workDir
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Lua compiled successfully..." ([System.ConsoleColor]::Green)
}

function Distinct-Installed-Files {
    Print-Colored "Cleaning up installation..." ([System.ConsoleColor]::Yellow)

    try {
        New-Item -Path $docPath -ItemType Directory;
        New-Item -Path $binPath -ItemType Directory;
        New-Item -Path $includePath -ItemType Directory;

        Copy-Item -Path "$buildDir\doc\*.*" -Destination $docPath

        Copy-Item -Path "$buildDir\src\*.dll" -Destination $binPath
        Copy-Item -Path "$buildDir\src\*.exe" -Destination $binPath

        Copy-Item -Path "$buildDir\src\luaconf.h" -Destination $includePath
        Copy-Item -Path "$buildDir\src\lua.h" -Destination $includePath
        Copy-Item -Path "$buildDir\src\lualib.h" -Destination $includePath
        Copy-Item -Path "$buildDir\src\lauxlib.h" -Destination $includePath
        Copy-Item -Path "$buildDir\src\lua.hpp" -Destination $includePath
    }
    catch [System.Exception] {
        OnException $_.Exception
    }

    Print-Colored "Installation directory cleaned..." ([System.ConsoleColor]::Green)
    
}

function Set-Env-Path {
    Print-Colored "Setting enviroment path..." ([System.ConsoleColor]::Yellow)

    try {
        $value = Get-ItemProperty -Path HKCU:\Environment -Name Path
        $newpath = $value.Path += ";$workDir"
        Set-ItemProperty -Path HKCU:\Environment -Name Path -Value $newpath
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Enviroment path set..." ([System.ConsoleColor]::Green)
}

function OnException {
    param (
        [System.Exception]$ex
    )
    
    Print-Colored "Exception occured: $($ex.Message), terminating script. Press any key to continue." ([System.ConsoleColor]::Red)
    Pause;
    Exit;
}

function Main {
    Print-Colored "Lua installation started..." ([System.ConsoleColor]::Yellow)

    try {
        Download-Lua-Source;
        Extract-Lua-Source;
        Build-Lua-Source;
        Distinct-Installed-Files;

        Clear-Temp-Files;

        Set-Env-Path;
    }
    catch {
        OnException $_.Exception
    }

    Print-Colored "Lua has been installed successfully, press any key to exit." ([System.ConsoleColor]::Green)
    Pause;
}

###

### Entry point ###

Main;