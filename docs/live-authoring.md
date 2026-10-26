# Live authoring lifecycle

## Keep three states distinct

1. **Exported representation:** `src/` and the source manifest correspond to a particular solution ZIP. Canvas YAML there is generated review source.
2. **Session workspace:** `.powerplatform/workspaces/<alias>/<session>/` contains synchronized YAML for a connected Studio session. It may be newer or older than the last export.
3. **Remote app/flows:** draft, saved, and published states exist in Power Platform. A successful compile/apply is not proof of durable draft saving, publishing, runtime behavior, or inclusion in a solution export.

The authoring authority is the development environment. Do not maintain a competing hand-edited source tree inside `src/` unless the project explicitly adopts a different workflow.

## Canvas procedure

1. Confirm task authorization and the intended nonproduction target. Review the exact logical name in the source manifest and local runtime app/environment IDs. A friendly alias is not an identity check.
2. Open the existing saved app in Studio, enable coauthoring, and keep the tab open. The Canvas MCP cannot create the initial app record or enable coauthoring for you; `connect` then fails with "Coauthoring is not enabled for this app" until the user enables it and reloads the tab.
3. Read the app's IDs from `.powerplatform/local.json`. If it has no entry for the app, record the Studio URL the user confirmed with the `target` command, so later sessions start from it. It stores only the necessary non-secret identifiers in ignored `.powerplatform/local.json`, not the entire URL/query. It validates the known maker hostname and URL shape; it cannot verify the app's actual logical identity remotely.
4. Connect using the native configuration skill or local adapter, then inspect the connected app read-only. Handle the correct account/tenant explicitly, especially for B2B guest access. Never infer the tenant ID or sign-in identity from an app name. `environment_category: "prod"` in `connect` is the public-cloud service category described under [Local target shape](#local-target-shape), not a production environment.
5. Create a fresh, absolute, **YAML-only** workspace and synchronize current server state before editing. Do not pass the repository root, plugin root, `src/`, or a documented snapshot containing Markdown to `sync_canvas`. Keep this first sync untouched as the baseline for order and content comparisons.
6. Follow the selected upstream Canvas workflow and discover current control/data contracts. Retain names, versions, bindings, and properties outside the approved delta. Handle missing host orchestration honestly.
7. Review changes and run the upstream compile/apply gate only within task authorization. Compilation is a remote mutation, not a harmless linter. Capture static vs applied diagnostics accurately. Push changes that span several screens through the [per-screen push loop](#per-screen-push-loop).
8. Inspect the intended Studio tab, verify changed formulas/layout, and save the draft. Reconnect/read back separately when persistent retention matters. Publish only after explicit approval and required manual validation.
9. Export a new unmanaged solution with the intended version after saving the relevant changes. Place it in `Solutions/`, unpack on a review branch, and review the generated diff. Compilation itself does not update this repo's export.

Place plans, acceptance notes, and screenshots alongside—not inside—the YAML-only synchronization directory when possible. The upstream skill's current workspace rules govern subsequent synchronization. Review outputs for secrets and tenant/user data before sharing them.

## Coauthoring behavior

Observed in project sessions with the Canvas Authoring MCP:

- **Sibling order can change on compile.** Large pushes (many control-type changes at once) scrambled child order in up to 35 containers; rename-only pushes swapped a few containers per screen. A per-screen push plus `canvas.py check` catches it.
- **Sync output can disagree with itself.** Two syncs without a compile between them have returned different orders. Trust a result only when two fresh syncs agree; `check` reports when they do not.
- **Top-level order in a component is z-order.** An overlay rectangle swapped above its panel captures every click. Check component files first after a push.
- **Studio can diverge from the session.** After a large push that coincided with a disconnect, Studio showed the new control types with default properties while sync showed the intended state. Studio saves what Studio shows: ask the user to close the tab without saving, reopen, and push again per screen.
- **Studio can lag behind a passing compile.** After a compile followed by `sync_canvas` HTTP 500s, Studio still showed the old names while syncs showed the pushed state; a browser refresh of the Studio tab showed the pushed state. Ask the user to refresh before judging a batch, and not to save a tab that shows the old state.
- **A rename is a delete plus a create.** Studio showed renamed controls being removed and re-created, not renamed in place. This likely triggers the reload below and the order changes; anything tied to the old control instance (not to its name in formulas) does not carry over.
- **Studio needs time to settle after a push, and may write back.** While it reloads, `sync_canvas` can return HTTP 500. Once a batch had verified clean, Studio's reload wrote the screen back with server-dropped defaults and a moved top-level component (z-order). Step 1 of the push loop catches this.
- **Studio freezes `Parent.Height` formulas in manual-layout containers the first time the user views a screen after a push.** `Height: =Parent.Height` became `=190`, `Y: =Parent.Height/2-Self.Height/2` became `=150`, and X/Y formulas bound to data were dropped; `Parent.Width` formulas survived. In a gallery template every `Height` formula became `=1` and the `Y` formulas disappeared. Restored formulas stayed put. Step 1 of the push loop catches this.
- **"Validation FAILED" does not mean nothing was applied.** A compile that reported 72 errors, and one that reported only warnings, both applied the pushed YAML. Judge every compile by two fresh syncs and `canvas.py check`, not by its status line.
- **A compile timeout does not tell you whether anything was applied.** One `HttpClient.Timeout of 100 seconds` left the server unchanged; the same push applied on the retry. Sync, `check`, and compile again if it did not land.
- **Compile can corrupt component function parameter defaults in a German-locale session.** `DateTime(2000, 1, 1, 0, 0, 0)` came back as `DateTime(2000. 1. 1. 0. 0. 0)`. Write such defaults without separators, e.g. `DateTimeValue("2000-01-01T00:00:00")`.
- **Compile drops `Group:` memberships.** The grouped controls themselves stay unchanged.
- **`sync_canvas` can return HTTP 500.** The target directory stays empty; retry once.
- **Compile rejects empty component Event defaults** (`Default: =`). `canvas.py fix-event-defaults` sets them to `=false`.

## Per-screen push loop

Any change that spans several screens (control updates, renames, multi-screen edits) goes to the server one **batch** at a time: one screen or component, plus `App.pa.yaml` or other files only when the batch's tool rewrote references there. Start with the smallest screen as a pilot.

Workspace `.powerplatform/workspaces/<alias>/<yyyymmdd-hhmmss>/`: `base/` is the first sync and stays untouched; `work/` is a copy for whole-app dry runs; maps, lists, and notes sit beside them. Per batch `NN`:

1. **Fresh state:** sync twice into `pre-NN-a/` and `pre-NN-b/`. From the second batch on, run `canvas.py check check-<prev>-a pre-NN-a pre-NN-b` against the previous batch to catch Studio's write-back. Each reported line is either an edit the user made on purpose, which stays, or a write-back (a formula frozen to a number, a dropped formula or default, moved order), which you restore from `check-<prev>-a/` in a separate batch through steps 3–5 before this one; ask when unsure. Then copy `pre-NN-a/` to `push-NN/`. Starting from a fresh sync keeps edits the user made in Studio since the last batch.
2. **Apply:** run the batch's offline tool on `push-NN/` only (e.g. `migrate-modern --only <file>`, `rename --defined-in <file>`). `diff -r pre-NN-a push-NN` must show only the intended files.
3. **Compile** `push-NN/`. If it fails on empty component event defaults, run `fix-event-defaults push-NN` and compile again.
4. **Verify:** sync twice into `check-NN-a/` and `check-NN-b/`, then `canvas.py check push-NN check-NN-a check-NN-b`.
   - **Clean:** go on.
   - **Order only:** compile `push-NN/` again and verify again. If the order still differs after the second push, or the two syncs disagree, ask the user which order Studio shows.
   - **Content:** stop. Ask the user to look at Studio before anything else is pushed.
5. **Confirm:** name the screen and what to look at; the user checks it in Studio and saves. The next batch starts only after the user confirms.

The loop is done when every batch is confirmed and the skill's own completion check passes on a fresh sync. Delete `pre-*`, `push-*`, and `check-*` folders after the next export is unpacked and committed.

## Canvas YAML tools

`scripts/canvas/canvas.py` (Python 3, standard library, run with `python3 -I`) works offline on sync workspaces and on `src/CanvasApps/<alias>/Src`. Use it instead of writing workspace scripts; extend it in the repo when a task needs something new. `canvas.py <command> --help` documents the arguments.

| Task | Command |
| --- | --- |
| Understand an app's structure | `inventory`, `tree` |
| Check names against the naming convention | `names` |
| Verify a compile | `check` |
| Rebuild an expected order on top of newer server content | `restore-order` |
| Rename controls or variables | `rename`; procedure in the `canvas-rename-controls` skill |
| Update legacy modern controls | `migrate-modern`; procedure in the `canvas-update-controls` skill |

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

Saving through FlowAgent (`edit_flow`/`update_flow`) drops `"authentication": "@parameters('$authentication')"` from every connector action of the saved flows in the next export, while the live definition keeps it. This is harmless: Project A 1.26.1014.1 lacked it in 30 actions across three flows, customers imported the managed solution, and the flows run there without problems (confirmed 2026-10-25). `unpack` lists such actions so the removed lines in the flow diff are explained; no action is needed.

Flow definitions under `src/Workflows/` remain export-derived review artifacts. Prefer approved changes through Power Platform authoring/tooling followed by export/unpack, not ad hoc JSON edits treated as deployed behavior.

## Baseline limitations

For Claude Code, `.claude/settings.json` allows the Canvas and FlowAgent tools, including mutating ones (connect, compile, run, publish, delete), without prompts, so live work runs in auto mode. Task authorization still governs every remote mutation (see AGENTS.md). When a tool outside the list is blocked, ask the user to approve it; never edit permission settings yourself.

Project-local registration limits activation/context outside this repo; it does not constrain the tools' remote permissions or prevent upstream instructions from suggesting global writes. Preserve the local-only rule during repair. A reviewed native plugin may still have hooks, telemetry, and authentication code running as your user.

Pi/generic adapters preserve the upstream reference material but do not reproduce native hooks or Task execution. Pi can optionally use the experimental [Herdr specialist adapter](herdr-specialists.md), with explicit enablement/request, coordinator-mediated metadata, and coordinator-only sync/compile. That route needs a nonproduction pilot; generic hosts without a supported runtime still stop on missing orchestration. Native host execution and real tenant behavior require separate validation. Never report setup, static YAML checks, or a successful local unpack as proof that Studio changes persisted or a flow behaves correctly.

For environment-variable/connection-reference reviews, use the offline-first [configuration-review workflow](configuration-review.md). Adding a Canvas source uses the upstream `add-data-source` human-in-Studio procedure, then MCP verification; inspecting existing bindings is a separate read-only operation. Dataverse/SharePoint backend capabilities are documented in [capability-profiles.md](capability-profiles.md), not automatically installed.
