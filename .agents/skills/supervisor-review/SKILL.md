---
name: supervisor-review
description: Run a read-only review or test fan-out for this repository by invoking the repo bridge script and then summarizing the generated artifacts. Use when the human wants a supervisor-oriented review of a run, worktree, or current repository state without mutating files.
---

# Supervisor Review

Use this skill for read-only review, risk summarization, or test-status analysis.

Workflow:
1. Run the review bridge script from the repository root.
2. Pass either a prior run id or a target path.
3. Read `result.md` and `result.json` from the generated run folder.
4. Summarize findings, validation status, and recommended next step for the human.

Example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorReview.ps1 -TargetRun "<run id>"
```

Important constraints:
- Keep the phase read-only.
- Do not pretend the app can stream hidden CLI worker details.
- Use the generated artifacts as the review surface.