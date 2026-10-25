"""Offline tools for Canvas YAML workspaces (sync_canvas output or src/CanvasApps/<alias>/Src).

Run with `python3 -I scripts/canvas/canvas.py <command> ...`; `<command> --help` shows arguments.
Standard library only. Nothing here contacts Power Platform: sync and compile stay with the
Canvas Authoring MCP. Commands that rewrite files touch only the directory you pass.

Commands:
  inventory DIR                 TSV of every control: file, owner, parent, name, type, prefixed
  tree DIR [FILTER]             indented control tree with a few descriptive properties
  names DIR | --list            controls without a naming prefix (exit 1 if any) / the prefix table
  order REF CAND                parents whose children appear in a different order than in REF
  check PUSHED SYNC [SYNC ...]  after a compile: order and content of each fresh sync vs. PUSHED
  restore-order REF TARGET      move whole control blocks in TARGET back into REF's order
  rename MAP DIR [--check]      rename controls/variables app-wide from a TSV map (old<TAB>new)
  fix-event-defaults DIR        give empty component Event properties a no-op `=false` default
  migrate-modern DIR            move legacy modern controls (Text, Button, ...) to the updated ones
"""
import argparse
import collections
import os
import re
import sys

# Naming prefixes: single source of truth for `names`, `rename --check` and docs/canvas-naming.md.
PREFIXES = {
    "ctn": "GroupContainer (any variant)",
    "lbl": "Text, ModernText, Label",
    "btn": "Button, ModernButton",
    "lnk": "Link, ModernLink",
    "ico": "Icon, ModernIcon",
    "img": "Image",
    "rect": "Rectangle",
    "hdr": "Header",
    "gal": "Gallery",
    "txt": "TextInput, ModernTextInput",
    "num": "NumberInput",
    "drp": "DropDown, ModernDropdown",
    "cbo": "ComboBox, ModernCombobox",
    "dte": "DatePicker, ModernDatePicker",
    "chk": "CheckBox, ModernCheckbox",
    "tgl": "Toggle, ModernToggle",
    "rad": "Radio, ModernRadio",
    "tab": "TabList",
    "html": "HtmlViewer",
    "pen": "PenInput",
    "spn": "Spinner",
    "tmr": "Timer",
    "frm": "Form",
    "cmp": "component instance (CanvasComponent)",
}
# Child items Studio generates for data-bound controls; their names are not renameable.
UNNAMED_TYPES = ("DropDownDataField", "TabListDataField", "RadioDataField", "ComboBoxDataField")

ITEM = re.compile(r"""^(\s*)- ([A-Za-z0-9_]+|'[^']+'|"[^"]+"):\s*$""")
OWNER = re.compile(r"^  ([^ \-#].*):\s*$")
CONTROL = re.compile(r"^\s+Control: (\S+)")


def indent(line):
    return len(line) - len(line.lstrip(" "))


def yaml_files(root):
    out = []
    for d, _, fs in os.walk(root):
        out += [os.path.relpath(os.path.join(d, f), root) for f in fs if f.endswith(".pa.yaml")]
    return sorted(out, key=lambda p: (p.count(os.sep), p))


def read(path):
    with open(path, encoding="utf-8", newline="") as fh:
        raw = fh.read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    return raw, nl


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def control_type(raw):
    """'Text@0.0.51' -> 'Text', 'Classic/Button@2.2.0' -> 'Button'."""
    return raw.split("@")[0].split("/")[-1]


def is_prefixed(name, extra=()):
    return any(re.match(re.escape(p) + r"[A-Z0-9]", name) for p in list(PREFIXES) + list(extra))


def sibling_order(path):
    """parent name (or ROOT) -> child control names in file order."""
    raw, nl = read(path)
    stack, out = [], {}
    for line in raw.split(nl):
        m = ITEM.match(line)
        if not m:
            continue
        ind, name = len(m.group(1)), m.group(2).strip("'\"")
        stack = [s for s in stack if s[0] < ind]
        out.setdefault(stack[-1][1] if stack else "ROOT", []).append(name)
        stack.append((ind, name))
    return out


