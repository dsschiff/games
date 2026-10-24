"""Cached headless Hearth local recovery checks; no editor, renderer or clipboard."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
PROJECT=Path(__file__).resolve().parents[1]
GODOT=Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():
    return {p.relative_to(PROJECT).as_posix():sha(p) for p in sorted(PROJECT.rglob("*")) if p.is_file() and p.name not in {"IMPORT_RECOVERY_CHECKPOINT.json","IMPORT_RECOVERY_AMENDMENT.md"} and not any(c.startswith(".") or c=="__pycache__" for c in p.relative_to(PROJECT).parts)}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suites",nargs="+",help="Existing test script basenames")
    parser.add_argument("--case", choices=["1-1","1-2","2-1","2-2"], help="One isolated transient Import direction")
    parser.add_argument("--part",choices=["matrix","edges","markers","layout"])
    parser.add_argument("--layout-index",type=int)
    args=parser.parse_args()
    if "import_uncertainty" in args.suites and not args.case: parser.error("Choose --case; each direction has fresh isolated data and no fixture deletion")
    if any("/" in n or "\\" in n or not (PROJECT/"tests"/(n+".gd")).is_file() for n in args.suites): parser.error("Use existing test script basenames")
    run=PROJECT/".artifacts"/("recovery-cpu-"+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")); run.mkdir(parents=True)
    before=sources(); report={"passed":False,"import_skipped":True,"source_before":before,"suites":[]}
    for name in args.suites:
        env=os.environ.copy()
        for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
            p=run/name/key.lower(); p.mkdir(parents=True); env[key]=str(p)
        command=[str(GODOT),"--headless","--audio-driver","Dummy","--fixed-fps","60","--path",str(PROJECT),"--script","res://tests/"+name+".gd","--","--capture-dir="+str(run)]
        if args.case: command += ["--case="+args.case]
        if args.part: command += ["--part="+args.part]
        if args.layout_index is not None: command += ["--layout-index="+str(args.layout_index)]
        with (run/(name+".log")).open("w",encoding="utf-8") as stream:
            try: code=subprocess.run(command,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240).returncode
            except subprocess.TimeoutExpired: code=124; stream.write("\nERROR: owned recovery test timeout\n")
        log=(run/(name+".log")).read_text(encoding="utf-8")
        errors=[line for line in log.splitlines() if any(s in line for s in ["ERROR:","SCRIPT ERROR:","WARNING:","ObjectDB instances leaked","Object was deleted while awaiting a callback","CrashHandlerException"])]
        passed=code==0 and "SUITE_COMPLETE: PASS" in log and not errors
        report["suites"].append({"suite":name,"command":command,"exit_code":code,"raw_errors":errors,"passed":passed})
        if not passed: break
    report["source_after"]=sources(); report["source_unchanged"]=before==report["source_after"]
    report["passed"]=report["source_unchanged"] and len(report["suites"])==len(args.suites) and all(r["passed"] for r in report["suites"])
    report["artifacts"]={p.name:sha(p) for p in sorted(run.iterdir()) if p.is_file()}
    (run/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"run":str(run),"passed":report["passed"],"suites":report["suites"]},indent=2)); return 0 if report["passed"] else 1
if __name__=="__main__": raise SystemExit(main())
