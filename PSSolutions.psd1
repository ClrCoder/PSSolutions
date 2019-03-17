@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'PSSolutions.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.3'

    # ID used to uniquely identify this module
    GUID              = '642DC5CF-400A-41E4-80AE-81F57CDF3857'

    # Author of this module
    Author            = 'ClrCoder community'

    # Copyright statement for this module
    Copyright         = '(c) 2019 ClrCoder community'

    # Description of the functionality provided by this module
    Description       = 'Manages PowerShell solutions, see https://github.com/PowerShell/PowerShell/issues/9098'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Get-PSSolution',
        'Import-PSSolution',
        'Remove-PSSolution'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess.
    # This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('Solutions', 'VirtualEnvironment', 'Dependencies')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/ClrCoder/PSSolutions/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/ClrCoder/PSSolutions'

            # ReleaseNotes of this module
            ReleaseNotes = 'https://github.com/ClrCoder/PSSolutions/blob/master/CHANGELOG.md'
        }
    }
}