def controls(root, rel, wanted=()):
    """Rows for every control in one file: owner, parent, name, type, depth and wanted properties."""
    raw, nl = read(os.path.join(root, rel))
    owner, stack, rows, cur = "", [], [], None
    for line in raw.split(nl):
        o = OWNER.match(line)
        if o and not line.strip().startswith("- "):
            if o.group(1) not in ("Properties", "Children", "CustomProperties"):
                owner, stack, cur = o.group(1), [], None
            continue
        m = ITEM.match(line)
        if m:
            ind, name = len(m.group(1)), m.group(2).strip("'\"")
            stack = [s for s in stack if s[0] < ind]
            cur = {"file": rel, "owner": owner, "parent": stack[-1][1] if stack else owner,
                   "name": name, "type": "?", "depth": len(stack), "ind": ind}
            rows.append(cur)
            stack.append((ind, name))
            continue
        if cur is None or not line.strip():
            continue
        c = CONTROL.match(line)
        if c and cur["type"] == "?":
            cur["type"] = control_type(c.group(1))
            continue
        key, _, val = line.strip().partition(":")
        if key in wanted and key not in cur and indent(line) == cur["ind"] + 6:
            cur[key] = val.strip().replace("\t", " ")[:70]
    return rows


def all_controls(root, wanted=()):
    return [r for rel in yaml_files(root) for r in controls(root, rel, wanted)]


# ---------------------------------------------------------------- inventory / tree / names

INVENTORY_PROPS = ("Text", "Title", "OnSelect", "Items", "Visible", "HtmlText", "Icon", "Image",
                   "Fill", "Height", "FillPortions", "LayoutDirection")


def cmd_inventory(a):
    print("\t".join(["file", "owner", "parent", "name", "control", "prefixed"] + list(INVENTORY_PROPS)))
    for r in all_controls(a.dir, INVENTORY_PROPS):
        print("\t".join([r["file"], r["owner"], r["parent"], r["name"], r["type"],
                         "y" if is_prefixed(r["name"]) else "n"] + [r.get(k, "") for k in INVENTORY_PROPS]))


def cmd_tree(a):
    show = ("Text", "Title", "Icon", "Image", "Items", "OnSelect", "Visible", "LayoutDirection")
    cur = None
    for r in all_controls(a.dir, show):
        if a.filter and a.filter not in r["file"]:
            continue
        if r["file"] != cur:
            cur = r["file"]
            print(f"\n### {cur}")
        info = "  ".join(f"{k}: {r[k][:45]}" for k in show if r.get(k))
        print(f"{'  ' * r['depth']}{r['name']} [{r['type']}] {info}".rstrip())


def cmd_names(a):
    if a.list:
        for p, types in PREFIXES.items():
            print(f"{p}\t{types}")
        return 0
    rows = [r for r in all_controls(a.dir) if r["type"] not in UNNAMED_TYPES]
    bad = [r for r in rows if not is_prefixed(r["name"], a.prefix)]
    dup = [n for n, c in collections.Counter(r["name"] for r in rows).items() if c > 1]
    for r in bad:
        print(f"{r['file']}: {r['name']} [{r['type']}] has no naming prefix")
    for n in dup:
        print(f"duplicate control name: {n}")
    print(f"controls {len(rows)}, without prefix {len(bad)}, duplicates {len(dup)}")
    return 1 if bad or dup else 0


# ---------------------------------------------------------------- order / check / restore-order

def order_diffs(ref, cand):
    """[(rel, parent)] where children present in both appear in a different order."""
    out = []
    for rel in yaml_files(ref):
        other = os.path.join(cand, rel)
        if not os.path.exists(other):
            continue
        a, b = sibling_order(os.path.join(ref, rel)), sibling_order(other)
        for parent, kids in b.items():
            expected = [k for k in a.get(parent, []) if k in kids]
            if expected != [k for k in kids if k in expected]:
                out.append((rel, parent))
    return out


def cmd_order(a):
    diffs = order_diffs(a.ref, a.cand)
    for rel, parent in diffs:
        print(f"{rel}: {parent} order differs")
    print("parents with different order:", len(diffs))
    return 1 if diffs else 0


