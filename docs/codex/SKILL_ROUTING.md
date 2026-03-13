# Skill Routing

## Purpose

This repository uses a repo-managed skill-routing contract so that supervised planning can route subtasks to the best matching skills without pretending to have undocumented runtime magic.

The routing source of truth lives in:
- `.codex/skill-routing/skills-catalog.yaml`
- `.codex/skill-routing/routing-rules.md`

## What skill-aware planning means here

When `Supervisor Plan` runs, it does not jump straight into decomposition.
It first inspects the skill catalog, then:

1. decomposes the task into subtasks
2. maps each subtask to zero, one, or multiple candidate skills
3. distinguishes planning-safe candidates from execution-deferred ones
4. records the routing decisions in `result.json` and `result.md`

## Routing categories

- `recommended_skill_invocations`
  - the strongest routing recommendations for the current task
- `implicit_skill_candidates`
  - skills that are confirmed, safe in the current phase, and reasonable to use without extra ceremony
- `explicit_skill_candidates`
  - skills that should be named clearly to the human because they are specialized, uncertain, or otherwise need visible steering
- `skills_blocked_by_prerequisites`
  - skills that fit the task but cannot be used yet because prerequisites are missing
- `skills_deferred_until_execution`
  - skills that fit the task but should not be used during the current read-only planning phase
- `skills_not_applicable`
  - cataloged skills that were checked and ruled out for this task

## Invocation-name honesty

This template records both a display name and an invocation mapping when possible.

If the invocation name is directly supported by evidence such as:
- `SKILL.md` frontmatter `name`
- repo-local skill frontmatter
- clearly documented prompt references

then the mapping can be marked as `confirmed`.

If the evidence is weaker, the result should surface:
- a probable invocation name
- a mapping status such as `probable` or `needs_manual_confirmation`

Do not silently guess.

## Control-plane vs domain skills

Repo-local `supervisor-plan`, `supervisor-execute`, and `supervisor-review` are workflow entrypoints.
They are not treated as ordinary domain skills for subtask implementation.

Planning should route domain subtasks to domain-relevant skills, while still using the supervisor skills as the visible workflow controls.

## Artifact visibility

The Codex app is still not treated as a live view into CLI child-agent internals.
The human supervisor should read the routing decisions from artifacts, especially:
- `result.json`
- `result.md`
- `effective-prompt.md` when deeper inspection is needed
