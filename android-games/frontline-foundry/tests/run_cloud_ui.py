"""CPU optional cloud UI regression; no GPU, native, network, or clipboard."""
from __future__ import annotations
import datetime,hashlib,json,os,subprocess
from pathlib import Path
PROJECT=Path(__file__).resolve().parents[1]
GODOT=Path('C:/projects/active/.game-toolchain/godot/4.7.2/Godot_v4.7.2-stable_win64.exe')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():
    paths=[p for name in ('scripts','tests') for p in (PROJECT/name).rglob('*') if p.suffix in {'.gd','.py','.uid'}]
    paths += [PROJECT/name for name in ('boot.tscn','project.godot','export_presets.cfg')]
    return {p.relative_to(PROJECT).as_posix():sha(p) for p in paths}
def main():
    folder=PROJECT/'.artifacts'/('cloud-ui-cpu-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    folder.mkdir(parents=True)
    env=os.environ.copy()
    for name in ('APPDATA','LOCALAPPDATA'):
        env[name]=str(folder/name); Path(env[name]).mkdir()
    command=[str(GODOT),'--headless','--audio-driver','Dummy','--path',str(PROJECT),'--script','res://tests/cloud_ui.gd','--','--report-dir='+str(folder)]
    before=sources(); code=124
    with (folder/'godot.log').open('w',encoding='utf-8') as log:
        try: code=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=180).returncode
        except subprocess.TimeoutExpired: log.write('\nERROR: CPU test exceeded180seconds\n')
    output=(folder/'godot.log').read_text(encoding='utf-8')
    path=folder/'cloud-ui.json'; report=json.loads(path.read_text()) if path.exists() else None
    after=sources(); runtime_errors=any(word in output for word in ('SCRIPT ERROR','ERROR:','WARNING:','ObjectDB instances leaked'))
    okay=code==0 and report is not None and not report['failures'] and not runtime_errors and before==after
    record={'passed':okay,'command':command,'exit_code':code,'source_before':before,'source_after':after,'report':report,'runtime_errors':runtime_errors,'files':{p.relative_to(folder).as_posix():sha(p) for p in folder.rglob('*') if p.is_file()},'limits':'Headless/Dummy; synthetic full contexts, fake faults, actual touch; materialized-file fresh bootstrap, not OS kill/native/render proof.'}
    (folder/'receipt.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps({'passed':okay,'folder':str(folder),'checks':report['checks'] if report else None,'failures':report['failures'] if report else [],'log':output[-8000:] if not okay else 'clean'},indent=2))
    raise SystemExit(0 if okay else 1)
if __name__=='__main__': main()