def content_diffs(pushed, server, ignore):
    """{rel: (missing lines, added lines)} comparing line multisets; order is checked separately."""
    out = {}
    for rel in sorted(set(yaml_files(pushed)) | set(yaml_files(server))):
        if os.path.basename(rel) == "_EditorState.pa.yaml":
            continue
        pa, sa = os.path.join(pushed, rel), os.path.join(server, rel)
        if not os.path.exists(sa) or not os.path.exists(pa):
            out[rel] = (["<file missing on server>"] if os.path.exists(pa) else [], ["<file only on server>"] if os.path.exists(sa) else [])
            continue
        x = collections.Counter(l.rstrip() for l in read(pa)[0].splitlines())
        y = collections.Counter(l.rstrip() for l in read(sa)[0].splitlines())
        keep = lambda l: l.strip() and not any(s in l for s in ignore)
        missing = [l.strip() for l in (x - y).elements() if keep(l)]
        added = [l.strip() for l in (y - x).elements() if keep(l)]
        if missing or added:
            out[rel] = (missing, added)
    return out


def cmd_check(a):
    failed = False
    for sync in a.sync:
        print(f"== {sync}")
        if not yaml_files(sync):
            print("   no .pa.yaml files: the sync failed or wrote elsewhere (retry once on HTTP 500)")
            failed = True
            continue
        for rel, parent in order_diffs(a.pushed, sync):
            print(f"   order: {rel}: {parent}")
            failed = True
        for rel, (missing, added) in content_diffs(a.pushed, sync, a.ignore).items():
            print(f"   content: {rel}: {len(missing)} pushed line(s) missing, {len(added)} unexpected")
            for l in missing[:a.show]:
                print(f"     - {l[:140]}")
            for l in added[:a.show]:
                print(f"     + {l[:140]}")
            failed = True
    if len(a.sync) > 1:
        unstable = order_diffs(a.sync[0], a.sync[1])
        if unstable:
            print(f"syncs disagree on order in {len(unstable)} parent(s): sync output is unstable here; sync again before restoring order")
    print("RESULT:", "differences found" if failed else "server matches pushed state")
    return 1 if failed else 0


def reorder(lines, ref):
    changed = []
    i = 0
    while i < len(lines):
        m, t = ITEM.match(lines[i]), OWNER.match(lines[i])
        if m:
            name, ind = m.group(2).strip("'\""), len(m.group(1))
            kids_ind, child_ind = ind + 4, ind + 6
        elif t:
            name, ind, kids_ind, child_ind = "ROOT", 2, 4, 6
        else:
            i += 1
            continue
        j = i + 1
        while j < len(lines) and (not lines[j].strip() or indent(lines[j]) > ind):
            if lines[j].strip() == "Children:" and indent(lines[j]) == kids_ind:
                break
            j += 1
        if j >= len(lines) or lines[j].strip() != "Children:" or name not in ref:
            i += 1
            continue
        k, blocks = j + 1, []
        while k < len(lines) and (not lines[k].strip() or indent(lines[k]) >= child_ind):
            mm = ITEM.match(lines[k])
            if mm and len(mm.group(1)) == child_ind:
                blocks.append([mm.group(2).strip("'\""), [lines[k]]])
            elif blocks:
                blocks[-1][1].append(lines[k])
            k += 1
        tail = []  # blank lines after the last block (e.g. end of file) stay in place
        while blocks and len(blocks[-1][1]) > 1 and not blocks[-1][1][-1].strip():
            tail.insert(0, blocks[-1][1].pop())
        names = {b[0] for b in blocks}
        want = [n for n in ref[name] if n in names]
        if want != [b[0] for b in blocks if b[0] in want]:
            pos = {n: p for p, n in enumerate(want)}
            keep = sorted((b for b in blocks if b[0] in pos), key=lambda b: pos[b[0]])
            extra = [b for b in blocks if b[0] not in pos]
            lines[j + 1:k] = [l for b in keep + extra for l in b[1]] + tail
            changed.append(name)
        i += 1
    return changed


def cmd_restore_order(a):
    total = 0
    for rel in yaml_files(a.target):
        ref = os.path.join(a.ref, rel)
        if not os.path.exists(ref):
            continue
        raw, nl = read(os.path.join(a.target, rel))
        lines = raw.split(nl)
        changed = reorder(lines, sibling_order(ref))
        if changed:
            write(os.path.join(a.target, rel), nl.join(lines))
            total += len(changed)
            print(f"{rel}: reordered {', '.join(changed)}")
    print("parents reordered:", total)


# ---------------------------------------------------------------- rename

