using namespace System
using namespace System.Text.RegularExpressions
using namespace System.Diagnostics.CodeAnalysis





#region Fields

$script_info = @{
    name           = 'RustDS HELPER'
    author         = '2CHEVSKII'
    version        = @{
        major = 2
        minor = 2
        patch = 1
    }
    license        = 'MIT LICENSE'
    'license-link' = 'https://www.tldrlegal.com/l/mit'
    repository     = 'https://github.com/2chevskii/Automation'
}

$constants = @{
    oxide_link         = @{
        windows = 'https://umod.org/games/rust/download'
        linux   = 'https://umod.org/games/rust/download/develop'
        api     = 'https://umod.org/games/rust.json'
    }
    app_id             = 258550
    oxide_archive_name = 'oxide-latest.zip'
    managed_path       = 'RustDedicated_Data/Managed'
}

#endregion

#region Helpers

function Write-Console {
    [SuppressMessageAttribute("PsAvoidUsingWriteHost", "")]
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

function Get-ASCIIBanner {
    param(
        [string]$text
    )

    $request_uri = "http://artii.herokuapp.com/make?text=$($text.Replace(' ', '+'))"

    Invoke-WebRequest -Uri $request_uri | Select-Object -ExpandProperty Content | Out-String
}

function Get-LatestOxideVersion {
    try {
        $response = Invoke-WebRequest -Uri $constants.oxide_link.api | Select-Object -ExpandProperty Content

        $response_object = ConvertFrom-Json -AsHashtable -InputObject $response

        return [version]::new($response_object['latest_release_version'] + '.0')
    } catch {
        return $null
    }
}

function Get-CurrentOxideVersion {
    param(
        [string]$server_path
    )

    $oxide_rust_path = Join-Path -Path $server_path -ChildPath $constants.managed_path -AdditionalChildPath 'Oxide.Rust.dll'
    try {
        $assembly = [Reflection.Assembly]::LoadFile($oxide_rust_path)

        return $assembly.GetName().Version
    } catch {
        return $null
    }
}

function Test-NeedOxideUpdate {
    param(
        [string]$server_path
    )

    $current_version = Get-CurrentOxideVersion -server_path $server_path

    if (!$current_version) {
        Write-Console '<darkgray>Oxide is not installed</darkgray>'
        return $true
    }

    $latest_version = Get-LatestOxideVersion

    if (!$latest_version) {
        Write-Console '<yellow>Could not fetch latest oxide version!</yellow>'
        return $true
    }

    $compare_result = $current_version.CompareTo($latest_version)

    switch ($compare_result) {
        -1 {
            Write-Console '<yellow>Current Oxide version is older than latest</yellow>'
            return $true
        }
        0 {
            Write-Console '<green>Current Oxide version is up-to-date</green>'
        }
        1 {
            Write-Console '<red>Current Oxide version is higher than latest... WTF?</red>'
        }
    }

    return $false
}


#endregion

#
function Update-Server {
    param (
        [string]$dir,
        [string]$cmd_path,
        [string]$cmd_script_path,
        [bool]$clear
    )

    try {
        Write-Console '[---] Preparing for Rust server update'

        if ($clear) {
            Write-Console '[---] Cleaning up old files in the Managed directory'
            Remove-Item -Path "$(Join-Path -Path $dir -ChildPath $constants.managed_path)/*" -ErrorAction SilentlyContinue
            Write-Console '<darkgreen>[10%] Old files removed</darkgreen>'
        }

        Write-Console "[---] Installing RustDedicatedServer into $dir"
        &$cmd_script_path -i $constants.app_id -d $dir -cmd $cmd_path -clean -v
        Write-Console "[99%] Installation finished"

        Write-Console '[ x ] Rust server updated'

    } catch {
        Write-Console '<red>Server update failed with error:</red>'
        Write-Console "<red>$($_.Exception.Message)</red>"
    }
}

function Update-Oxide {
    param (
        [string]$dir#,
        #[bool]$clear # <- clean oxide archive after installation
    )

    Write-Console '<yellow>[---] Preparing for Oxide update</yellow>'
    Write-Console '<yellow>[---] Checking Oxide versions</yellow>'
    if (Test-NeedOxideUpdate -server_path $dir) {
        try {
            Write-Console '<yellow>[---] Started Oxide update</yellow>'

            ## Download build
            $download_link = ($IsWindows ? $constants.oxide_link.windows : $constants.oxide_link.linux)
            Write-Console "<darkgray>[---] Downloading latest version of Oxide from</darkgray> <blue>$download_link</blue>"
            $archive_path = Join-Path -Path $dir -ChildPath $constants.oxide_archive_name
            Invoke-WebRequest -Uri $download_link -OutFile $archive_path
            Write-Console "<darkgreen>[50%]Latest Oxide build downloaded into</darkgreen> <blue>$archive_path</blue>"
            $managed_dir = Join-Path -Path $dir -ChildPath $constants.managed_path

            ## Extract archive
            Write-Console "<darkgray>[---]Extracting Oxide archive into</darkgray> $managed_dir"
            Expand-Archive -Path $archive_path -DestinationPath $managed_dir -Force
            Write-Console "<darkgreen>[99%]Oxide archive upzipped</darkgreen>"

            # ## Maybe cleanup files? Not sure if necessary, gonna leave it commented out for now
            # Write-Console 'Cleaning up temp files'
            # Remove-Item $archive_path
            # Write-Console 'Temp files removed'

            Write-Console '<green>[ x ] Oxide update completed!</green>'
        } catch {
            Write-Console '<red>Oxide update failed with error:</red>'
            Write-Console "<red>$($_.Exception.Message)</red>"
            return $false
        }
    } else {
        Write-Console '<green>[ x ] Oxide update is not necessary</green>'
    }

    return $true
}



#### WELCOME SCREEN

Get-ASCIIBanner -text $script_info['name']
Write-Console "Author                         -> <magenta>$($script_info['author'])</magenta>"
Write-Console "Version                        -> <darkyellow>$($script_info.version.major).$($script_info.version.minor).$($script_info.version.patch)</darkyellow>"
Write-Console "Licensed under the <darkred>$($script_info['license'])</darkred> -> <blue>$($script_info['license-link'])</blue>"
Write-Console "Repository                     -> <blue>$($script_info['repository'])</blue>"

###################
