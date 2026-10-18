"""Inventory actual source-bound movie model observations, never approve art."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path

from production_sources import PROJECT, PLAN, sha

ROLES = {"commander", "citizen", "defender", "raider", "runner", "armor", "swarm", "mender", "shade", "ram", "matriarch", "regent"}


def inventory(runs):
    stages = set()
    regions = set()
    merged = {role: {"live_active_frames": 0, "longest_single_actor_live_frames": 0, "runs": []} for role in ROLES}
    sources = []
    for run in runs:
        run = run.resolve()
        assert run.is_relative_to((PROJECT / ".artifacts").resolve())
        receipt = json.loads((run / "receipt.json").read_text())
        report = json.loads((run / "production-report.json").read_text())
        assert receipt["passed"] and receipt["source_unchanged"] and receipt["media"]["pixel_and_frame_count_match"] and not report["failures"]
        assert any(row["path"] == "production-report.json" and row["sha256"] == sha(run / "production-report.json") for row in receipt["artifacts"])
        assert sha(run / "continuous.mp4") == receipt["media"]["sha256"]
        stage = report["stage"]
        stages.add(stage)
        current = {}
        last_frame = -2
        longest = {role: 0 for role in ROLES}
        for frame in report["coverage"]["frames"]:
            active = frame["phase"] == "playing" and not frame["paused"]
            if active:
                regions.add(frame["region"])
            next_counts = {}
            for role, observation in frame["models"].items():
                if not active:
                    continue
                merged[role]["live_active_frames"] += int(bool(observation["live_ids"]))
                for actor in observation["live_ids"]:
                    key = (role, actor)
                    count = current.get(key, 0) + 1 if frame["frame"] == last_frame + 1 else 1
                    next_counts[key] = count
                    longest[role] = max(longest[role], count)
            current = next_counts
            last_frame = frame["frame"]
        for role in ROLES:
            merged[role]["longest_single_actor_live_frames"] = max(merged[role]["longest_single_actor_live_frames"], longest[role])
            if longest[role]:
                merged[role]["runs"].append({"run": str(run), "stage": stage, "max_contiguous_frames": longest[role], "seconds_at_fixed30": longest[role] / 30})
        sources.append({"run": str(run), "stage": stage, "receipt_sha256": sha(run / "receipt.json"), "movie_sha256": receipt["media"]["sha256"], "runtime_freeze": receipt["runtime_freeze"]})
    return {"schema": 1, "sources": sources, "stages": sorted(stages), "roles": merged, "active_regions": sorted(regions),
            "primary_stages_missing": sorted({"opening", "heavy", "later"} - stages),
            "roles_not_observed_alive": sorted(role for role in ROLES if merged[role]["live_active_frames"] == 0),
            "roles_below_half_second_single_actor": sorted(role for role in ROLES if merged[role]["longest_single_actor_live_frames"] < 15),
            "regions_missing_active": sorted({0, 1, 2} - regions),
            "limits": "Projected model observations and contiguous live-ID exposure, not actual visible-pixel/motion quality or independent visual acceptance. Half-second threshold only flags review gaps. A reviewer may require more. Queue only concrete bounded earned-encounter gaps; never rerun an unchanged complete campaign."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = inventory(args.runs)
    output = args.output or PROJECT / ".artifacts" / ("production-coverage-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".json")
    assert output.resolve().is_relative_to((PROJECT / ".artifacts").resolve())
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(output), "primary_stages_missing": result["primary_stages_missing"], "roles_not_observed_alive": result["roles_not_observed_alive"], "roles_below_half_second_single_actor": result["roles_below_half_second_single_actor"], "regions_missing_active": result["regions_missing_active"]}, indent=2))


if __name__ == "__main__":
    main()
