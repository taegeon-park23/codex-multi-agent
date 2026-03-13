---
name: supervisor-execute
description: Run the approved execution handoff for this repository by invoking the repo bridge script with an already approved plan run and explicit approval note. Use only after the human has explicitly approved a specific plan and wants the mutating work to happen in an isolated worktree.
---

# Supervisor Execute

Use this skill only after the human has explicitly approved a specific plan run.

Workflow:
1. Confirm the approved plan run id or path and the supervisor approval note.
2. Run the repo bridge script from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\orchestration\Invoke-SupervisorExecute.ps1 -PlanRun "<approved run id>" -ApprovalNote "<approval note>"
```

3. Read the returned run artifacts.
4. Summarize the execution report back to the human in supervisor language.
5. If the execution report says more approval is required or a blocked action remains, stop and surface that clearly.

Important constraints:
- Do not use this skill without explicit human approval first.
- Do not pretend the app can watch live CLI sub-agent activity.
- Rely on the generated artifacts and worktree path instead.