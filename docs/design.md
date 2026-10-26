# Starter design — version 0.6.0

## Agreed decisions

- One solution per repo, potentially multiple Canvas apps.
- Only unmanaged exports are inputs. Pick the highest numeric version from the ZIP manifest on an explicit command.
- Use PAC's normal unpacked solution layout under `src/`; introduce one readable alias directory per Canvas app for `SourceCode` YAML review output.
- Retain original logical names and exported filenames. Strip only the observed generated suffix convention for starter-owned aliases; allow overrides and reject collisions.
- Treat the development environment as authoring authority, exported source as generated review representation, and live Studio workspaces as separate local state.
- Recommend a branch rather than enforcing it. Protect dirty generated source; do not commit, push, or open PRs automatically.
- One PowerShell 7 implementation, callable directly on Windows/macOS or through thin Bash launchers.
- Distribute a copyable starter, not a runtime dependency on central mutable scripts.
- Register Canvas Apps and Power Automate only within the project/session. Include Canvas data-source guidance and a starter-owned offline configuration-review skill. Dataverse/SharePoint backend toolchains remain opt-in.
- Offer Herdr specialist coordination only as an explicitly enabled/requested Pi adaptation. Workers do not connect/sync/compile; the coordinator brokers current metadata and applies changes.
- Keep `AGENTS.md` small; use `SETUP.md` for human/agent harness-specific installation and verification.
- Use native plugins where supported, local skills/MCPs elsewhere, and explicitly document unavailable hooks/orchestration.
- Pin tooling and update deliberately. Keep downloads, target mappings, workspaces, and generated machine-specific configuration out of Git.

## Implementation trade-offs

### One implementation instead of separate shell versions

PowerShell 7 adds a prerequisite on macOS, but avoids duplicated ZIP/XML/version/rollback logic and permits the same offline tests on both platforms. Bash launchers forward arguments and exit codes only.

### Complete upstream assets with small local adapters

Installing only SKILL.md files can leave references, specialist agents, hooks, or the FlowAgent bundle missing. Restore the complete pinned upstream snapshot unchanged, then create a disposable runtime overlay for explicit MCP wiring. Native hosts receive the actual plugin folders; other hosts receive small adapters rather than an unmaintainable fork of all Microsoft skills.

This is not blanket compatibility: missing native Task execution and host hooks remain limitations. The optional [Herdr adapter](herdr-specialists.md) translates specialist handoffs to separate Pi sessions with coordinator-mediated metadata; it does not claim native parity and still needs a nonproduction pilot. Other unsupported workflows stop rather than inventing execution.

### Small baseline, explicit backend profiles

Canvas and cloud-flow tooling covers ordinary app work; Canvas `add-data-source` already covers the human Studio binding step. The starter adds an offline [configuration-review workflow](configuration-review.md) rather than reuse Power Pages-specific environment-variable ALM. [Dataverse/SharePoint profiles](capability-profiles.md) stay documented opt-ins, preserving project scope and avoiding technology-mismatched skills.

### Session-local native loading

The inspected Copilot CLI does not offer project scope for plugin installation, so its launcher supplies local plugin paths per session with `--plugin-dir`. This avoids global activation and makes the pinned snapshot usable consistently. Claude Code instead installs the plugins natively in project scope (`.claude/settings.json`): a starter decision trading the pinned snapshot for a simpler, launcher-free start that survives resumed sessions. VS Code native plugin workspace activation remains a separately documented, unverified integration path.

### Generated replacement instead of in-place updates

Staging a complete result naturally removes obsolete components and avoids partial output from failed PAC/Canvas calls. Rename-based replacement plus rollback protects normal errors, but cannot guarantee crash/power-loss atomicity across source and manifest. Preserve recovery staging on rollback failure and document interrupted-operation recovery.

### Conservative alias normalization

The five-hex suffix rule is based on the Project A and Project B examples, not a universal Power Platform identity rule. Explicit overrides handle false matches and naming formats not recognized automatically. Exact identity and runtime IDs remain separate from aliases.

## Not in version 0.6.0

- Automatic environment export, solution version assignment, import/deployment, publishing, or flow execution.
- Background folder watching, automatic Git/PR operations, or input archive retention.
- Complete code-first Canvas authoring/packing from exported review YAML.
- A generic implementation of plugin specialists/hooks in every agent harness.
- Automatic Dataverse/SharePoint backend capability installation or a generic profile installer.
- An automated environment-variable/connection-reference validator or deployment-settings generator; the configuration-review skill is an agent-guided procedure.
- Guaranteed filesystem transactions, execution sandboxing, or remote permission enforcement.

## Primary references

- [Microsoft Power Platform skills](https://github.com/microsoft/power-platform-skills)
- [Canvas plugin README](https://github.com/microsoft/power-platform-skills/blob/478cfdf838aa614a09915d4606e6fd4227490fed/plugins/canvas-apps/README.md)
- [Canvas plugin agent architecture](https://github.com/microsoft/power-platform-skills/blob/478cfdf838aa614a09915d4606e6fd4227490fed/plugins/canvas-apps/AGENTS.md)
- [Power Automate plugin README](https://github.com/microsoft/power-platform-skills/blob/478cfdf838aa614a09915d4606e6fd4227490fed/plugins/power-automate/README.md)
- [Power Automate setup skill](https://github.com/microsoft/power-platform-skills/blob/478cfdf838aa614a09915d4606e6fd4227490fed/plugins/power-automate/skills/setup/SKILL.md) — includes a global MCP repair path that must be adapted to this repo's local-only policy.
- Local PAC 2.8.1 help for `solution unpack` and `canvas unpack`; local Claude/Copilot CLI help for scope/loading behavior.
- Installed Pi documentation: project skills, `.pi/mcp.json`, project trust, deferred exposure, and CLI configuration.
