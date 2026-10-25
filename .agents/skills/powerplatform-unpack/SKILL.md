---
name: powerplatform-unpack
description: Unpack or review a new unmanaged Power Platform solution export, refresh generated source, or compare Canvas Power Fx changes in this repository.
---

# Unpack and review a solution export

Resolve the repository root as `../../..` relative to this skill directory. Read `docs/unpacking.md` there when handling conflicts or adopting an existing repo.

1. Inspect Git status and the input ZIPs under `Solutions/`. Recommend a separate working branch. Preserve unrelated work.
2. Run `scripts/powerplatform.ps1 unpack -Preview` from the root (or the Bash launcher with the same arguments). Confirm the reported solution identity and selected version match the task. Preview does not run PAC.
3. Run `scripts/powerplatform.ps1 unpack`. If generated source is dirty, ask the user to commit/stash it. Use `-AllowDirty` only when explicitly authorized to discard those changes.
4. Review the diff of `src/` and `.powerplatform/source-manifest.json` together. Confirm the expected solution version, all app mappings, renamed aliases, and component removals. Check exported configuration for secrets before committing.
5. Report the selected input/version, changed areas, and validation performed. Local unpack success is not an app/runtime test. Commit, push, or create a PR only if requested.

If the highest export fails, diagnose that export; do not silently unpack an older one. Never modify generated solution metadata to make unpack succeed.
