# Supervised Orchestration

## What it means in this repository

Supervised orchestration means:
- the human stays in the loop
- Codex app is the main review and approval surface
- Codex CLI performs worker fan-out and non-interactive execution
- structured artifacts bridge the visibility gap between app and CLI

This repository is not a fully autonomous agent system.
It is a supervised template for future projects.

## Responsibilities

### Codex app

- collect the natural-language task from the human
- invoke a repo-local skill or local action
- read generated artifacts after a worker run
- summarize results in supervisor language
- ask for human approval before higher-risk or mutating phases

### Codex CLI

- run non-interactive worker sessions
- optionally fan out to documented repo-local roles
- write structured and human-readable artifacts to disk
- stop cleanly when approval or safety boundaries prevent further work

### Human

- provide the initial task
- review plan and review artifacts
- approve or reject any write-capable execution step
- decide whether the proposed next step is acceptable

## Modes

### Read-only planning mode

Used for:
- decomposition
- architecture shaping
- risk analysis
- testing and review planning

Properties:
- read-only sandboxing
- no repo mutation
- begins with skill catalog inspection and deterministic subtask routing
- produces proposal artifacts and approval requests when execution is recommended

### Approval-gated execution mode

Used for:
- implementing an already approved slice
- making write-capable changes inside an isolated worktree

Properties:
- explicit prior approval required
- isolated worktree by default
- bounded scope
- no dangerous sandbox bypasses

### Review mode

Used for:
- reviewing a prior execution run
- summarizing current worktree risks and test posture
- generating supervisor-facing findings without mutating anything

## Artifact location

Runs live under `.codex/runs/<run-id>/`.
Each run writes:
- `request.md`
- `effective-prompt.md`
- `result.json`
- `result.md`
- `approval-request.md` when applicable
- mode-specific report copies such as `execution-report.json` or `review-report.json`
- `events.jsonl`
- `logs/`

For planning runs, `result.json` and `result.md` should also show:
- which skills were checked
- which subtasks matched which skills
- which skill suggestions are implicit, explicit, blocked, or deferred until execution

## Worktree usage

Use local mode for:
- read-only planning
- read-only review
- repo-wide documentation analysis

Use worktree mode for:
- any approved write-capable execution
- isolated implementation slices
- reducing collisions between parallel tasks

Background automations are not enabled by default in this template.
If added later, they should remain non-destructive and supervisor-first.

## Known limitations

- Codex app is not treated as a live child-agent monitor.
- Nested CLI approval prompts are not a reliable supervisor UX.
- Therefore the safe default is read-only fan-out first, approved worktree execution second.
- `.codex/environments/environment.toml` remains app-managed and is not hand-authored here.
- This workflow is intentionally generic and does not imply a web-only stack.
