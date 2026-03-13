# Codex Local Environment Setup

This repository includes a repo-scoped `.codex/config.toml` for documented Codex CLI configuration.

It does not attempt to author additional Codex app-generated local environment files because the exact file format and lifecycle are app-managed and may vary by version. The existing `.codex/environments/environment.toml` file should remain app-managed.

## What to configure in the Codex app

- Open the repository root as the workspace.
- Keep the repository in Local mode.
- Treat Codex app as the supervisor surface, not the worker engine.
- Let repo-local skills or manual actions invoke the orchestration scripts.
- Read generated run artifacts back into the conversation after each worker run.

## Recommended setup script

Use this for a simple environment prep action:

```powershell
docker compose build workspace
```

## Recommended app actions

Recommended names and base commands:

- `Supervisor Plan`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorPlan.ps1`
- `Supervisor Execute Approved Plan`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorExecute.ps1`
- `Supervisor Review Run`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorReview.ps1`
- `Open Latest Run Folder`
  - `powershell -NoProfile -Command "Get-ChildItem .codex\runs -Directory | Sort-Object Name -Descending | Select-Object -First 1 | ForEach-Object { $_.FullName }"`
- `Docker Compose Validate`
  - `docker compose config`
- `Workspace Shell`
  - `docker compose run --rm workspace bash`

If your Codex app build supports prompting for script arguments, bind task text, plan run id, and approval note to these entrypoints. If it does not, let the repo-local skill call the scripts directly through the terminal tool instead of relying on undocumented placeholder syntax.

## Making new worktrees usable

For each new worktree:
- open the worktree root as its own Codex workspace when you want app-level supervision there
- rerun `docker compose config` if you need the generic workspace checks
- keep orchestration runs tied to the worktree that owns the mutating changes
- keep run artifacts in the main repo's `.codex/runs/` unless you intentionally branch the template itself

## Operating guidance

- Use `Supervisor Plan` first.
- Only use `Supervisor Execute Approved Plan` after explicit human approval.
- Use `Supervisor Review Run` to summarize a run or worktree without mutating it.
- Do not guess undocumented app config formats.