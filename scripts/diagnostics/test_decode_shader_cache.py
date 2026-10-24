"""Transport acceptance tests; synthetic frames are not native shader evidence."""
import base64
import hashlib
import json
import unittest

from decode_shader_cache import CHUNK_BYTES, MAX_MESSAGE_BYTES, MAX_PAYLOAD_BYTES, PREFIX, TRANSPORT_SCHEMA, decode


def frames(payload, record_id="0", pid=123):
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    chunks = [raw[i:i + CHUNK_BYTES] for i in range(0, len(raw), CHUNK_BYTES)]
    return [f"10-24 18:00:00.000 {pid} 456 I godot : " + PREFIX + json.dumps({
        "schema": TRANSPORT_SCHEMA, "record_id": record_id, "payload_bytes": len(raw),
        "payload_sha256": hashlib.sha256(raw).hexdigest(), "chunk_index": i,
        "chunk_count": len(chunks), "encoding": "base64",
        "chunk_base64": base64.b64encode(chunk).decode("ascii"),
    }, separators=(",", ":")) for i, chunk in enumerate(chunks)]


class DecodeTests(unittest.TestCase):
    def setUp(self):
        self.payload = {"schema": 1, "event": "load", "shader": "SceneShaderGLES3", "info_log": "shader: \u03b1\U0001f534\n\"\\" * 9000}
        self.lines = frames(self.payload)

    def test_unicode_boundary_and_large_log_roundtrip(self):
        result = decode("unrelated engine warning\n" + "\n".join(self.lines), expected_pid=123)
        self.assertEqual(result["records"][0]["observation"], self.payload)
        self.assertGreater(result["frames"], 2)
        self.assertTrue(all(len(line.split(PREFIX)[1]) + len(PREFIX) <= MAX_MESSAGE_BYTES for line in self.lines))

    def test_android_observed_print_budget_with_max_record_id(self):
        payload = {"schema": 1, "event": "load", "info_log": ""}
        overhead = len(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        payload["info_log"] = "a" * (MAX_PAYLOAD_BYTES - overhead)
        lines = frames(payload, record_id="18446744073709551615")
        messages = [line.split(" I godot : ", 1)[1] for line in lines]
        self.assertTrue(all(len(message.encode("ascii")) <= MAX_MESSAGE_BYTES < 1023 for message in messages))
        self.assertTrue(all(message[:1023] == message for message in messages))

    def test_transport_epoch_one_rejected(self):
        line = frames({"schema": 1, "event": "load"})[0]
        header, framed = line.split(PREFIX, 1)
        value = json.loads(framed)
        value["schema"] = 1
        with self.assertRaisesRegex(ValueError, "unsupported frame protocol"):
            decode(header + PREFIX + json.dumps(value), expected_pid=123)

    def test_observed_1023_byte_truncation_rejected(self):
        raw = b"a" * 1536
        frame = {"schema": 1, "record_id": "0", "payload_bytes": len(raw), "payload_sha256": hashlib.sha256(raw).hexdigest(), "chunk_index": 0, "chunk_count": 1, "encoding": "base64", "chunk_base64": base64.b64encode(raw).decode("ascii")}
        truncated = (PREFIX + json.dumps(frame, separators=(",", ":")))[:1023]
        with self.assertRaisesRegex(ValueError, "Android message framing"):
            decode("10-24 18:00:00.000 123 456 I godot : " + truncated, expected_pid=123)

    def test_oversized_message_rejected(self):
        with self.assertRaisesRegex(ValueError, "Android message framing"):
            decode("10-24 18:00:00.000 123 456 I godot : " + PREFIX + " " * MAX_MESSAGE_BYTES, expected_pid=123)

    def test_out_of_order_chunks_preserve_payload(self):
        self.assertEqual(decode("\n".join(reversed(self.lines)), expected_pid=123)["records"][0]["observation"], self.payload)

    def test_missing_chunk_rejected(self):
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            decode("\n".join(self.lines[1:]), expected_pid=123)

    def test_truncated_json_rejected(self):
        with self.assertRaisesRegex(ValueError, "malformed or truncated"):
            decode("\n".join([self.lines[0][:-4], *self.lines[1:]]), expected_pid=123)

    def test_valid_base64_payload_corruption_rejected(self):
        frame = json.loads(self.lines[0].split(PREFIX)[1])
        chunk = bytearray(base64.b64decode(frame["chunk_base64"])); chunk[12] ^= 1
        frame["chunk_base64"] = base64.b64encode(chunk).decode("ascii")
        corrupt = self.lines[0].split(PREFIX)[0] + PREFIX + json.dumps(frame)
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            decode("\n".join([corrupt, *self.lines[1:]]), expected_pid=123)

    def test_duplicate_chunk_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate chunk"):
            decode("\n".join([*self.lines, self.lines[0]]), expected_pid=123)

    def test_wrong_pid_rejected(self):
        with self.assertRaisesRegex(ValueError, "PID/header mismatch"):
            decode("\n".join(self.lines), expected_pid=999)

    def test_missing_whole_record_rejected(self):
        valid = frames({"schema": 1, "event": "save"})
        gap = frames({"schema": 1, "event": "save"}, record_id="2")
        with self.assertRaisesRegex(ValueError, "Missing whole record"):
            decode("\n".join(valid + gap), expected_pid=123)

    def test_no_frames_rejected(self):
        with self.assertRaisesRegex(ValueError, "No shader diagnostic"):
            decode("ordinary engine output", expected_pid=123)


if __name__ == "__main__":
    unittest.main()
