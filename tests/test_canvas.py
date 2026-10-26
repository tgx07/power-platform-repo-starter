"""Offline tests for scripts/canvas/canvas.py. Run: python3 -I tests/test_canvas.py"""
import contextlib
import importlib.util
import io
import os
import shutil
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True  # keep scripts/canvas free of __pycache__
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("canvas", os.path.join(HERE, "..", "scripts", "canvas", "canvas.py"))
canvas = importlib.util.module_from_spec(spec)
spec.loader.exec_module(canvas)

SCREEN = """Screens:
  Done:
    Properties:
      Fill: =White
    Children:
      - ctnDoneScreen:
          Control: GroupContainer@1.5.0
          Variant: AutoLayout
          Properties:
            LayoutDirection: =LayoutDirection.Vertical
          Children:
            - icoDoneSuccess:
                Control: Icon@0.0.7
                Properties:
                  Icon: ="CheckmarkCircle"
            - TextCanvas7:
                Control: Text@0.0.51
                Properties:
                  Text: ="Fertig"
                  Weight: ='TextCanvas.Weight'.Semibold
            - btnDoneHome:
                Control: Button@0.0.45
                Properties:
                  OnSelect: =Navigate(Home); Notify(TextCanvas7.Text)
                  Text: ="Zur Startseite"
"""

COMPONENT = """ComponentDefinitions:
  Picker:
    DefinitionType: CanvasComponent
    CustomProperties:
      OnCancel:
        PropertyKind: Event
        DisplayName: OnCancel
        Default: =
    Children:
      - rectPickerOverlay:
          Control: Rectangle@2.3.0
      - ctnPickerPanel:
          Control: GroupContainer@1.5.0
"""


