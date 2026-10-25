---
name: powerplatform-canvas-herdr
description: Coordinate Canvas specialist Pi sessions when the user explicitly requests Herdr for a Canvas workflow; requires an active Herdr pane and project-local opt-in.
---
<!-- power-platform-repo-starter managed -->

# Herdr Canvas coordinator

Resolve the repo root as `../../..` relative to this installed skill directory. Read `docs/herdr-specialists.md` completely before dispatch. This is an opt-in adaptation, not a native Task tool or proof of plugin parity.

1. Require an explicit user request to use Herdr for this task. Check `HERDR_ENV=1` before any Herdr control command. Outside Herdr, stop this route; do not inspect/control a focused session from elsewhere. Verify local setup state has `harness: pi` and `herdrSpecialists: true` and matches the current root/tooling lock.
2. Establish the authorized Canvas task, intended app/environment, current synchronized YAML, and selected upstream workflow. Use the normal Canvas adapter for connection and route assessment. Direct/ordinary sequential Partitioned edits stay in the coordinator; use specialists only where the selected upstream CREATE or Planned EDIT workflow delegates them.
3. Inspect `herdr --help`, `herdr agent`, and `herdr pane` to verify current syntax. Follow any available Herdr skill. Use opaque IDs returned by the CLI, preserve the caller's project cwd/focus, and create only owned sibling panes. Never manipulate unrelated agents/panes.
4. Prepare absolute-path task handoffs and a baseline source inventory in a coordination directory outside the YAML sync tree. Assign non-overlapping writes and current revisions. Select the pinned upstream specialist definition and required references; never copy the full coordinator conversation as the role specification.
5. Launch Pi workers with the restricted flags and appended worker contract documented in `docs/herdr-specialists.md`. Workers have no MCP and no delegation authority. Send the exact task-file path, wait for settled state, inspect their response, and verify actual artifacts/changed paths before accepting results. Unknown, blocked, failed, or stale results are not completion.
6. Broker only approved read-only metadata requests through the coordinator's existing MCP session. Return raw results with query and app/revision provenance; workers must consume them before configuring controls. Scope/UX/data compromises return to the user. Never invent a specialist tool call that did not occur.
7. Keep upstream stage dependencies and approval gates. Run at most three independent screen builders per wave, unless the pinned workflow is stricter. The coordinator alone owns App/editor files, shared contract application, sync, compile/apply, validation, and user communication. Do not sync/compile or edit shared app state while workers can still write.
8. Before applying, verify scope/diffs, metadata validity, local QA evidence, and all worker handoffs. Follow the upstream compilation/convergence gates within task authorization. Report this adapter's deviations and which static/applied/runtime checks actually ran. Save/publish remain separate operations.

Do not spawn any session just because this skill was installed or because Herdr is present. Installation, availability, and authorization to delegate are distinct. The worker flags/file allowlists are not a sandbox; a worker shell still has OS-user privileges. See the documented pilot limitations before claiming this workflow is production-validated.
