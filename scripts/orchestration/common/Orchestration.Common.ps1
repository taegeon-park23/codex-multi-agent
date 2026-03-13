Set-StrictMode -Version Latest

function Get-OrchestrationRepoRoot {
    param(
        [string]$StartPath = $PSScriptRoot
    )

    $candidate = Resolve-Path -Path $StartPath
    if ($candidate -is [System.Array]) {
        $candidate = $candidate[0]
    }

    $current = $candidate.Path
    while ($null -ne $current) {
        if ((Test-Path -Path (Join-Path -Path $current -ChildPath ".git")) -or
            (Test-Path -Path (Join-Path -Path $current -ChildPath ".codex"))) {
            return $current
        }

        $parent = Split-Path -Path $current -Parent
        if ($parent -eq $current) {
            break
        }

        $current = $parent
    }

    throw "Unable to locate the repository root from '$StartPath'."
}

function ConvertTo-OrchestrationSlug {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "run"
    }

    $slug = $Value.ToLowerInvariant()
    $slug = [System.Text.RegularExpressions.Regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "run"
    }

    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).Trim("-")
    }

    return $slug
}

function Write-OrchestrationTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-OrchestrationJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    $json = $Object | ConvertTo-Json -Depth 32
    Write-OrchestrationTextFile -Path $Path -Content ($json + "`n")
}

function Read-OrchestrationTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.File]::ReadAllText($Path)
}

function Read-OrchestrationJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        return $null
    }

    $raw = Read-OrchestrationTextFile -Path $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return $raw | ConvertFrom-Json
}

function ConvertFrom-OrchestrationJsonText {
    param(
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        return ($Text | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        return $null
    }
}

function Test-OrchestrationStructuredResult {
    param(
        [object]$Value,
        [string]$ExpectedMode,
        [string]$ExpectedRunId
    )

    if ($null -eq $Value) {
        return $false
    }

    $propertyNames = @($Value.PSObject.Properties.Name)
    if (-not ($propertyNames -contains 'run_id') -or -not ($propertyNames -contains 'mode') -or -not ($propertyNames -contains 'summary')) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedMode) -and $Value.mode -ne $ExpectedMode) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedRunId) -and $Value.run_id -ne $ExpectedRunId) {
        return $false
    }

    return $true
}

function Read-OrchestrationResultFromEvents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EventsPath,
        [string]$ExpectedMode,
        [string]$ExpectedRunId
    )

    if (-not (Test-Path -Path $EventsPath)) {
        return $null
    }

    $lines = Get-Content -Path $EventsPath
    if ($null -eq $lines -or $lines.Count -eq 0) {
        return $null
    }

    [array]::Reverse($lines)
    foreach ($line in $lines) {
        $event = ConvertFrom-OrchestrationJsonText -Text $line
        if ($null -eq $event) {
            continue
        }

        $candidates = @()

        if (($event.PSObject.Properties.Name -contains 'type') -and $event.type -eq 'agent_message' -and ($event.PSObject.Properties.Name -contains 'text')) {
            $candidates += $event.text
        }

        if ($event.PSObject.Properties.Name -contains 'item') {
            $item = $event.item
            if ($null -ne $item -and ($item.PSObject.Properties.Name -contains 'agents_states')) {
                foreach ($stateProperty in $item.agents_states.PSObject.Properties) {
                    $state = $stateProperty.Value
                    if ($null -ne $state -and ($state.PSObject.Properties.Name -contains 'message')) {
                        $candidates += $state.message
                    }
                }
            }
        }

        foreach ($candidate in $candidates) {
            $parsed = ConvertFrom-OrchestrationJsonText -Text $candidate
            if (Test-OrchestrationStructuredResult -Value $parsed -ExpectedMode $ExpectedMode -ExpectedRunId $ExpectedRunId) {
                return $parsed
            }
        }
    }

    return $null
}

