<#
.SYNOPSIS
Runs an approval-gated supervised execution handoff through Codex CLI.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PlanRun,
    [Parameter(Mandatory = $true)]
    [string]$ApprovalNote,
    [string]$WorktreeName
)

Set-StrictMode -Version Latest
. (Join-Path -Path $PSScriptRoot -ChildPath "common\Orchestration.Common.ps1")

if ([string]::IsNullOrWhiteSpace($ApprovalNote)) {
    throw "ApprovalNote is required for the execution phase."
}

$repoRoot = Get-OrchestrationRepoRoot -StartPath $PSScriptRoot
$planRunFolder = Get-OrchestrationRunFolder -RepoRoot $repoRoot -Identifier $PlanRun
$planResultPath = Join-Path -Path $planRunFolder -ChildPath "result.json"
$planResult = Read-OrchestrationJsonFile -Path $planResultPath
if ($null -eq $planResult) {
    throw "Unable to read the approved plan result from '$planResultPath'."
}

$layout = New-OrchestrationRunLayout -Mode "execute" -Title $WorktreeName -Slug $null -RepoRoot $repoRoot
$requestMarkdown = @"
# Supervisor Execute Request

- Run ID: $($layout.RunId)
- Mode: execute
- Approved plan run: $($planResult.run_id)

## Supervisor Approval Note

$ApprovalNote
"@
Write-OrchestrationTextFile -Path $layout.RequestPath -Content $requestMarkdown

$worktree = $null
$executionResultPath = Join-Path -Path $layout.RunRoot -ChildPath "execution-report.json"
$commandsAttempted = @("git worktree add")

try {
    $worktree = New-OrchestrationWorktree -RepoRoot $repoRoot -RunId $layout.RunId -WorktreeName $WorktreeName
} catch {
    $result = New-OrchestrationFailureResult `
        -Mode "execute" `
        -RunId $layout.RunId `
        -Summary "The approved execution run did not start because the isolated worktree could not be created." `
        -RecommendedNextStep "Review the git worktree error, resolve it, and rerun the approved execution phase." `
        -RequiresHumanApproval $true `
        -ApprovalReason "Execution must remain isolated. The required worktree could not be created safely." `
        -AdditionalProperties @{
            approved_plan_run_id  = $planResult.run_id
            worktree_path         = $null
            files_touched         = @()
            commands_attempted    = $commandsAttempted
            tests_requested_or_run = @()
            blocked_actions       = @($_.Exception.Message)
        }
    Write-OrchestrationJsonFile -Path $layout.ResultJsonPath -Object $result
    Write-OrchestrationJsonFile -Path $executionResultPath -Object $result
    Write-OrchestrationTextFile -Path $layout.ResultMarkdownPath -Content (Convert-OrchestrationResultToMarkdown -Result $result -Mode "execute" -RunId $layout.RunId -RunRoot $layout.RunRoot)
    Write-OrchestrationApprovalRequest -Path $layout.ApprovalRequestPath -Result $result -RunId $layout.RunId

    [pscustomobject]@{
        run_id           = $layout.RunId
        run_folder       = $layout.RunRoot
        result_json      = $layout.ResultJsonPath
        result_markdown  = $layout.ResultMarkdownPath
        approval_request = $layout.ApprovalRequestPath
        codex_exit_code  = 1
    }
    return
}

$instructionPath = Join-Path -Path $repoRoot -ChildPath ".codex\instructions\supervisor-execute.md"
$schemaPath = Join-Path -Path $repoRoot -ChildPath ".codex\schemas\execution-report.schema.json"
$planResultJson = $planResult | ConvertTo-Json -Depth 32
$contextBlocks = @(
    "## Run Metadata`n- run_id: $($layout.RunId)`n- mode: execute",
    "## Isolation`n- Worktree path: $($worktree.Path)`n- Worktree branch: $($worktree.Branch)`n- All write-capable work must remain inside this worktree.",
    "## Approved Plan Result`n```json`n$planResultJson`n```",
    "## Supervisor Approval`n- Approval note: $ApprovalNote",
    "## Output Contract`n- Return JSON only.`n- Match the provided schema exactly.`n- Set run_id to '$($layout.RunId)'.`n- Set mode to 'execute'.`n- Set approved_plan_run_id to '$($planResult.run_id)'."
)
$promptText = New-OrchestrationPrompt -InstructionFile $instructionPath -TaskText $planResult.summary -ContextBlocks $contextBlocks
Write-OrchestrationTextFile -Path $layout.EffectivePromptPath -Content $promptText

$exitCode = Invoke-OrchestrationCodexExec `
    -Profile "supervisor_execute" `
    -PromptText $promptText `
    -SchemaPath $schemaPath `
    -OutputJsonPath $layout.ResultJsonPath `
    -EventsPath $layout.EventsPath `
    -StdoutPath $layout.StdoutPath `
    -StdErrPath $layout.StdErrPath `
    -WorkingDirectory $worktree.Path

$result = $null
if ($exitCode -eq 0) {
    $result = Read-OrchestrationResult -ResultJsonPath $layout.ResultJsonPath -EventsPath $layout.EventsPath -ExpectedMode "execute" -ExpectedRunId $layout.RunId
}

if ($null -eq $result) {
    $result = New-OrchestrationFailureResult `
        -Mode "execute" `
        -RunId $layout.RunId `
        -Summary "The approved execution run did not complete successfully." `
        -RecommendedNextStep "Inspect logs/stderr.log, confirm Codex CLI is available and authenticated, and rerun the approved execution phase." `
        -AdditionalProperties @{
            approved_plan_run_id  = $planResult.run_id
            worktree_path         = $worktree.Path
            files_touched         = @()
            commands_attempted    = @(
                "git worktree add -b $($worktree.Branch) $($worktree.Path) HEAD",
                "codex exec -p supervisor_execute --json --output-schema $schemaPath -o $($layout.ResultJsonPath)"
            )
            tests_requested_or_run = @()
            blocked_actions       = @("Codex CLI execution failed; see logs/stderr.log.")
        }
    Write-OrchestrationJsonFile -Path $layout.ResultJsonPath -Object $result
}

Copy-Item -Path $layout.ResultJsonPath -Destination $executionResultPath -Force
Write-OrchestrationTextFile -Path $layout.ResultMarkdownPath -Content (Convert-OrchestrationResultToMarkdown -Result $result -Mode "execute" -RunId $layout.RunId -RunRoot $layout.RunRoot)
Write-OrchestrationApprovalRequest -Path $layout.ApprovalRequestPath -Result $result -RunId $layout.RunId

[pscustomobject]@{
    run_id           = $layout.RunId
    run_folder       = $layout.RunRoot
    worktree_path    = $worktree.Path
    result_json      = $layout.ResultJsonPath
    execution_report = $executionResultPath
    result_markdown  = $layout.ResultMarkdownPath
    approval_request = $layout.ApprovalRequestPath
    codex_exit_code  = $exitCode
}