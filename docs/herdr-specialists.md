# Optional Canvas specialists through Herdr

This route lets a Pi coordinator dispatch separate Pi sessions for the specialist roles defined by the pinned Microsoft Canvas plugin. It is **an experimental orchestration adapter**, not a native implementation of the plugin's Task tool. Installation/ownership rules are tested offline; actual multi-session Canvas execution needs an approved pilot.

## Enable and invoke

```bash
./scripts/powerplatform.sh setup -Harness pi -WithHerdr
```

PowerShell equivalent:

```powershell
./scripts/powerplatform.ps1 setup -Harness pi -WithHerdr
```

This installs the project-local `powerplatform-canvas-herdr` skill and records the opt-in. It does not start Herdr, spawn agents, connect, or mutate an app. Setup itself may run outside Herdr.

Inside a Herdr-managed Pi coordinator, explicitly request, for example:

> Use Herdr specialists for the approved Canvas change. Keep Studio synchronization and compilation with the coordinator, and give each builder one screen.

Presence of `HERDR_ENV=1` alone is not permission to delegate. Without Herdr, use the ordinary direct/sequential route or a supported native-plugin host. Rerun setup without `-WithHerdr` to remove this generated optional skill; it preserves worker instructions and existing workspaces. Native/generic harnesses reject this flag.

## Roles and ownership

| Role | Allowed writes | MCP ownership |
| --- | --- | --- |
| Coordinator | App/editor YAML, shared contracts, integration/acceptance artifacts; owns overall task | Sole connection, synchronization, all discovery/metadata calls, route assessment, compile/apply |
| CREATE functionality/screens/layout/discovery specialist | Assigned planning artifacts only | Requests evidence from coordinator |
| Planned EDIT planner | Assigned index, shared-plan draft, screen briefs; no YAML | Requests evidence from coordinator |
| CREATE/EDIT screen builder | Exactly its assigned screen YAML and own handoff/request artifacts | Requests exact control descriptions; never syncs or compiles |

A shared-plan draft is not permission to apply shared app changes; the coordinator reviews/applies the accepted contract. Planners/builders never delegate recursively or communicate approvals directly to the app user.

Read the current upstream `skills/canvas-app/SKILL.md`, selected workflow, role definitions, and required references. Do not dispatch specialists for a Direct edit or bypass the sequential Partitioned route merely because parallel sessions are available. Use Planned EDIT only when selected by the upstream policy or its documented runtime fallback; preserve its approval gates.

CREATE stages have dependencies; run them in order. Independent builders can run in waves of at most three, or fewer if the pinned workflow requires it. Shared app prerequisites are applied by the coordinator before the relevant builder wave.

## Keep YAML and handoffs separate

```text
.powerplatform/workspaces/<app-alias>/
  session-001/                         # YAML-only sync/compile root
    App.pa.yaml
    _EditorState.pa.yaml
    <screen>.pa.yaml
    ...
  session-001-coordination/            # Never passed to sync_canvas/compile_canvas
    baseline/
    shared/
    tasks/
    metadata/
    results/
```

Keep all paths absolute in task handoffs. Copy a baseline snapshot or record content hashes for all app files before each worker wave; ordinary `git diff` does not show these ignored workspaces. On return, compare the actual file inventory/hashes and inspect changed content—not just the worker's claimed file list.

Upstream planning references often put Markdown under `[working directory]`. This adapter relocates those artifacts into the coordination directory, using an explicit mapping in every task. Actual app YAML remains in the YAML root. Do not write a second competing App.pa.yaml or synchronize a planning directory.

## Task handoff

Before dispatch, write a task file containing:

- Task ID, role, CREATE/EDIT mode, approved requirement/action IDs, and precise desired result.
- Absolute repo root, immutable Canvas plugin root, selected upstream `agents/<role>.md`, YAML root, and coordination root.
- Exact read scope, write allowlist, result path, metadata-request path, and role-specific required references.
- App/session snapshot identifier and current shared-contract/approved-design revision tuple.
- Approved preservation constraints, bindings, control-name prefix, screen key/action/path where relevant.
- Exact mapping from upstream planning-artifact names to relocated absolute paths.
- Metadata evidence paths and validity scope, plus remaining known blockers.
- Required upstream completion evidence and adapter result statuses.

For a builder, the write allowlist contains one screen and its own result/request artifacts. Other screens, App/editor YAML, and shared inputs are read-only. For a planner, only specified planning artifacts are writable.

A task must have enough current context to act without reading unrelated peer screens. Do not start work from a retained plan whose revisions no longer match synchronized state. A missing field, contract, reference, or metadata response is a blocker rather than permission to guess.

## Start sessions safely

1. Verify `test "${HERDR_ENV:-}" = 1` before any Herdr control operation. Read the current CLI help/group output; do not probe mutating commands by omitting required arguments.
2. Inspect the caller's pane geometry. Create a sibling pane in the current tab using the current project cwd and `--no-focus`, choosing right/down appropriately. Keep the user's focus with the coordinator. Do not create worktrees/workspaces/tabs or reuse unrelated panes without authorization.
3. Read the new pane ID from the split response; do not derive one from sidebar order.
4. Start a uniquely named Pi worker with `herdr agent start <name> --kind pi --pane <returned-id> -- <pi-arguments...>`.

