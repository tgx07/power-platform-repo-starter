# Adopting the starter

## New repository

Run `scripts/powerplatform.ps1 new -Destination <path>` in the starter. It clones the committed starter (ignored `vendor`, `runtime`, `state`, and `workspaces` stay behind), removes the starter's history, remote, and `.powerplatform/starter-template.json`, and commits one baseline on `main`. Add the project's own remote afterwards. The starter must have no uncommitted changes.

A folder copied with `cp -R` or Explorer still contains the starter's `.git`: commits would land in the starter's history and pushes would go to the starter's remote. `unpack` and `target` refuse to run while the marker file exists. Run `scripts/powerplatform.ps1 detach` in the copy to replace its history and remote with a fresh repository; it refuses to run in a folder that still has the starter's name. Until then, the starter's pre-push hook refuses to push from the copy. After either command, add the project's own remote (Azure DevOps or GitHub).

Add project-specific domain rules, environment roles, configuration constraints, and release procedures as separate docs. Keep the generic `AGENTS.md` entry point short. For Copilot hosts that need a separate instruction entry point, link to these shared instructions using that host's project-scoped mechanism rather than duplicating them.

## Existing repository

Work on a review branch and back up/commit existing state first.

1. Merge `AGENTS.md`, `CLAUDE.md`, `.gitignore`, and `.gitattributes` with existing project policies. Preserve existing domain docs, skills, MCP entries, and release behavior.
2. Add the scripts and `.powerplatform` shared files. Do not copy another developer's ignored state or absolute MCP paths.
3. Standardize `src/` casing deliberately. On case-insensitive systems, moving `Src/` to `src/` may require a temporary intermediate name via `git mv`. Inspect links/docs/tests that refer to the old casing.
4. Move authored snapshots and notes out of generated `src/` before allowing replacement. Preserve them in a documented non-generated location and reconcile them with the remote app; never blindly compile them over current Studio state.
5. Configure aliases where names are ambiguous/collide. The default drops only an observed five-hex suffix; it does not rename actual apps.
6. Review which ZIPs are inputs. All direct `Solutions/*.zip` must be unmanaged exports of the same solution. Move managed release artifacts to their appropriate existing location; do not delete or change the project's release policy just to satisfy the starter.
7. Preview and generate. Review source/provenance together, including component removals and renamed alias directories. Reconcile tests/documentation referring to old paths.
8. Select one local harness setup. Check for duplicate native/standalone/global integrations before live work.

`src/` is regenerated wholesale. Custom documents or hand-edited files left there will be removed on a successful authorized replacement.

## Existing pipelines

The scripts have no Azure DevOps dependency. A future pipeline can call the same unpack entry point, passing `-Root` and the pinned `-PacPath`, after placing unmanaged export inputs in `Solutions/` or an isolated starter workspace.

Do not simply point this unpacker at a folder containing managed/unmanaged release pairs. Keep input selection separate from customer release packaging. Pipeline-generated source must still be reviewed according to the project's established branch/PR, export, retention, and deployment rules.

For Project B, preserve its existing authored snapshot and acceptance documentation before replacing `Src/`. Normalize casing and migrate references separately. Its existing standalone Microsoft skill installation should be reconciled with the complete assets/adapter approach to prevent duplicate or incomplete guidance.

### Partial adoption beside an existing pipeline

A repository whose pipeline already exports and unpacks the solution can adopt the live-authoring parts without the unpack contract. Project A, a solution with an Azure DevOps export pipeline, did this on 2026-10-25 from starter 0.5.0:

- **Adopted:** `scripts/canvas/canvas.py` with `tests/test_canvas.py` (unchanged); the `canvas-update-controls`, `canvas-rename-controls`, and `powerplatform-configuration` skills; `docs/live-authoring.md` and `docs/configuration-review.md`; `.claude/settings.json`, `.envrc`, `.env.example`, and `.gitattributes`.
- **Adapted:** workspaces in the ignored `tmp/canvas/` instead of `.powerplatform/workspaces/`; naming conventions in `docs/agents/canvas-conventions.md` instead of `docs/solution/README.md`; provenance from `src/Other/Solution.xml` and `release/<solution>.json` instead of the source manifest; the Studio URL from the user instead of `target`/`local.json`; "export" means running the export pipeline. Setup notes live in its `docs/live-authoring.md`, since it has no `SETUP.md`.
- **Not adopted:** `unpack`, `PowerPlatform.psm1`, the source manifest, app aliases, the `powerplatform-unpack` skill, and the starter's `Solutions/` input convention. Its pipeline exports from the development environment, keeps `src/CanvasApps/contoso_sample_86b9c/Src/` unaliased, and publishes managed releases as retained pipeline artifacts; adopting `unpack` would require an intentional pipeline change.

To upgrade such a project, diff only the adopted files (`git diff v0.5.0 HEAD -- scripts/canvas tests/test_canvas.py .agents/skills/canvas-* .agents/skills/powerplatform-configuration docs/live-authoring.md docs/configuration-review.md`) and carry the changes over through its adapted paths. Project A records the starter version in those two docs, not in a lock file. The later flow `authentication` finding is already included.

## Maintaining the starter

Run `git config core.hooksPath scripts/git-hooks` once in each clone of the starter itself. The `pre-push` hook allows pushes only from a folder named like `folderName` in `.powerplatform/starter-template.json`, so a plain copy cannot push to the starter's remote. Projects created with `new` or `detach` get a fresh `.git` without that setting.

## Upgrading a copied starter

A project's starter version is `starterVersion` in `.powerplatform/tooling.lock.json` and the source manifest. The starter tags each version (`v0.4.0`), so `git -C <starter> diff v<project version> HEAD --stat` lists what changed since. Copy only intended shared changes, then raise `starterVersion`. Merge project-specific instructions, aliases, release policies, and tests. Do not automatically overwrite an entire adopted repo, pull a moving central script at runtime, or erase ignored live workspaces.
