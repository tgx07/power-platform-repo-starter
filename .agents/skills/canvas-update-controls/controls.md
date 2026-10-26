# Control notes

What `migrate-modern` does per control type beyond the common renames and pins, and what to settle in review (step 2). Observed against Studio's own update in project sessions.

- **ComboBox (Fluent v9) → ModernCombobox:** same pins as Studio's own update: single select, no external items, theme font size and weight. `BorderRadius` and `TriggerOutput` drop.
- **Label (classic) → Text:** keeps size, color, and height. `LineHeight`, `Role`, `Live`, `Tooltip`, and the hover, pressed, disabled, and focus colors drop and are reported. Decide per screen whether a dropped `Tooltip` or `Live` mattered.
- **Spinner (Fluent v9) → ModernSpinner:** like Studio's own update, the old 200×200 box stays and `SpinnerSize` becomes equal padding around the spinner. ModernSpinner scales to its box, so a spinner spanning `Parent.Height` gets a fixed height of 80, centered. A full-screen loading overlay is better replaced by the app's loading component.
- **Dropdown (current version):** matches `Default` against `Items` by the whole record, not by key. A lookup-column record such as `User.preferredZone` stays unselected; wrap it as `LookUp(<items>, <key> = <record>.<key>)`.
- **Button and TextInput (current versions):** cannot be `SetFocus` targets, and compile reports an error. Agree on another focus target or drop the call.