def load_map(path):
    pairs = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\r\n")
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 2:
                sys.exit(f"{path}:{n}: expected old<TAB>new")
            pairs.append((parts[0].strip(), parts[1].strip()))
    return pairs


def in_string(line, pos):
    head = line[:pos]
    if re.match(r'^\s*[A-Za-z]+: "=', line):
        return head.count('\\"') % 2 == 1
    return head.count('"') % 2 == 1


def cmd_rename(a):
    pairs = load_map(a.map)
    mapping = dict(pairs)
    files = yaml_files(a.dir)
    texts = {f: read(os.path.join(a.dir, f))[0] for f in files}
    defined = collections.Counter(r["name"] for f in files for r in controls(a.dir, f))
    alt = "|".join(re.escape(n) for n in sorted(mapping, key=len, reverse=True))
    rx = re.compile(r"(?<![A-Za-z0-9_])(" + alt + r")(?![A-Za-z0-9_])")
    if a.check:
        errors = []
        olds, news = [o for o, _ in pairs], [n for _, n in pairs]
        errors += [f"duplicate old name {o}" for o, c in collections.Counter(olds).items() if c > 1]
        errors += [f"duplicate new name {n}" for n, c in collections.Counter(news).items() if c > 1]
        source = "\n".join(texts.values())
        for o in olds:
            if defined[o] > 1:
                errors.append(f"old name {o} defined {defined[o]}x")
            elif defined[o] == 0 and not re.search(r"(?<![A-Za-z0-9_])" + re.escape(o) + r"(?![A-Za-z0-9_])", source):
                errors.append(f"old name {o} not found")
        kept = set(defined) - set(olds)
        for o, n in pairs:
            if n in kept:
                errors.append(f"new name {n} collides with a kept control")
            if re.search(r"(?<![A-Za-z0-9_.])" + re.escape(n) + r"(?![A-Za-z0-9_])", source):
                errors.append(f"new name {n} already appears in source")
            if defined[o] and not is_prefixed(n, a.prefix):
                errors.append(f"new control name {n} has no naming prefix")
        print(f"controls {sum(defined.values())}, renamed {len(pairs)}, kept {len(kept)}")
        print("kept without prefix:", sorted(k for k in kept if not is_prefixed(k, a.prefix)) or "none")
        strs = []
        for f, t in texts.items():
            for i, line in enumerate(t.splitlines(), 1):
                strs += [f"{f}:{i}: {m.group(1)}: {line.strip()[:120]}" for m in rx.finditer(line) if in_string(line, m.start())]
        print("hits inside string literals (review, they are renamed too):", len(strs))
        for s in strs:
            print("  ", s)
        print("errors:", "; ".join(errors) or "none")
        return 1 if errors else 0
    for f in a.only or files:
        new, n = rx.subn(lambda m: mapping[m.group(1)], texts[f])
        if n:
            write(os.path.join(a.dir, f), new)
        print(f"{f}: {n} replacements")
    return 0


# ---------------------------------------------------------------- fix-event-defaults

def cmd_fix_event_defaults(a):
    root = os.path.join(a.dir, "Components")
    for f in sorted(os.listdir(root)) if os.path.isdir(root) else []:
        if not f.endswith(".pa.yaml"):
            continue
        p = os.path.join(root, f)
        raw, _ = read(p)
        new, n = re.subn(r"(PropertyKind: Event\r?\n(?:[ ]{8}\w+: .*\r?\n)*?[ ]{8}Default: )=(\r?\n)", r"\1=false\2", raw)
        if n:
            write(p, new)
        print(f"Components/{f}: {n} event default(s) set")


# ---------------------------------------------------------------- migrate-modern

