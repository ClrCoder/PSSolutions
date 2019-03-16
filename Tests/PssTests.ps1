# Performing cleanup
if (Get-Module PSSolutions) {
    Remove-Module PSSolutions -Force
}

. "$PSScriptRoot/../PsPolyfill.ps1"

try {
    Import-Module "$PSScriptRoot/../PSSolutions.psm1" -ErrorAction Stop

    # Checking behavior of selection if the module *.psd1 file have a bad syntax.
    $err = $null
    try {
        Import-PSSolution "$PSScriptRoot/UnknownSolution"
    }
    catch {
        $err = $_
    }

    if (!$err) {
        throw "Unknown path unhandled"
    }

    $originalPSModulePath = $PSModulePath
    $originalPath = Get-PathVar

    Import-PSSolution "$PSScriptRoot/DummySolution" -Verbose
    Write-Host "Second load"
    Import-PSSolution "$PSScriptRoot/DummySolution" -Verbose

    # Testing Get-PSSolution
    $solutions = Get-PSSolution
    $expectedPath = [IO.Path]::GetFullPath("$PSScriptRoot/DummySolution")
    if (!$solutions -or $solutions[0].Name -ne "Default" `
            -or $solutions[0].Path -ne $expectedPath) {
        Write-Host $solutions
        throw "Get-PSSolution does not works properly"
    }

    Remove-PSSolution
    if ($originalPSModulePath -ne $PSModulePath) {
        Write-Host "Original:"
        Write-Host $originalPSModulePath
        Write-Host "Modified:"
        Write-Host $PSModulePath
        throw "Load/Unload roundtrip brokes $PSModulePath"
    }
}
catch {
    throw;
}
