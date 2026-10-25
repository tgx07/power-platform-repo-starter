---
name: powerplatform-canvas
description: Connect to Power Apps Studio, add an app data source/connector, or inspect, create, edit, or diagnose a live Canvas app through this project's Canvas Authoring MCP server.
---
<!-- power-platform-repo-starter managed -->

# Project-local Canvas authoring adapter

Resolve the repo root as `../../..` relative to this installed skill directory. Read `docs/live-authoring.md` there before remote work.

1. Confirm `.powerplatform/setup-state.json` matches this root and `.powerplatform/tooling.lock.json`. If setup is missing/stale, follow `SETUP.md`; do not install global tooling.
2. Read the selected target in `.powerplatform/local.json` and its exact logical-name mapping in `.powerplatform/source-manifest.json`. A recorded target is a user assertion, not proof of identity. Show the app/environment IDs and confirm they match the task. If no target exists, ask for the open Studio edit URL and record it with the `target` command.
3. Read `.powerplatform/runtime/plugins/canvas-apps/skills/configure-canvas-mcp/SKILL.md`. Discover the actual MCP tool names in this harness and connect to the confirmed session. Use the upstream authentication recovery guidance; credentials belong in official caches, not repo files.
4. Resolve the absolute plugin root as `.powerplatform/runtime/plugins/canvas-apps` under the repo. If adding a data source/connection/API connector (including SharePoint or Dataverse), read its `skills/add-data-source/SKILL.md`: guide the user to add it in Studio, wait for confirmation, then verify exact names and schemas/APIs through MCP. Do not attempt programmatic connector addition through the Canvas MCP. For inspection of existing sources, call `list_data_sources`/`list_apis` and relevant schema/operation tools directly instead. For app edits, read `skills/canvas-app/SKILL.md`; every `${PLUGIN_ROOT}` reference means that absolute plugin root, never the app workspace. Read the selected workflow and its required references before editing.
5. Create a fresh YAML-only directory beneath `.powerplatform/workspaces/<app-alias>/<session>/`. Synchronize current server state before reading/editing; never compile exported review YAML over a live app without reconciliation.
6. Honor the upstream metadata, preservation, coordination, and validation gates. `compile_canvas` applies remote changes; obtain task authorization before calling it. Keep the Studio tab open and verify the draft was saved separately from compilation. Publish only when explicitly authorized.

## Host capability limit

This adapter provides routing, path resolution, and project safety; it does not implement the native plugin's hooks, Task tool, or plan mode. Direct and ordinary sequential Partitioned edits stay with the coordinator when their required tools are available. If the user explicitly requests Herdr specialists, verify the project-local opt-in and follow `docs/herdr-specialists.md` plus the installed `powerplatform-canvas-herdr` skill; never delegate solely because Herdr is present. That experimental route adapts metadata/tool handoff rather than reproducing the native runtime. Without a supported orchestration route, report the limitation and use a native-plugin host or an explicitly reviewed project-local extension. Do not fabricate tool calls or claim plugin-equivalent validation. Follow the sync-before-work rule manually on every Canvas turn.
