"""Fresh isolated headless GUI touch audit; no renderer/import/OS clipboard."""
from pathlib import Path
from datetime import datetime, timezone
import argparse,hashlib,json,os,subprocess
P=Path(__file__).resolve().parents[1]
def pins():return {f.relative_to(P).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(P.rglob("*")) if f.is_file() and f.name not in {"TOUCH_SCROLL.md", "TOUCH_SCROLL_CHECKPOINT.json"} and not any(x.startswith(".") or x=="__pycache__" for x in f.relative_to(P).parts)}
def main():
 parser=argparse.ArgumentParser();parser.add_argument("--baseline",action="store_true");args=parser.parse_args();run=P/".artifacts"/("touch-scroll-"+("baseline-" if args.baseline else "current-")+datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"));run.mkdir(parents=True)
 env=os.environ.copy()
 for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
  d=run/key.lower();d.mkdir(parents=True);env[key]=str(d)
 command=["C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe","--headless","--audio-driver","Dummy","--fixed-fps","60","--path",str(P),"--script","res://tests/touch_scroll.gd","--","--capture-dir="+str(run)]+(["--baseline"] if args.baseline else [])
 before=pins();(run/"source-before.json").write_text(json.dumps(before,indent=2),encoding="utf-8")
 with (run/"godot.log").open("w",encoding="utf-8") as log:
  try:code=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90).returncode
  except subprocess.TimeoutExpired:code=124
 after=pins();(run/"source-after.json").write_text(json.dumps(after,indent=2),encoding="utf-8");text=(run/"godot.log").read_text(encoding="utf-8",errors="replace");errors=[line for line in text.splitlines() if any(x in line for x in ["ERROR:","WARNING:","ObjectDB"])];r={"command":command,"exit_code":code,"errors":errors,"source_unchanged":before==after,"passed":code==0 and not errors and before==after and "SUITE_COMPLETE: PASS" in text};(run/"receipt.json").write_text(json.dumps(r,indent=2),encoding="utf-8");print(run);print(json.dumps(r,indent=2));print(text[-2000:]);raise SystemExit(0 if r["passed"] else 1)
if __name__=="__main__":main()
