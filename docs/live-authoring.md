# Live authoring lifecycle

## Keep three states distinct

1. **Exported representation:** `src/` and the source manifest correspond to a particular solution ZIP. Canvas YAML there is generated review source.
2. **Session workspace:** `.powerplatform/workspaces/<alias>/<session>/` contains synchronized YAML for a connected Studio session. It may be newer or older than the last export.
3. **Remote app/flows:** draft, saved, and published states exist in Power Platform. A successful compile/apply is not proof of durable draft saving, publishing, runtime behavior, or inclusion in a solution export.

The authoring authority is the development environment. Do not maintain a competing hand-edited source tree inside `src/` unless the project explicitly adopts a different workflow.

## Canvas procedure

1. Confirm task authorization and the intended nonproduction target. Review the exact logical name in the source manifest and local runtime app/environment IDs. A friendly alias is not an identity check.
2. Open the existing saved app in Studio, enable coauthoring, and keep the tab open. The Canvas MCP cannot create the initial app record or enable coauthoring for you.
3. Record the Studio URL with the `target` command if desired. It stores only the necessary non-secret identifiers in ignored `.powerplatform/local.json`, not the entire URL/query. It validates the known maker hostname and URL shape; it cannot verify the app's actual logical identity remotely.
4. Connect using the native configuration skill or local adapter, then inspect the connected app read-only. Handle the correct account/tenant explicitly, especially for B2B guest access. Never infer the tenant ID or sign-in identity from an app name.
5. Create a fresh, absolute, **YAML-only** workspace and synchronize current server state before editing. Do not pass the repository root, plugin root, `src/`, or a documented snapshot containing Markdown to `sync_canvas`.
6. Follow the selected upstream Canvas workflow and discover current control/data contracts. Retain names, versions, bindings, and properties outside the approved delta. Handle missing host orchestration honestly.
7. Review changes and run the upstream compile/apply gate only within task authorization. Compilation is a remote mutation, not a harmless linter. Capture static vs applied diagnostics accurately.
8. Inspect the intended Studio tab, verify changed formulas/layout, and save the draft. Reconnect/read back separately when persistent retention matters. Publish only after explicit approval and required manual validation.
9. Export a new unmanaged solution with the intended version after saving the relevant changes. Place it in `Solutions/`, unpack on a review branch, and review the generated diff. Compilation itself does not update this repo's export.

Place plans, acceptance notes, and screenshots alongside—not inside—the YAML-only synchronization directory when possible. The upstream skill's current workspace rules govern subsequent synchronization. Review outputs for secrets and tenant/user data before sharing them.

## Local target shape

The `target` command creates a structure like this (IDs shown are placeholders):

```json
{
  "schemaVersion": 1,
  "selectedCanvasApp": "contoso_booking_abc12",
  "canvasTargets": {
    "contoso_booking_abc12": {
      "logicalName": "contoso_booking_abc12",
      "alias": "contoso_booking",
      "environmentId": "<environment-guid>",
      "appId": "<runtime-app-guid>",
      "makerHostname": "make.powerapps.com",
      "environmentCategory": "prod"
    }
  }
}
```

`prod` here is Microsoft's public-cloud **service category**, not a declaration that the selected environment is the project's production deployment. Confirm the actual development/test/production role separately.

Targets are keyed by exact logical name. If an app is replaced and receives a different logical identity, bind and verify it again; do not reuse an old runtime mapping merely because its alias is similar. You can maintain separate working copies/local files for different environments.

## Flow procedure

Use the complete upstream Power Automate plugin or the local adapter. Start with effective identity, tenant/cloud, and environment checks, then inspect the intended flow by ID. Cached defaults and display names are not sufficient.

A diagnostic request authorizes reads, not creating flows or rerunning business operations. Running/resubmitting flows can send messages, write data, or trigger downstream processes. Publish/enable/disable/delete, connection lifecycle operations, and restoring a backup require explicit scope and a rollback/validation plan.

Flow definitions under `src/Workflows/` remain export-derived review artifacts. Prefer approved changes through Power Platform authoring/tooling followed by export/unpack, not ad hoc JSON edits treated as deployed behavior.

## Baseline limitations

Project-local registration limits activation/context outside this repo; it does not constrain the tools' remote permissions or prevent upstream instructions from suggesting global writes. Preserve the local-only rule during repair. A reviewed native plugin may still have hooks, telemetry, and authentication code running as your user.

Pi/generic adapters preserve the upstream reference material but do not reproduce native hooks or Task execution. Pi can optionally use the experimental [Herdr specialist adapter](herdr-specialists.md), with explicit enablement/request, coordinator-mediated metadata, and coordinator-only sync/compile. That route needs a nonproduction pilot; generic hosts without a supported runtime still stop on missing orchestration. Native host execution and real tenant behavior require separate validation. Never report setup, static YAML checks, or a successful local unpack as proof that Studio changes persisted or a flow behaves correctly.

For environment-variable/connection-reference reviews, use the offline-first [configuration-review workflow](configuration-review.md). Adding a Canvas source uses the upstream `add-data-source` human-in-Studio procedure, then MCP verification; inspecting existing bindings is a separate read-only operation. Dataverse/SharePoint backend capabilities are documented in [capability-profiles.md](capability-profiles.md), not automatically installed.