MIGRATE_TYPES = {
    "Text": "ModernText", "Button": "ModernButton", "TextInput": "ModernTextInput",
    "DropDown": "ModernDropdown", "DatePicker": "ModernDatePicker", "CheckBox": "ModernCheckbox",
    "Toggle": "ModernToggle", "Icon": "ModernIcon", "Link": "ModernLink",
}
COMMON_RENAMES = {
    "FontColor": "Color", "FontSize": "Size", "FontItalic": "Italic", "FontStrikethrough": "Strikethrough",
    "FontUnderline": "Underline", "BorderRadiusTopLeft": "RadiusTopLeft", "BorderRadiusTopRight": "RadiusTopRight",
    "BorderRadiusBottomLeft": "RadiusBottomLeft", "BorderRadiusBottomRight": "RadiusBottomRight",
}
PER_TYPE_RENAMES = {
    "Text": {"Weight": "FontWeight"}, "TextInput": {"Value": "Default", "Mode": "Type"},
    "DropDown": {"DefaultSelectedItems": "Default"}, "DatePicker": {"SelectedDate": "DefaultDate"},
    "CheckBox": {"Checked": "Default"}, "Toggle": {"Checked": "Default"}, "Link": {"Appearance": "Type"},
}
DROPPED = {"Button": {"AcceptsFocus"}, "Icon": {"TabIndex"}, "CheckBox": {"OnSelect"}, "Toggle": {"OnSelect"}, "Link": {"AcceptsFocus"}}
# Old default -> pinned value, applied only when the property is absent, so the look stays the same.
PINS = {
    "Text": {"Size": "=14", "PaddingTop": "=0", "PaddingBottom": "=0", "PaddingLeft": "=0", "PaddingRight": "=0",
             "VerticalAlign": "=VerticalAlign.Top", "Width": "=96"},
    "TextInput": {"TriggerOutput": "=TriggerOutput.FocusOut", "Placeholder": '=""'},
    "Link": {"Size": "=14", "PaddingTop": "=0", "PaddingBottom": "=0", "PaddingLeft": "=0", "PaddingRight": "=0"},
}
LAYOUT_PINS = {"Text": {"LayoutMinWidth": "=96"}, "Link": {"LayoutMinWidth": "=320"}}  # AutoLayout parents only
ENUM_REPLACEMENTS = [
    (r"'TextCanvas\.Align'\.Start", "Align.Left"), (r"'TextCanvas\.Align'\.End", "Align.Right"),
    (r"'TextCanvas\.Align'\.(Center|Justify)", r"Align.\1"),
    (r"'TextCanvas\.Weight'\.(Regular|Medium)", "FontWeight.Normal"), (r"'TextCanvas\.Weight'\.(Semibold|Bold)", r"FontWeight.\1"),
    (r"'ButtonCanvas\.Appearance'\.(\w+)", r"ButtonAppearance.\1"), (r"'ButtonCanvas\.Layout'\.(\w+)", r"ButtonLayout.\1"),
    (r"'ButtonCanvas\.IconStyle'\.(\w+)", r"IconStyle.\1"), (r"'Icon\.IconStyle'\.(\w+)", r"IconStyle.\1"),
    (r"'TextInputCanvas\.Appearance'\.(\w+)", r"Appearance.\1"), (r"'TextInputCanvas\.Mode'\.(\w+)", r"TextInputType.\1"),
    (r"'TextInputCanvas\.TriggerOutput'\.(\w+)", r"TriggerOutput.\1"),
    (r"'TextInputCanvas\.ValidationState'\.(\w+)", r"ValidationState.\1"), (r"'TextInputCanvas\.Type'\.(\w+)", r"TextInputType.\1"),
    (r"'DropdownCanvas\.Appearance'\.(\w+)", r"Appearance.\1"), (r"'DropdownCanvas\.ValidationState'\.(\w+)", r"ValidationState.\1"),
    (r"'DatePickerCanvas\.Appearance'\.(\w+)", r"Appearance.\1"), (r"'DatePickerCanvas\.StartOfWeek'\.(\w+)", r"StartOfWeek.\1"),
    (r"'DatePickerCanvas\.Format'\.(\w+)", r"DatePickerFormat.\1"), (r"'DatePickerCanvas\.DateTimeZone'\.(\w+)", r"DateTimeZone.\1"),
    (r"'DatePickerCanvas\.ValidationState'\.(\w+)", r"ValidationState.\1"),
    (r"'Toggle\.LabelPosition'\.(\w+)", r"ToggleLabelPosition.\1"), (r"'LinkCanvas\.Appearance'\.(\w+)", r"LinkAppearance.\1"),
]