function Read-OrchestrationResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResultJsonPath,
        [Parameter(Mandatory = $true)]
        [string]$EventsPath,
        [string]$ExpectedMode,
        [string]$ExpectedRunId
    )

    $result = Read-OrchestrationJsonFile -Path $ResultJsonPath
    if (Test-OrchestrationStructuredResult -Value $result -ExpectedMode $ExpectedMode -ExpectedRunId $ExpectedRunId) {
        return $result
    }

    $result = Read-OrchestrationResultFromEvents -EventsPath $EventsPath -ExpectedMode $ExpectedMode -ExpectedRunId $ExpectedRunId
    if ($null -ne $result) {
        Write-OrchestrationJsonFile -Path $ResultJsonPath -Object $result
        return $result
    }

    return $null
}

function New-OrchestrationRunLayout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mode,
        [string]$Title,
        [string]$Slug,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-OrchestrationRepoRoot
    }

    if ([string]::IsNullOrWhiteSpace($Slug)) {
        $slugSource = $Title
        if ([string]::IsNullOrWhiteSpace($slugSource)) {
            $slugSource = $Mode
        }
        $Slug = ConvertTo-OrchestrationSlug -Value $slugSource
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
    $runId = "{0}-{1}-{2}-{3}" -f $timestamp, $Mode, $Slug, $suffix
    $runRoot = Join-Path -Path $RepoRoot -ChildPath (".codex\runs\" + $runId)
    $logsRoot = Join-Path -Path $runRoot -ChildPath "logs"

    New-Item -ItemType Directory -Force -Path $logsRoot | Out-Null

    return [pscustomobject]@{
        RepoRoot            = $RepoRoot
        RunId               = $runId
        Mode                = $Mode
        RunRoot             = $runRoot
        LogsRoot            = $logsRoot
        RequestPath         = (Join-Path -Path $runRoot -ChildPath "request.md")
        EffectivePromptPath = (Join-Path -Path $runRoot -ChildPath "effective-prompt.md")
        ResultJsonPath      = (Join-Path -Path $runRoot -ChildPath "result.json")
        ResultMarkdownPath  = (Join-Path -Path $runRoot -ChildPath "result.md")
        ApprovalRequestPath = (Join-Path -Path $runRoot -ChildPath "approval-request.md")
        EventsPath          = (Join-Path -Path $runRoot -ChildPath "events.jsonl")
        StdoutPath          = (Join-Path -Path $logsRoot -ChildPath "stdout.log")
        StdErrPath          = (Join-Path -Path $logsRoot -ChildPath "stderr.log")
    }
}

function Get-OrchestrationTaskText {
    param(
        [string]$Task,
        [string]$TaskFile
    )

    if (-not [string]::IsNullOrWhiteSpace($Task) -and -not [string]::IsNullOrWhiteSpace($TaskFile)) {
        throw "Provide either -Task or -TaskFile, not both."
    }

    if (-not [string]::IsNullOrWhiteSpace($Task)) {
        return $Task.Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($TaskFile)) {
        if (-not (Test-Path -Path $TaskFile)) {
            throw "Task file '$TaskFile' was not found."
        }

        return (Read-OrchestrationTextFile -Path (Resolve-Path -Path $TaskFile)).Trim()
    }

    throw "A task value is required."
}

function New-OrchestrationPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstructionFile,
        [Parameter(Mandatory = $true)]
        [string]$TaskText,
        [string[]]$ContextBlocks
    )

    $parts = @()
    $parts += (Read-OrchestrationTextFile -Path $InstructionFile).Trim()
    $parts += "## Task`n$TaskText"

    foreach ($block in $ContextBlocks) {
        if (-not [string]::IsNullOrWhiteSpace($block)) {
            $parts += $block.Trim()
        }
    }

    return (($parts -join "`n`n") + "`n")
}

function Invoke-OrchestrationCodexExec {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Profile,
        [Parameter(Mandatory = $true)]
        [string]$PromptText,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputJsonPath,
        [Parameter(Mandatory = $true)]
        [string]$EventsPath,
        [Parameter(Mandatory = $true)]
        [string]$StdoutPath,
        [Parameter(Mandatory = $true)]
        [string]$StdErrPath,
        [string]$WorkingDirectory
    )

    $codex = Get-Command -Name codex -ErrorAction Stop
    $arguments = @(
        "exec",
        "-p", $Profile,
        "--json",
        "--output-schema", $SchemaPath,
        "-o", $OutputJsonPath
    )

    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $arguments += @("-C", $WorkingDirectory)
    }

    $arguments += "-"

    $PromptText | & $codex.Source @arguments 1> $EventsPath 2> $StdErrPath
    $exitCode = $LASTEXITCODE

    if (Test-Path -Path $EventsPath) {
        Copy-Item -Path $EventsPath -Destination $StdoutPath -Force
    }

    return $exitCode
}

