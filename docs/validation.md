# Validation record — starter 0.5.0

Validated on **2026-10-17**, macOS ARM64. No source or agent configuration in the example repositories was changed. Customer exports were copied only to disposable temporary projects and are not included in this starter.

## Toolchain used

| Tool | Version |
| --- | --- |
| PowerShell | 7.5.3 |
| .NET SDK | 10.0.301 |
| PAC | 2.8.1 |
| Node.js | 24.12.0 |
| Microsoft skills repository | `478cfdf838aa614a09915d4606e6fd4227490fed` |
| Canvas Authoring MCP package | 1.1.29 |
| Claude Code CLI inspected | 2.1.302 |
| GitHub Copilot CLI inspected | 1.0.98 |
| Pi documentation/CLI inspected | 1.3.0 |
| Herdr CLI inspected | 0.9.5 |

This records the test environment, not a guarantee of compatibility with every version of those hosts.

## Executed checks

### Offline suite: 40 passed, 0 failed

Command:

```powershell
pwsh -NoLogo -NoProfile -File ./tests/Run-Tests.ps1
```

Uses temporary Git repositories, synthetic exports, and a fake PAC. No network, sign-in, model invocation, or Power Platform access.

Coverage includes:

- Numeric version selection independent of input filename order.
- Multiple Canvas apps, nested component YAML, preservation of exported assets, and exclusion of `.msapr` intermediates.
- Repeat output determinism and removal of obsolete generated apps.
- Dirty source/provenance protection and explicit destructive override.
- Preview without PAC invocation or writes.
- Managed inputs, multiple identities, previous identity binding, malformed versions, missing inputs, conflicting duplicate versions, and identical duplicate inputs.
- Alias collisions, explicit overrides, portable alias validation, unmapped packages, missing app YAML, and unexpected output.
- Solution/Canvas failures preserving previous source; manifest-replacement rollback; rollback failure retaining source and provenance recovery files.
- ZIP traversal/case-collision rejection, PAC version mismatch, and concurrent writer exclusion.
- Studio URL parsing, URL-decoded provider app IDs, unknown target/host rejection, and preservation of unrelated local settings.
- Local setup idempotency, pinned/deferred MCP configuration, preservation of unrelated MCP entries, conflicting-entry protection, non-starter/additional skill-file protection, native/adapter separation, vendor cleanliness including ignored files, and stale-lock launch protection.
- Herdr opt-in installation, Pi-only harness restriction, disable behavior, and preservation of additional files in the optional skill directory. Tests do not invoke Herdr or spawn workers.
- Offline configuration-skill availability/preservation during native setup, and refusal of upstream assets missing Canvas `add-data-source` guidance. This checks packaging/routing prerequisites, not whether an agent obeys the review/redaction procedure.

Setup tests use a small synthetic upstream Git fixture; actual upstream restore is checked separately below. These checks are not application/runtime tests.

### Real PAC: two examples, twice each

```powershell
./tests/Invoke-RealPacSmoke.ps1 -SolutionZip '<unmanaged-export.zip>'
```

| Example input | Solution version | Canvas apps | Generated YAML files | Repeat paths/hashes/provenance |
| --- | --- | --- | --- | --- |
| Project A historical unmanaged export | `1.26.805.1` | 1 | 36 | Identical |
| Project B unmanaged export | `1.26.1017.1` | 1 | 11 | Identical |

Both ran in temporary paths containing spaces. Original exported package names were retained and review folders used the intended `contoso_sample` / `contoso_review` aliases. No `.msapr` appeared under generated `src/`. These inputs validate representative real exports, not every Power Platform component type or the latest Project A pipeline release.

### Actual upstream tooling restore and MCP startup (baseline 0.1.0 evidence)

- Restored the pinned Microsoft skills commit in a disposable project; verified repeat setup.
- Generated Pi-local configuration and complete runtime assets without registering global skills/plugins/MCPs.
- Started the pinned Canvas server using `dotnet dnx` and the bundled FlowAgent server using Node.
- Sent only MCP `initialize` and `tools/list`: **15 Canvas tools** and **62 FlowAgent tools** returned before app connection. Tool counts may change dynamically after connection or with reviewed version updates.
- Reproducible startup-only command after local setup:

  ```powershell
  node ./tests/mcp-handshake.mjs ./.pi/mcp.json
  ```

No app/session connection, environment authentication, compile/apply, flow run, import, or publishing operation was performed. Package caches may be populated by the official runtimes; no global integration registration was written.

### Entry points and static checks

- PowerShell parser accepted all `.ps1` / `.psm1` files.
- `bash -n` accepted both launchers.
- Bash and PowerShell doctor entry points succeeded.
- Native Claude/Copilot launchers forwarded project plugin paths and `--help` successfully (exit 0). This checks command construction, not a full model/plugin/hook session.
- Shared JSON files parsed and local Markdown links were checked.
- Manual implementation/requirements self-review completed. No independent sub-agent code review or Git-based review baseline was available in this new, uninitialized directory.

