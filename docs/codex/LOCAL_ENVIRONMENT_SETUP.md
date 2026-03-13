# Codex Local Environment Setup

This repository includes a repo-scoped [`.codex/config.toml`](../../.codex/config.toml)
for minimal Codex defaults.

This repository does not add additional Codex local-environment files beyond that
because the exact app-managed file format and lifecycle can vary across Codex app
versions. The existing `.codex/environments/environment.toml` file is treated as
app-managed.

## What to configure in the Codex app

- Open the repository root as the workspace.
- Keep the repository in Local mode.
- Prefer workspace-limited sandboxing for routine work.
- Use Docker-first commands for build, validation, and future runtime tasks.

## Recommended setup script

Use a simple setup action that prepares the generic workspace container:

```powershell
docker compose build workspace
```

## Recommended app actions

Useful actions to expose in the app:

- Validate Compose:

  ```powershell
  docker compose config
  ```

- Build workspace:

  ```powershell
  docker compose build workspace
  ```

- Open workspace shell:

  ```powershell
  docker compose run --rm workspace bash
  ```

## Making new worktrees usable

For each new worktree:
- open the worktree root as its own Codex workspace
- run `docker compose config`
- build the workspace image if needed
- keep task-specific changes isolated to that worktree

## Operating guidance

- Add stack-specific setup only after the stack is approved.
- Avoid host-local runtime setup as the default path.
- Prefer adding new app actions only when there is a stable containerized command
  worth exposing.

