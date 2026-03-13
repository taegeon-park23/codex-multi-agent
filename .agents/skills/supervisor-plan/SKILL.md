---
name: supervisor-plan
description: Run supervised planning, architecture, decomposition, risk, or analysis fan-out for this repository by invoking the repo bridge script and then summarizing the generated run artifacts. Use when the human wants a read-only proposal before any implementation or higher-risk step.
---

# Supervisor Plan

Use this skill when the task is still in planning, analysis, architecture, review-planning, or risk-assessment mode.

Workflow:
1. Run the repo bridge script from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorPlan.ps1 -Task "<task text>"
```

2. Read the generated artifacts from the returned run folder.
3. Use `result.md` for the quick summary and `result.json` for structured fields.
4. Summarize the run back to the human in supervisor language.
5. If `requires_human_approval` is true, explicitly ask for approval before suggesting the execute skill.

Important constraints:
- Do not claim the app can natively see live CLI child-agent internals.
- Treat artifacts as the visibility bridge.
- Keep the phase read-only.