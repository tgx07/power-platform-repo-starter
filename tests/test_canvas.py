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
