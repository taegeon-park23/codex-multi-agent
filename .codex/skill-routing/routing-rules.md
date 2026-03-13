# Skill Routing Rules

This repository uses a deterministic skill-routing contract during supervised planning.

## Default order

1. Inspect the skill catalog first.
2. Decompose the task into supervisor-visible subtasks.
3. Evaluate each subtask against the catalog.
4. Decide whether a skill is:
   - implicit candidate
   - explicit candidate
   - blocked by prerequisites
   - deferred until execution
   - not applicable
5. Produce the final plan with a human-readable routing summary.

## Routing heuristics

### General rules

- Use the repo-managed catalog as the routing source of truth.
- Do not invent unlisted skills.
- Do not hide uncertain mappings.
- Treat repo-local supervisor skills as control-plane entrypoints, not normal subtask solvers.

### Choose the primary skill candidate when

- the skill's `should_trigger_for` matches the subtask closely
- the skill's `should_not_trigger_for` does not conflict
- prerequisites are satisfied or can be stated clearly
- the current phase is listed in `safe_phase`

### Mark a skill as an implicit candidate when

- `invocation_name_status` is `confirmed`
- the current phase is in `safe_phase`
- `mutates_files` is `false`
- prerequisites are already satisfied

### Mark a skill as an explicit candidate when

- `invocation_name_status` is not `confirmed`
- or the skill is specialized enough that the human should see it named explicitly
- or the skill has prerequisites or side effects the supervisor should notice even if it is otherwise allowed

### Mark a skill as deferred until execution when

- `safe_phase` is execution-only
- or `mutates_files` is `true`
- or the current planning pass should not cross an approval gate

### Mark a skill as blocked by prerequisites when

- required MCP access is missing
- required environment variables or local runtimes are missing
- required target context does not exist yet
- the user has not provided the required design, URL, app, or approved plan

### Mark a skill as not applicable when

- it does not materially help with the current task
- it would push the workflow into an unsupported or higher-risk path

## Honesty rules

- If a skill is visible in this environment but its invocation name cannot be proven, record the probable invocation name and mark the status honestly.
- If a skill needs a capability that is not safe in the current phase, surface that as a deferred or blocked skill rather than pretending it can be used now.
- Do not imply that the Codex app can see live CLI child-agent internals.
- Do not imply that implicit invocation is guaranteed just because a skill is a candidate.

## Supervisor expectations

The final plan should make these points easy for the human supervisor to read:

- which skills were checked
- which skills fit which subtasks
- which skills are safe in the current read-only planning phase
- which skills are blocked or deferred
- which next step requires human approval
