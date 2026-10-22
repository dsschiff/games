import importlib.util
import tempfile
import unittest
from pathlib import Path

tool = Path(__file__).resolve().parents[2] / "android-games/tower-trials/tools/graphics_check.py"
spec = importlib.util.spec_from_file_location("graphics_check", tool)
graphics_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(graphics_check)


class NeedsImportTests(unittest.TestCase):
    def test_fresh_project_without_godot_folder_needs_import(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertTrue(graphics_check.needs_import(Path(folder)))

    def test_empty_imported_folder_needs_import(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / ".godot/imported").mkdir(parents=True)
            self.assertTrue(graphics_check.needs_import(Path(folder)))

    def test_populated_imported_folder_skips_import(self):
        with tempfile.TemporaryDirectory() as folder:
            imported = Path(folder) / ".godot/imported"
            imported.mkdir(parents=True)
            (imported / "model.glb-abc.scn").write_bytes(b"x")
            self.assertFalse(graphics_check.needs_import(Path(folder)))

    def test_import_arguments_are_headless_and_silent_of_audio_flags(self):
        self.assertEqual(graphics_check.IMPORT_ARGUMENTS, ["--headless", "--editor", "--import", "--quit"])


if __name__ == "__main__":
    unittest.main()