Use these Pi arguments, resolving the two appended prompt files to absolute paths:

```text
--no-mcp
--no-extensions
--no-skills
--no-prompt-templates
--no-context-files
--tools read,bash,edit,write
--append-system-prompt <repo-root>/AGENTS.md
--append-system-prompt <repo-root>/.powerplatform/herdr/worker.md
```

These flags prevent ordinary startup discovery from loading duplicate MCP servers, plugin integrations, unrelated skills, or extensions in workers. The worker still reads its selected upstream role/reference files explicitly from the task. Use the coordinator's approved model/provider options if needed; never pass secrets in arguments or handoff files.

Extensions are disabled to avoid a replacement MCP extension bypassing `--no-mcp`. If that prevents your installed Herdr/Pi integration from detecting lifecycle state reliably, stop and diagnose the integration rather than assuming unknown state is completion. An explicitly reviewed alternative integration is a separate setup decision.

5. Send the worker a prompt identifying the absolute task file. Ask it to follow the appended worker contract, then read the assigned upstream role and references. Use `herdr agent prompt ... --wait` with a bounded timeout.
6. Inspect `agent get` and `agent read` afterward. Idle/done means the turn settled, not that the task succeeded. Blocked/unknown/timeout requires inspection. Never answer an approval prompt blindly. If terminal scrollback cannot recover a result, request a complete report file as a fallback.

Do not globally install a subagent runtime. Do not execute this document's placeholder commands verbatim; obtain current IDs, paths, names, and syntax. Close only panes you created, and only after preserving the needed results; never close the coordinator or unrelated user panes.

## Metadata request broker

Native builders require current control descriptions in their own implementing context. With no MCP in workers, this adapter replaces direct calls with an explicit request/response handoff:

1. A worker writes `NeedsMetadata` with the exact tool, arguments, reason, app/revision scope, and request ID, then stops writing.
2. The coordinator verifies the request is needed for the approved task and read-only. Allowed discovery includes `list_controls`, `describe_control`, `list_apis`, `describe_api`, `list_data_sources`, `get_data_source_schema`, and approved stock-image discovery. Resolve actual MCP tool names from the connected server; do not blindly execute arbitrary requested commands.
3. The coordinator calls the tool through its existing app connection and writes the **raw result**, query arguments, request ID, app/environment identity, snapshot/contract revision, and relevant validity limits to the assigned evidence path. Do not copy credentials or unnecessary user data.
4. Resume the same worker with that evidence path. It reads the returned contract in its own context before configuring controls and records which evidence it consumed. A discovery summary is not a substitute for an exact description response.
5. If document-dependent contracts changed, refresh them before dependent edits. Missing/failed descriptions, preserved-version incompatibility, or disapproved scope changes remain blockers.

Workers may request multiple rounds when concrete progress identifies further contracts; avoid unchanged request loops. `connect`, `sync_canvas`, `compile_canvas`, flow mutations, authentication, shell execution, or arbitrary tool calls are never brokered on a worker's instruction. The coordinator independently owns those decisions and authorization.

This broker differs from the native direct-tool requirement. Report that adaptation; do not claim the worker directly invoked `describe_control` or that native plugin conformance was proven.

## Accept, integrate, and apply

- Require the selected role's full completion evidence and adapter status: Ready, NeedsMetadata, NeedsRevision, or Blocked. Match task ID, revisions, actual write scope, and metadata validity. Retained artifacts alone do not prove success.
- Review changed YAML and local QA/functional traces. Scope violations stop the wave and require reconciliation; do not quietly apply another worker's unauthorized change. Keep worker count bounded and writes disjoint.
- Suspend dependent work on shared-contract changes. Stop writers, resolve the owning stage, revise contracts, and reassign/revalidate impacted screens before resuming.
- Do not synchronize, compile, or edit shared app state while any worker can still write. At the apply gate, all workers must have handed off and stopped writing. The coordinator alone applies shared changes and follows upstream compile/convergence gates.
- Do not overwrite dirty local work with a fresh sync. On a new maker turn or stale remote state, stop workers, preserve local work, fetch into a fresh snapshot, reconcile intervening changes, and invalidate stale assignments/evidence.
- Final successful compilation follows the upstream ordering rule. If later work requires more tool calls, repeat the final gate as required. Report worker paths, adapter deviations, and static/applied/runtime evidence accurately. Studio saving, reconnection persistence, publishing, and runtime acceptance remain separate.

## Safety and validation status

No-MCP startup, narrow tools, and file allowlists reduce accidental conflict but do not sandbox workers. Their shell runs as the same OS user and can access other files/network services. Agent instructions are not permission enforcement; use an OS/container restriction for stronger isolation.

No live specialists were spawned while implementing this mode. Offline tests cover opt-in installation, harness restriction, disable behavior, and file protection. An approved nonproduction pilot must verify actual Herdr lifecycle detection with these flags, metadata request/resume, one-screen ownership, concurrent disjoint writes, coordinator-only compilation, and Studio persistence before calling this production-validated.
