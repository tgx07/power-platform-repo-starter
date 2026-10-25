# Power Platform repo starter

A copyable, pipeline-independent starter for **one Power Platform solution per repository**. Version **0.2.0**.

- Unpack the highest-version unmanaged export using PAC on macOS or Windows.
- Discover every exported Canvas app and generate `.pa.yaml` review source.
- Keep exported source separate from live Studio authoring workspaces.
- Activate Microsoft Canvas Apps and Power Automate tooling only in this project/session.
- Review environment variables, connection references, and backend dependencies with a redaction-first, offline baseline skill.
- Optionally coordinate Canvas specialists through Herdr with a single MCP-owning Pi coordinator.
- Use the same PowerShell 7 implementation from PowerShell or Bash.

## Start here

1. Copy this starter, including dotfolders, into a new solution repo. For an existing repo, follow [adoption guidance](docs/adoption.md); merge instructions/configuration instead of overwriting them.
2. Follow [SETUP.md](SETUP.md) for offline prerequisites. Live plugins/MCPs are optional for unpacking.
3. Put unmanaged solution ZIP exports directly in `Solutions/`. Their filenames do not determine selection.
4. Prefer an export/review branch, then preview and unpack:

   ```bash
   git switch -c exports/review
   ./scripts/powerplatform.sh unpack -Preview
   ./scripts/powerplatform.sh unpack
   git diff -- src .powerplatform/source-manifest.json
   git status --short
   ```

   PowerShell 7 equivalent:

   ```powershell
   ./scripts/powerplatform.ps1 unpack -Preview
   ./scripts/powerplatform.ps1 unpack
   ```

5. Review and commit generated source/provenance together. New files require `git status`/staging to appear in ordinary diffs. No script commits, pushes, creates PRs, or changes your Power Platform environment during unpacking.

## Commands

| Command | Purpose |
| --- | --- |
| `powerplatform.ps1 doctor` | Inspect local prerequisites; no authentication |
| `powerplatform.ps1 unpack -Preview` | Show the selected export without invoking PAC or replacing files |
| `powerplatform.ps1 unpack` | Stage, validate, and replace generated source |
| `powerplatform.ps1 setup -Harness pi\|claude\|copilot\|generic` | Restore pinned upstream assets and prepare local integration; network download, no sign-in |
| `powerplatform.ps1 setup -Harness pi -WithHerdr` | Additionally install the optional Herdr orchestration skill; starts no workers |
| `powerplatform.ps1 target -AppAlias <alias> -StudioUrl '<URL>'` | Record an ignored local Canvas target; no connection |
| `start-agent.ps1 pi\|claude\|copilot` | Launch using the selected project integration |

Bash launchers accept the same PowerShell-style options. `-Root <path>` selects another initialized starter project; otherwise the scripts locate their own repo, regardless of the caller's working directory. `-PacPath <path>` chooses the PAC executable explicitly.

## Layout

```text
AGENTS.md, CLAUDE.md             Small agent entry points
SETUP.md                        Human/agent setup by harness
Solutions/                      Unmanaged ZIP inputs; no automatic deletion
src/                            Generated solution files and per-app YAML
scripts/                        Shared implementation and launchers
.agents/skills/                 Offline unpack/configuration skills; restored live adapters
.powerplatform/config.json      Repo policy and alias overrides
.powerplatform/tooling.lock.json Tested toolchain pins
.powerplatform/source-manifest.json  Generated provenance (commit it)
.powerplatform/local.json       Ignored runtime targets
.powerplatform/workspaces/      Ignored live authoring/evidence
.powerplatform/vendor/          Ignored, unchanged upstream checkout
.powerplatform/runtime/         Ignored plugin overlay with pinned MCP wiring
```

## Read next

- [Unpacking rules, aliases, safeguards, and recovery](docs/unpacking.md)
- [Studio and flow authoring lifecycle](docs/live-authoring.md)
- [Configuration review and evidence boundaries](docs/configuration-review.md)
- [Baseline and optional Dataverse/SharePoint profiles](docs/capability-profiles.md)
- [Optional Herdr specialist coordination](docs/herdr-specialists.md)
- [Existing-repo and pipeline adoption](docs/adoption.md)
- [Design decisions](docs/design.md)
- [Validation evidence and remaining gaps](docs/validation.md)

## Tests

No Pester installation or Python is required:

```powershell
pwsh -NoProfile -File ./tests/Run-Tests.ps1
```

For local integration checks with actual PAC and your own export:

```powershell
./tests/Invoke-RealPacSmoke.ps1 -SolutionZip '/absolute/path/to/export.zip'
```

The smoke test uses temporary projects, unpacks twice, and compares normalized source/provenance hashes. It does not authenticate, import, publish, or run application logic. An optional Node-based MCP startup/tool-discovery check is documented in [SETUP.md](SETUP.md#5-verify-without-mutations). On Windows, Bash is optional; run PowerShell entry points directly.
