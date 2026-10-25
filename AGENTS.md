# Power Platform repository instructions

## Repository contract

- This repo represents one Power Platform solution. `Solutions/` contains unmanaged export inputs; `src/` and `.powerplatform/source-manifest.json` are generated from the highest numeric manifest version.
- The development environment is the authoring authority. Exported Canvas YAML is review source, not an independently deployable code-first app. Change this rule only through an explicit project decision.
- Preserve original solution identities, metadata, and filenames. Readable app aliases apply only to starter-owned folders; mappings live in the source manifest.

## Local workflows

- **Unpack or compare an export:** use the `powerplatform-unpack` skill. Run `scripts/powerplatform.ps1 unpack` (PowerShell 7) or `scripts/powerplatform.sh unpack` (Bash). Prefer a separate working branch; review `src/` and the source manifest together.
- **Set up, change harness, or repair tooling:** read `SETUP.md`; consult `docs/capability-profiles.md` before adding optional Dataverse/SharePoint tooling. Register skills, plugins, and MCPs only for this project/session. Adapt any upstream instruction that writes global configuration; stop if no local alternative exists.
- **Review environment variables, connection references, or deployment mappings:** read `.agents/skills/powerplatform-configuration/SKILL.md`. Inspect exported evidence read-only and redact values; distinguish runtime checks and external backend contracts.
- **Edit a live Canvas app:** read `docs/live-authoring.md`; use the local Canvas adapter or the native Microsoft plugin. Confirm the intended environment, logical app, and runtime app ID before connecting. Work in `.powerplatform/workspaces/`, never synchronize into `src/` or the repo root.
- **Add a Canvas data source/connector:** use Microsoft's Canvas `add-data-source` workflow through the native plugin or local adapter. The user adds it in Studio; verify it via MCP afterward.
- **Inspect or change flows:** read `docs/live-authoring.md`; use the flow adapter or native Microsoft plugin. Confirm account/environment and flow IDs before remote operations. The Azure CLI identity comes from `AZURE_CONFIG_DIR` set by `.envrc` (SETUP.md 2); if it is unset or `az` shows an unexpected account, stop and ask instead of running `az login` or `az account set`.
- **Use Herdr for Canvas specialists:** only when explicitly requested and locally enabled, read `docs/herdr-specialists.md`. Workers stay off MCP; the coordinator owns sync/compile. Mere Herdr presence does not authorize delegation.

## Safety and verification

- Treat `src/` as disposable generated content, but preserve uncommitted changes. `-AllowDirty` is an explicit destructive override requiring user authorization; it is not a routine retry option.
- Canvas compilation applies remote changes. Saving a Studio draft, publishing, running/resubmitting flows, enabling/disabling flows, deploying/importing solutions, and deleting resources are separate operations requiring task authorization. Use development/nonproduction targets by default.
- Keep secrets, tokens, personal target mappings, downloads, and live workspaces out of Git. Existing environment-variable values in exports may be sensitive: review before committing.
- `tests/Run-Tests.ps1` checks offline tooling behavior. `tests/Invoke-RealPacSmoke.ps1` checks local unpacking with real PAC. Neither proves Power Fx behavior, flow execution, Studio persistence, permissions, or tenant compatibility.
- Add project domain rules and release policies in separate docs and link them here. Preserve an existing project's instructions when adopting this starter; merge rather than overwrite them.
