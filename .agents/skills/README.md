# Repo-local Skills

This repository now includes repo-local skills for supervised planning, approved execution, and read-only review.

Current skills:
- `supervisor-plan`
- `supervisor-execute`
- `supervisor-review`

Each skill should:
- keep the app in the supervisor role
- invoke the PowerShell bridge scripts
- read back generated artifacts
- avoid pretending the app can stream CLI child-agent internals
- preserve human approval checkpoints