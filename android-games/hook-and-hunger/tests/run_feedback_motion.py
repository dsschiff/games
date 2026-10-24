"""Short Hook feedback capture; CPU default, renderer only with explicit --execute."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
from run_graphics import PROJECT, GODOT, sources, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--verbose',action='store_true')
    parser.add_argument('--force-defeat',action='store_true')
    parser.add_argument('--drain-audio',action='store_true')
    parser.add_argument('--suite',choices=['feedback_motion','charge_play','finale_readability'])
    parser.add_argument('--route',choices=['stage-09-start','stage-11-wave-5'])
    args = parser.parse_args()
    if args.suite in ('charge_play', 'finale_readability') and not args.route:
        parser.error('Earned continuation suites require --route')
    if args.route and args.suite == 'feedback_motion':
        parser.error('The opening fixture suite does not consume an earned route')
    run = PROJECT / '.artifacts' / ('feedback-motion-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ'))
    run.mkdir(parents=True)
    env = os.environ.copy()
    for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
        path = run / key.lower()
        path.mkdir()
        env[key] = str(path)
    checkpoint = None
    if args.route:
        index = json.loads((PROJECT/'evidence/campaign-checkpoint.json').read_text())
        relative = '.artifacts/campaign-code2-final/'+args.route+'.json'
        expected = next(x for x in index['artifacts'] if x['path']==relative)
        checkpoint = Path('C:/projects/active/_worktrees/games-hook-and-hunger-20261018/android-games/hook-and-hunger')/relative
        if sha(checkpoint) != expected['sha256']:
            raise RuntimeError('Historical earned checkpoint hash mismatch')
    frozen = sources()
    (run / 'source-before.json').write_text(json.dumps(frozen, indent=2)+'\n')
    command = [str(GODOT),'--audio-driver','Dummy','--fixed-fps','60','--path',str(PROJECT),'--resolution','720x1280','--position','0,0','--script','res://tests/'+((args.suite + '.gd') if args.suite else ('charge_play.gd' if args.route else 'feedback_motion.gd'))]
    if args.verbose:
        command += ['--verbose']
    if not args.execute:
        command += ['--headless']
    command += ['--','--capture-dir='+str(run)]
    if checkpoint:
        command += ['--checkpoint='+str(checkpoint)]
    if args.force_defeat:
        command += ['--force-defeat']
    if args.drain_audio:
        command += ['--drain-audio']
    if args.execute:
        command += ['--frames']
    with (run / 'execution.log').open('w',encoding='utf-8') as log:
        code = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120).returncode
    output = (run / 'execution.log').read_text(encoding='utf-8',errors='replace')
    errors = [line for line in output.splitlines() if any(x in line for x in ('ERROR:', 'SCRIPT ERROR:', 'Parse Error:', 'WARNING:'))]
    unchanged = sources() == frozen
    (run / 'source-after.json').write_text(json.dumps(sources(),indent=2)+'\n')
    passed = code == 0 and 'SUITE_COMPLETE: PASS' in output and not errors and unchanged
    report = {'command':command,'executed_renderer':args.execute,'exit_code':code,'errors_and_warnings':errors,'source_unchanged':unchanged,'passed':passed,'checkpoint':str(checkpoint) if checkpoint else None,'checkpoint_sha256':sha(checkpoint) if checkpoint else None}
    if args.execute:
        report['passed'] = False
        clip = run / 'feedback-1x.mp4'
        encode = ['ffmpeg','-hide_banner','-loglevel','error','-framerate','60','-i',str(run/'frames/%06d.png'),'-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-movflags','+faststart',str(clip)]
        with (run / 'encode.log').open('w') as log:
            report['encode_exit'] = subprocess.run(encode,stdout=log,stderr=subprocess.STDOUT).returncode
        if report['encode_exit'] == 0:
            with (run / 'decode.log').open('w') as log:
                report['decode_exit'] = subprocess.run(['ffmpeg','-v','error','-i',str(clip),'-f','null','-'],stdout=log,stderr=subprocess.STDOUT).returncode
            probe = subprocess.run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(clip)],capture_output=True,text=True,check=True)
            (run/'probe.json').write_text(probe.stdout)
            report['clip_sha256'] = sha(clip)
            report['clip_bytes'] = clip.stat().st_size
            frame_root = (run/'frames').resolve()
            if frame_root.parent != run.resolve():
                raise RuntimeError('Frame cleanup target escaped run')
            manifest = {p.name:sha(p) for p in sorted(frame_root.glob('*.png'))}
            (run/'frame-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n')
            if report['decode_exit'] == 0 and not (run/'decode.log').read_text().strip():
                for p in frame_root.glob('*.png'):
                    if p.resolve().parent != frame_root:
                        raise RuntimeError('Frame path escaped cleanup directory')
                    p.unlink()
                frame_root.rmdir()
                report['disposable_frame_sequence_removed'] = True
            report['passed'] = passed and report['decode_exit'] == 0 and not (run/'decode.log').read_text().strip()
    report['artifacts'] = {p.name:{'sha256':sha(p),'bytes':p.stat().st_size} for p in run.iterdir() if p.is_file()}
    (run/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'run':str(run),**report},indent=2))
    return 0 if report['passed'] else 1

if __name__ == '__main__':
    raise SystemExit(main())

