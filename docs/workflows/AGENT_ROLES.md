# Agent Roles

This repository is prepared for a future human-in-the-loop workflow. The roles
below are operating roles, not separate product requirements.

## Intended flow

1. Orchestrator
   - routes incoming work
   - confirms the active objective
   - checks whether the task is planning, implementation, QA, or review
2. Planner
   - turns the request into a concrete plan
   - identifies unknowns, dependencies, and approval checkpoints
3. PM
   - maintains PRD and requirements quality
   - keeps scope and success criteria clear
4. Architect
   - proposes the solution shape
   - justifies dependencies and runtime decisions
5. Designer
   - defines UX, flows, states, and interaction notes when relevant
6. Developer
   - implements approved tasks in isolated work
   - updates docs and validation artifacts
7. Tester
   - validates behavior against requirements and test strategy
8. Reviewer and refactor
   - reviews risks, regressions, maintainability, and cleanup after tests pass

## Required gates

- Planning happens before coding.
- Architecture is reviewed before implementation starts.
- Implementation is broken into tasks before work begins.
- Testing happens before a task is considered complete.
- Refactoring follows successful tests, not the other way around.
- Human review happens at the major decision points.

## Worktree guidance

For future parallel work:
- isolate independent tasks into separate worktrees
- keep each worktree tied to one task or small task group
- merge only after validation and review

## Human checkpoints

Require explicit human review before:
- stack selection
- architecture approval
- major dependency additions
- infrastructure additions
- destructive repository actions

