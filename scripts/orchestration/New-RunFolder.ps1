<#
.SYNOPSIS
Creates a new supervised orchestration run folder.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "execute", "review")]
    [string]$Mode,
    [string]$Title,
    [string]$Slug
)

. (Join-Path -Path $PSScriptRoot -ChildPath "common\Orchestration.Common.ps1")

$layout = New-OrchestrationRunLayout -Mode $Mode -Title $Title -Slug $Slug
[pscustomobject]@{
    run_id     = $layout.RunId
    mode       = $layout.Mode
    run_folder = $layout.RunRoot
}