def run(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = canvas.main(list(argv))
    return code, out.getvalue()


class CanvasTools(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.ref = self.workspace("ref")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def workspace(self, name, screen=SCREEN, component=COMPONENT):
        root = os.path.join(self.tmp, name)
        os.makedirs(os.path.join(root, "Components"))
        canvas.write(os.path.join(root, "Done.pa.yaml"), screen)
        canvas.write(os.path.join(root, "Components", "Picker.pa.yaml"), component)
        return root

    def swapped(self, name):
        """Same content with the top-level component children swapped (overlay above panel)."""
        return self.workspace(name, component=COMPONENT.replace(
            "      - rectPickerOverlay:\n          Control: Rectangle@2.3.0\n      - ctnPickerPanel:\n          Control: GroupContainer@1.5.0\n",
            "      - ctnPickerPanel:\n          Control: GroupContainer@1.5.0\n      - rectPickerOverlay:\n          Control: Rectangle@2.3.0\n"))

    def test_names_flags_unprefixed_and_strips_versions(self):
        code, out = run("names", self.ref)
        self.assertEqual(code, 1)
        self.assertIn("TextCanvas7 [Text] has no naming prefix", out)
        self.assertIn("without prefix 1", out)

    def test_order_and_restore_handle_top_level_component_children(self):
        cand = self.swapped("cand")
        code, out = run("order", self.ref, cand)
        self.assertEqual(code, 1)
        self.assertIn("Components/Picker.pa.yaml: ROOT order differs", out)
        run("restore-order", self.ref, cand)
        with open(os.path.join(cand, "Components", "Picker.pa.yaml"), encoding="utf-8") as fh:
            self.assertEqual(fh.read(), COMPONENT)

    def test_check_reports_order_content_and_empty_sync(self):
        same = self.workspace("same")
        self.assertEqual(run("check", self.ref, same)[0], 0)
        code, out = run("check", self.ref, self.swapped("swapped"), self.workspace("dropped", screen=SCREEN.replace('                  Text: ="Fertig"\n', "")))
        self.assertEqual(code, 1)
        self.assertIn("order: Components/Picker.pa.yaml: ROOT", out)
        self.assertIn('- Text: ="Fertig"', out)
        empty = os.path.join(self.tmp, "empty")
        os.makedirs(empty)
        self.assertIn("no .pa.yaml files", run("check", self.ref, empty)[1])

    def test_rename_check_then_apply_renames_references(self):
        mp = os.path.join(self.tmp, "map.tsv")
        canvas.write(mp, "# Done\nTextCanvas7\tlblDoneMessage\n")
        self.assertEqual(run("rename", mp, self.ref, "--check")[0], 0)
        canvas.write(os.path.join(self.tmp, "bad.tsv"), "TextCanvas7\tDoneMessage\n")
        self.assertEqual(run("rename", os.path.join(self.tmp, "bad.tsv"), self.ref, "--check")[0], 1)
        run("rename", mp, self.ref)
        with open(os.path.join(self.ref, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertNotIn("TextCanvas7", text)
        self.assertIn("Notify(lblDoneMessage.Text)", text)

    def test_rename_defined_in_follows_references_into_other_files(self):
        other = os.path.join(self.ref, "Other.pa.yaml")
        canvas.write(other, "Screens:\n  Other:\n    Properties:\n      OnVisible: =Set(varText, TextCanvas7.Text)\n")
        mp = os.path.join(self.tmp, "map.tsv")
        canvas.write(mp, "TextCanvas7\tlblDoneMessage\nrectPickerOverlay\trectPickerShade\n")
        run("rename", mp, self.ref, "--defined-in", "Done.pa.yaml")
        with open(other, encoding="utf-8") as fh:
            self.assertIn("lblDoneMessage.Text", fh.read())
        with open(os.path.join(self.ref, "Components", "Picker.pa.yaml"), encoding="utf-8") as fh:
            self.assertIn("rectPickerOverlay", fh.read())  # defined elsewhere: left for its own batch

    def test_migrate_dry_run_reports_remaining_legacy_controls(self):
        out = run("migrate-modern", self.ref, "--dry-run")[1]
        self.assertIn("would change Done.pa.yaml", out)
        self.assertIn("'Text': 1", out)
        run("migrate-modern", self.ref)
        self.assertIn("none |", run("migrate-modern", self.ref, "--dry-run")[1])

    def test_rename_check_counts_applied_entries(self):
        mp = os.path.join(self.tmp, "map.tsv")
        canvas.write(mp, "TextCanvas7\tlblDoneMessage\n")
        self.assertIn("applied 0, pending 1", run("rename", mp, self.ref, "--check")[1])
        run("rename", mp, self.ref)
        code, out = run("rename", mp, self.ref, "--check")
        self.assertEqual(code, 0)
        self.assertIn("applied 1, pending 0", out)

    def test_migrate_only_moves_textinput_references_in_other_files(self):
        form = SCREEN.replace("Control: Text@0.0.51", "Control: TextInput@0.0.54").replace("TextCanvas7", "txtDoneName")
        root = self.workspace("ti", screen=form)
        other = os.path.join(root, "Other.pa.yaml")
        canvas.write(other, "Screens:\n  Other:\n    Properties:\n      OnVisible: =Set(varName, txtDoneName.Value)\n")
        run("migrate-modern", root, "--only", "Done.pa.yaml")
        with open(other, encoding="utf-8") as fh:
            self.assertIn("txtDoneName.Text", fh.read())

    def test_migrate_drops_textinput_type_text_as_default(self):
        form = SCREEN.replace("Control: Text@0.0.51", "Control: TextInput@0.0.54").replace(
            "Weight: ='TextCanvas.Weight'.Semibold", "Type: ='TextInputCanvas.Type'.Text")
        root = self.workspace("tt", screen=form)
        run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("Control: ModernTextInput", text)
        self.assertNotIn("Type: =", text)  # SingleLine is the default and is left out

    def test_migrate_textinput_multiline_mode_wins_over_type_text(self):
        form = SCREEN.replace("Control: Text@0.0.51", "Control: TextInput@0.0.54").replace(
            "Weight: ='TextCanvas.Weight'.Semibold",
            "Mode: ='TextInputCanvas.Mode'.Multiline\n                  Type: ='TextInputCanvas.Type'.Text")
        root = self.workspace("ml", screen=form)
        run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("Type: =TextInputType.Multiline", text)
        self.assertEqual(text.count("Type: ="), 1)

    def test_migrate_classic_label_to_modern_text(self):
        form = SCREEN.replace("Control: Text@0.0.51", "Control: Label@2.5.1").replace(
            "Weight: ='TextCanvas.Weight'.Semibold", "FontWeight: =FontWeight.Bold\n                  LineHeight: =1")
        root = self.workspace("lb", screen=form)
        code, out = run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("Control: ModernText", text)
        self.assertIn("FontWeight: =FontWeight.Bold", text)
        self.assertIn("Size: =13", text)
        self.assertIn("Color: =RGBA(0, 0, 0, 1)", text)
        self.assertIn("LayoutMinHeight: =40", text)  # parent is an AutoLayout container
        self.assertNotIn("LineHeight", text)
        self.assertIn("dropped LineHeight", out)

    def test_migrate_combobox_keeps_single_select_and_display_field(self):
        combo = SCREEN.replace("""            - btnDoneHome:""", """            - cboDoneLocation:
                Control: ComboBox
                Properties:
                  Appearance: ='ComboboxCanvas.Appearance'.Outline
                  FontSize: =16
                  Items: =locations
                Children:
                  - id1:
                      Control: ComboBoxDataField
                      Variant: textualColumn
                      IsLocked: true
                      Properties:
                        FieldName: ="wbs_id"
                        Order: =2
                  - name1:
                      Control: ComboBoxDataField
                      Variant: textualColumn
                      IsLocked: true
                      Properties:
                        FieldName: ="wbs_name"
                        Order: =1
            - btnDoneHome:""")
        root = self.workspace("cb", screen=combo)
        run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("Control: ModernCombobox", text)
        self.assertIn("SelectMultiple: =false", text)
        self.assertIn("AllowExternalSelectedItems: =false", text)
        self.assertIn('FontWeight: =""', text)
        self.assertIn("ItemDisplayText: =ThisItem.wbs_name", text)
        self.assertIn("Appearance: =Appearance.Outline", text)
        self.assertIn("Size: =16", text)
        self.assertNotIn("ComboBoxDataField", text)

    def test_migrate_spinner_turns_size_into_padding_like_studio(self):
        spinners = SCREEN.replace("""            - btnDoneHome:""", """            - spnDoneHuge:
                Control: Spinner
                Properties:
                  AlignInContainer: =AlignInContainer.Stretch
                  LayoutMaxHeight: =
                  SpinnerSize: ='Spinner.SpinnerSize'.Huge
            - spnDoneOverlay:
                Control: Spinner
                Properties:
                  Height: =Parent.Height
                  LabelPosition: ='Spinner.LabelPosition'.Below
                  Width: =Parent.Width
            - btnDoneHome:""")
        root = self.workspace("spn", screen=spinners)
        run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        huge, overlay = text.split("spnDoneHuge:")[1].split("spnDoneOverlay:")
        self.assertIn("Control: ModernSpinner", huge)
        self.assertIn("Height: =200", huge)
        self.assertIn("PaddingTop: =78", huge)  # (200 - 44) / 2, as Studio sets it
        self.assertNotIn("SpinnerSize", huge)
        self.assertNotIn("LayoutMaxHeight", huge)
        self.assertIn('FontWeight: =""', huge)
        self.assertIn("LabelPosition: =SpinnerLabelPosition.Below", overlay)
        self.assertIn("PaddingTop: =0", overlay)  # formula box: no padding
        self.assertIn("Height: =80", overlay)  # a full-height ModernSpinner would scale up to the parent
        self.assertIn("Y: =(Parent.Height-Self.Height)/2", overlay)

    def test_migrate_button_border_radius_becomes_corner_radii(self):
        root = self.workspace("br", screen=SCREEN.replace('Text: ="Zur Startseite"\n',
                                                          'BorderRadius: =8\n                  Text: ="Zur Startseite"\n'))
        run("migrate-modern", root)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertNotIn("BorderRadius", text)
        for corner in ("RadiusBottomLeft", "RadiusBottomRight", "RadiusTopLeft", "RadiusTopRight"):
            self.assertIn(f"{corner}: =8", text)

    def test_migrate_last_control_in_file_keeps_trailing_newline(self):
        root = self.workspace("eof", screen=SCREEN.replace('Text: ="Zur Startseite"\n', 'Text: ="Zur Startseite"\n'))
        path = os.path.join(root, "Done.pa.yaml")
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(src.replace("Control: Button@0.0.45", "Control: Text@0.0.51").rstrip("\n") + "\n")
        run("migrate-modern", root)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        self.assertTrue(text.endswith("\n"))
        self.assertNotIn("\n\n                  ", text)  # no blank line inside a property block

    def test_names_after_escapes_in_double_quoted_scalars(self):
        # Studio exports some formulas as "=...\r\n..." scalars; the `n` of `\n` must not hide the next name.
        other = os.path.join(self.ref, "Other.pa.yaml")
        canvas.write(other, 'Screens:\n  Other:\n    Properties:\n      OnVisible: "=If(true,\\r\\nTextCanvas7.Text,\\r\\nSelf.Text)"\n')
        mp = os.path.join(self.tmp, "map.tsv")
        canvas.write(mp, "TextCanvas7\tlblDoneMessage\n")
        run("rename", mp, self.ref)
        with open(other, encoding="utf-8") as fh:
            self.assertIn("\\r\\nlblDoneMessage.Text", fh.read())
        canvas.write(other, 'Screens:\n  Other:\n    Properties:\n      OnVisible: "=If(true,\\r\\nTextCanvas7.Text)"\n')
        self.assertIn("applied 0, pending 1", run("rename", mp, self.ref, "--check")[1])
        form = SCREEN.replace("Control: Text@0.0.51", "Control: TextInput@0.0.54").replace("TextCanvas7", "txtDoneName")
        root = self.workspace("ti", screen=form)
        other = os.path.join(root, "Other.pa.yaml")
        canvas.write(other, 'Screens:\n  Other:\n    Properties:\n      OnVisible: "=If(true,\\r\\ntxtDoneName.Value)"\n')
        run("migrate-modern", root)
        with open(other, encoding="utf-8") as fh:
            self.assertIn("\\r\\ntxtDoneName.Text", fh.read())

    def test_migrate_modern_radio_numberinput_infobutton_tablist(self):
        screen = """Screens:
  Form:
    Children:
      - ctnFormScreen:
          Control: GroupContainer@1.5.0
          Variant: AutoLayout
          Children:
            - radFormType:
                Control: Radio@0.0.25
                Properties:
                  DefaultSelectedItems: =LookUp(Choices(src.type),Value = locRequest.type)
                  Layout: ='RadioGroupCanvas.Layout'.Horizontal
                Children:
                  - Value3:
                      Control: RadioDataField
                      Variant: textualColumn
                      IsLocked: true
                      Properties:
                        FieldName: ="Value"
                        Order: =1
            - numFormHours:
                Control: NumberInput@1.0.0
                Properties:
                  DelayOutput: =true
                  OnChange: =Set(varHours, Self.Value)
                  Value: =ThisItem.hours
            - infoFormType:
                Control: InfoButton@0.0.3
                Properties:
                  AcceptsFocus: =true
                  Content: ="Hinweis"
            - tabFormTypes:
                Control: TabList@0.0.1
                Properties:
                  Items: =fxMenu
                  Size: ='TabList.Size'.Small
                Children:
                  - id1:
                      Control: TabListDataField
                      Properties:
                        FieldName: ="id"
                        Order: =2
                  - name1:
                      Control: TabListDataField
                      Properties:
                        FieldName: ="name"
                        Order: =1
"""
        root = self.workspace("fluent", screen=screen)
        out = run("migrate-modern", root)[1]
        self.assertIn("numFormHours dropped DelayOutput", out)
        self.assertIn("infoFormType dropped AcceptsFocus", out)
        with open(os.path.join(root, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        for expected in ("Control: ModernRadio", "Default: =LookUp(Choices(src.type),Value = locRequest.type)",
                         "Layout: =OptionLayout.Horizontal", "RadioSize: =16", "ItemDisplayText: =ThisItem.Value",
                         "Control: ModernNumberInput", "Default: =ThisItem.hours", "Self.Value",
                         "Control: ModernInformationButton", "Control: ModernTabList", "ItemDisplayText: =ThisItem.name",
                         "TabSize: =TabSize.Small", "Height: =55", "LayoutMinHeight: =55"):
            self.assertIn(expected, text)
        for gone in ("DataField", "DelayOutput", "AcceptsFocus", "DefaultSelectedItems", "RadioGroupCanvas", "'TabList.Size'"):
            self.assertNotIn(gone, text)
        self.assertIn("none |", run("migrate-modern", root, "--dry-run")[1])

    def test_fix_event_defaults(self):
        run("fix-event-defaults", self.ref)
        with open(os.path.join(self.ref, "Components", "Picker.pa.yaml"), encoding="utf-8") as fh:
            self.assertIn("Default: =false", fh.read())

    def test_migrate_modern_maps_types_properties_and_pins(self):
        run("migrate-modern", self.ref)
        with open(os.path.join(self.ref, "Done.pa.yaml"), encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn("Control: ModernText", text)
        self.assertIn("Control: ModernButton", text)
        self.assertIn("FontWeight: =FontWeight.Semibold", text)
        self.assertIn("LayoutMinWidth: =96", text)  # parent is an AutoLayout container
        self.assertIn("Control: GroupContainer@1.5.0", text)


if __name__ == "__main__":
    unittest.main()
