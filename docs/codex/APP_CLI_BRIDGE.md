# App to CLI Bridge

## Purpose

The bridge scripts translate a Codex app interaction into a Codex CLI worker run and then back into artifacts that the app can read.

Default path:
- app prompt
- repo-local skill or app action
- PowerShell bridge script
- `codex exec`
- run artifacts on disk
- app reads `result.md` and `result.json`
- human approves or rejects the next step

## Bridge scripts

- `scripts/orchestration/Invoke-SupervisorPlan.ps1`
  - read-only planning and analysis fan-out
- `scripts/orchestration/Invoke-SupervisorExecute.ps1`
  - approved execution handoff in an isolated worktree
- `scripts/orchestration/Invoke-SupervisorReview.ps1`
  - read-only review and test fan-out
- `scripts/orchestration/New-RunFolder.ps1`
  - utility for creating a run folder
- `scripts/orchestration/common/Orchestration.Common.ps1`
  - shared helpers for prompt building, artifact writing, CLI invocation, and worktree creation

## Artifact contract

Every run produces machine-readable and human-readable outputs.

Core artifacts:
- `request.md`
- `effective-prompt.md`
- `result.json`
- `result.md`
- `events.jsonl`
- `logs/stdout.log`
- `logs/stderr.log`

Optional or mode-specific artifacts:
- `approval-request.md`
- `execution-report.json`
- `review-report.json`

## Why artifacts matter

The Codex app cannot be assumed to surface all CLI child-agent internals.
The artifact layer is therefore the visibility contract.

The app should read and summarize:
- `result.md` for quick supervisor-facing status
- `result.json` for machine-readable fields such as `requires_human_approval`, `recommended_next_step`, `risks`, and `proposed_subtasks`

## Profile usage

Bridge scripts use repo-local profiles from `.codex/config.toml`:
- `supervisor_plan`
- `supervisor_execute`
- `supervisor_review`

Those profiles set the root worker instructions, and the repo-local agent definitions provide the role-specific behavior for planner, architect, tester, reviewer, and implementer.

## Failure behavior

If a worker run fails:
- the bridge keeps the run folder
- logs remain on disk
- a fallback `result.json` and `result.md` are written when possible
- the next step tells the supervisor to inspect logs and decide how to proceed