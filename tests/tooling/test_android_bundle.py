"""Fault-oriented checks for local bundle identity, inputs and cleanup boundaries."""
import io
import contextlib
import json
import os
import time
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import build_android_bundle as bundle
import owned_process

PRESET = """[preset.0]
name="Android"
platform="Android"
exclude_filter="tests/*"
[preset.0.options]
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=true
version/code=8
version/name="0.4.2"
package/unique_name="com.dsschiff.towertrials"
package/signed=true
permissions/internet=false
"""
XML = """<manifest xmlns:android="http://schemas.android.com/apk/res/android"
package="com.dsschiff.towertrials" android:versionCode="8" android:versionName="0.4.2">
<uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/>
<application android:debuggable="false"/>
</manifest>"""
NAMES = ["base/lib/arm64-v8a/libgodot_android.so",
         "base/lib/x86_64/libgodot_android.so"]


class BundleTests(unittest.TestCase):
    def setUp(self):
        home = ROOT / ".artifacts/bundle-tooling-tests"
        home.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=home)
        self.home = Path(self.temp.name)
        self.safe_root = home.resolve()

    def tearDown(self):
        self.assertTrue(self.home.resolve().is_relative_to(self.safe_root))
        self.temp.cleanup()

    def test_staged_override_is_scoped_to_selected_preset(self):
        other = '\n[preset.1]\nname="Desktop"\nplatform="Windows Desktop"\n[preset.1.options]\npackage/signed=true\n'
        section, expected = bundle.preset_info(PRESET + other, "Android")
        changed = bundle.bundle_preset(PRESET + other, section)
        self.assertTrue(changed.endswith(other))
        self.assertEqual(PRESET.count("package/signed=true"), 1)
        self.assertIn("package/signed=false", changed)
        self.assertEqual(bundle.preset_info(changed, "Android")[1], expected)
        self.assertEqual(expected["abis"], ["arm64-v8a", "x86_64"])

    def test_ambiguous_or_nonandroid_presets_are_rejected(self):
        duplicate = PRESET + PRESET.replace("preset.0", "preset.1")
        for text in (duplicate, PRESET.replace('platform="Android"', 'platform="Windows Desktop"')):
            with self.subTest(text=text), self.assertRaises(ValueError):
                bundle.preset_info(text, "Android")

    def test_custom_templates_and_implicit_architectures_are_not_silently_packaged(self):
        for text in (PRESET + 'gradle_build/android_source_template="custom.zip"\n',
                     PRESET + 'gradle_build/gradle_build_directory="res://custom"\n',
                     PRESET.replace("architectures/x86=false\n", "")):
            with self.subTest(text=text), self.assertRaises(ValueError):
                bundle.preset_info(text, "Android")

    def test_manifest_and_native_abi_must_match_selected_game(self):
        expected = bundle.preset_info(PRESET, "Android")[1]
        self.assertEqual(bundle.inspect_manifest(XML, NAMES, expected)["version_code"], 8)
        for field, new in (("towertrials", "othergame"), ('versionCode="8"', 'versionCode="7"'),
                           ('versionName="0.4.2"', 'versionName="0.4.1"'),
                           ('debuggable="false"', 'debuggable="true"'),
                           ('minSdkVersion="24"', 'minSdkVersion="21"'),
                           ('targetSdkVersion="36"', 'targetSdkVersion="35"')):
            with self.subTest(field=field), self.assertRaises(ValueError):
                bundle.inspect_manifest(XML.replace(field, new), NAMES, expected)
        with self.assertRaises(ValueError):
            bundle.inspect_manifest(XML, NAMES[:1], expected)

    def test_unexpected_network_permission_and_missing_application_fail(self):
        expected = bundle.preset_info(PRESET, "Android")[1]
        permission = '<uses-permission android:name="android.permission.INTERNET"/>'
        for xml in (XML.replace("<uses-sdk", permission + "<uses-sdk"),
                    XML.replace('<application android:debuggable="false"/>', "")):
            with self.subTest(xml=xml), self.assertRaises(ValueError):
                bundle.inspect_manifest(xml, NAMES, expected)

    def test_certificate_requires_one_full_sha256(self):
        digest = "25" * 32
        self.assertEqual(bundle.signer_digest("SHA256: " + ":".join(["25"] * 32)), digest)
        for output in ("jar is unsigned", "SHA256: " + "25" * 12,
                       "SHA256: " + digest + "\nSHA256: " + digest):
            with self.subTest(output=output), self.assertRaises(ValueError):
                bundle.signer_digest(output)

    def archive(self, members):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            for name in members:
                archive.writestr(name, b"fixture")
        data.seek(0)
        return zipfile.ZipFile(data)

    def test_template_rejects_escape_ads_absolute_and_windows_case_collision(self):
        for members in (["../escaped"], ["C:/escaped"], ["/escaped"], ["safe:stream"],
                        ["Config.gradle", "config.gradle"]):
            target = self.home / ("stage" + str(len(list(self.home.iterdir()))))
            target.mkdir()
            with self.archive(members) as archive, self.subTest(members=members), self.assertRaises(ValueError):
                bundle.extract_template(archive, target)
        self.assertFalse((self.home / "escaped").exists())

    def test_template_rejects_symbolic_link(self):
        member = zipfile.ZipInfo("link")
        member.external_attr = (stat.S_IFLNK | 0o777) << 16
        with self.archive([member]) as archive, self.assertRaises(ValueError):
            bundle.extract_template(archive, self.home)

    def test_template_roundtrip_is_complete(self):
        target = self.home / "build"
        target.mkdir()
        with self.archive(["config.gradle", "lib/test.aar"]) as archive:
            self.assertEqual(bundle.extract_template(archive, target), 14)
        self.assertEqual((target / "lib/test.aar").read_bytes(), b"fixture")

    def test_cleanup_cannot_remove_a_sibling_or_source(self):
        run = self.home / "run"
        run.mkdir()
        outside = self.home / "staged-project"
        outside.mkdir()
        (outside / "unique").write_text("keep")
        with self.assertRaises(ValueError):
            bundle.remove_stage(outside, run)
        self.assertTrue((outside / "unique").exists())
        stage = run / "staged-project"
        stage.mkdir()
        (stage / "derived").write_bytes(b"generated")
        self.assertEqual(bundle.remove_stage(stage, run)["bytes_removed"], 9)
        self.assertFalse(stage.exists())

    def test_source_snapshot_detects_new_uids_but_excludes_generated_cache(self):
        stage = self.home / "project"
        stage.mkdir()
        (stage / "project.godot").write_text("fixture")
        before = bundle.staged_sources(stage)
        (stage / ".godot").mkdir()
        (stage / ".godot/cache").write_text("generated")
        self.assertEqual(bundle.staged_sources(stage), before)
        (stage / "new.gd.uid").write_text("uid://new")
        self.assertNotEqual(bundle.staged_sources(stage), before)

    def test_dirty_or_missing_tracked_source_is_refused(self):
        subprocess.run(["git", "init", "-q", str(self.home)], check=True)
        project = self.home / "android-games/fixture"
        project.mkdir(parents=True)
        (project / "project.godot").write_text("fixture")
        (project / "export_presets.cfg").write_text(PRESET)
        subprocess.run(["git", "-C", str(self.home), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.home), "-c", "user.name=Bundle Fixture",
                        "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=" + str(self.home / "no-hooks"),
                        "commit", "-qm", "fixture"], check=True)
        self.assertEqual(len(bundle.tracked_sources(self.home, project)), 2)
        (project / "untracked-source.gd").write_text("new")
        with self.assertRaises(ValueError):
            bundle.tracked_sources(self.home, project)



    @unittest.skipUnless(os.name == "nt", "Windows Job Object integration")
    def test_structured_stdout_stays_separate_from_raw_stderr_banner(self):
        expected = bundle.preset_info(PRESET, "Android")[1]
        stdout = self.home / "structured.log"
        stderr = self.home / "structured.stderr.log"
        command = [sys.executable, "-I", "-S", "-c",
                   "import sys;sys.stderr.write('Picked up JAVA_TOOL_OPTIONS: controlled fixture\\n');"
                   "sys.stdout.write(" + repr(XML) + ")"]
        with stdout.open("wb") as output, stderr.open("wb") as errors:
            value = owned_process.run_owned(command, env=os.environ.copy(), log=output,
                                            stderr_log=errors, timeout=5)
        self.assertEqual(value["exit_code"], 0)
        self.assertTrue(value["process_tree_stopped"])
        self.assertEqual(bundle.inspect_manifest(stdout.read_text(), NAMES, expected)["package"],
                         expected["package"])
        self.assertIn("Picked up JAVA_TOOL_OPTIONS: controlled fixture", stderr.read_text())

    @unittest.skipUnless(os.name == "nt", "Windows Job Object integration")
    def test_timeout_drains_actual_child_and_grandchild_without_touching_sentinel(self):
        pids = self.home / "pids.json"
        heartbeat = self.home / "heartbeat"
        child = self.home / "spawn_child.py"
        grandchild = (
            "from pathlib import Path; import time\n"
            "p=Path(" + repr(str(heartbeat)) + ")\n"
            "while True:\n"
            " p.write_text(str(time.monotonic())); time.sleep(.03)\n")
        child.write_text(
            "import subprocess,sys,os,json,time\n"
            "from pathlib import Path\n"
            "p=subprocess.Popen([sys.executable,'-I','-S','-c'," + repr(grandchild) +
            "],creationflags=subprocess.CREATE_NO_WINDOW)\n"
            "Path(" + repr(str(pids)) + ").write_text(json.dumps([os.getpid(),p.pid]))\n"
            "print('CONTROLLED_CHILD_READY',flush=True)\ntime.sleep(60)\n")
        sentinel = subprocess.Popen([sys.executable, "-I", "-S", "-c", "import time;time.sleep(60)"],
                                    creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with (self.home / "timeout.log").open("wb") as log:
                value = owned_process.run_owned([sys.executable, "-I", "-S", str(child)],
                                                env=os.environ.copy(), log=log, timeout=2)
            self.assertTrue(value["timed_out"], value)
            self.assertTrue(value["target_admitted"], value)
            self.assertTrue(value["process_tree_stopped"], value)
            self.assertGreaterEqual(value["before_cleanup"]["total_processes"], 3)
            self.assertEqual(value["after_cleanup"]["active_processes"], 0)
            self.assertEqual(len(json.loads(pids.read_text())), 2)
            self.assertIn("CONTROLLED_CHILD_READY", (self.home / "timeout.log").read_text())
            frozen = heartbeat.read_bytes()
            time.sleep(.15)
            self.assertEqual(heartbeat.read_bytes(), frozen)
            self.assertIsNone(sentinel.poll())
        finally:
            sentinel.terminate()
            sentinel.wait(timeout=10)

    @unittest.skipUnless(os.name == "nt", "Windows Job Object integration")
    def test_job_assignment_failure_never_admits_target(self):
        touched = self.home / "must-not-run"
        class DeniedJob:
            def assign(self, _): raise OSError("controlled assignment denial")
            def close(self): pass
        command = [sys.executable, "-c", "from pathlib import Path;Path(" + repr(str(touched)) + ").touch()"]
        with mock.patch.object(owned_process, "_Job", DeniedJob):
            with (self.home / "denied.log").open("wb") as log:
                value = owned_process.run_owned(command, env=os.environ.copy(), log=log, timeout=2)
        self.assertFalse(value["target_admitted"])
        self.assertTrue(value["process_tree_stopped"])
        self.assertIn("controlled assignment denial", value["process_error"])
        self.assertFalse(touched.exists())

    def main_fault(self, outcome):
        if os.name != "nt" or self.home.drive.casefold() != "f:":
            self.skipTest("Staged pipeline integration uses this host's Windows F: volume")
        project = self.home / "android-games/fixture"
        project.mkdir(parents=True)
        (project / "project.godot").write_text("fixture")
        (project / "export_presets.cfg").write_text(PRESET)
        (self.home / "scripts").mkdir()
        for name in ("portfolio.py", "install_toolchain.py", "owned_process.py"):
            (self.home / "scripts" / name).write_text("controlled fixture")
        (self.home / "toolchain.json").write_text("{}")
        jar = self.home / "bundletool.jar"
        jar.write_bytes(b"controlled bundletool fixture")
        source = {p.name: bundle.file_sha256(p) for p in project.iterdir()}
        output = self.home / "attempt"
        config = {"godot_version": "4.7.2.stable.official.ed1daf0bf", "export_preset": "Android"}
        command_admission = []
        def controlled(_argv, *, env, log, **_kwargs):
            admitted = json.loads((output / "manifest.json").read_text())
            command_admission.append(admitted["commands"][-1])
            log.write(b"controlled partial engine output\n")
            return outcome
        argv = ["bundle", "fixture", "--output", str(output), "--bundletool", str(jar),
                "--gradle-cache", str(self.home / "cache"), "--unsigned"]
        with mock.patch.object(bundle, "REPO_ROOT", self.home), \
             mock.patch.object(bundle, "discover_projects", return_value={"fixture": project}), \
             mock.patch.object(bundle, "read_config", return_value=config), \
             mock.patch.object(bundle, "resolve_godot", return_value=sys.executable), \
             mock.patch.object(bundle, "tracked_sources", return_value=source), \
             mock.patch.object(bundle, "tool_environment", return_value=os.environ.copy()), \
             mock.patch.object(bundle, "prepare_template", return_value={"controlled_fixture": True}), \
             mock.patch.object(bundle, "BUNDLETOOL_SHA256", bundle.file_sha256(jar)), \
             mock.patch.object(bundle, "run_owned", side_effect=controlled), \
             mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(bundle.main(), 1)
        self.assertEqual(command_admission[0]["state"], "admitted")
        self.assertEqual(command_admission[0]["timeout_seconds"], 900)
        self.assertEqual((output / "engine-version.log").read_text(), "controlled partial engine output\n")
        self.assertEqual({p.name: bundle.file_sha256(p) for p in project.iterdir()}, source)
        return output, json.loads((output / "manifest.json").read_text())

    def test_timed_out_pipeline_records_outcome_and_cleans_only_after_tree_exit(self):
        output, value = self.main_fault({"exit_code": None, "timed_out": True,
                                        "process_tree_stopped": True})
        self.assertEqual(value["result"], "failed")
        self.assertEqual(value["commands"][0]["state"], "timed_out")
        self.assertTrue(value["cleanup"]["removed"])
        self.assertFalse((output / "staged-project").exists())

    def test_uncertain_process_ownership_retains_stage_and_fails(self):
        output, value = self.main_fault({"exit_code": 0, "timed_out": False,
                                        "process_tree_stopped": False})
        self.assertEqual(value["result"], "failed")
        self.assertIn("Process-tree lifetime unresolved", value["cleanup_error"])
        self.assertTrue((output / "staged-project/project.godot").exists())


if __name__ == "__main__":
    unittest.main()