### Herdr/configuration additions in 0.2.0

- Inspected the installed Herdr CLI and pinned upstream builder/EDIT workflow contracts; documented role ownership, metadata broker, artifact relocation, restricted worker flags, and explicit dispatch authorization.
- The configuration-review skill and backend profiles are agent-guided workflows, not automatic scanners, provisioning, or new MCP registrations.
- No live specialist, Studio connection, metadata broker/resume, backend connection, or runtime configuration review was executed. The initial MCP startup/native `--help` checks above predate these additions; their toolchain pins remain unchanged.

### Retro additions in 0.3.0

Added on **2026-10-25** from the Project C sessions: `scripts/canvas/canvas.py`, the flow `authentication` warning in `unpack`, Claude permission rules, `docs/canvas-naming.md`, and the `docs/solution/` template.

- `canvas.py` consolidates scripts written during those sessions. On their saved workspaces it matched the originals: order detection (106 of 106 parents in a scrambled copy), `restore-order` (byte-identical restore), `rename` (identical output for a 379-entry map), and `migrate-modern` (identical except the intentional removal of a German DatePicker placeholder pin). `tests/test_canvas.py` covers each command offline.
- `Get-FlowAuthenticationGaps` reported 14 actions on the Project C 1.26.1020.2 export, matching the manual analysis, 0 on its 1.26.1018.2 export and 0 on Project D 1.26.1025.1. A real-PAC unpack in Project D left `src/` unchanged apart from provenance.
- Not exercised: the permission rules in a live auto-mode session (whether `ask` rules prompt as intended), `canvas.py check` against live syncs, and `migrate-modern` on an app other than Project C.

### Git and control skills in 0.4.0

Added on **2026-10-25**: the starter is a Git repository; `new`, `detach`, and the starter-template guard; the `canvas-update-controls` and `canvas-rename-controls` skills, with the naming convention moved into the rename skill; the per-screen push loop in `docs/live-authoring.md`; `rename --defined-in`, applied/pending counts in `rename --check`, and cross-file TextInput references in `migrate-modern --only`.

- On the Project C workspaces, applying every screen as its own batch gave byte-identical results to the whole-app run for `rename --defined-in`, for `migrate-modern --only`, and for both combined per screen. On the combined result, `names` reported 0 controls without a prefix, `migrate-modern --dry-run` reported no legacy controls, and `rename --check` reported 379 of 379 entries applied.
- `new` and `detach` are covered by offline tests with a synthetic starter (fresh history, no remote, marker removed, refusal on a dirty starter, on a non-empty destination, and on the starter's own folder).
- Not exercised: either skill end to end in a live coauthoring session.

### Project D changes in 0.5.0

Added on **2026-10-25** from the Project D sessions: `rename` and `migrate-modern` match names after `\n`/`\r`/`\t` escapes in double-quoted scalars; `migrate-modern` covers Radio, NumberInput, InfoButton, and TabList; `check` ignores three more server-dropped defaults; three coauthoring observations in `docs/live-authoring.md`; the Canvas procedure reads targets from `local.json` and records missing ones; `.claude/settings.json` allows the mutating Canvas and FlowAgent tools without prompts; a starter-only `pre-push` hook (`scripts/git-hooks`) blocks pushes from a plain folder copy until `detach`.

- `tests/test_canvas.py` covers the escape handling and the four new control types offline. The tooling changes were used for the Project D control update and rename and arrive unchanged from that project.
- The hook is covered offline: the starter pushes to a bare remote, a plain copy is refused, and `detach` leaves no hook setting.
- Not exercised: the new control mappings on an app other than Project D, and the changed permission rules in a fresh starter project.

## Remaining validation

- Execute the suite and real-PAC smoke checks on **Windows**. Cross-platform implementation is provided; Windows execution is not yet verified.
- Exercise native Claude/Copilot plugins through a real session, including specialist execution, hook behavior, and tool approval. `--help` is not proof of those behaviors.
- Validate Pi's deferred-tool discovery, data-source routing, local adapter behavior, and actual live Canvas direct-edit workflows. Pilot the optional Herdr route with real lifecycle detection, request/resume metadata, revision checks, disjoint screen writes, and coordinator-only compilation. Native Task/hook equivalence is not claimed.
- Exercise configuration-review guidance against an approved redacted fixture and runtime target, including secret-safe output and unresolved/deployment-input distinctions; skill installation tests do not validate agent judgment.
- Verify any VS Code native plugin/workspace integration against the installed host's scope and version controls. It is documented, not automated/tested here.
- Confirm real tenant account/environment targeting, permissions, licensing, coauthoring, Studio draft retention after reconnection, manual UI/runtime acceptance, and flow behavior in an approved nonproduction environment.
- Test additional solution component types and unusual Canvas metadata/source layouts. Unsupported mappings currently fail rather than silently omit apps.
- Normal rollback is exercised with injected filesystem-operation failures; OS crash/power-loss recovery is documented, not transactionally guaranteed.
