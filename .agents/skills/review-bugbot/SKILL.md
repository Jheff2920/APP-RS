---
name: review-bugbot
description: Run Cursor Bugbot to find runtime failures, crashes, and logic bugs in Boleta Print. Use when the user asks to analyze code for failures, run Bugbot, or review the app so nothing breaks.
---

# Review Bugbot (Boleta Print)

Official Cursor analyzer for **failures** (not style). Installed in this repo so any agent can run it.

## When to use

- User asks to analyze the code for bugs/failures
- User says `/review-bugbot`, Bugbot, or "que nada falle"
- After a large change (Bluetooth, iOS, print, share)

## How to run

Launch exactly one `bugbot` subagent:

- `description`: `Bugbot`
- `subagent_type`: `bugbot`
- `run_in_background`: `false` unless the user asked for background

Prompt shape (do not invent extra fields):

```text
Full Repository Path: C:\Users\RS-Soporte\Documents\app
Diff: <branch changes | uncommitted changes | natural language>
Change Description: <only if Diff is natural language>
Custom Instructions: <only if the user gave extra review rules>
```

- Default: `uncommitted changes` if the working tree is dirty; else `branch changes`.
- If the user asks to review **all** the code: `Diff: natural language` and describe every major surface (print, BT, USB, iOS, share).
- After it finishes: table Severity | Location | Finding. Do not fix unless the user asks.

## Also run (this project)

```powershell
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
```
