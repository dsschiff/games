import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location("portfolio", Path(__file__).resolve().parents[2] / "scripts/portfolio.py")
portfolio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(portfolio)


class PortfolioTests(unittest.TestCase):
    def setUp(self):
        home = Path(__file__).resolve().parents[2] / ".artifacts/tooling-tests"
        home.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=home)
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def project(self, slug="probe"):
        project = self.root / "android-games/probes" / slug
        project.mkdir(parents=True)
        (project / "project.godot").touch()
        return project

    def config(self):
        (self.root / "toolchain.json").write_text(json.dumps({
            "toolchain_root": str(self.root / "tools"), "godot": "missing-godot",
            "android_sdk": "{toolchain_root}/sdk", "java_home": "jdk"}))

    def test_recursive_discovery_ignores_cache(self):
        project = self.project()
        cached = project / ".godot/imported/project.godot"
        cached.parent.mkdir(parents=True)
        cached.touch()
        self.assertEqual(portfolio.discover_projects(self.root), {"probe": project.resolve()})

    def test_duplicate_names_fail(self):
        self.project()
        duplicate = self.root / "android-games/other/probe"
        duplicate.mkdir(parents=True)
        (duplicate / "project.godot").touch()
        with self.assertRaisesRegex(ValueError, "Ambiguous"):
            portfolio.discover_projects(self.root)

    def test_relative_godot_path_uses_repo_root(self):
        path = self.root / "engine.exe"
        path.touch()
        self.assertEqual(portfolio.resolve_godot({}, "./engine.exe", self.root), str(path.resolve()))

    def test_explicit_relative_path_does_not_resolve_from_cwd(self):
        path = self.root / "tools/engine.exe"
        path.parent.mkdir()
        path.touch()
        with mock.patch.object(portfolio.shutil, "which", return_value="wrong-cwd.exe"):
            self.assertEqual(portfolio.resolve_godot({}, "tools/engine.exe", self.root), str(path.resolve()))

    def test_explicit_missing_godot_is_error(self):
        with self.assertRaises(FileNotFoundError):
            portfolio.resolve_godot({}, "absent.exe", self.root)

    def test_config_expands_portable_root(self):
        self.config()
        config = portfolio.read_config(self.root)
        self.assertEqual(config["android_sdk"], str(self.root / "tools") + "/sdk")

    def test_subprocess_nonzero_propagates(self):
        log = self.root / "failure.log"
        with contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.run_command([sys.executable, "-c", "print('failed'); raise SystemExit(7)"], log)
        self.assertEqual(code, 7)
        self.assertIn("failed", log.read_text())

    def test_godot_zero_exit_script_error_fails(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.run_command([sys.executable, "-c", "print('SCRIPT ERROR: broken')"], self.root / "bad.log")
        self.assertEqual(code, 1)

    def test_subprocess_success_is_success(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.run_command([sys.executable, "-c", "print('PASS')"], self.root / "pass.log")
        self.assertEqual(code, 0)

    def test_manifest_detects_mutation(self):
        artifact = self.root / "sample.apk"
        artifact.write_bytes(b"actual build bytes")
        manifest = {"schema_version": 1, "result": "built", "artifact": portfolio.artifact_record(artifact, self.root)}
        self.assertTrue(portfolio.validate_manifest(manifest, self.root))
        artifact.write_bytes(b"other bytes")
        self.assertFalse(portfolio.validate_manifest(manifest, self.root))

    def test_empty_artifact_rejected(self):
        artifact = self.root / "empty.apk"
        artifact.touch()
        with self.assertRaises(ValueError):
            portfolio.artifact_record(artifact, self.root)

    def test_manifest_rejects_failed_or_escaped_artifact(self):
        manifest = {"schema_version": 1, "result": "failed", "artifact": {}}
        self.assertFalse(portfolio.validate_manifest(manifest, self.root))
        manifest.update(result="built", artifact={"path": "../outside.apk"})
        self.assertFalse(portfolio.validate_manifest(manifest, self.root))

    def test_no_projects_is_skip_not_pass(self):
        self.config()
        with contextlib.redirect_stdout(io.StringIO()) as output:
            code = portfolio.main(["test", "--root", str(self.root)])
        self.assertEqual(code, 2)
        self.assertIn("SKIPPED", output.getvalue())

    def test_unknown_project_does_not_succeed(self):
        self.config()
        with contextlib.redirect_stderr(io.StringIO()):
            code = portfolio.main(["test", "absent", "--root", str(self.root)])
        self.assertEqual(code, 1)

    def test_source_fingerprint_tracks_sources_and_ignores_cache(self):
        project = self.project()
        source = project / "rules.gd"
        source.write_text("original")
        initial = portfolio.source_fingerprint(project)
        cache = project / ".godot/imported/texture.cache"
        cache.parent.mkdir(parents=True)
        cache.write_bytes(b"transient")
        self.assertEqual(portfolio.source_fingerprint(project), initial)
        source.write_text("changed")
        self.assertNotEqual(portfolio.source_fingerprint(project), initial)

    def test_source_fingerprint_tracks_file_names(self):
        project = self.project()
        source = project / "rules.gd"
        source.write_text("same bytes")
        initial = portfolio.source_fingerprint(project)
        source.rename(project / "other.gd")
        self.assertNotEqual(portfolio.source_fingerprint(project), initial)

    def test_source_drift_invalidates_success(self):
        manifest = {"result": "built"}
        portfolio.record_source_stability(manifest, "before", "after")
        self.assertEqual(manifest["result"], "failed")
        self.assertFalse(manifest["source_unchanged"])

    def test_suite_requires_explicit_marker(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.suite_command([sys.executable, "-c", "print('ordinary exit')"],
                                            self.root / "suite.log", None, 10)
        self.assertEqual(code, 1)

    def test_suite_marker_and_zero_exit_succeed(self):
        with contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.suite_command([sys.executable, "-c", "print('SUITE_COMPLETE: PASS')"],
                                            self.root / "suite.log", None, 10)
        self.assertEqual(code, 0)

    def test_rules_only_is_partial_not_pass(self):
        project = self.project()
        (project / "tests").mkdir()
        (project / "tests/run_tests.gd").touch()
        config = {"toolchain_root": str(self.root / "tools"), "godot": "fake", "godot_version": "pinned",
                  "android_sdk": str(self.root / "sdk"), "java_home": str(self.root / "jdk")}
        with mock.patch.object(portfolio, "read_config", return_value=config), \
             mock.patch.object(portfolio, "resolve_godot", return_value="fake"), \
             mock.patch.object(portfolio, "git_revision", return_value="revision"), \
             mock.patch.object(portfolio, "source_status", return_value=[]), \
             mock.patch.object(portfolio.subprocess, "run", return_value=SimpleNamespace(stdout="pinned")), \
             mock.patch.object(portfolio, "run_command", return_value=0), \
             mock.patch.object(portfolio, "suite_command", return_value=0), \
             contextlib.redirect_stdout(io.StringIO()):
            code = portfolio.main(["test", "--root", str(self.root)])
        self.assertEqual(code, 2)
        manifest = json.loads(next((self.root / ".artifacts").rglob("manifest.json")).read_text())
        self.assertEqual(manifest["result"], "rules_only")

    def test_apk_metadata_reports_actual_network_permission(self):
        metadata = portfolio.parse_apk_metadata("package: name='com.example.game' versionCode='1' versionName='0.1'\nuses-permission: name='android.permission.INTERNET'\n")
        self.assertTrue(metadata["internet_permission"])
        self.assertEqual(metadata["package"], "com.example.game")

    def test_apk_metadata_without_permissions_is_offline(self):
        metadata = portfolio.parse_apk_metadata("package: name='com.example.game' versionCode='1' versionName='0.1'\n")
        self.assertFalse(metadata["internet_permission"])
        self.assertEqual(metadata["permissions"], [])


if __name__ == "__main__":
    unittest.main()
