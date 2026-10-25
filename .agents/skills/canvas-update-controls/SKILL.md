---
name: canvas-update-controls
description: Update a connected Canvas app's legacy modern controls (Text, Button, TextInput, DropDown, DatePicker, CheckBox, Toggle, Icon, Link, Radio, NumberInput, InfoButton, TabList) to the current versions, screen by screen through coauthoring, keeping the look. Use for Studio's "update controls" notice, control version updates, or modern-control migration, alone or combined with renaming.
---

# Update Canvas controls

Resolve the repo root as `../../..` relative to this skill directory. Before step 1 read the Canvas procedure, coauthoring behavior, and per-screen push loop in `docs/live-authoring.md`. Run the tools as `python3 -I scripts/canvas/canvas.py` from the root; `<ws>` is a fresh `.powerplatform/workspaces/<alias>/<yyyymmdd-hhmmss>/`.

The update needs a coauthoring session on the intended app (Canvas procedure steps 1–4). Without one, ask the user for the Studio URL and connect first.

`migrate-modern` swaps each legacy control for its current type, renames changed properties, maps enum values, and pins the old defaults (size, padding, alignment, minimum width in auto-layout containers) so nothing moves. Data-field children of DropDown, Radio, and TabList become `ItemDisplayText`. Header, Gallery, Image, Rectangle, PenInput, HtmlViewer, and `Classic/*` controls stay as they are.

1. **Baseline.** Sync into `<ws>/base/`, copy it to `<ws>/work/`, and run `migrate-modern <ws>/work` on the whole copy. Done when the whole-app result is in `work/`.
2. **Review.** Go through the output with the user. These need a decision:
   - **Dropped properties:** an `OnSelect` with logic on a CheckBox or Toggle belongs in `OnChange`. `AcceptsFocus`, `TabIndex`, and NumberInput `DelayOutput` drop without replacement.
   - **TabLists without `DefaultSelectedItems`:** check in Studio which tab is selected on screen load; set `Default` if the first one is no longer preselected.
   - **DatePickers without a placeholder:** the old control showed a localized hint. Agree on a `Placeholder` text, or accept an empty field.
   - **Classic controls:** they are not migrated. Replacing them is a redesign task outside this skill.

   Done when every reported line has a decision. Write the decisions and the batch order (smallest screen first, components among them) to `<ws>/update-plan.md`.
3. **Renaming too?** If the user wants the controls renamed as well, run steps 2–4 of the `canvas-rename-controls` skill on `<ws>/base` now. The map stays valid, because the update does not change names. Done when the user has approved a map or declined renaming.
4. **Push.** Run the per-screen push loop. Each batch is `migrate-modern push-NN --only <file>`. This also moves `.Value` references to updated TextInputs in other files to `.Text`. Then apply the batch's decisions from step 2. When combined with renaming, also run `rename <map> push-NN --defined-in <file>` in the same batch, and push the variable map last. Tell the user what to compare in Studio: text size and padding, button look and label, input placeholders, dropdown display text, link width. Done when the user has confirmed every batch.
5. **Completion check.** On a fresh sync, `migrate-modern <sync> --dry-run` reports `legacy controls ...: none`. `get_appchecker_errors` shows no errors that are missing in `base`. When combined, the completion check of `canvas-rename-controls` passes too. Done when all of these hold.

Report the batches, the decisions from step 2, any remaining classic controls, and the next step: save, publish when approved, then export and unpack with the `powerplatform-unpack` skill.
