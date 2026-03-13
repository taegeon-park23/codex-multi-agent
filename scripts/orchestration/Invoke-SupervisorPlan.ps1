<#
.SYNOPSIS
Runs a read-only supervised planning fan-out through Codex CLI.
#>
[CmdletBinding(DefaultParameterSetName = "Task")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Task")]
    [string]$Task,
    [Parameter(Mandatory = $true, ParameterSetName = "TaskFile")]
    [string]$TaskFile,
    [string]$Title,
    [string]$Slug
)

Set-StrictMode -Version Latest
. (Join-Path -Path $PSScriptRoot -ChildPath "common\Orchestration.Common.ps1")

$repoRoot = Get-OrchestrationRepoRoot -StartPath $PSScriptRoot
$taskText = Get-OrchestrationTaskText -Task $Task -TaskFile $TaskFile
$layout = New-OrchestrationRunLayout -Mode "plan" -Title $Title -Slug $Slug -RepoRoot $repoRoot

$requestMarkdown = @"
# Supervisor Plan Request

- Run ID: $($layout.RunId)
- Mode: plan

## Original Task

$taskText
"@
Write-OrchestrationTextFile -Path $layout.RequestPath -Content $requestMarkdown

$instructionPath = Join-Path -Path $repoRoot -ChildPath ".codex\instructions\supervisor-plan.md"
$schemaPath = Join-Path -Path $repoRoot -ChildPath ".codex\schemas\orchestration-plan.schema.json"
$contextBlocks = @(
    "## Run Metadata`n- run_id: $($layout.RunId)`n- mode: plan",
    "## Repository Context`n- This repository is a supervised orchestration template, not a product implementation.`n- Planning must stay read-only.`n- All visibility for the Codex app must come from artifacts written to disk.",
    "## Output Contract`n- Return JSON only.`n- Match the provided schema exactly.`n- Set run_id to '$($layout.RunId)'.`n- Set mode to 'plan'.`n- If mutating execution is the next step, set requires_human_approval to true."
)
$promptText = New-OrchestrationPrompt -InstructionFile $instructionPath -TaskText $taskText -ContextBlocks $contextBlocks
Write-OrchestrationTextFile -Path $layout.EffectivePromptPath -Content $promptText

$exitCode = Invoke-OrchestrationCodexExec `
    -Profile "supervisor_plan" `
    -PromptText $promptText `
    -SchemaPath $schemaPath `
    -OutputJsonPath $layout.ResultJsonPath `
    -EventsPath $layout.EventsPath `
    -StdoutPath $layout.StdoutPath `
    -StdErrPath $layout.StdErrPath

$result = $null
if ($exitCode -eq 0) {
    $result = Read-OrchestrationResult -ResultJsonPath $layout.ResultJsonPath -EventsPath $layout.EventsPath -ExpectedMode "plan" -ExpectedRunId $layout.RunId
}

if ($null -eq $result) {
    $result = New-OrchestrationFailureResult `
        -Mode "plan" `
        -RunId $layout.RunId `
        -Summary "The supervised planning run did not complete successfully." `
        -RecommendedNextStep "Inspect logs/stderr.log and rerun the plan after resolving the Codex CLI issue." `
        -AdditionalProperties @{
            proposed_worktrees     = @()
            proposed_subtasks      = @()
            per_agent_findings     = @()
            tests_requested_or_run = @()
        }
    Write-OrchestrationJsonFile -Path $layout.ResultJsonPath -Object $result
}

$resultMarkdown = Convert-OrchestrationResultToMarkdown -Result $result -Mode "plan" -RunId $layout.RunId -RunRoot $layout.RunRoot
Write-OrchestrationTextFile -Path $layout.ResultMarkdownPath -Content $resultMarkdown
Write-OrchestrationApprovalRequest -Path $layout.ApprovalRequestPath -Result $result -RunId $layout.RunId

[pscustomobject]@{
    run_id           = $layout.RunId
    run_folder       = $layout.RunRoot
    result_json      = $layout.ResultJsonPath
    result_markdown  = $layout.ResultMarkdownPath
    approval_request = $layout.ApprovalRequestPath
    codex_exit_code  = $exitCode
}