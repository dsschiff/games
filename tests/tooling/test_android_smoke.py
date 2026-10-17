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


class ActualBackInputTests(unittest.TestCase):
    def test_back_uses_android_back_not_home(self):
        self.assertEqual(smoke.input_command({"type": "key", "key": "BACK"}),
                         ["shell", "input", "keyevent", "KEYCODE_BACK"])

    def test_unknown_actions_and_keys_fail(self):
        for event in ({"type": "key", "key": "HOME"}, {"type": "key"},
                      {"type": "key", "key": "BACK; reboot"}, {"type": "unknown"}):
            with self.subTest(event=event), self.assertRaises(ValueError):
                smoke.input_command(event)

    def test_wait_has_no_input_and_touch_remains_explicit(self):
        self.assertEqual(smoke.input_command({"type": "wait"}), [])
        self.assertEqual(smoke.input_command({"type": "tap", "x": 12, "y": 34}),
                         ["shell", "input", "tap", "12", "34"])


class SavedStateExpectationTests(unittest.TestCase):
    def setUp(self):
        self.saved = {"version": 2, "state": {"phase": "battle", "time": 6.1,
                                             "board": [{"id": 2, "x": 1}]}}

    def test_nested_dictionary_and_array_equality(self):
        result = smoke.evaluate_expectations(self.saved, {"expected_save": {
            "state.phase": "battle", "state.board.0.id": 2, "state.board.0.x": 1}})
        self.assertTrue(result["checks"]["expected_saved_state_after_input"])
        self.assertEqual(result["exact_fields"], 3)

    def test_valid_numeric_bounds(self):
        result = smoke.evaluate_expectations(self.saved, {"expected_numeric": {"state.time": {"min": 5, "max": 8}}})
        self.assertTrue(result["checks"]["expected_numeric_state_after_input"])

    def test_missing_nested_field_fails(self):
        result = smoke.evaluate_expectations(self.saved, {"expected_save": {"state.board.8.x": 1}})
        self.assertFalse(result["checks"]["expected_saved_state_after_input"])
        self.assertTrue(result["failures"])

    def test_wrong_container_and_numeric_type_fail(self):
        result = smoke.evaluate_expectations(self.saved, {
            "expected_save": {"state.phase.value": "battle"},
            "expected_numeric": {"state.phase": {"min": 0}}})
        self.assertFalse(result["checks"]["expected_saved_state_after_input"])
        self.assertFalse(result["checks"]["expected_numeric_state_after_input"])

    def test_out_of_bounds_or_invalid_bounds_fail(self):
        for bounds in ({"min": 8}, {"max": 5}, {"min": "5"}, {}, {"max": float("inf")}):
            with self.subTest(bounds=bounds):
                result = smoke.evaluate_expectations(self.saved, {"expected_numeric": {"state.time": bounds}})
                self.assertFalse(result["checks"]["expected_numeric_state_after_input"])

    def test_equality_mismatch_and_boolean_number_fail(self):
        for path, expected in (("version", 3), ("state.board.0.x", True)):
            with self.subTest(path=path, expected=expected):
                result = smoke.evaluate_expectations(self.saved, {"expected_save": {path: expected}})
                self.assertFalse(result["checks"]["expected_saved_state_after_input"])

    def test_absent_expectations_do_not_add_success_checks(self):
        result = smoke.evaluate_expectations(self.saved, {})
        self.assertEqual(result["checks"], {})
        self.assertEqual(result["exact_fields"], 0)
        self.assertEqual(result["numeric_fields"], 0)


if __name__ == "__main__":
    unittest.main()