function Format-OrchestrationList {
    param(
        [object[]]$Items,
        [string]$Prefix = "- "
    )

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return @("- none")
    }

    $lines = @()
    foreach ($item in $Items) {
        $lines += ($Prefix + $item)
    }

    return $lines
}

function ConvertTo-OrchestrationInlineValue {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return "unknown"
    }

    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "unknown"
    }

    return $text
}

function ConvertTo-OrchestrationInlineList {
    param(
        [object[]]$Items
    )

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return "none"
    }

    $values = @()
    foreach ($item in $Items) {
        $values += (ConvertTo-OrchestrationInlineValue -Value $item)
    }

    return ($values -join ", ")
}

function Format-OrchestrationSkillLabel {
    param(
        [object]$Skill
    )

    if ($null -eq $Skill) {
        return "unknown skill"
    }

    $display = $null
    if ($Skill.PSObject.Properties.Name -contains "display_name") {
        $display = $Skill.display_name
    }
    if ([string]::IsNullOrWhiteSpace($display) -and ($Skill.PSObject.Properties.Name -contains "invocation_name")) {
        $display = $Skill.invocation_name
    }
    if ([string]::IsNullOrWhiteSpace($display) -and ($Skill.PSObject.Properties.Name -contains "probable_invocation_name")) {
        $display = $Skill.probable_invocation_name
    }
    if ([string]::IsNullOrWhiteSpace($display)) {
        $display = "unknown skill"
    }

    $status = "unknown"
    if ($Skill.PSObject.Properties.Name -contains "invocation_name_status") {
        $status = ConvertTo-OrchestrationInlineValue -Value $Skill.invocation_name_status
    }

    $invoke = $null
    if (($Skill.PSObject.Properties.Name -contains "invocation_name") -and -not [string]::IsNullOrWhiteSpace([string]$Skill.invocation_name)) {
        $invoke = [string]$Skill.invocation_name
    } elseif (($Skill.PSObject.Properties.Name -contains "probable_invocation_name") -and -not [string]::IsNullOrWhiteSpace([string]$Skill.probable_invocation_name)) {
        $invoke = "probable=" + [string]$Skill.probable_invocation_name
    }

    if ([string]::IsNullOrWhiteSpace($invoke)) {
        return ("{0} (status={1})" -f $display, $status)
    }

    return ("{0} (status={1}, invoke={2})" -f $display, $status, $invoke)
}