def parse_blocks(lines):
    out, stack = [], []
    for i, line in enumerate(lines):
        m = ITEM.match(line)
        if not m or i + 1 >= len(lines):
            continue
        m2 = re.match(r"^(\s*)Control: (\S+)", lines[i + 1])
        if not m2:
            continue
        dash, body = len(m.group(1)), len(m2.group(1))
        while stack and stack[-1]["dash"] >= dash:
            stack.pop()
        variant, k = None, i + 2
        while k < len(lines) and (not lines[k].strip() or indent(lines[k]) >= body):
            if indent(lines[k]) == body and lines[k].strip().startswith("Variant:"):
                variant = lines[k].split(":", 1)[1].strip()
            if indent(lines[k]) == body and lines[k].strip() in ("Properties:", "Children:"):
                break
            k += 1
        c = {"line": i, "dash": dash, "body": body, "name": m.group(2).strip("'\""), "raw": m2.group(2),
             "type": control_type(m2.group(2)) if "/" not in m2.group(2) else m2.group(2),
             "variant": variant, "parent": stack[-1] if stack else None}
        out.append(c)
        stack.append(c)
    return out


def section(lines, c, title):
    j = c["line"] + 2
    while j < len(lines):
        if lines[j].strip() and indent(lines[j]) < c["body"]:
            return None
        if indent(lines[j]) == c["body"] and lines[j].strip() == title + ":":
            k = j + 1
            while k < len(lines) and (not lines[k].strip() or indent(lines[k]) > c["body"]):
                k += 1
            return j, k
        j += 1
    return None


def migrate_file(path, textinput_names, report):
    raw, nl = read(path)
    lines = raw.split(nl)
    for c in reversed(parse_blocks(lines)):  # bottom-up keeps earlier indices valid
        old = c["type"]
        if old not in MIGRATE_TYPES:
            continue
        sec = section(lines, c, "Properties")
        pind = c["body"] + 2
        props = []
        for line in (lines[sec[0] + 1:sec[1]] if sec else []):
            if line.strip() and indent(line) == pind and re.match(r"^\s*\w+:", line):
                props.append([line.strip().split(":", 1)[0], [line]])
            elif props:
                props[-1][1].append(line)
        renames = dict(COMMON_RENAMES, **PER_TYPE_RENAMES.get(old, {}))
        new_props = {}
        for key, plines in props:
            if key in DROPPED.get(old, set()):
                report.append(f"{os.path.basename(path)}: {c['name']} dropped {key}: {plines[0].split(':', 1)[1].strip()}")
                continue
            nkey = renames.get(key, key)
            text = nl.join([plines[0].replace(key + ":", nkey + ":", 1)] + plines[1:])
            if old == "TextInput":
                text = re.sub(r"\bSelf\.Value\b", "Self.Text", text)
            if old in ("TextInput", "DropDown") and nkey == "ValidationState":
                text = text.replace('"Error"', "ValidationState.Error").replace('"None"', "ValidationState.None")
            if old == "DatePicker" and nkey == "StartOfWeek":
                text = re.sub(r'="(\w+)"', r"=StartOfWeek.\1", text)
            if old == "DropDown" and nkey == "Default" and text.rstrip().endswith("=[]"):
                text = text.rstrip()[:-3] + "=Blank()"
            new_props[nkey] = text.split(nl)
        pins = dict(PINS.get(old, {}))
        p = c["parent"]
        if p and control_type(p["raw"]) == "GroupContainer" and p["variant"] in ("AutoLayout", "Vertical", "Horizontal"):
            pins.update(LAYOUT_PINS.get(old, {}))
        for key, val in pins.items():
            new_props.setdefault(key, [" " * pind + f"{key}: {val}"])
        if old == "DatePicker" and "Placeholder" not in new_props:
            report.append(f"{os.path.basename(path)}: {c['name']} has no Placeholder; the old control showed a localized default hint")
        children = section(lines, c, "Children")
        if old == "DropDown" and children:  # data fields become ItemDisplayText
            block = nl.join(lines[children[0] + 1:children[1]])
            pairs = sorted(zip((int(o) for o in re.findall(r"Order: =(\d+)", block)), re.findall(r'FieldName: ="(\w+)"', block)))
            if pairs and "ItemDisplayText" not in new_props:
                new_props["ItemDisplayText"] = [" " * pind + f"ItemDisplayText: =ThisItem.{pairs[0][1]}"]
            del lines[children[0]:children[1]]
        body = [l for key in sorted(new_props) for l in new_props[key]]
        if sec:
            lines[sec[0] + 1:sec[1]] = body
        elif body:
            at = c["line"] + 2
            while at < len(lines) and indent(lines[at]) == c["body"] and lines[at].strip().startswith(("Variant:", "IsLocked:", "Layout:", "Group:")):
                at += 1
            lines[at:at] = [" " * c["body"] + "Properties:"] + body
        lines[c["line"] + 1] = re.sub(r"Control: \S+", "Control: " + MIGRATE_TYPES[old], lines[c["line"] + 1], count=1)
    text = nl.join(lines)
    for pattern, repl in ENUM_REPLACEMENTS:
        text = re.sub(pattern, repl, text)
    text = re.sub(r'\.ValidationState\s*=\s*"(Error|None)"', r".ValidationState = ValidationState.\1", text)
    for name in textinput_names:
        text = re.sub(r"(?<![\w'])('?" + re.escape(name) + r"'?)\.Value\b", r"\1.Text", text)
    return raw, text


