# Canvas naming convention

Default for every project. A project records its screen short names and any deviations under "Conventions" in `docs/solution/README.md`; those win over this file.

## Controls

`<prefix><Context><Role>` in camelCase, English role words, unique app-wide.

- **prefix:** the control type. The authoritative table is `python3 -I scripts/canvas/canvas.py names --list`. A project adds its own prefixes with `--prefix` and records them in `docs/solution/README.md`.
- **Context:** the screen or component short name, 3–12 characters, e.g. `RegNew` for "Visitor management | New registration", `EventList`, `RegDetails` for a component. Related screens share a stem (`RegOverview`, `RegList`, `RegNew`, `RegDone`).
- **Role:** what the control does or shows: `Submit`, `Back`, `Message`, `Title`, `Search`, `DateFrom`.

Repeated building blocks keep the same role on every screen:

| Block | Name |
| --- | --- |
| Screen root container / header container | `ctn<Ctx>Screen`, `ctn<Ctx>Header` |
| Header control / back button | `hdr<Ctx>`, `btn<Ctx>Back` |
| Spacer rectangles at screen top/bottom | `rect<Ctx>SpacerTop`, `rect<Ctx>SpacerBottom` |
| Spacer inside a form | named after the section that follows: `rect<Ctx>SpacerCatering` |
| List as table | `ctn<Ctx>Table`, `ctn<Ctx>TableHeader`, `gal<Ctx>Items`, `ctn<Ctx>Row` |
| Overlay behind a panel | `rect<Ctx>Overlay` |
| Loading overlay | `ctn<Ctx>Loading`, `spn<Ctx>Loading` |

Examples: `ctnRegNewScreen`, `btnRegNewSubmit`, `galEventListItems`, `rectRegDetailsOverlay`, `txtKioskVisitorName`.

Keep a name that already follows the convention. Fix typos in the role while renaming (`ctnPerconalAccessCode` → `ctnKioskEntry`). Studio's generated data-field children (`DropDownDataField` and similar) keep their names; `names` skips them.

## Formulas and data

| Kind | Prefix | Example |
| --- | --- | --- |
| Context variable (`UpdateContext`) | `loc` | `locSelectedEvent` |
| Global variable (`Set`) | `var` | `varCurrentUser` |
| Collection | `col` | `colParticipantsInternal` |
| Named formula / user-defined function | `fx` | `fxDesign` |

Solution components (flows, environment variables, connection references, data sources) keep their existing schema names; they are part of the solution identity. Their scheme belongs in `docs/solution/README.md`.
