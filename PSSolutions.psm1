param()

$PSModulesFolderName = "ps_modules"
$PSScriptsFolderName = "ps_scripts"
$PSSolutionFileName = "ps-solution.json"
$PSSolutionLockFileName = "ps-solution-lock.json"

. $PSScriptRoot/PsPolyfill.ps1

class PSSolution {
    [ValidateNotNullOrEmpty()][string]$Path
}

$ImportedPSSolutions = @{}

function ThrowError {
    # Utility to throw an errorrecord
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,

        [System.Object]
        $ExceptionObject,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )

    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject
    $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
}

$OnRemoveScript = {
    $keys = $ImportedPSSolutions.Keys | % { $_ }
    foreach ($key in $keys) {
        Remove-PSSolution -Name $key
    }
}

$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript

function Get-PSSolutionModule {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,
        [Parameter(Mandatory = $false)]
        [switch] $SkipLoadData
    )
    
    foreach ($dir in Get-ChildItem -LiteralPath $Path -Directory | ? `
        {$_.Name -ne $PSModulesFolderName -and $_.Name -ne $PSScriptsFolderName}) {
        $moduleDataPath = Join-Path $dir.FullName "$($dir.Name).psd1"
        if (Test-Path $moduleDataPath -PathType Leaf) {

            if (!$SkipLoadData) {
                $moduleData = Import-PowerShellDataFile $moduleDataPath -ErrorAction Stop
            }
            
            [PSCustomObject]@{
                "Name"          = $dir.Name
                "LastWriteTime" = $dir.LastWriteTime
                "Data"          = $moduleData
            }
        }
    }
}

function Get-PSSolution {
    param()
    $ImportedPSSolutions.keys | % {[PSCustomObject]@{
            Name = $_
            Path = $ImportedPSSolutions[$_].Path
        }}
}

function Get-LockData {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    
    $lockData = $null
    
    try {
        $lockDataRaw = Get-Content -Raw -Path (Join-Path $Path "$PSSolutionLockFileName") -ErrorAction Stop
        $lockData = $lockDataRaw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        # Do nothing.
    }
    return $lockData
}

function Get-SolutionModulesState {
    param(
        $SolutionModules
    )

    $SolutionModules `
        | % {
        [PSCustomObject]@{ 
            Name  = $_.Name; 
            State = [string]$_.LastWriteTime.Ticks
        }} `
        | Sort-Object Name
}

function Save-ModuleFast {
    param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter(ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [ValidateNotNull()]
        [string]
        $MinimumVersion,

        [Parameter(Mandatory = $true, ParameterSetName = 'NameAndLiteralPathParameterSet')]
        [string]
        $LiteralPath
    )
    
    $module = Find-Module -Name $Name -MinimumVersion $MinimumVersion -ErrorAction Stop
    $targetModulePath = [IO.Path]::Combine($LiteralPath, $module.Name, $module.Version)
    if (!(Test-Path $targetModulePath -PathType Container)) {
        Save-Module -Name $Name -RequiredVersion $module.Version -LiteralPath $LiteralPath -AllowPrerelease -AcceptLicense -Force -ErrorAction Stop
    }
}
function Import-PSSolution {
    [outputtype("PSSolution")]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = "Default",
        [Parameter(Mandatory = $false)]
        [switch]
        $ForceReload = $false
    )

    # Normalizing solution path
    $solutionPath = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).Path, $Path))
    Write-Verbose "PSSolution directory: '$solutionPath'"

    # Checking solution path exists
    if (!(Test-Path $solutionPath -PathType Container)) {
        $errorMessage = "'$solutionPath' not found"
        ThrowError  -ExceptionName "System.ArgumentException" `
            -ExceptionMessage $errorMessage `
            -ErrorId "PathNotFound" `
            -CallerPSCmdlet $PSCmdlet `
            -ExceptionObject $Path `
            -ErrorCategory InvalidArgument
    }

    $oldSolution = $ImportedPSSolutions[$Name]
    
    $lockData = Get-LockData -Path $solutionPath

    # Performing checks for already imported solution
    if ($oldSolution) {
        
        Write-Verbose "Solution 'Name' already loaded, checking module states"
        
        # Disallowing changes of the solution path without explicit unload
        if ($oldSolution.Path -ne $solutionPath) {
            $errorMessage = "Solution with the name '$Name' already loaded with the different path '$($oldSolution.Path)'"
            ThrowError  -ExceptionName "System.ArgumentException" `
                -ExceptionMessage $errorMessage `
                -ErrorId "DifferentPath" `
                -CallerPSCmdlet $PSCmdlet `
                -ExceptionObject $Path `
                -ErrorCategory InvalidArgument
        }

        $solutionModules = Get-PSSolutionModule -Path $solutionPath -SkipLoadData

        $currentState = Get-SolutionModulesState @($solutionModules)
        $oldState = $lockData.moduleState
       
        # Comparing module states
        $stateAreEqual = $false
        if ($currentState.Count -eq $oldState.Count) {
            for ($i = 0; $i -lt $currentState.Count; $i++) {
                if ($currentState[$i].Name -ne $oldState[$i].Name `
                        -or $currentState[$i].State -ne $oldState[$i].State) {
                    break;
                }
            }
            $stateAreEqual = $true
        }
        
        if ($stateAreEqual) {
            Write-Verbose "Modules state has not been changed"
            return;
        }
    }

    # Loading solution modules with their data
    $solutionModules = Get-PSSolutionModule -Path $solutionPath
    
    # Populating modules dictionary
    $solutionModulesDictionary = @{}

    $solutionModules | % {$solutionModulesDictionary.Add($_.Name, $_)}
    
    # Generating dependencies spec of the solution
    $depModules = @()
    foreach ($module in $solutionModules) {
        foreach ($moduleDep in $module.Data.RequiredModules) {
            if (!$solutionModulesDictionary.ContainsKey($moduleDep.ModuleName)) {
                $depModules += [PSCustomObject]@{
                    Name           = $moduleDep.ModuleName
                    MinimumVersion = $moduleDep.ModuleVersion
                }
            }
        }
    }
    
    # Normalizing dependencies specs
    $depModules = @($depModules | `
        Group-Object {$_.Name + [char]0x0 + $_.MinimumVersion} | `
        Sort-Object -Property Name | `
        % {[PSCustomObject]@{
            Name           = $_.Group[0].Name 
            MinimumVersion = $_.Group[0].MinimumVersion
        }})

    $depModulesNotChanged = $false
    $oldDepModules = $lockData.DependencyModules

    if ($oldDepModules.Count -eq $depModules.Count) {
        for ($i = 0; $i -lt $oldDepModules.Count; $i++) {
            if ($oldDepModules[$i].Name -ne $depModules[$i].Name `
                    -or $oldDepModules[$i].MinimumVersion -ne $depModules[$i].MinimumVersion) {
                break;
            }
        }
        $depModulesNotChanged = $true
    }

    $depMdulesPath = Join-Path $solutionPath $PSModulesFolderName

    # TODO: Add ps_scripts update here

    # Updating dependency modules
    if ($depModulesNotChanged) {
        Write-Verbose "Dependency modules has not been changed."
        if ($oldSolution) {
            return;
        }
    }
    else {
        if ($oldSolution) {
            Write-Verbose "Dependency modules changed, unloading PSSolution"
            Remove-PSSolution -Name $Name -Verbose:$Verbose
        }
    
        $activityName = "Installing solution dependency modules"
        try {
            $totalDepsCount = $depModules.Count
            $i = 0
            foreach ($dep in $depModules) {
                $percentComplete = [int](($i / $totalDepsCount) * 100)
                Write-Progress -Activity $activityName -Status "$percentComplete% Complete:" -PercentComplete $percentComplete;
                Save-ModuleFast -Name $dep.Name -MinimumVersion $dep.Version -LiteralPath $depMdulesPath
                $i++
            }
        }
        finally {
            Write-Progress -Activity $activityName -Completed
        } 
    }
    
    
    ConvertTo-Json @{
        DependencyModules = @($depModules)
        ModuleState       = @(Get-SolutionModulesState @($solutionModules))
    } | Out-File -Encoding utf8 -FilePath (Join-Path $solutionPath $PSSolutionLockFileName)

    $solution = [PSSolution]@{
        Path = $solutionPath
    }

    $ImportedPSSolutions.Add($Name, $solution)

    # Adding modules path to the PSModulesPath
    $psModulesParts = Get-PathVar -VarName PSModulePath
    $psModulesParts = @($solutionPath, $depMdulesPath) + $psModulesParts
    Set-PathVar -Parts $psModulesParts -VarName PSModulePath

    # TODO: Add ps_scripts and solution path to the $env:Path
}

