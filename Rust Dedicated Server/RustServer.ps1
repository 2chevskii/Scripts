using namespace System
using namespace System.Text.RegularExpressions
using namespace System.Diagnostics.CodeAnalysis

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

Get-ASCIIBanner -text $script_info['name']
Write-Console "Author                         -> <magenta>$($script_info['author'])</magenta>"
Write-Console "Version                        -> <darkyellow>$($script_info.version.major).$($script_info.version.minor).$($script_info.version.patch)</darkyellow>"
Write-Console "Licensed under the <darkred>$($script_info['license'])</darkred> -> <blue>$($script_info['license-link'])</blue>"
Write-Console "Repository                     -> <blue>$($script_info['repository'])</blue>"
