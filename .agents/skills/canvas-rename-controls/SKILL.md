---
name: canvas-rename-controls
description: Rename a connected Canvas app's controls and variables to the naming convention, screen by screen through coauthoring. Use to rename controls, fix generated names like TextCanvas7 or Container2_3, or apply the naming convention, which this skill holds.
---

# Rename Canvas controls

Resolve the repo root as `../../..` relative to this skill directory. Before step 1 read [naming.md](naming.md), the Conventions section of `docs/solution/README.md`, and in `docs/live-authoring.md` the Canvas procedure and the per-screen push loop. Run the tools as `python3 -I scripts/canvas/canvas.py` from the root; `<ws>` is a fresh `.powerplatform/workspaces/<alias>/<yyyymmdd-hhmmss>/`.

Renaming needs a coauthoring session on the intended app (Canvas procedure steps 1–4). Without one, ask the user for the Studio URL and connect first.

1. **Baseline.** Sync into `<ws>/base/` and copy it to `<ws>/work/`. Run `migrate-modern <ws>/work --dry-run`. If it lists legacy controls, offer the user the combined route in the `canvas-update-controls` skill. Done when the user has chosen rename-only or combined.
2. **Inventory.** Run `inventory <ws>/base > <ws>/inventory.tsv`, `tree <ws>/base`, and `names <ws>/base`. Give every screen and component a short name: reuse the ones in `docs/solution/README.md` and propose the rest. Done when every file has a short name.
3. **Map.** Write `<ws>/rename-map.tsv` (`old<TAB>new`, one `# <file>` comment per screen). Include every control `names` lists and every prefixed name that breaks the convention. Put variables and collections that break the convention or have typos in `<ws>/rename-vars.tsv`. Run `rename <map> <ws>/base --check` for both maps until each reports `errors: none`. Read every hit inside a string literal: a user-visible word that equals a control name would be renamed too, so drop or rename that entry. Done when both checks pass and no string hit is left unexplained.
4. **Approval.** Show the user the counts (renamed, kept), the short-name table, the recurring patterns from naming.md as applied here, two or three examples per screen, every string-literal hit, and the map paths. Apply the user's corrections and re-run the checks. Record the short names and any project prefixes under Conventions in `docs/solution/README.md`. Done when the user approves the map.
5. **Push.** Run the per-screen push loop. Each batch is one screen or component: `rename <ws>/rename-map.tsv push-NN --defined-in <file>`. That renames the screen's controls in every file that references them. The pilot is the smallest screen. Variables come last as one batch: `rename <ws>/rename-vars.tsv push-NN`. Done when the user has confirmed every batch in Studio.
6. **Completion check.** On a fresh sync, `rename --check` reports `pending 0` for both maps, and `names` exits 0 or lists only names the user decided to keep. Done when both hold.

Report the batches, anything the user decided to keep, and the next step: save, publish when approved, then export and unpack with the `powerplatform-unpack` skill, whose `names` check confirms the result in `src/`.