def cmd_migrate_modern(a):
    files = [f for f in yaml_files(a.dir) if not os.path.basename(f).startswith("_")]
    textinputs = {c["name"] for f in files for c in parse_blocks(read(os.path.join(a.dir, f))[0].splitlines()) if c["type"] == "TextInput"}
    report = []
    for f in files:
        if a.only and f not in a.only:
            continue
        raw, new = migrate_file(os.path.join(a.dir, f), textinputs, report)
        if raw != new:
            print(f"{'would change' if a.dry_run else 'changed'} {f}")
            if not a.dry_run:
                write(os.path.join(a.dir, f), new)
    for line in report:
        print(line)


# ---------------------------------------------------------------- CLI

def main(argv=None):
    ap = argparse.ArgumentParser(prog="canvas.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("inventory", help="TSV of every control"); s.add_argument("dir"); s.set_defaults(fn=cmd_inventory)
    s = sub.add_parser("tree", help="indented control tree"); s.add_argument("dir"); s.add_argument("filter", nargs="?", default=""); s.set_defaults(fn=cmd_tree)
    s = sub.add_parser("names", help="controls without a naming prefix")
    s.add_argument("dir", nargs="?"); s.add_argument("--list", action="store_true", help="print the prefix table")
    s.add_argument("--prefix", action="append", default=[], help="extra project prefix (repeatable)"); s.set_defaults(fn=cmd_names)
    s = sub.add_parser("order", help="compare sibling order"); s.add_argument("ref"); s.add_argument("cand"); s.set_defaults(fn=cmd_order)
    s = sub.add_parser("check", help="verify fresh syncs against the pushed workspace")
    s.add_argument("pushed"); s.add_argument("sync", nargs="+")
    s.add_argument("--ignore", action="append", default=[], help="skip lines containing this text, e.g. a default the server drops")
    s.add_argument("--show", type=int, default=5, help="lines shown per file"); s.set_defaults(fn=cmd_check)
    s = sub.add_parser("restore-order", help="restore REF's sibling order in TARGET"); s.add_argument("ref"); s.add_argument("target"); s.set_defaults(fn=cmd_restore_order)
    s = sub.add_parser("rename", help="rename from a TSV map")
    s.add_argument("map"); s.add_argument("dir"); s.add_argument("--check", action="store_true", help="validate only, write nothing")
    s.add_argument("--only", action="append", default=[], help="rewrite only this relative file (repeatable)")
    s.add_argument("--prefix", action="append", default=[], help="extra project prefix (repeatable)"); s.set_defaults(fn=cmd_rename)
    s = sub.add_parser("fix-event-defaults", help="empty component Event defaults -> =false"); s.add_argument("dir"); s.set_defaults(fn=cmd_fix_event_defaults)
    s = sub.add_parser("migrate-modern", help="legacy modern controls -> updated controls")
    s.add_argument("dir"); s.add_argument("--dry-run", action="store_true")
    s.add_argument("--only", action="append", default=[], help="rewrite only this relative file (repeatable)"); s.set_defaults(fn=cmd_migrate_modern)
    a = ap.parse_args(argv)
    if a.cmd == "names" and not a.list and not a.dir:
        ap.error("names needs DIR or --list")
    return a.fn(a) or 0


if __name__ == "__main__":
    sys.exit(main())
