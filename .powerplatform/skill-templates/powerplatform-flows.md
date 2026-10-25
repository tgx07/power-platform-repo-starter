---
name: powerplatform-flows
description: Browse, author, inspect runs, or diagnose Power Automate cloud flows through this project's FlowAgent MCP server.
---
<!-- power-platform-repo-starter managed -->

# Project-local flow adapter

Resolve the repo root as `../../..` relative to this installed skill directory. Read `docs/live-authoring.md` there before remote work.

1. Confirm local setup is current using `.powerplatform/setup-state.json` and `.powerplatform/tooling.lock.json`. Resolve the absolute plugin root as `.powerplatform/runtime/plugins/power-automate` under the repo.
2. Read that plugin's `README.md`. Select and read the relevant skill under its `skills/` directory: `browse-flows`, `create-flow`, `build-flow`, `debug-flow`, `diagnose-flow`, or `manage-flows`. Use `route-environments` only for maker/default-environment routing, not routine solution configuration or connection-reference review. For environment-variable/deployment mapping reviews, use the starter's `powerplatform-configuration` skill. Resolve all supporting paths against the installed plugin root and selected skill directory. Read required references, not the whole skill catalog.
3. Discover the actual FlowAgent tool names. Use read-only identity and environment inspection first. Confirm the intended account, tenant, environment, and existing flow IDs against the user's task. Do not trust a cached current environment or infer flow identity from display names alone.
4. Apply the selected upstream procedure within the approved scope. Flow creation/edits, publishing, enable/disable/delete, test execution, resubmission, connection changes, and rollback are remote mutations. Ask for authorization when not covered by the task; a diagnostic request is read-only by default.
5. Keep local evidence and backups under ignored `.powerplatform/workspaces/`. Redact run inputs/outputs and connection details before reporting or committing them. Export and unpack a new solution to refresh `src/` after approved live changes.

If upstream setup proposes writing `~/.copilot/mcp-config.json` or another global configuration, use this project's `SETUP.md` instead. This adapter does not reproduce native plugin hooks or permission enforcement; host limitations must be reported, not silently bypassed.
