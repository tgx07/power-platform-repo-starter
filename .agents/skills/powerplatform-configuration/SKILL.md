---
name: powerplatform-configuration
description: Review solution environment variables, connection references, deployment mappings, or Dataverse/SharePoint backend dependencies; distinguish exported configuration from runtime state without exposing sensitive values.
---

# Review solution configuration

Resolve the repo root as `../../..` relative to this skill directory. Read `docs/configuration-review.md` there before inspection. This starter-owned workflow works offline; no plugin/MCP setup or authentication is required for an exported-source review.

1. Establish review scope: exported solution, proposed deployment settings, or an explicitly authorized runtime comparison. Read source provenance and project rules. State the export version and any unknown target environment. Do not unpack/replace dirty source, authenticate, or install backend tooling merely to begin a review.
2. Discover component files by path. Parse XML/JSON locally and emit a redacted inventory; do not dump raw configuration files, flow definitions, app connection metadata, or deployment-settings values into chat/logs. Record schema/logical names, types, value presence, connector IDs, and evidence paths—not secret values, connection tokens, user emails, or raw URLs containing credentials.
3. Inventory environment-variable definitions and any exported values. Trace usage through flows, app metadata/review YAML, and settings. Separate definitions, defaults, current values, and target overrides. Missing current values can be valid when defaults or import-time inputs apply; classify unresolved requirements rather than invent defects.
4. Inventory connection references and consuming flows/apps. Distinguish a solution connection-reference logical name from its connector ID, alias, and environment-specific authenticated connection. Trace aliases/expressions before declaring a reference missing. An exported mapping does not prove the target connection exists, is authorized, or has the intended owner.
5. Compare supplied deployment-setting keys/mappings against required components. Review completeness and accidental environment coupling without copying values. Keep runtime-dependent checks open unless authorized evidence confirms them; treat flow connections and solution connection-reference mappings as related but different surfaces.
6. Identify external dependencies and required backend checks. Dataverse business-table schema and SharePoint list schema/permissions need project-specific evidence. A SharePoint-backed app still has solution infrastructure; environment variables/connection references alone do not mean the app uses Dataverse as its business-data backend. See `docs/capability-profiles.md` before enabling optional tooling.
7. Report findings using the documented template: confirmed export facts, likely risks, unresolved runtime checks, backend dependencies, and safe next steps. Include file/component pointers and the validation boundary. A review request is read-only; propose fixes rather than editing generated metadata, changing remote values/connections, importing, running flows, or publishing.

For a request to add a Canvas data source, use the native Canvas `add-data-source` skill or the local Canvas adapter's explicit route. For live flow diagnostics, use the flow workflow after confirming authorization and target identity. Runtime validation is a separate task; never present a clean static inventory as deployment readiness.
