import importlib.util
from pathlib import Path
import sys
import unittest

scripts = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(scripts))
spec = importlib.util.spec_from_file_location("android_smoke", scripts / "android_smoke.py")
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class DisplayMappingTests(unittest.TestCase):
    def test_baseline_coordinates_are_unchanged(self):
        event = {"type": "tap", "x": 540, "y": 1740}
        self.assertEqual(smoke.scale_action(event, (1080, 2400), (1080, 2400)), event)

    def test_taller_cover_adds_letterbox_offset(self):
        event = {"type": "tap", "x": 540, "y": 1740}
        mapped = smoke.scale_action(event, (1080, 2400), (1080, 2520))
        self.assertEqual(mapped["x"], 540)
        self.assertEqual(mapped["y"], 1800)

    def test_inner_geometry_preserves_horizontal_center(self):
        event = {"type": "swipe", "x1": 540, "y1": 1200, "x2": 900, "y2": 1200, "duration_ms": 1200}
        mapped = smoke.scale_action(event, (1080, 2400), (1968, 2184))
        self.assertEqual((mapped["x1"], mapped["y1"]), (984, 1092))
        self.assertGreater(mapped["x2"], mapped["x1"])
        self.assertEqual(mapped["duration_ms"], 1200)


if __name__ == "__main__":
    unittest.main()
