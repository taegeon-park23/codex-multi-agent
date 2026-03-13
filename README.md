# Repository Bootstrap Foundation

## What this repository is for

This repository currently contains the operating foundation for a future product.
It is intentionally limited to bootstrap infrastructure, process documentation,
and Docker-first development ergonomics.

## Current status

Bootstrap and foundation only.

Not included yet:
- product requirements
- application code
- product framework selection
- database or cache services
- CI/CD automation

## Prerequisites

- Windows 11 host
- Git
- Docker Desktop with `docker compose`
- Codex desktop app in Local mode

No host-local Node, Python, or other product runtime is required for the normal
workflow at this stage.

## Quick start

1. Optional: copy `.env.example` to `.env` if you want a custom Compose project name.
2. Validate the Compose file:

   ```powershell
   docker compose config
   ```

3. Build the workspace container:

   ```powershell
   docker compose build workspace
   ```

4. Open a shell inside the workspace container:

   ```powershell
   docker compose run --rm workspace bash
   ```

## Docker-first workflow

This repository is set up so that future development, build, test, and validation
commands can run inside containers instead of relying on host-installed runtimes.

Current command surface:
- Validate container configuration:

  ```powershell
  docker compose config
  ```

- Build the generic workspace image:

  ```powershell
  docker compose build workspace
  ```

- Open an interactive workspace shell:

  ```powershell
  docker compose run --rm workspace bash
  ```

Until the product stack is chosen, there are no app-specific `dev`, `test`, or
`lint` commands yet.

## Repository structure

```text
.
|- .agents/
|- .codex/
|- docker/
|- docs/
|- AGENTS.md
|- README.md
`- docker-compose.yml
```

## How to continue after bootstrap

1. Define the product before choosing the stack.
   - Start with [docs/product/PRD.template.md](docs/product/PRD.template.md)
   - Then complete [docs/product/REQUIREMENTS.template.md](docs/product/REQUIREMENTS.template.md)
2. Review architecture before implementation.
   - Use [docs/architecture/ARCHITECTURE.template.md](docs/architecture/ARCHITECTURE.template.md)
3. Break approved work into tasks before coding.
   - Use [docs/planning/TASK_BREAKDOWN.template.md](docs/planning/TASK_BREAKDOWN.template.md)
4. Add the actual application scaffold only after the human approves the stack,
   dependency footprint, and initial architecture.

## Human approval checkpoints

Human approval is expected before:
- choosing the application stack
- adding major dependencies or services
- introducing data stores or background infrastructure
- making destructive repository actions
- moving from templates to implementation

