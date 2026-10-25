# Unpacking contract

## Selection

Inputs are `.zip` files directly under `Solutions/`, case-insensitive extension. Nested directories are not scanned. Every ZIP must be a readable, unmanaged Power Platform solution with one root `solution.xml`, one solution identity across candidates, and a four-part numeric version. Selection compares those version segments, not filenames, timestamps, or lexicographic order.

The highest eligible version is always selected. Corrupt/managed/unrelated ZIPs cause an error instead of being silently skipped. Same-version different-byte exports are ambiguous and rejected, even if they might unpack similarly. Identical duplicate ZIPs are allowed; filename sorting breaks that tie deterministically. Prefer keeping only one copy.

Before the first unpack, optionally set `solutionUniqueName` in `.powerplatform/config.json`. Afterward, the committed source manifest also binds the repo to that solution identity. Deleting old ZIPs never silently permits a different solution to take its place. Intentionally repurposing a repo requires an explicit configuration/provenance reset and review.

Removing the highest ZIP can make the remaining highest version lower than the recorded version. The command does not independently prohibit that downgrade: its contract is highest version **present**. Review the preview/provenance before regeneration.

## Source layout and app aliases

Solution files use PAC's normal layout under `src/`: tables, flows, environment variables, Canvas packages/metadata, and every other component that PAC can unpack. The starter does not introduce custom rewrites of generated XML or flow JSON.

Each `CanvasApps/*.meta.xml` maps its exact logical `Name` and `DocumentUri` to an exported `.msapp`. All packages must be mapped; missing packages, unmapped packages, duplicate mappings, and unsupported URI layouts fail clearly rather than omit an app.

The review source for an app is:

```text
src/CanvasApps/<alias>/Src/App.pa.yaml
src/CanvasApps/<alias>/Src/<screen>.pa.yaml
src/CanvasApps/<alias>/Src/Components/<component>.pa.yaml
```

Original package/metadata filenames remain unchanged. Canvas unpack runs with `--layout SourceCode` in staging; only the YAML `Src/` subtree is copied to the introduced alias folder. Intermediate `.msapr` output is discarded. Original resources remain in the exported package/solution representation; this is not a complete standalone app-authoring package.

Default normalization strips exactly a trailing underscore plus **five hexadecimal characters**, matching the two observed examples:

- `contoso_sample_86b9c` → `contoso_sample`
- `contoso_review_085db` → `contoso_review`
- `contoso_booking_mobile` stays unchanged.

This is a conservative convention, not proof that every matching suffix was generated. Override ambiguous names explicitly:

```json
{
  "schemaVersion": 1,
  "solutionUniqueName": "Example",
  "protectedBranches": ["main", "master"],
  "appAliases": {
    "contoso_booking_abc12": "contoso_booking",
    "contoso_booking_def34": "contoso_booking_mobile",
    "contoso_customer_abcde": "contoso_customer_abcde"
  }
}
```

Aliases are portable filename segments and must be unique ignoring case. Collision with another app or an exported path fails. Publisher prefixes are retained. Runtime app GUIDs do not come from alias normalization; configure them per developer/environment.

## Git and destructive overrides

The branch rule is **advisory**. `main`/`master` (or configured names) generate a warning, not a refusal. Detached HEAD also warns. Scripts never create/switch branches, commit, push, or create PRs.

Changes under `src/` and `.powerplatform/source-manifest.json`, including staged/untracked files, block replacement. Commit or stash generated changes first. Unrelated edits elsewhere do not block unpacking. Configured Git ignored paths are not reported by `git status`; keep `src/` tracked and do not ignore hand-maintained files inside it.

`-AllowDirty` explicitly authorizes replacing those dirty files. It also permits replacement of existing source outside Git. Use it only after reviewing/backing up the affected paths. A branch alone does not protect uncommitted work. A new repo without generated source can unpack before Git initialization, with a warning.

## Failure safety and recovery

The command validates all candidate archives, requires the locked PAC version, and takes an exclusive project writer lock. It copies the selected ZIP into same-filesystem staging and verifies its SHA-256 before unpacking. Both solution identity and Canvas output are checked before replacement.

The new source is assembled separately. The previous `src/` is moved into staging as a backup, the new source is moved into place, and provenance is updated. A normal replacement error triggers rollback of source/provenance. If rollback itself fails, staging is retained and the error names its recovery path.

This is **not a filesystem transaction**: a process kill, OS crash, or power loss between moves can leave staging/recovery files or source/provenance out of sync. Before retrying after interruption, inspect `.powerplatform/staging-*`, recover `previous-src` if needed, and compare provenance. Never blindly delete a recovery folder that might contain your only previous source. File-lock handles release when the process ends; the ignored empty lock file can remain.

Symlinks/junctions in managed directories are rejected. ZIP traversal and duplicate/case-colliding entry names are rejected before PAC. These safeguards are not a sandbox: PAC still executes as your user. Use trusted exports and reviewed tooling.

## Provenance and review

Commit `.powerplatform/source-manifest.json` with `src/`. It records the selected input, exact solution version/type, archive SHA-256, PAC/layout/starter version, and app mappings. It deliberately omits machine paths and generation timestamps so repeat runs can be compared deterministically.

After replacing `src/`, `unpack` warns about flow connector actions without `"authentication": "@parameters('$authentication')"` (see the flow procedure in [live-authoring.md](live-authoring.md#flow-procedure)). The warning does not fail the unpack.

ZIP hashes establish which input was used, not equivalence across separate exports. For repeatability checks, compare normalized generated paths/file hashes from the same frozen export. Review exported environment-variable defaults/current values and other tenant metadata for sensitive information before committing. Input ZIP retention and customer release distribution are project policies, not responsibilities of this unpacker.
