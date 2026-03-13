# Approval Model

## Default rule

Read-only planning and review are the default.
Mutating execution requires explicit prior human approval at the app level.

## Why the model is strict

This template is designed around a known limitation:
Codex CLI may need approval or sandbox changes during a worker run, but nested non-interactive approval prompts are not a reliable supervisor interface inside the app.

Therefore this repository does not hide that limitation.
It designs around it.

## Practical rules

### Planning and review

- use read-only sandboxing
- use `approval_policy = "never"` for non-interactive worker sessions
- if the worker would need more permissions, it should fail safely and report the block
- any recommended mutating next step must set `requires_human_approval = true`

### Execution

- only start from an already approved plan run
- require an explicit approval note
- create an isolated worktree by default
- use write-capable sandboxing only inside that approved execution phase
- if isolation fails, stop and report the block
- if more approval or broader access would be needed, stop and report it

## Never allowed by default

- `danger-full-access`
- `--dangerously-bypass-approvals-and-sandbox`
- silent escalation
- hidden autonomous expansion of scope

## Approval checkpoints

Supervisor approval is required before:
- moving from plan to execute
- changing from read-only analysis to write-capable work
- using a different target worktree than the one already approved
- any destructive or scope-expanding action

## Reporting requirements

The worker output must make these fields clear:
- whether approval is required
- why approval is required
- what the recommended next step is
- what risks or blocked actions remain