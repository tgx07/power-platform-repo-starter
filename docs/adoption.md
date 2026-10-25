# Adopting the starter

## New repository

Copy the starter including dotfolders, excluding any local `vendor`, `runtime`, `state`, `workspaces`, target/config-generation files, and real validation ZIPs. The starter itself contains no customer exports. Initialize Git if appropriate, review the baseline, and commit it before generation.

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

For Project A specifically, adoption would require an intentional pipeline change: its current export pipeline hard-codes one Canvas package and writes managed/unmanaged candidates outside `Solutions/`. Its historical managed ZIPs and release retention rules are not the generic starter's input convention. Its current `contoso_sample_86b9c/Src/` review folder would become `contoso_sample/Src/` under the proposed alias rule. None of those changes is performed by creating this starter.

For Project B, preserve its existing authored snapshot and acceptance documentation before replacing `Src/`. Normalize casing and migrate references separately. Its existing standalone Microsoft skill installation should be reconciled with the complete assets/adapter approach to prevent duplicate or incomplete guidance.

## Upgrading a copied starter

Record the current starter version in `tooling.lock.json`. Review the diff between starter versions and copy only intended shared changes. Merge project-specific instructions, aliases, release policies, and tests. Do not automatically overwrite an entire adopted repo, pull a moving central script at runtime, or erase ignored live workspaces.
