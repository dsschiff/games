"""Bounded Journey GUI regression; headless/Dummy only."""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, os, subprocess
P=Path(__file__).resolve().parents[1]
G="C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
N=Path("F:/games-workspaces/hearth-preview-capture-20261024/.artifacts/native-first-pair-20261024/frontline/journey-top")
def source():
 return {f.relative_to(P).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(P.rglob("*")) if f.is_file() and not any(x.startswith(".") or x=="__pycache__" for x in f.relative_to(P).parts)}
def main():
 parser=argparse.ArgumentParser();parser.add_argument("--baseline",action="store_true");args=parser.parse_args()
 run=P/".artifacts"/("journey-touch-"+("baseline-" if args.baseline else "current-")+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"));run.mkdir(parents=True)
 env=os.environ.copy()
 for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
  d=run/key.lower();d.mkdir();env[key]=str(d)
 command=[G,"--headless","--audio-driver","Dummy","--fixed-fps","60","--path",str(P),"--script","res://tests/journey_touch.gd","--","--capture-dir="+str(run),"--native-dir="+str(N)]+(["--baseline"] if args.baseline else [])
 before=source();(run/"source-before.json").write_text(json.dumps(before,indent=2),encoding="utf-8")
 with (run/"godot.log").open("w",encoding="utf-8") as log:
  try:code=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90).returncode
  except subprocess.TimeoutExpired:code=124
 after=source();(run/"source-after.json").write_text(json.dumps(after,indent=2),encoding="utf-8");text=(run/"godot.log").read_text(encoding="utf-8",errors="replace");errors=[line for line in text.splitlines() if any(x in line for x in ["ERROR:","WARNING:","ObjectDB"])]
 report={"command":command,"exit_code":code,"source_unchanged":before==after,"errors":errors,"passed":code==0 and not errors and before==after and "SUITE_COMPLETE: PASS" in text}
 (run/"receipt.json").write_text(json.dumps(report,indent=2),encoding="utf-8");print(run);print(json.dumps(report,indent=2));print(text[-1800:]);raise SystemExit(0 if report["passed"] else 1)
if __name__=="__main__":main()
