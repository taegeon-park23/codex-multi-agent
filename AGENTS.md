# AGENTS.md

## Purpose

This repository is in bootstrap mode. Favor clarity, reviewability, and Docker-first
execution over speed or cleverness.

## Repo layout

- `docker/`: generic container definitions for repository work
- `docs/`: product, architecture, planning, QA, review, and Codex workflow docs
- `.agents/skills/`: future repo-local skills
- `.codex/config.toml`: repo-scoped Codex defaults

## Commands

Current supported commands:

- Validate Compose:

  ```powershell
  docker compose config
  ```

- Build workspace container:

  ```powershell
  docker compose build workspace
  ```

- Open workspace shell:

  ```powershell
  docker compose run --rm workspace bash
  ```

No product-specific build, test, lint, or dev commands exist yet. Add them only
after the product stack is approved.

## Docker-first rules

- Prefer `docker compose` commands over host-local runtimes.
- Avoid assuming host-installed Node, Python, Java, or similar toolchains.
- If a task can run inside the `workspace` container, use the container path first.
- Do not add service containers like Postgres, Redis, or message brokers until the
  product requires them and the human approves them.

## Engineering conventions

- Inspect before changing.
- Planning happens before implementation.
- Architecture is reviewed before implementation starts.
- Keep dependencies minimal and justify each major addition.
- Keep docs aligned with the current repository state.
- Use boring, maintainable defaults.

## Do-not rules

- Do not invent product requirements.
- Do not scaffold a product framework without approval.
- Do not bypass approval gates for major dependencies or destructive actions.
- Do not claim tests passed when no real tests exist.
- Do not optimize for cloud deployment before the product needs it.

## Approval gates

Ask for approval before:
- choosing or changing the primary application stack
- adding heavy frameworks
- adding infrastructure services
- performing destructive actions
- changing the repository operating model

## Definition of done

For bootstrap-phase changes:
- files are small, reviewable, and aligned with current scope
- Docker-first commands are documented and coherent
- templates remain generic and do not contain fake product details
- validation results are explicit
- open questions are called out clearly

## Review expectations

Reviews should check:
- scope discipline
- dependency justification
- documentation accuracy
- Docker command coherence
- future task isolation and worktree friendliness

## How Codex should behave in this repo

- Inspect first, then propose or implement.
- Prefer containerized workflows where practical.
- Keep humans in the loop at major decision points.
- Treat this repository as foundation-only until the product stack is approved.
- Avoid host-local runtime assumptions where possible.