function Convert-OrchestrationResultToMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Result,
        [Parameter(Mandatory = $true)]
        [string]$Mode,
        [Parameter(Mandatory = $true)]
        [string]$RunId,
        [Parameter(Mandatory = $true)]
        [string]$RunRoot
    )

    $lines = @(
        "# Orchestration Result",
        "",
        "- Run ID: $RunId",
        "- Mode: $Mode",
        "- Run folder: $RunRoot",
        ""
    )

    if ($Result.PSObject.Properties.Name -contains "summary") {
        $lines += @("## Summary", "", $Result.summary, "")
    }

    if ($Result.PSObject.Properties.Name -contains "recommended_next_step") {
        $lines += @("## Recommended Next Step", "", $Result.recommended_next_step, "")
    }

    if ($Result.PSObject.Properties.Name -contains "requires_human_approval") {
        $approvalRequired = [bool]$Result.requires_human_approval
        $lines += @("## Approval", "", ("- Requires human approval: {0}" -f $approvalRequired.ToString().ToLowerInvariant()))
        if (($Result.PSObject.Properties.Name -contains "approval_reason") -and -not [string]::IsNullOrWhiteSpace($Result.approval_reason)) {
            $lines += ("- Approval reason: " + $Result.approval_reason)
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "skill_routing_summary") {
        $lines += @("## Skill Routing Summary", "", $Result.skill_routing_summary, "")
    }

    if ($Result.PSObject.Properties.Name -contains "skill_inventory_checked") {
        $lines += @("## Skill Inventory Checked", "")
        if ($Result.skill_inventory_checked.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($skill in $Result.skill_inventory_checked) {
                $lines += ("- {0}; scope={1}; safe_phase={2}; mutates_files={3}; external_context={4}; confidence={5}" -f (Format-OrchestrationSkillLabel -Skill $skill), (ConvertTo-OrchestrationInlineValue -Value $skill.source_scope), (ConvertTo-OrchestrationInlineList -Items $skill.safe_phase), (ConvertTo-OrchestrationInlineValue -Value $skill.mutates_files), (ConvertTo-OrchestrationInlineValue -Value $skill.requires_external_context), (ConvertTo-OrchestrationInlineValue -Value $skill.confidence_of_mapping))
            }
        }
        $lines += ""
    }

    foreach ($section in @(
        @{ Name = "recommended_skill_invocations"; Title = "Recommended Skill Invocations" },
        @{ Name = "implicit_skill_candidates"; Title = "Implicit Skill Candidates" },
        @{ Name = "explicit_skill_candidates"; Title = "Explicit Skill Candidates" }
    )) {
        if ($Result.PSObject.Properties.Name -contains $section.Name) {
            $lines += @(("## {0}" -f $section.Title), "")
            $items = $Result.$($section.Name)
            if ($items.Count -eq 0) {
                $lines += "- none"
            } else {
                foreach ($item in $items) {
                    $lines += ("- {0}; use_mode={1}; phase={2}; reason={3}" -f (Format-OrchestrationSkillLabel -Skill $item), (ConvertTo-OrchestrationInlineValue -Value $item.use_mode), (ConvertTo-OrchestrationInlineValue -Value $item.phase), (ConvertTo-OrchestrationInlineValue -Value $item.reason))
                    $lines += ("  - subtasks: {0}" -f (ConvertTo-OrchestrationInlineList -Items $item.subtasks))
                }
            }
            $lines += ""
        }
    }

    if ($Result.PSObject.Properties.Name -contains "skills_blocked_by_prerequisites") {
        $lines += @("## Skills Blocked By Prerequisites", "")
        if ($Result.skills_blocked_by_prerequisites.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($item in $Result.skills_blocked_by_prerequisites) {
                $lines += ("- {0}: {1}" -f (Format-OrchestrationSkillLabel -Skill $item), (ConvertTo-OrchestrationInlineValue -Value $item.blocking_reason))
                $lines += ("  - missing prerequisites: {0}" -f (ConvertTo-OrchestrationInlineList -Items $item.missing_prerequisites))
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "skills_deferred_until_execution") {
        $lines += @("## Skills Deferred Until Execution", "")
        if ($Result.skills_deferred_until_execution.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($item in $Result.skills_deferred_until_execution) {
                $lines += ("- {0}: {1}" -f (Format-OrchestrationSkillLabel -Skill $item), (ConvertTo-OrchestrationInlineValue -Value $item.reason))
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "skills_not_applicable") {
        $lines += @("## Skills Not Applicable", "")
        if ($Result.skills_not_applicable.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($item in $Result.skills_not_applicable) {
                $lines += ("- {0}: {1}" -f (ConvertTo-OrchestrationInlineValue -Value $item.display_name), (ConvertTo-OrchestrationInlineValue -Value $item.reason))
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "subtask_to_skill_map") {
        $lines += @("## Subtask To Skill Map", "")
        if ($Result.subtask_to_skill_map.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($item in $Result.subtask_to_skill_map) {
                $lines += ("- [{0}] {1}" -f (ConvertTo-OrchestrationInlineValue -Value $item.subtask_id), (ConvertTo-OrchestrationInlineValue -Value $item.subtask_title))
                $lines += ("  - recommended: {0}" -f (Format-OrchestrationSkillLabel -Skill $item.recommended_skill))
                if ($item.alternate_skills.Count -eq 0) {
                    $lines += "  - alternates: none"
                } else {
                    $alternates = @()
                    foreach ($alternate in $item.alternate_skills) {
                        $alternates += (Format-OrchestrationSkillLabel -Skill $alternate)
                    }
                    $lines += ("  - alternates: {0}" -f ($alternates -join "; "))
                }
                $lines += ("  - reason: {0}" -f (ConvertTo-OrchestrationInlineValue -Value $item.routing_reason))
                $lines += ("  - manual confirmation required: {0}" -f (([bool]$item.manual_confirmation_required).ToString().ToLowerInvariant()))
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "proposed_subtasks") {
        $lines += @("## Proposed Subtasks", "")
        if ($Result.proposed_subtasks.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($subtask in $Result.proposed_subtasks) {
                $lines += ("- [{0}] {1} ({2}, {3})" -f $subtask.id, $subtask.title, $subtask.owner_role, $subtask.mode)
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "proposed_worktrees") {
        $lines += @("## Proposed Worktrees", "")
        if ($Result.proposed_worktrees.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($worktree in $Result.proposed_worktrees) {
                $lines += ("- {0}: {1}" -f $worktree.name, $worktree.purpose)
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "per_agent_findings") {
        $lines += @("## Per-Agent Findings", "")
        if ($Result.per_agent_findings.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($finding in $Result.per_agent_findings) {
                $usedMultiAgent = $false
                if ($finding.PSObject.Properties.Name -contains "used_multi_agent") {
                    $usedMultiAgent = [bool]$finding.used_multi_agent
                }
                $lines += ("- {0}: {1} (delegated={2})" -f $finding.agent, $finding.summary, $usedMultiAgent.ToString().ToLowerInvariant())
                if ($finding.PSObject.Properties.Name -contains "details") {
                    foreach ($detail in $finding.details) {
                        $lines += ("  - " + $detail)
                    }
                }
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "findings") {
        $lines += @("## Findings", "")
        if ($Result.findings.Count -eq 0) {
            $lines += "- none"
        } else {
            foreach ($finding in $Result.findings) {
                $lines += ("- [{0}] {1}: {2}" -f $finding.severity, $finding.title, $finding.summary)
            }
        }
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "severity_summary") {
        $summary = $Result.severity_summary
        $lines += @("## Severity Summary", "")
        $lines += ("- critical: {0}" -f $summary.critical)
        $lines += ("- high: {0}" -f $summary.high)
        $lines += ("- medium: {0}" -f $summary.medium)
        $lines += ("- low: {0}" -f $summary.low)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "worktree_path") {
        $lines += @("## Worktree", "")
        $lines += ("- Path: " + $Result.worktree_path)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "files_touched") {
        $lines += @("## Files Touched", "")
        $lines += (Format-OrchestrationList -Items $Result.files_touched)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "commands_attempted") {
        $lines += @("## Commands Attempted", "")
        $lines += (Format-OrchestrationList -Items $Result.commands_attempted)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "tests_requested_or_run") {
        $lines += @("## Tests Requested Or Run", "")
        $lines += (Format-OrchestrationList -Items $Result.tests_requested_or_run)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "blocked_actions") {
        $lines += @("## Blocked Actions", "")
        $lines += (Format-OrchestrationList -Items $Result.blocked_actions)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "risks") {
        $lines += @("## Risks", "")
        $lines += (Format-OrchestrationList -Items $Result.risks)
        $lines += ""
    }

    if ($Result.PSObject.Properties.Name -contains "open_questions") {
        $lines += @("## Open Questions", "")
        $lines += (Format-OrchestrationList -Items $Result.open_questions)
        $lines += ""
    }

    return (($lines -join "`n").Trim() + "`n")
}

function Write-OrchestrationApprovalRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Result,
        [Parameter(Mandatory = $true)]
        [string]$RunId
    )

    if (-not ($Result.PSObject.Properties.Name -contains "requires_human_approval")) {
        return
    }

    if (-not [bool]$Result.requires_human_approval) {
        return
    }

    $lines = @(
        "# Approval Request",
        "",
        "- Run ID: $RunId",
        ""
    )

    if ($Result.PSObject.Properties.Name -contains "approval_reason") {
        $lines += @("## Why approval is required", "", $Result.approval_reason, "")
    }

    if (($Result.PSObject.Properties.Name -contains "skill_routing_summary") -and -not [string]::IsNullOrWhiteSpace([string]$Result.skill_routing_summary)) {
        $lines += @("## Skill routing note", "", $Result.skill_routing_summary, "")
    }

    if ($Result.PSObject.Properties.Name -contains "recommended_next_step") {
        $lines += @("## Recommended next step", "", $Result.recommended_next_step, "")
    }

    Write-OrchestrationTextFile -Path $Path -Content (($lines -join "`n").Trim() + "`n")
}

function Get-OrchestrationRunFolder {
    param(
        [string]$RepoRoot,
        [string]$Identifier,
        [switch]$AllowLatest
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Get-OrchestrationRepoRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($Identifier)) {
        if (Test-Path -Path $Identifier) {
            return (Resolve-Path -Path $Identifier).Path
        }

        $candidate = Join-Path -Path $RepoRoot -ChildPath (".codex\runs\" + $Identifier)
        if (Test-Path -Path $candidate) {
            return (Resolve-Path -Path $candidate).Path
        }

        throw "Run folder '$Identifier' was not found."
    }

    if ($AllowLatest) {
        $runsRoot = Join-Path -Path $RepoRoot -ChildPath ".codex\runs"
        if (-not (Test-Path -Path $runsRoot)) {
            throw "No run folders exist yet."
        }

        $latest = Get-ChildItem -Path $runsRoot -Directory | Sort-Object -Property Name -Descending | Select-Object -First 1
        if ($null -eq $latest) {
            throw "No run folders exist yet."
        }

        return $latest.FullName
    }

    throw "A run identifier or path is required."
}

function New-OrchestrationFailureResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Mode,
        [Parameter(Mandatory = $true)]
        [string]$RunId,
        [Parameter(Mandatory = $true)]
        [string]$Summary,
        [Parameter(Mandatory = $true)]
        [string]$RecommendedNextStep,
        [bool]$RequiresHumanApproval = $false,
        [string]$ApprovalReason,
        [hashtable]$AdditionalProperties
    )

    $data = [ordered]@{
        run_id                  = $RunId
        mode                    = $Mode
        summary                 = $Summary
        recommended_next_step   = $RecommendedNextStep
        requires_human_approval = $RequiresHumanApproval
        approval_reason         = $ApprovalReason
        risks                   = @()
        open_questions          = @()
    }

    if ($null -ne $AdditionalProperties) {
        foreach ($key in $AdditionalProperties.Keys) {
            $data[$key] = $AdditionalProperties[$key]
        }
    }

    return [pscustomobject]$data
}

function New-OrchestrationWorktree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$RunId,
        [string]$WorktreeName
    )

    $git = Get-Command -Name git -ErrorAction Stop
    $worktreeRoot = Join-Path -Path $RepoRoot -ChildPath ".worktrees"
    New-Item -ItemType Directory -Force -Path $worktreeRoot | Out-Null

    $nameSource = $WorktreeName
    if ([string]::IsNullOrWhiteSpace($nameSource)) {
        $nameSource = $RunId
    }

    $folderName = ConvertTo-OrchestrationSlug -Value $nameSource
    $branchName = "codex/{0}" -f $folderName
    $path = Join-Path -Path $worktreeRoot -ChildPath $folderName

    if (Test-Path -Path $path) {
        throw "Worktree path '$path' already exists."
    }

    $existingBranch = & $git.Source -C $RepoRoot branch --list $branchName
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect existing git branches."
    }

    if (-not [string]::IsNullOrWhiteSpace(($existingBranch -join ""))) {
        throw "Branch '$branchName' already exists."
    }

    & $git.Source -C $RepoRoot worktree add -b $branchName $path HEAD 1> $null 2> $null
    if ($LASTEXITCODE -ne 0) {
        throw "git worktree add failed for '$path'."
    }

    return [pscustomobject]@{
        Path   = (Resolve-Path -Path $path).Path
        Branch = $branchName
    }
}

