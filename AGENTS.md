# AGENTS.md

## Purpose

This repository is a supervised orchestration template.
Use it to route Codex app prompts into Codex CLI worker runs while keeping the human in the loop.

## Repo layout

- `docker/`: generic workspace container for future product work
- `docs/`: product templates plus Codex orchestration docs
- `.codex/`: repo-local Codex config, agent configs, instruction files, skill-routing catalog, schemas, and ignored run artifacts
- `scripts/orchestration/`: PowerShell bridge scripts for supervisor plan, execute, and review flows
- `.agents/skills/`: repo-local skills that tell the app how to invoke the bridge scripts

## Commands

Container and workspace commands:

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

Supervisor workflow commands:

- Plan:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorPlan.ps1 -Task "Describe the task here"
  ```

- Execute an approved plan:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorExecute.ps1 -PlanRun <run-id> -ApprovalNote "Approved scope: ..."
  ```

- Review a run:

  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorReview.ps1 -TargetRun <run-id>
  ```

## Operating model

- Codex app is the supervisor surface.
- Codex CLI is the worker engine.
- Read-only planning and review are the default.
- Planning begins with skill inspection against the repo-managed skill catalog and routing rules.
- Write-capable execution requires prior human approval and isolated worktree mode.
- Run artifacts are the source of truth for what the worker did or proposed.

## Docker-first rules

- Keep Docker-first principles for future product/runtime workflows.
- Do not force future product work onto host-local Node, Python, or similar runtimes.
- The orchestration layer is the exception: Codex app and Codex CLI run on the host by necessity.

## Engineering conventions

- Inspect before changing.
- Keep the repository generic.
- Keep role instructions narrow and explicit.
- Prefer boring, maintainable defaults.
- Keep approval gates visible in code and docs.
- Keep artifacts machine-readable and human-readable.
- Surface uncertain skill mappings honestly instead of guessing.

## Do-not rules

- Do not pretend the app can natively show all CLI sub-agent activity.
- Do not pretend uncertain skill mappings are confirmed.
- Do not skip approval gates.
- Do not silently switch to dangerous full access.
- Do not choose a product stack unless explicitly approved.
- Do not add service containers or heavy frameworks unless the orchestration foundation itself truly needs them.

## Approval gates

Ask for approval before:
- invoking the execute handoff
- widening scope beyond the approved plan
- destructive actions
- heavy dependency additions
- infrastructure additions
- changing the repo operating model again

## Definition of done

For this repo's orchestration work:
- docs match the real workflow
- scripts create coherent run artifacts
- schemas are valid JSON
- read-only vs approved execution is explicit
- worktree isolation is used for mutating work
- validation claims are real

## Review expectations

Reviews should focus on:
- approval-model correctness
- artifact completeness
- script safety and Windows friendliness
- doc consistency
- product-stack neutrality

## How Codex should behave in this repo

- Use repo-local skills when the task matches supervised planning, execution, or review.
- Start planning by inspecting `.codex/skill-routing/skills-catalog.yaml` and `.codex/skill-routing/routing-rules.md`.
- Read generated artifacts back to the human instead of pretending to stream hidden CLI internals.
- Distinguish implicit skill candidates from explicit or execution-deferred recommendations.
- Keep humans in the loop before any higher-risk step.
- Treat `.codex/environments/environment.toml` as app-managed.
- Avoid host-local runtime assumptions for future product code where possible.