function Remove-PSSolution {
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name = "Default"
    )

    if (!$ImportedPSSolutions.Contains($Name)) {
        $errorMessage = "Cannot find imported PSSolution with name '$Name'"
        ThrowError  -ExceptionName "System.ArgumentException" `
            -ExceptionMessage $errorMessage `
            -ErrorId "PSSolutionNameAlreadyImported" `
            -CallerPSCmdlet $PSCmdlet `
            -ExceptionObject $Name `
            -ErrorCategory InvalidArgument
    }

    $fullPath = $ImportedPSSolutions[$Name].Path;
    $depMdulesPath = Join-Path $fullPath $PSModulesFolderName

    # Removing solution module pathes from PSModulePathes
    $psModulesParts = Get-PathVar -VarName PSModulePath
    $psModulesParts = $psModulesParts | ? {($_ -ne $fullPath) -and ($_ -ne $depMdulesPath)}
    Set-PathVar -Parts $psModulesParts -VarName PSModulePath

    $ImportedPSSolutions.Remove($Name)

    $modulesToRemove = Get-Module | ? {($_.Path).StartsWith($fullPath)} 
    $modulesToRemove | Remove-Module -Force
}

function Use-PSSolution() {

}

$exportModuleMemberParams = @{
    Function = @(
        'Get-PSSolution',
        'Import-PSSolution',
        'Remove-PSSolution'
    )

    Variable = @(
    )
}

Export-ModuleMember @exportModuleMemberParams
