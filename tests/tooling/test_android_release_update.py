import importlib.util
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import android_release_update as update


class ReleaseUpdateGuards(unittest.TestCase):
    def metadata(self):
        return {"package": "com.dsschiff.frontlinefoundry", "debuggable": False,
                "internet_permission": False, "signer_certificate_sha256": "a" * 64,
                "version_code": "6"}

    def arguments(self, serial="emulator-5554"):
        return ["update", "--apk", "new.apk", "--package", "com.dsschiff.frontlinefoundry",
                "--expect-signer", "a" * 64, "--serial", serial]

    def test_physical_device_rejected_before_tool_or_device_calls(self):
        with mock.patch.object(sys, "argv", self.arguments("R5PHONE")), mock.patch.object(update, "read_config") as config, mock.patch.object(update.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "physical"):
                update.main()
            config.assert_not_called()
            run.assert_not_called()

    def refused(self, changes, message):
        metadata = self.metadata() | changes
        with tempfile.TemporaryDirectory() as home, mock.patch.object(update, "REPO_ROOT", Path(home)), mock.patch.object(sys, "argv", self.arguments()), mock.patch.object(update, "read_config", return_value={"android_sdk": home}), mock.patch.object(update, "tool_environment", return_value={}), mock.patch.object(update, "inspect_apk", return_value=metadata), mock.patch.object(update.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, message):
                update.main()
            run.assert_not_called()

    def test_wrong_signer_never_reaches_device(self):
        self.refused({"signer_certificate_sha256": "b" * 64}, "signer")

    def test_wrong_package_never_reaches_device(self):
        self.refused({"package": "other.game"}, "identity")

    def test_debuggable_binary_never_reaches_device(self):
        self.refused({"debuggable": True}, "identity")

    def test_unexpected_network_permission_never_reaches_device(self):
        self.refused({"internet_permission": True}, "identity")

    def test_equal_or_newer_installed_version_never_installs(self):
        for installed in (6, 9):
            commands = []
            def device(command, **kwargs):
                commands.append(command)
                parts = command[3:]
                value = "emulator-5554" if parts == ["get-serialno"] else "1" if parts[-1] == "sys.boot_completed" else f"versionCode={installed} minSdk=24"
                return SimpleNamespace(stdout=value.encode(), returncode=0)
            with tempfile.TemporaryDirectory() as home, mock.patch.object(update, "REPO_ROOT", Path(home)), mock.patch.object(sys, "argv", self.arguments()), mock.patch.object(update, "read_config", return_value={"android_sdk": home}), mock.patch.object(update, "tool_environment", return_value={}), mock.patch.object(update, "inspect_apk", return_value=self.metadata()), mock.patch.object(update.subprocess, "run", side_effect=device):
                with self.assertRaisesRegex(ValueError, "lower version"):
                    update.main()
            self.assertFalse(any("install" in command for command in commands))


if __name__ == "__main__":
    unittest.main()
