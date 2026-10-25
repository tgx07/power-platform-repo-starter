# Canvas naming convention

Default for every project. A project records its screen short names and any deviations in [`docs/solution/README.md`](solution/README.md#conventions).

## Controls

`<prefix><Context><Role>` in camelCase, English role words, unique app-wide:

- **prefix:** the control type. The authoritative table is `python3 -I scripts/canvas/canvas.py names --list`; projects add their own with `--prefix`.
- **Context:** the screen or component short name from `docs/solution/README.md`, e.g. `RegNew` for "Visitor management | New registration".
- **Role:** what the control does or shows, e.g. `Submit`, `Header`, `SpacerTop`, `Table`, `Row`.

Examples: `ctnRegNewScreen`, `hdrRegNew`, `btnRegNewBack`, `galEventListItems`, `rectRegDetailsOverlay`.

Repeated building blocks keep the same role on every screen: `ctn<Ctx>Screen`, `ctn<Ctx>Header`, `hdr<Ctx>`, `btn<Ctx>Back`, `rect<Ctx>SpacerTop`/`SpacerBottom`. Studio's generated data-field children (`DropDownDataField` and similar) keep their names.

## Formulas and data

| Kind | Prefix | Example |
| --- | --- | --- |
| Context variable (`UpdateContext`) | `loc` | `locSelectedEvent` |
| Global variable (`Set`) | `var` | `varCurrentUser` |
| Collection | `col` | `colParticipantsInternal` |
| Named formula / UDF | `fx` | `fxDesign` |

Solution components (flows, environment variables, connection references) follow the scheme recorded in `docs/solution/README.md`; keep existing schema names, they are part of the solution identity.

## Renaming an existing app

1. `inventory` the synced workspace and write a map `old<TAB>new` (`#` comments group it by screen). Variables go in the same map.
2. `rename <map> <dir> --check` until it reports no errors; review the hits inside string literals.
3. Pilot one small screen, then one screen or component per push, each verified with `canvas.py check` as in [live-authoring.md](live-authoring.md#canvas-procedure).
4. `names` on the next unpacked export confirms the result.
