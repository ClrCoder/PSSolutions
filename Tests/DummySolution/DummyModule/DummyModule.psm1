param()
function Get-DummyString{
    "I am dummy module!"
}

$exportModuleMemberParams = @{
    Function = @(
        'Get-DummyString'
    )

    Variable = @(
    )
}

Export-ModuleMember @exportModuleMemberParams
