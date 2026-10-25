# Solution configuration review

The baseline `powerplatform-configuration` skill is starter-owned. It does not depend on a live Dataverse/SharePoint MCP or pretend that a technology-specific upstream ALM skill applies generically. The procedure is agent-guided inspection, not an automated configuration validator.

## Start with evidence and scope

Read `.powerplatform/source-manifest.json` and the project's domain/deployment documentation. If source or provenance is missing, report that and propose preview/unpack as a separate action; preserve uncommitted work. Review the selected exported version, not an assumed current tenant state.

Use these evidence labels:

- **Export-confirmed:** directly represented in the named source/export version.
- **Configuration-input:** supplied target settings or documented project policy; not proof they were applied.
- **Runtime-confirmed:** checked in the explicitly identified environment using authorized read-only operations.
- **Needs runtime check:** cannot be established from the export/settings alone.
- **External dependency:** backend/service requirement not packaged by the solution.

A diagnostic/configuration review authorizes reads only. Do not implicitly authenticate, create connections, change environment-variable values, import, enable flows, run business operations, or install global tooling. For a runtime comparison, confirm account, tenant, environment role, solution version, and permitted reads first. Dataverse for Teams, licensing, DLP, connector permissions, and tenant differences remain possible constraints.

## Redact before reading/reporting

Discover filenames first. XML/JSON files and flow run outputs can contain actual secrets and tenant/user information. Prefer local parsers that emit only component names, types, presence flags, consumer names, connector IDs, and file pointers. Do not use raw `cat`/`Get-Content` dumps or matching-line searches as the initial inventory when values could be sensitive.

Treat Secret-type variables, credentials, token-like values, Graph secrets, connection strings, and authentication material as sensitive even if exported in an ordinary string field. For review output, report `present`, `absent`, `redacted`, or a safe classification. A complete non-secret URL can still identify a customer; display only what the task needs and never expose credential-bearing query strings.

If a suspected secret is found, identify the affected component/path without echoing its value or generating an irreversible derivative such as an unsalted secret hash. Recommend excluding/remediating it and following the organization's rotation policy if it was committed or shared. Do not move secrets into tracked example files.

## Environment variables

Start with `src/environmentvariabledefinitions/**/environmentvariabledefinition.xml`, any associated exported value files, and `src/Other/Customizations.xml` when the export layout stores components there. Layout and capitalization may vary. Inspect the actual XML structure rather than assume one fixed representation.

For every definition, record:

- Schema name and display label when useful.
- Declared data type and sensitivity classification. Resolve numeric type codes from reliable metadata rather than guessing.
- Default-value presence, exported current-value presence/count, and target-override presence—without their contents.
- Intended purpose, required/optional status, consumers, and evidence paths.
- Whether a default or import-time input is intentionally sufficient, or the requirement remains undocumented.

Trace references in flow parameter declarations/expressions, app metadata/review YAML, and project-specific settings. An unused-looking definition may be consumed dynamically or externally; mark uncertainty rather than auto-delete it. An external environment-variable reference can be a declared dependency rather than a missing local component.

Do not equate:

```text
definition != default value != current value != proposed deployment override
```

A missing exported current value is not necessarily a defect. Conversely, a value embedded in an export is not proof of the target environment's effective value. For Secret variables, retrieval/authorization semantics require separate runtime evidence; a successful metadata read does not prove consumers can resolve the secret.

## Connection references and connections

Find solution reference definitions in the actual unpacked layout: they may appear in `src/Other/Customizations.xml`, dedicated component files, and solution root/dependency metadata. Follow the structured content; do not invent a fixed folder or component type code.

Keep these identities separate:

1. **Connector ID:** identifies the service/connector, such as SharePoint Online.
2. **Connection-reference logical name:** portable solution component referenced by apps/flows.
3. **Flow/app alias:** local key mapped to a reference or connection.
4. **Connection ID:** environment-specific authenticated connection, with an owner, permissions, and lifecycle.

Inspect flow connection-reference mappings, `$connections`/other parameters, and action/trigger host expressions. Follow aliases and dynamic expressions before reporting a missing definition. Canvas metadata can contain nested/escaped connection references; inspect it with redaction rather than printing its raw contents. Some connections are direct or inherited; absence of one expected field is not proof of a broken app.

Report consuming components and whether the mapping is export-confirmed, supplied for deployment, external, or unresolved. A connection reference in Git cannot prove the target connection exists, is shared correctly, uses the intended account, meets DLP requirements, or can access the required site/mailbox/API.

FlowAgent can inspect/manage connection objects, but that is not interchangeable with complete solution connection-reference ALM. Repairing, deleting, or replacing a connection is a mutation and may affect other apps/flows; keep it outside a read-only review.

## Deployment settings

If supplied, compare deployment-settings entries—commonly `EnvironmentVariables` and `ConnectionReferences`—with the solution's actual schema/logical names. Inspect the format supported by the project's import tooling rather than assume every deployment uses the same shape.

Check required inputs, unknown/duplicate keys, connector compatibility, stale references, optional/default behavior, and inappropriate environment-specific coupling. Compare values locally when authorized, but report the result without copying sensitive data. Example/customer settings are inputs, never evidence of applied runtime state.

The starter does not currently generate or apply deployment-settings files. Suggest an explicit, reviewed implementation if that is wanted. Prefer environment-first configuration plus consistent export; do not patch generated solution XML/JSON to simulate an applied fix.

## Backend contract

### Dataverse

Distinguish business tables from Power Platform configuration/infrastructure tables. For relevant business tables, inspect available schema, columns, relationships, choices, ownership, and declared solution dependencies. Record which runtime permission/security/licensing checks remain open. Full Dataverse operations cannot be assumed available in Dataverse for Teams.

Enable the optional Dataverse/ALM profile only when the task needs live schema/data/solution operations. An export-only review can inspect existing metadata without starting another MCP.

### SharePoint

A Power Platform solution ZIP does not provision or fully capture SharePoint list schema, list/site permissions, content, or library configuration. App/flow bindings can reveal dependencies, but are not a complete provisioning contract.

For each required list/library, record only necessary identifiers and the source of its contract. Review internal column names, types, required fields, choice/lookup/person behavior, relevant indexes, attachment/library behavior, and permissions as applicable to the actual workload. A display-name match is not sufficient identity evidence. Live inspection or schema provisioning requires a separately approved project-local toolchain and target.

See [capability-profiles.md](capability-profiles.md) for optional skills and technology boundaries.

## Report template

```markdown
## Scope
- Solution/export version and source provenance:
- Target environment/installed version: confirmed or unknown
- Evidence surfaces reviewed:
- Validation boundary: export-only / supplied-settings comparison / authorized runtime reads

## Inventory
| Kind | Schema/logical name | Type/connector | Default/current/override presence or mapping status | Consumers | Evidence |
|------|---------------------|----------------|--------------------------------------------------------------------|-----------|----------|

## Findings
| Severity | Evidence label | Component | Finding without sensitive values | Next check/action |
|----------|----------------|-----------|----------------------------------|-------------------|

## External dependencies and runtime checks
- Dataverse/SharePoint/service contracts and missing evidence:
- Identity, permissions, DLP, licensing, connection-owner and effective-value checks:

## Proposed next steps
- Read-only diagnostic steps:
- Changes requiring separate authorization:
- Validation/deployment/rollback considerations if changes are proposed:
```

Do not report 'ready to deploy' from an export-only inventory. A clean static review means only that no issue was found in the inspected evidence; remote validity and application behavior remain separate.
