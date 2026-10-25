# Setup — humans and agents

Choose **offline unpack/configuration review** or add **live Canvas/flow tooling**. Run commands from the repo root unless stated otherwise. All starter registration is project/session-scoped. Package caches and official credential stores may remain user-scoped; project scope is not an OS sandbox or a permission boundary.

## 1. Offline unpack/review prerequisites

| Tool | Required for |
| --- | --- |
| PowerShell 7 (`pwsh`) | All starter scripts, including the Bash entry point |
| Git | Review branches and dirty-source protection |
| .NET compatible with pinned PAC | Running the cross-platform PAC .NET tool |
| PAC matching `.powerplatform/tooling.lock.json` | Solution and Canvas unpacking |
| Bash | Optional launcher, not required on Windows |

Install PowerShell 7 from [Microsoft's instructions](https://learn.microsoft.com/powershell/scripting/install/installing-powershell). Install the [.NET SDK](https://dotnet.microsoft.com/download) appropriate for the recorded toolchain. The initial lock uses PAC 2.8.1, tested here with .NET SDK 10.0.301.

Prefer a **repo-local PAC install** instead of changing a globally installed version. Read the lock before installing; the command below matches the initial lock:

```powershell
dotnet tool install Microsoft.PowerApps.CLI.Tool --version 2.8.1 --tool-path ./.powerplatform/vendor/pac
```

If an old local PAC is already installed, use `dotnet tool update` with the explicit reviewed version. Do not automatically upgrade global PAC.

Use the executable explicitly:

```powershell
# macOS/Linux
./scripts/powerplatform.ps1 doctor -PacPath ./.powerplatform/vendor/pac/pac
./scripts/powerplatform.ps1 unpack -Preview
./scripts/powerplatform.ps1 unpack -PacPath ./.powerplatform/vendor/pac/pac

# Windows PowerShell 7
./scripts/powerplatform.ps1 doctor -PacPath ./.powerplatform/vendor/pac/pac.exe
./scripts/powerplatform.ps1 unpack -PacPath ./.powerplatform/vendor/pac/pac.exe
```

An existing `pac` on PATH also works when its version matches the lock. `doctor` reports local paths, PAC version, SDKs, and Node version; it does not sign in, start MCP servers, or prove live connectivity. Missing live-only tools are warnings, not offline failures.

If needed, initialize Git and commit the copied baseline before the first unpack. Review your organization's policy before putting solution ZIPs in Git. The starter permits them but never commits or removes them automatically.

## 2. Add live tooling prerequisites

- **Canvas:** .NET 10 SDK or later (not just the runtime), including `dotnet dnx`; Python 3.9+ for `scripts/canvas/canvas.py`; an existing saved app, edit permission, enabled coauthoring, and an open Studio tab. Generated MCP wiring calls `dotnet dnx` directly rather than depending on a platform-specific `dnx` shell shim.
- **Flows:** a supported Node.js LTS (Node 22/24 recommended; upstream engine minimum is 18), Azure CLI, and permission/licensing for the intended environment. FlowAgent bundles its JavaScript engine; no npm package install is required for it.
- A harness supporting MCP stdio, plus the host features required by the selected authoring workflow.
- Network access for setup and live services; local unpacking itself has no authentication dependency.

Only sign in when live work needs it. FlowAgent uses Azure CLI and a separate connectivity/MSAL identity path; `az login` alone does not prove both identities match. Use read-only `whoami`/`doctor` checks before mutations. Never print access tokens to verify sign-in.

### Project Azure identity

FlowAgent calls `az account get-access-token` without a tenant or subscription, so it follows the active account of the Azure CLI profile it inherits. The tracked `.envrc` points `AZURE_CONFIG_DIR` at a separate profile (`~/.azure-powerplatform-dev`) for this repo. Your default `~/.azure` profile, for example the one `az devops` uses, stays untouched. Both stay signed in at the same time.

One-time per machine:

```bash
brew install direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
AZURE_CONFIG_DIR=~/.azure-powerplatform-dev az login --allow-no-subscriptions
```

Per working copy:

```bash
cp .env.example .env   # optional: replace placeholders for login hint, tenant, or another profile path
direnv allow
az account show --query user.name -o tsv   # expect the dev account
```

Start the agent from the repo root so it, its Bash commands, and FlowAgent inherit the variable. Without direnv (e.g. Windows), set it in the shell first: `$env:AZURE_CONFIG_DIR = "$HOME/.azure-powerplatform-dev"`. Inside this repo, `az devops` also uses the dev profile; prefix `AZURE_CONFIG_DIR=~/.azure` for a one-off call with the default account. Git remotes authenticate through Git Credential Manager and are not affected.

PAC keeps its own auth profiles, and the selected one applies to every terminal. Create one for the dev account (`pac auth create --name <profile>`) and run `pac auth select --name <profile>` before live PAC work.

## 3. Choose one integration path

`setup` downloads the pinned Microsoft repository into `.powerplatform/vendor/power-platform-skills`, verifies its commit and clean state, and creates `.powerplatform/runtime`. It preserves complete Canvas/flow references, agents, hooks, shared files, and FlowAgent's bundled engine. The runtime overlay changes only MCP wiring: pinned Canvas package, explicit FlowAgent bundle path, and local telemetry settings.

It registers only Canvas Authoring and FlowAgent; the upstream optional Microsoft Learn MCP is not added. Canvas `add-data-source` guidance is included in the restored assets and explicitly routed by the local adapter; it guides a human Studio action and then verifies it through MCP.

The tracked `powerplatform-unpack` and `powerplatform-configuration` skills work without live setup. For configuration review, follow [configuration-review.md](docs/configuration-review.md); it is agent-guided read-only inspection, not an automated validator. Additional Dataverse/SharePoint capabilities remain opt-in; see [capability-profiles.md](docs/capability-profiles.md). That document describes choices, not an implemented `-Profile` installer.

### A. Claude Code — native plugins, project scope

Claude Code installs Microsoft's `canvas-apps` and `power-automate` plugins natively in **project scope**. The tracked `.claude/settings.json` already declares the `power-platform-skills` marketplace, enables both plugins, and sets the Power Automate telemetry opt-out. On a fresh clone, trust the folder and accept the plugin install prompt on first start, or install explicitly from the repo root:

```bash
claude plugin marketplace add microsoft/power-platform-skills
claude plugin install canvas-apps@power-platform-skills --scope project
claude plugin install power-automate@power-platform-skills --scope project
```

Then start plain `claude` from the repo root. No `setup` run or launcher is needed for Claude's live tooling. Never choose user/global scope.

The tracked `permissions` in `.claude/settings.json` allow the Canvas and FlowAgent tools, including `connect`, `compile_canvas`, and the FlowAgent tools that save, run, publish, restore, or delete. Without them, auto mode blocked live calls as "Production Reads/Deploy" in past sessions; `connect` reports the public cloud as `prod`, which reads like a production target. Remote mutations still need task authorization (AGENTS.md). Tools outside the list fall back to the active permission mode.

Trade-offs of this starter decision:

- Plugin versions follow the marketplace, not `.powerplatform/tooling.lock.json`. Update deliberately through `/plugin` and review the change.
- MCP wiring is upstream's: the Canvas package version is not pinned by this starter, and FlowAgent's config directory and telemetry log use their user-scoped defaults (`~/.power-platform-skills`, `~/.flowagent`). Only the telemetry opt-out is set, via `env` in `.claude/settings.json`.
- Do not also load the plugins with `--plugin-dir` or install the standalone live adapters: both would register the same plugins or servers twice. The `start-agent` launcher no longer accepts `claude`.

`CLAUDE.md` imports the shared `AGENTS.md`. Claude Code does not discover `.agents/skills/`, so the tracked offline skills are exposed through relative symlinks in `.claude/skills/` (on Windows, clone with `core.symlinks=true` and Developer Mode enabled).

**Beside Pi:** a working copy set up with `-Harness pi` can also be used with Claude without rerunning setup. Claude reads neither `.pi/mcp.json` nor `.agents/skills/`, so the live servers are not registered twice.

The launcher scripts (`start-agent`) remain for Copilot CLI, Pi, and the other harnesses below.

### B. GitHub Copilot CLI — native plugins, session-local

```powershell
./scripts/powerplatform.ps1 setup -Harness copilot
./scripts/start-agent.ps1 copilot
```

Use the corresponding `.sh` launchers from Bash. This uses repeated `--plugin-dir` arguments. The installed CLI's `plugin install` has no project-scope option; do not substitute a persistent/global installation.

### C. GitHub Copilot in VS Code — inspect scope before enabling

VS Code's native agent-plugin support is a different host from Copilot CLI. Follow the current [VS Code agent-plugin documentation](https://code.visualstudio.com/docs/agent-customization/agent-plugins), checking workspace activation and whether the plugin version can be pinned. Do not assume a marketplace's **Install** button is workspace-only.

This starter does not automate or claim tested workspace-only native plugin installation in VS Code. If the installed VS Code version cannot guarantee it, use the session-local Copilot CLI route above, or configure the generic baseline using workspace `.vscode/mcp.json` and project skills. For that fallback, translate `mcpServers` to `servers`, use the supported stdio schema, and keep the generated absolute bundle paths local. Do not register the same server again when a native plugin already supplies it.

### D. Pi — project-local MCP and skill adapters

```powershell
./scripts/powerplatform.ps1 setup -Harness pi
./scripts/start-agent.ps1 pi
```

Setup merges the two baseline servers into **`.pi/mcp.json`**, preserving unrelated entries. It refuses to overwrite conflicting user-managed entries. It adds only the two local adapters under `.agents/skills/`; Pi discovers that directory natively. MCP tools use **deferred exposure** to reduce the baseline tool-description load.

Review and grant project trust when prompted. Use `/reload` after local changes and `/mcp` to inspect configuration sources, tool availability, and connection errors. `pi mcp list` is an explicit connection check, not part of offline doctor. Pi's default shell MCP registration is global: any manual `pi mcp add` must include **`--local`**.

**Capability limit:** Pi does not supply the native plugin's Task/specialist runtime or hooks by default. Direct and ordinary sequential Partitioned workflows remain with the coordinator. For explicitly requested Herdr specialist execution, opt in locally:

```powershell
./scripts/powerplatform.ps1 setup -Harness pi -WithHerdr
```

The Bash entry point accepts the same flag. Installation starts no sessions and can run outside Herdr. Dispatch requires an explicit user request and `HERDR_ENV=1`; workers start without MCP/extensions, while the coordinator brokers metadata and owns sync/compile. Read [herdr-specialists.md](docs/herdr-specialists.md) for stage ownership, task handoff, and pilot limitations. This experimental adapter does not reproduce native hooks or direct specialist MCP calls. Setup without the flag removes the optional generated skill; other harnesses reject the flag. Without a supported orchestration route, use a native host or an explicitly reviewed local extension. Setup success is not proof of authoring parity.

### E. Other harnesses — local skills and MCP separately

```powershell
./scripts/powerplatform.ps1 setup -Harness generic
```

This prepares `.agents/skills/` adapters and **`.powerplatform/mcp.json`**. It does not globally register anything. Configure the host's project-local MCP support to consume/translate that file; register the adapter skills locally if it does not discover `.agents/skills/`.

Check tool-name mapping, path resolution, hooks, specialist-agent execution, and permission controls. Stop on missing prerequisites rather than silently treating the plugin as compatible.

### Using `npx skills add`

The usual manual entry point is:

```bash
npx skills add microsoft/power-platform-skills
```

Use its current help/interactive selector to choose only the required skills and project installation; **never select global scope**. Pin the source revision when supported and retain its lockfile. Do not run a broad install in addition to native plugins or the starter adapters—it can duplicate skills and introduce `setup`/`report-issue` name collisions.

Crucially, skill-only installation is not proof that sibling `references/`, specialist agents, hooks, and FlowAgent's `server/mcp.mjs` were installed or that `${PLUGIN_ROOT}` is resolved. Inspect those dependencies. The starter's adapters plus complete pinned asset restore are the default non-plugin route; direct upstream skill installation is an alternative requiring host-specific validation, not an extra mandatory step.

## 4. Record and connect to the right Studio app

Unpack first so the source manifest contains logical-name/alias mappings. Open the intended app in Studio, enable coauthoring, and keep its tab open.

```powershell
./scripts/powerplatform.ps1 target -AppAlias contoso_booking -StudioUrl 'https://make.powerapps.com/e/<environment-guid>/canvas/?action=edit&app-id=<app-guid>'
```

Replace the placeholders with the actual URL copied from the browser. Quote the URL, especially its `&` characters. The command validates and records IDs/category in ignored `.powerplatform/local.json`; it does not authenticate, prove app identity, or connect.

Ask the agent to connect using the local target, or invoke the native `configure-canvas-mcp` skill and provide the Studio URL. Show/confirm the resolved app and environment before connecting. Verify read-only control/data-source discovery before editing. See [live-authoring.md](docs/live-authoring.md) for the full lifecycle.

## 5. Verify without mutations

Optionally verify just the two server processes and tool discovery, before connecting to an app/environment:

```powershell
# After setup -Harness pi; for generic use .powerplatform/mcp.json instead.
node ./tests/mcp-handshake.mjs ./.pi/mcp.json
```

Run only against a trusted local configuration: the test starts its configured programs. It sends only MCP initialization and tool-list requests. Canvas may download the pinned NuGet package on first use. Success does not prove sign-in, app/session access, or runtime behavior.

- **Canvas:** confirm the expected Studio tab/app, connect, and list controls/data sources. Do not compile as a setup smoke test; compilation applies changes.
- **Flows:** inspect effective identity, list environments, and inspect the intended existing flow. Do not create, run, resubmit, enable, or publish a flow as a connectivity test.
- **Scope:** inspect MCP configuration sources and loaded plugins/skills in the harness. Confirm these baseline integrations are absent when launching another project without this starter.

The starter does not remove or disable unrelated global integrations you previously installed. Clean those up separately if they defeat your context-isolation goal.

## 6. Updates, switching harnesses, and removal

1. Use a review branch. Read upstream release notes and choose exact PAC/MCP versions and a full skills repository commit.
2. Edit `.powerplatform/tooling.lock.json` explicitly. No command follows upstream `main` automatically.
3. If the skills commit changed, move/remove `.powerplatform/vendor/power-platform-skills` after checking it contains no local work; rerun `setup -Harness <host>`. It recreates the disposable runtime. Update repo-local PAC separately with its explicit version.
4. Run offline tests and real-PAC smoke checks. Verify the chosen live integration read-only and record the host/version and remaining gaps. Review generated source diffs caused by tool changes.
5. Rerun setup when the project moves or the harness changes. It can update untouched entries it previously generated, but refuses conflicting manually edited MCP entries.

Use one integration path per working copy; the only supported combination is using Claude's project-scoped plugins beside a Pi setup (see 3A). Before switching from Pi/generic to native plugins, remove only the starter's `canvas-authoring`/`flowagent` entries from the old local config to avoid double registration. Setup removes only its marked standalone live adapters when selecting a native host, including the optional Herdr adapter. It never removes the tracked offline unpack/configuration skills, unrelated skills, global configuration, or existing live workspaces. Rerunning Pi setup without `-WithHerdr` disables that optional skill.

To uninstall, stop the agent, remove the starter's local MCP entries/adapters, and delete only disposable vendor/runtime/setup-state directories. Keep source/provenance, lock/config, and any live workspaces you still need. No global uninstall is required for the starter's session-local native paths. For Claude, remove the project-scoped plugins with `claude plugin uninstall <plugin>@power-platform-skills --scope project`.

### Telemetry and credentials

The launcher and FlowAgent MCP entry opt out of Power Automate remote telemetry transmission and redirect its documented local mirrors/config into ignored `.powerplatform/state/`. The pinned upstream implementation still controls collection behavior; review its telemetry docs when updating. Native hosts should be started through the launcher to apply hook environment settings too.

Official credential caches, host logs, SDK/package caches, and authentication flows may still use user directories. No tokens or secrets belong in `config.json`, `tooling.lock.json`, `local.json`, skills, or Git.
