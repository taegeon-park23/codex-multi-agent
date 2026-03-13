# Code Review Checklist

Use this checklist for future implementation work.

## Scope and clarity

- The change matches approved scope.
- Requirements are not expanded implicitly.
- Naming and structure are understandable.

## Correctness

- The behavior is coherent with the task.
- Edge cases and failure paths are considered.
- Assumptions are explicit.

## Dependencies

- New dependencies are justified.
- Heavy dependencies were approved before addition.
- Unused dependencies were not introduced.

## Docker-first workflow

- Commands work through containers where practical.
- Host-local runtime assumptions are avoided where possible.
- Container docs match actual commands.

## Testing and validation

- Validation matches the actual change.
- Test claims are real and reproducible.
- Missing coverage is called out explicitly.

## Documentation

- README and AGENTS are updated when behavior changes.
- Relevant design, planning, or QA docs are linked or updated.

## Review outcome

- Approve
- Request changes
- Block pending human decision

