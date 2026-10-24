"""Verify every LF-normalised ``*_sha256`` sibling recorded in android-games JSON.

What is checked
---------------
Every JSON object under ``android-games`` (any depth; ``AMENDMENT-*.json`` are scanned but carry only
path-less manifest digests pointing into ``.artifacts``, so they yield no checked pairs) that has
a string ``path`` (or ``file``) member AND one or more members whose name contains ``sha256``
plus ``lf`` or ``normalized`` (``lf_sha256``, ``sha256_lf``, ``sha256_lf_normalized``,
``normalized_lf_sha256``, ``committed_lf_sha256``, ``tracked_LF_sha256``, ``parent_lf_sha256``,
``candidate_lf_sha256`` ...). Plain ``sha256`` / ``*_raw_*`` members are not checked: raw bytes
depend on the checkout's autocrlf state. Hashes with no ``path`` sibling (bundle / manifest /
tree digests such as ``executed_lf_source_bundle_sha256``) are out of scope.

Mapping rule
------------
The hash refers to the file named by the sibling ``path``/``file``:
  * a path starting ``android-games/`` is repo-relative;
  * any other relative path is relative to the game directory (first path component under
    ``android-games`` of the JSON file) -- the layout every checkpoint uses;
  * absolute paths and anything under ``.artifacts``/``.references`` are ignored (untracked).
The expected value is sha256 of the file bytes with CRLF replaced by LF, done in memory so the
result does not depend on how git checked the file out. Files containing a NUL byte are
treated as binary and hashed unchanged.

Historical receipts
-------------------
Checkpoint receipts record the source at the time they were written, and the source has moved
on since. A recorded hash therefore passes if it equals the LF hash of the current file OR of
any committed revision of that path (``git log -- path``, deleted files included). A hash that
matches no revision fails. In a shallow clone the history is unavailable: pairs that match
the current file (or whatever history exists) are still asserted, and only the pairs that need
missing history are left unverified; the test then skips AFTER its assertions, listing them.

What this cannot catch
----------------------
Any-revision matching proves only that the hash once described this path's content. It does not
prove the receipt cites the revision it claims to, so a receipt pointing at a stale (but real)
revision passes. It also cannot catch a hash that is the right file under the wrong path, a hash
that equals a different tracked file's content, or a CRLF-form hash under an LF key when that
file was never committed with CRLF content (such cases are listed in KNOWN_UNMATCHED instead).
"""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
GAMES = ROOT / "android-games"
# Untracked build output; never required to exist (see test_delivery_consistency.py).
ARTIFACT_DIRS = {".artifacts", ".references"}

# (json path relative to android-games, member, recorded path) -> reason. Findings only:
# a recorded hash that matches no revision of its file. Reported in the track checkpoint.
# The hashes are NOT re-recorded here; fixing the receipt makes the stale-exception test fail.
_CRLF_REASON = ("recorded hash is sha256 of the current file converted to CRLF, stored under "
                "an LF-named key (matches no LF revision)")
KNOWN_UNMATCHED = {
    ("delivery.json", "tracked_LF_sha256", "android-games/reviews/portfolio-final-fidelity-astra.md"):
        _CRLF_REASON,
    ("evidence/dead-run-code2-native-campaign.json", "tracked_LF_sha256",
     "android-games/reviews/dead-run-code2-native-platform-astra.md"): _CRLF_REASON,
    ("evidence/dead-run-code3-candidate.json", "tracked_LF_sha256",
     "android-games/reviews/dead-run-code3-native-candidate-astra.md"): _CRLF_REASON,
}


def lf_sha256_bytes_raw(raw: bytes) -> bytes:
    """Bytes with CRLF replaced by LF (binary files, i.e. containing NUL, unchanged)."""
    return raw if b"\0" in raw else raw.replace(b"\r\n", b"\n")


def lf_sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(lf_sha256_bytes_raw(raw)).hexdigest()


def is_lf_key(key: str) -> bool:
    low = key.lower()
    return "sha256" in low and ("lf" in low or "normalized" in low)


def _git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True)


