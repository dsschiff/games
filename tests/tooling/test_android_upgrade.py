import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

scripts = Path(__file__).resolve().parents[2] / "scripts"
sys.path.insert(0, str(scripts))
spec = importlib.util.spec_from_file_location("android_upgrade", scripts / "android_upgrade.py")
upgrade = importlib.util.module_from_spec(spec)
spec.loader.exec_module(upgrade)


class UpgradeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.old = {"version": 2, "state": {"board": [{"id": 2, "x": 1, "y": 2}], "produced": 8}}
        self.metadata = {"package": "com.example.game", "version_code": "1", "version_name": "0.1",
                         "signature_verified": True, "internet_permission": False, "permissions": []}

    def test_migration_can_add_keys_without_resetting_critical_board(self):
        migrated = copy.deepcopy(self.old)
        migrated["version"] = 3
        migrated["campaign"] = {"region": 1}
        migrated["state"]["board"][0]["new_modifier"] = "none"
        result = upgrade.compare_preserved_paths(self.old, migrated, ["state.board", "state.produced"])
        self.assertTrue(result["passed"])

    def test_missing_nested_path_never_passes(self):
        result = upgrade.compare_preserved_paths(self.old, {"version": 3}, ["state.board.0.x"])
        self.assertFalse(result["passed"])
        self.assertIn("error", result["paths"]["state.board.0.x"])

    def test_board_reset_or_actor_order_change_is_detected(self):
        migrated = copy.deepcopy(self.old)
        migrated["state"]["board"][0]["x"] = 0
        self.assertFalse(upgrade.compare_preserved_paths(self.old, migrated, ["state.board"])["passed"])
        self.assertFalse(upgrade.semantic_subset([{"id": 1}, {"id": 2}], [{"id": 2}, {"id": 1}]))

    def test_semantic_numbers_allow_json_integer_float_but_not_boolean_or_nan(self):
        self.assertTrue(upgrade.semantic_subset({"x": 1}, {"x": 1.0, "new": True}))
        self.assertFalse(upgrade.semantic_subset({"x": 1}, {"x": True}))
        self.assertFalse(upgrade.semantic_subset(float("nan"), float("nan")))

    def test_missing_preservation_and_expectation_assertions_are_rejected(self):
        with self.assertRaises(ValueError):
            upgrade.compare_preserved_paths(self.old, self.old, [])
        with self.assertRaises(ValueError):
            upgrade.require_expectation_spec({"actions": [{"type": "tap"}]}, "old")

    def test_actual_package_and_increasing_code_are_required(self):
        new = dict(self.metadata, version_code="2", version_name="0.2")
        self.assertEqual(upgrade.validate_apk_pair(self.metadata, new, "com.example.game"),
                         {"from_version_code": 1, "to_version_code": 2})
        for changes in ({"version_code": "1"}, {"version_code": "0"},
                        {"version_code": "not-a-code"}, {"package": "com.other.game"}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                upgrade.validate_apk_pair(self.metadata, dict(new, **changes), "com.example.game")

    def test_unsigned_or_network_apks_are_rejected(self):
        new = dict(self.metadata, version_code="2")
        for changes in ({"signature_verified": False}, {"internet_permission": True},
                        {"permissions": ["android.permission.INTERNET"]}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                upgrade.validate_apk_pair(self.metadata, dict(new, **changes), "com.example.game")

    def test_installed_code_requires_real_unambiguous_dumpsys_value(self):
        self.assertEqual(upgrade.installed_version_code("Package [com.example.game]\n  versionCode=2 minSdk=24 targetSdk=36\n"), 2)
        for text in ("No package found", "versionName=0.2", "versionCode=1\nversionCode=2"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                upgrade.installed_version_code(text)

    def test_untouched_old_file_cannot_prove_new_app_persisted(self):
        old = upgrade.save_file_metadata("1700000000:125:1024\n")
        unchanged = upgrade.save_file_metadata("1700000000:125:1024\n")
        rewritten = upgrade.save_file_metadata("1700000006:126:1100\n")
        self.assertFalse(upgrade.fresh_save_write(old, unchanged))
        self.assertTrue(upgrade.fresh_save_write(old, rewritten))

    def test_missing_file_metadata_does_not_pass(self):
        for output in ("", "stat: no such file", "1700000000:125:0", "1700000000"):
            with self.subTest(output=output), self.assertRaises(ValueError):
                upgrade.save_file_metadata(output)

    def test_no_assertion_fixture_fails_before_any_external_command(self):
        home = Path(__file__).resolve().parents[2] / ".artifacts/tooling-tests"
        home.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=home) as temp:
            root = Path(temp)
            fixture = root / "actions.json"
            fixture.write_text(json.dumps({"actions": [{"type": "tap", "x": 10, "y": 10}]}))
            argv = ["--from-apk", str(root / "old.apk"), "--to-apk", str(root / "new.apk"),
                    "--package", "com.example.game", "--save", "files/save.json", "--actions", str(fixture),
                    "--preserve-path", "state.board", "--expected-version", "3", "--root", str(root)]
            with mock.patch.object(upgrade.subprocess, "run") as command, contextlib.redirect_stdout(io.StringIO()):
                code = upgrade.main(argv)
            self.assertEqual(code, 1)
            command.assert_not_called()
            manifest = json.loads(next(root.rglob("manifest.json")).read_text())
            self.assertEqual(manifest["result"], "failed")
            self.assertIn("assertions are required", manifest["error"])

    def test_physical_serial_is_refused_before_external_commands(self):
        argv = ["--from-apk", "old.apk", "--to-apk", "new.apk", "--package", "com.example.game",
                "--save", "files/save.json", "--actions", "actions.json", "--preserve-path", "state.board",
                "--expected-version", "3", "--serial", "R58PHONE"]
        with mock.patch.object(upgrade.subprocess, "run") as command, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            upgrade.main(argv)
        command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
