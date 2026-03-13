<#
.SYNOPSIS
Runs a read-only supervised review or test fan-out through Codex CLI.
#>
[CmdletBinding()]
param(
    [string]$TargetRun,
    [string]$TargetPath,
    [string]$Title
)

Set-StrictMode -Version Latest
. (Join-Path -Path $PSScriptRoot -ChildPath "common\Orchestration.Common.ps1")

$repoRoot = Get-OrchestrationRepoRoot -StartPath $PSScriptRoot

$resolvedTargetPath = $null
$targetRunId = "current-repo"
$targetSummary = "Review the current repository state."

if (-not [string]::IsNullOrWhiteSpace($TargetRun)) {
    $resolvedTargetPath = Get-OrchestrationRunFolder -RepoRoot $repoRoot -Identifier $TargetRun
    $targetResult = Read-OrchestrationJsonFile -Path (Join-Path -Path $resolvedTargetPath -ChildPath "result.json")
    if ($null -ne $targetResult) {
        $targetRunId = $targetResult.run_id
        $targetSummary = $targetResult.summary
    } else {
        $targetRunId = Split-Path -Path $resolvedTargetPath -Leaf
        $targetSummary = "Review the artifacts and results for run '$targetRunId'."
    }
} elseif (-not [string]::IsNullOrWhiteSpace($TargetPath)) {
    $resolvedTargetPath = (Resolve-Path -Path $TargetPath).Path
    $targetRunId = Split-Path -Path $resolvedTargetPath -Leaf
    $targetSummary = "Review the state at path '$resolvedTargetPath'."
} else {
    $resolvedTargetPath = $repoRoot
}

$layout = New-OrchestrationRunLayout -Mode "review" -Title $Title -Slug $null -RepoRoot $repoRoot
$requestMarkdown = @"
# Supervisor Review Request

- Run ID: $($layout.RunId)
- Mode: review
- Target: $resolvedTargetPath
"@
Write-OrchestrationTextFile -Path $layout.RequestPath -Content $requestMarkdown

$instructionPath = Join-Path -Path $repoRoot -ChildPath ".codex\instructions\supervisor-review.md"
$schemaPath = Join-Path -Path $repoRoot -ChildPath ".codex\schemas\review-report.schema.json"
$contextBlocks = @(
    "## Run Metadata`n- run_id: $($layout.RunId)`n- mode: review",
    "## Review Target`n- target_run_id: $targetRunId`n- target_path: $resolvedTargetPath",
    "## Output Contract`n- Return JSON only.`n- Match the provided schema exactly.`n- Set run_id to '$($layout.RunId)'.`n- Set mode to 'review'.`n- Set target_run_id to '$targetRunId'."
)
$promptText = New-OrchestrationPrompt -InstructionFile $instructionPath -TaskText $targetSummary -ContextBlocks $contextBlocks
Write-OrchestrationTextFile -Path $layout.EffectivePromptPath -Content $promptText

$exitCode = Invoke-OrchestrationCodexExec `
    -Profile "supervisor_review" `
    -PromptText $promptText `
    -SchemaPath $schemaPath `
    -OutputJsonPath $layout.ResultJsonPath `
    -EventsPath $layout.EventsPath `
    -StdoutPath $layout.StdoutPath `
    -StdErrPath $layout.StdErrPath `
    -WorkingDirectory $resolvedTargetPath

$result = $null
if ($exitCode -eq 0) {
    $result = Read-OrchestrationResult -ResultJsonPath $layout.ResultJsonPath -EventsPath $layout.EventsPath -ExpectedMode "review" -ExpectedRunId $layout.RunId
}

$reviewReportPath = Join-Path -Path $layout.RunRoot -ChildPath "review-report.json"
if ($null -eq $result) {
    $result = New-OrchestrationFailureResult `
        -Mode "review" `
        -RunId $layout.RunId `
        -Summary "The supervised review run did not complete successfully." `
        -RecommendedNextStep "Inspect logs/stderr.log, confirm Codex CLI is available and authenticated, and rerun the review." `
        -AdditionalProperties @{
            target_run_id         = $targetRunId
            findings              = @()
            severity_summary      = @{
                critical = 0
                high     = 0
                medium   = 0
                low      = 0
            }
            tests_requested_or_run = @()
        }
    Write-OrchestrationJsonFile -Path $layout.ResultJsonPath -Object $result
}

Copy-Item -Path $layout.ResultJsonPath -Destination $reviewReportPath -Force
Write-OrchestrationTextFile -Path $layout.ResultMarkdownPath -Content (Convert-OrchestrationResultToMarkdown -Result $result -Mode "review" -RunId $layout.RunId -RunRoot $layout.RunRoot)
Write-OrchestrationApprovalRequest -Path $layout.ApprovalRequestPath -Result $result -RunId $layout.RunId

[pscustomobject]@{
    run_id           = $layout.RunId
    run_folder       = $layout.RunRoot
    target_path      = $resolvedTargetPath
    result_json      = $layout.ResultJsonPath
    review_report    = $reviewReportPath
    result_markdown  = $layout.ResultMarkdownPath
    approval_request = $layout.ApprovalRequestPath
    codex_exit_code  = $exitCode
}