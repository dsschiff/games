"""Consistency checks across delivery.json, graphics-overhaul.json and the evidence files they cite.

Evidence-path rule: a repo-relative path string (starting with ``android-games/``) must be
tracked by git. Neither JSON file has an explicit artifact-only marker, so by convention
(AGENTS.md: build/evidence outputs live in ignored ``.artifacts/``) paths under ``.artifacts/``
or ``.references/`` and absolute paths (``C:/...``) are artifact-only and are not required in git.
The tests never require ``.artifacts`` to exist.
"""
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
DELIVERY = ROOT / "android-games/delivery.json"
GRAPHICS = ROOT / "android-games/graphics-overhaul.json"

ARTIFACT_PREFIXES = (".artifacts/", ".references/")
TRACKED_PREFIX = "android-games/"

# Known exceptions on main. Each entry is a finding reported in the track checkpoint; keep
# this empty unless a real inconsistency is found, and comment every entry.
KNOWN_MISSING_EVIDENCE = set()
KNOWN_NON_MONOTONIC = set()

# graphics-overhaul.json checkpoint key -> delivery.json slug (keys are not slugs).
CHECKPOINT_SLUGS = {
    "gear_fit_checkpoint": "gear-bastion",
    "frontline_pooling_checkpoint": "frontline-foundry",
    "hook_graphics_checkpoint": "hook-and-hunger",
    "dead_run_graphics_checkpoint": "dead-run",
}


def _load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def _walk(node, where=""):
    if isinstance(node, dict):
        for key, value in node.items():
            yield from _walk(value, f"{where}.{key}" if where else key)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from _walk(value, f"{where}[{index}]")
    elif isinstance(node, str):
        yield where, node


def _classify(value):
    """Return 'tracked', 'artifact' or None (not a path) for a string value."""
    text = value.replace("\\", "/")
    if re.match(r"^[A-Za-z]:/", text) or text.startswith(ARTIFACT_PREFIXES):
        return "artifact"
    if text.startswith(TRACKED_PREFIX) and " " not in text:
        return "tracked"
    return None


def _git_tracked():
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True
    ).stdout.decode("utf-8")
    return set(filter(None, out.split("\0")))


def _version_key(text):
    return tuple(int(part) for part in text.split("."))


class ToolingGateConsistencyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.delivery = _load(DELIVERY)
        cls.graphics = _load(GRAPHICS)
        cls.tracked = _git_tracked()

    def test_both_json_files_load(self):
        self.assertIsInstance(self.delivery, dict)
        self.assertIsInstance(self.graphics, dict)
        self.assertEqual(self.delivery["schema_version"], 1)
        self.assertEqual(self.graphics["schema_version"], 1)

    def test_tracked_evidence_paths_exist_in_git(self):
        missing = []
        checked = 0
        for label, data in (("delivery", self.delivery), ("graphics", self.graphics)):
            for where, value in _walk(data):
                if _classify(value) != "tracked":
                    continue
                checked += 1
                path = value.replace("\\", "/")
                if path not in self.tracked and (label, where, path) not in KNOWN_MISSING_EVIDENCE:
                    missing.append(f"{label}:{where} -> {path}")
        self.assertGreater(checked, 10, "path walker found suspiciously few evidence paths")
        self.assertEqual(missing, [], "evidence paths not in git ls-files")

    def test_artifact_only_paths_are_not_required_in_git(self):
        # Documents the convention: these are allowed to be absent from git and from disk.
        kinds = {
            _classify(v)
            for data in (self.delivery, self.graphics)
            for _, v in _walk(data)
        }
        self.assertIn("artifact", kinds)

    def _checkpoints(self):
        """Yield (slug, label, version, code) from graphics-overhaul.json checkpoints."""
        for key, block in self.graphics.items():
            if isinstance(block, dict) and "version" in block and "version_code" in block:
                slug = CHECKPOINT_SLUGS.get(key)
                self.assertIsNotNone(slug, f"unmapped checkpoint {key}; add it to CHECKPOINT_SLUGS")
                yield slug, key, block["version"], block["version_code"]

    def test_delivery_versions_monotonic_per_game(self):
        problems = []
        slugs = set()
        for game in self.delivery["games"]:
            slug = game["slug"]
            self.assertNotIn(slug, slugs, "duplicate slug")
            slugs.add(slug)
            self.assertIsInstance(game["version_code"], int)
            base = game.get("historical_baseline")
            if base:
                if not _version_key(base["version"]) < _version_key(game["version"]):
                    problems.append(f"{slug}: baseline version {base['version']} !< {game['version']}")
                if not base["version_code"] < game["version_code"]:
                    problems.append(f"{slug}: baseline code {base['version_code']} !< {game['version_code']}")
            installed = game.get("emulator_installed_version_code")
            if installed is not None and installed > game["version_code"]:
                problems.append(f"{slug}: emulator code {installed} > delivered {game['version_code']}")
        problems = [p for p in problems if p not in KNOWN_NON_MONOTONIC]
        self.assertEqual(problems, [])

    def test_graphics_checkpoints_never_older_than_delivery(self):
        delivered = {g["slug"]: g for g in self.delivery["games"]}
        problems = []
        seen = 0
        for slug, key, version, code in self._checkpoints():
            game = delivered.get(slug)
            self.assertIsNotNone(game, f"{key} names unknown game {slug}")
            seen += 1
            if _version_key(version) < _version_key(game["version"]):
                problems.append(f"{key}: version {version} < delivery {game['version']}")
            if code < game["version_code"]:
                problems.append(f"{key}: code {code} < delivery {game['version_code']}")
            # version and code must move together
            if (_version_key(version) > _version_key(game["version"])) != (code > game["version_code"]):
                problems.append(f"{key}: version/code disagree on direction vs delivery")
        self.assertGreater(seen, 0)
        problems = [p for p in problems if p not in KNOWN_NON_MONOTONIC]
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