def _nodes(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from _nodes(value)
    elif isinstance(node, list):
        for value in node:
            yield from _nodes(value)


def resolve(json_file: Path, recorded: str) -> str:
    """Repo-relative posix path the recorded ``path`` refers to, or '' if not applicable."""
    if recorded.startswith(("/", "\\")) or (len(recorded) > 1 and recorded[1] == ":"):
        return ""
    recorded = recorded.replace("\\", "/")
    if recorded.startswith("android-games/"):
        return recorded
    game = json_file.relative_to(GAMES).parts[0]
    return f"android-games/{game}/{recorded}"


def collect():
    """Yield (json_rel, member, recorded_path, repo_rel, expected_hash) for every sibling."""
    for json_file in sorted(GAMES.rglob("*.json")):
        if ARTIFACT_DIRS.intersection(json_file.relative_to(GAMES).parts):
            continue
        try:
            data = json.loads(json_file.read_text(encoding="utf-8-sig"))
        except ValueError:
            continue
        parts = json_file.relative_to(GAMES).parts
        json_rel = "/".join(parts)
        for node in _nodes(data):
            recorded = node.get("path", node.get("file"))
            if not isinstance(recorded, str):
                continue
            if ARTIFACT_DIRS.intersection(recorded.replace("\\", "/").split("/")):
                continue
            if len(parts) == 1 and not recorded.startswith("android-games/"):
                continue  # top-level files cite repo-relative paths only
            rel = resolve(json_file, recorded)
            if not rel:
                continue
            for key, value in node.items():
                if is_lf_key(key) and isinstance(value, str) and len(value) == 64:
                    yield json_rel, key, recorded, rel, value


def history_hashes(rel: str, cache={}) -> set:
    """LF hashes of every committed revision of ``rel`` (deleted revisions included)."""
    if rel not in cache:
        revs = _git("log", "--format=%H", "--", rel).stdout.decode().split()
        hashes = set()
        if revs:
            query = "".join(f"{rev}:{rel}\n" for rev in revs).encode()
            out = subprocess.run(["git", "-C", str(ROOT), "cat-file", "--batch"],
                                 input=query, capture_output=True).stdout
            pos = 0
            while pos < len(out):
                end = out.index(b"\n", pos)
                header = out[pos:end].split()
                pos = end + 1
                if len(header) == 3 and header[1] == b"blob":
                    size = int(header[2])
                    hashes.add(lf_sha256_bytes(out[pos:pos + size]))
                    pos += size + 1
        cache[rel] = hashes
    return cache[rel]


class LfSha256SiblingTests(unittest.TestCase):
    def test_siblings_are_discovered(self):
        entries = list(collect())
        self.assertGreater(len(entries), 250)

    def _unresolved(self):
        out = []
        for json_rel, key, recorded, rel, expected in collect():
            path = ROOT / rel
            if path.is_file() and lf_sha256_bytes(path.read_bytes()) == expected:
                continue
            out.append((json_rel, key, recorded, rel, expected))
        return out

    def test_every_lf_sha256_matches_current_or_committed_revision(self):
        shallow = _git("rev-parse", "--is-shallow-repository").stdout.strip() == b"true"
        bad, needs_history = [], []
        for json_rel, key, recorded, rel, expected in self._unresolved():
            if expected in history_hashes(rel):
                continue
            if (json_rel, key, recorded) in KNOWN_UNMATCHED:
                continue
            line = f"{json_rel}: {key}={expected[:12]} does not match any revision of {rel}"
            (needs_history if shallow else bad).append(line)
        self.assertEqual(bad, [])
        if needs_history:
            self.skipTest("shallow clone, history needed for: " + "; ".join(needs_history))

    def test_known_unmatched_entries_are_still_unmatched(self):
        """A KNOWN_UNMATCHED entry that now matches (or vanished) must be removed."""
        found = {(j, k, r): (rel, h) for j, k, r, rel, h in collect()}
        for entry in KNOWN_UNMATCHED:
            self.assertIn(entry, found, f"stale exception: {entry}")
            rel, recorded = found[entry]
            current = ROOT / rel
            if current.is_file():
                self.assertNotEqual(lf_sha256_bytes(current.read_bytes()), recorded,
                                    f"receipt now matches current file, remove: {entry}")
            self.assertNotIn(recorded, history_hashes(rel),
                             f"receipt now matches a committed revision, remove: {entry}")

    def test_known_unmatched_are_crlf_hash_under_lf_key(self):
        """The finding is explicit: each is sha256 of the current file's CRLF form."""
        for (json_rel, key, recorded), (rel, h) in (
                ((j, k, r), (rel, h)) for j, k, r, rel, h in collect()
                if (j, k, r) in KNOWN_UNMATCHED):
            lf = lf_sha256_bytes_raw((ROOT / rel).read_bytes())
            raw = lf.replace(b"\n", b"\r\n")
            self.assertEqual(hashlib.sha256(raw).hexdigest(), h, f"{json_rel} {recorded}")


if __name__ == "__main__":
    unittest.main()
