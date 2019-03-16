function Get-IsUnix() {
    [outputtype("bool")]
    param()
    return ($null -eq $IsWindows) -or !($IsWindows)
}

function Get-PathVar {
    [outputtype("string[]")]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$VarName
    )

    if (!$VarName) {
        if (Get-IsUnix) {
            $VarName = "PATH"
        }
        else {
            $VarName = "Path"
        }
    }

    $pathString = (Get-Item env:$VarName).Value
    return $pathString -split [IO.Path]::PathSeparator
}
function Set-PathVar {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string[]] $Parts,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$VarName
    )

    if (!$VarName) {
        if (Get-IsUnix) {
            $VarName = "PATH"
        }
        else {
            $VarName = "Path"
        }
    }

    $pathString = $Parts -join [IO.Path]::PathSeparator
    Set-Item -Path env:$VarName -Value $pathString
}
