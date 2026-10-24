"""Decode complete shader diagnostic records from one PID/launch log; fail closed."""
from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
from pathlib import Path
import re

PREFIX = "GAMES_SHADER_CACHE_DIAGNOSTIC "
CHUNK_BYTES = 1536
MAX_PAYLOAD_BYTES = 2 * 1024 * 1024
FIELDS = {"schema", "record_id", "payload_bytes", "payload_sha256", "chunk_index", "chunk_count", "encoding", "chunk_base64"}


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def _json(text):
    def reject(value):
        raise ValueError("Non-finite JSON value: " + value)
    return json.loads(text, object_pairs_hook=_unique_object, parse_constant=reject)


def decode(text, expected_pid=None):
    records = {}
    frames_seen = 0
    for line_number, line in enumerate(text.splitlines(), 1):
        if PREFIX not in line:
            continue
        before, framed = line.split(PREFIX, 1)
        if expected_pid is not None:
            header = re.match(r"^\s*(?:\d{4}-)?\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+\d+\s+[VDIWEFA]\s+[^:]*:\s*$", before)
            if not header or int(header.group(1)) != expected_pid:
                raise ValueError(f"Line {line_number}: diagnostic PID/header mismatch")
        if not framed.isascii() or len((PREFIX + framed).encode("ascii")) > 3072:
            raise ValueError(f"Line {line_number}: invalid Android message framing")
        try:
            frame = _json(framed)
        except (ValueError, TypeError) as error:
            raise ValueError(f"Line {line_number}: malformed or truncated frame") from error
        if not isinstance(frame, dict) or set(frame) != FIELDS:
            raise ValueError(f"Line {line_number}: unexpected frame fields")
        if type(frame["schema"]) is not int or frame["schema"] != 1 or frame["encoding"] != "base64":
            raise ValueError(f"Line {line_number}: unsupported frame protocol")
        record_id = frame["record_id"]
        if not isinstance(record_id, str) or not re.fullmatch(r"0|[1-9][0-9]{0,19}", record_id) or int(record_id) > 2**64 - 1:
            raise ValueError(f"Line {line_number}: invalid record ID")
        size, count, index = (frame[k] for k in ("payload_bytes", "chunk_count", "chunk_index"))
        if any(type(value) is not int for value in (size, count, index)):
            raise ValueError(f"Line {line_number}: non-integer frame sizes")
        if not 0 < size <= MAX_PAYLOAD_BYTES or count != (size + CHUNK_BYTES - 1) // CHUNK_BYTES or not 0 <= index < count:
            raise ValueError(f"Line {line_number}: invalid frame sizes")
        digest = frame["payload_sha256"]
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"Line {line_number}: invalid payload digest")
        try:
            chunk = base64.b64decode(frame["chunk_base64"], validate=True)
        except (ValueError, TypeError, binascii.Error) as error:
            raise ValueError(f"Line {line_number}: invalid base64") from error
        if base64.b64encode(chunk).decode("ascii") != frame["chunk_base64"]:
            raise ValueError(f"Line {line_number}: noncanonical base64")
        if len(chunk) != min(CHUNK_BYTES, size - index * CHUNK_BYTES):
            raise ValueError(f"Line {line_number}: truncated chunk")
        identity = (size, count, digest)
        record = records.setdefault(record_id, {"identity": identity, "chunks": {}, "first_line": line_number})
        if record["identity"] != identity:
            raise ValueError(f"Line {line_number}: conflicting record identity")
        if index in record["chunks"]:
            raise ValueError(f"Line {line_number}: duplicate chunk")
        record["chunks"][index] = chunk
        frames_seen += 1
    if not records:
        raise ValueError("No shader diagnostic frames observed")
    if sorted(int(record_id) for record_id in records) != list(range(len(records))):
        raise ValueError("Missing whole record or collection did not start at record zero")
    decoded = []
    for record_id, record in records.items():
        size, count, digest = record["identity"]
        if set(record["chunks"]) != set(range(count)):
            raise ValueError("Incomplete record: " + record_id)
        raw = b"".join(record["chunks"][i] for i in range(count))
        if len(raw) != size or hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Payload length/hash mismatch: " + record_id)
        try:
            observation = _json(raw.decode("utf-8"))
        except (ValueError, UnicodeError) as error:
            raise ValueError("Invalid UTF-8/JSON payload: " + record_id) from error
        if not isinstance(observation, dict) or type(observation.get("schema")) is not int or observation.get("schema") != 1 or observation.get("event") not in ("load", "size_query", "save"):
            raise ValueError("Invalid observation schema: " + record_id)
        decoded.append({"record_id": record_id, "first_line": record["first_line"], "payload_bytes": size, "payload_sha256": digest, "chunks": count, "observation": observation})
    return {"schema": 1, "frames": frames_seen, "records": decoded}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--pid", required=True, type=int, help="Expected PID in threadtime logcat captured for one launch")
    args = parser.parse_args()
    if args.pid <= 0:
        parser.error("--pid must be positive")
    raw = args.log.read_bytes()
    try:
        result = decode(raw.decode("utf-8"), expected_pid=args.pid)
    except (ValueError, UnicodeError) as error:
        parser.exit(1, str(error) + "\n")
    result["expected_pid"] = args.pid
    result["raw_log"] = {"path": str(args.log.resolve()), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
    # An existing observation file must survive a mistaken repeated invocation.
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps({"output": str(args.output), "records": len(result["records"]), "frames": result["frames"]}))


if __name__ == "__main__":
    main()
