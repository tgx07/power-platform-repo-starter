# Baseline and optional capability profiles

A profile here is a documented choice of project capabilities, **not an implemented `-Profile` installer flag**. The setup script currently supports the Canvas/Flow baseline and optional Pi Herdr skill only. Additional toolchains require an explicit project-local setup, reviewed pins, and read-only verification.

## Default: Canvas + cloud flows + configuration review

| Workflow | Source | Notes |
| --- | --- | --- |
| Unpack/review exported solution | Starter `powerplatform-unpack` skill | Offline, no environment connection |
| Review environment variables, connection references, deployment inputs, backend dependencies | Starter `powerplatform-configuration` skill | Offline-first/read-only; see [configuration-review.md](configuration-review.md) |
| Connect/edit Canvas app | Microsoft Canvas plugin or local adapter | Readable folders do not replace logical/runtime identity |
| Add data source/connector to Canvas app | Microsoft Canvas `add-data-source` skill | Guides the user through Studio, then verifies source/API and schema through MCP |
| Browse/create/build/debug/diagnose/manage cloud flows | Microsoft Power Automate plugin or local adapter | Read-only diagnostics versus authorized mutations remain separate |
| Herdr-based Canvas specialists | Optional starter Pi adapter | Explicit `setup -Harness pi -WithHerdr`; not automatic on Herdr presence |

`add-data-source` is already bundled in the Canvas plugin and restored runtime; it does not need another MCP. The local Canvas adapter explicitly routes to it. The pinned skill requires the user to add/authenticate/select the source in Studio; the agent then verifies it. Existing-source inspection instead uses `list_data_sources`/`list_apis` and schema/operation discovery directly.

`route-environments` in the flow plugin concerns maker/default-environment routing. It is not a generic replacement for solution-target selection or connection-reference ALM. Do not load it for every environment-variable task.

## Optional: Dataverse / solution ALM

The Power Platform marketplace exposes a Dataverse plugin maintained in the separate [microsoft/Dataverse-skills](https://github.com/microsoft/Dataverse-skills) repository. It is not part of the starter's current Canvas/Flow asset restore or lock pins.

Select the smallest useful set:

| Skill | Use |
| --- | --- |
| `dv-overview` | Foundational environment/safety/tool guidance |
| `dv-connect` | Live setup/authentication/MCP diagnostics |
| `dv-solution` | Solution lifecycle, export/import/package/deployment validation |
| `dv-metadata` | Inspect or evolve business tables, columns, relationships, forms/views |
| `dv-query` | Read-only record investigation and analytics |
| `dv-data` | Explicitly authorized record writes/imports/sample data |
| `dv-security` / `dv-admin` | Task-specific access/admin work, not routine baseline |

A SharePoint-backed app can still benefit from solution ALM tools: environment variables and connection references are platform components. Their presence alone does not justify starting a Dataverse data MCP or classify the business backend as Dataverse.

Before enabling this profile:

1. Confirm the task, development/test target, account/tenant, and Dataverse versus Dataverse-for-Teams constraints.
2. Pin a reviewed upstream revision and compatible dependencies separately. Preserve complete required scripts/references instead of copying bare skills.
3. Adapt setup to project scope. Current upstream setup includes global npm installation, Python dependency installation, `.env`, and host MCP registration; do not run those instructions blindly. Use local CLI/virtual-environment dependencies and local MCP registration, keeping generated configuration/secrets ignored.
4. Preserve the starter's PAC pin and generated-source layout. `dv-solution` must not replace the highest-version selection/source-provenance contract or directly rewrite generated solution metadata as an alternative deployment path.
5. Verify read-only identity/metadata access before authoring. Query, data-write, schema-change, deployment, and admin privileges/authorization are separate.

No Dataverse profile installation is performed by the baseline setup. Availability of a skill does not prove its commands, APIs, licensing, or permissions work in a particular tenant.

## Optional: SharePoint backend

Use the Canvas data-source workflow for app binding and the FlowAgent workflow for flow/connector discovery. For backend inspection/provisioning, choose an approved project-local SharePoint/Microsoft Graph/PnP toolchain, minimum required permissions, separate dependency pins, and explicit read/write authorization.

The Power Platform catalog has `add-sharepoint` under **Code Apps** and **Mobile Apps**. Those workflows use their own SDKs, CLI commands, and project layouts. Do not install/invoke them unchanged for a Canvas app simply because the connector name matches. Relevant schema guidance can inform a separately reviewed adaptation; it does not establish executable compatibility.

Keep list/library schema and permissions/provisioning evidence separate from exported `src/`. See [configuration-review.md](configuration-review.md#backend-contract) for the contract inventory. Never assume a solution ZIP recreates its SharePoint backend.

## Excluded unless the project actually uses them

- Power Pages and its `configure-env-variables`/ALM skills: those environment-variable workflows are specifically for Power Pages site settings, not generic Canvas solution configuration.
- Code Apps, mobile/wrap extensions, model-driven app builders, PCF, process mining, and MCP-app generation: add only for a concrete project capability.
- Desktop-flow/RPA operations: not part of the cloud-flow workflow baseline, even when bundled in a native plugin's catalog.

This keeps ordinary project context small and avoids selecting a technology-specific skill with a misleadingly generic name. Native plugins may expose bundled skills beyond the selected workflows; use only those relevant to the authorized task, and use a local adapter/curated integration when strict per-skill exposure is required.
