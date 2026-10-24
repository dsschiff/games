"""CPU-only, bounded, source-bound recovery adapter regression receipt."""
from __future__ import annotations
import hashlib,json,subprocess,datetime,os
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
ROOT=PROJECT.parents[1]
GODOT=Path("C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64.exe")
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def sources():
    paths=[p for root in (PROJECT/"scripts",PROJECT/"tests") for p in root.rglob("*.gd")]
    paths += [PROJECT/"project.godot",PROJECT/"export_presets.cfg",PROJECT/"boot.tscn",PROJECT/"scripts/cloud/vendor-source.json",Path(__file__).resolve(),ROOT/"android-games/shared/play-cloud/cloud_backup.gd"]
    return {p.relative_to(ROOT).as_posix():digest(p) for p in paths}
def main():
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder=PROJECT/".artifacts"/("cloud-cpu-"+stamp); folder.mkdir(parents=True)
    before=sources()
    env=os.environ.copy()
    for name in ("APPDATA","LOCALAPPDATA"):
        env[name]=str(folder/name); Path(env[name]).mkdir()
    command=[str(GODOT),"--headless","--audio-driver","Dummy","--path",str(PROJECT),"--script","res://tests/cloud_recovery.gd","--","--report-dir="+str(folder)]
    try:
        result=subprocess.run(command,env=env,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=45)
    except subprocess.TimeoutExpired as error:
        result=subprocess.CompletedProcess(command,124,(error.stdout or b"").decode("utf-8",errors="replace"),(error.stderr or b"").decode("utf-8",errors="replace")+"\nERROR: test exceeded 45 seconds")
    (folder/"godot.log").write_text(result.stdout+result.stderr,encoding="utf-8")
    report_path=folder/"cloud-recovery.json"
    report=json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else None
    after=sources()
    errors=any(word in (result.stdout+result.stderr) for word in ("SCRIPT ERROR","ERROR:","WARNING:","ObjectDB instances leaked"))
    vendor=PROJECT/"scripts/cloud/codec.gd"
    shared=ROOT/"android-games/shared/play-cloud/cloud_backup.gd"
    pin=json.loads((PROJECT/"scripts/cloud/vendor-source.json").read_text(encoding="utf-8"))
    passed=digest(vendor)==pin["sha256"] and vendor.read_bytes()==shared.read_bytes() and result.returncode==0 and report is not None and not report["failures"] and not errors and before==after
    receipt={"passed":passed,"command":command,"exit_code":result.returncode,"report":report,"runtime_errors":errors,"source_before":before,"source_after":after,"outputs":{p.name:digest(p) for p in folder.iterdir() if p.is_file()},"limits":"No production scene linkage. Fake port only, no native auth/cloud or rendered/export validation."}
    (folder/"receipt.json").write_text(json.dumps(receipt,indent=2),encoding="utf-8")
    print(json.dumps({"passed":passed,"folder":str(folder),"checks":report["checks"] if report else None,"failures":report["failures"] if report else [],"log":result.stdout+result.stderr if not passed else "clean"},indent=2))
    raise SystemExit(0 if passed else 1)
if __name__=="__main__": main()
