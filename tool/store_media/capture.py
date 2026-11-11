"""Runs integration_test/store_media_test.dart on an iOS simulator or on this
Mac and takes the screenshots and recordings it asks for, through its @@
markers.

    python3 tool/store_media/capture.py <simulator udid> <iphone|ipad> [scene]
    python3 tool/store_media/capture.py mac [scene]
    python3 tool/store_media/capture.py android

On a simulator the status bar is set to Apple's 9:41, full battery and full
signal while the test runs, and cleared at the end.

On "mac" the test runs on this Mac and draws the app off screen, at the size
and scale of a Retina window; the screenshots come back through the log, as
@@DATA lines of base64, and land in build/store_media/mac/raw/. The previews'
frames are saved in the app's sandbox container, and moved from there to
build/store_media/mac/frames/<recording>/.

"android" does the same for the Google Play screenshots: the test runs on this
Mac as if it were Android, on a 1080 × 2400 phone, and the screenshots land in
build/store_media/android/raw/.

Writes to build/store_media/<iphone|ipad>/: raw/ (plain screenshots), masked/
(with the device's rounded corners and notch, for the framed versions),
video/ (the recordings) and marks.json (when each recording's content begins
and ends, in seconds from the start of the file). Then run compose.py.
"""

import base64
import json
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
MARKER = re.compile(r'@@(\w+)(?: (\S+))?(?: (\S+))? t=(\d+)')

# The simulator service may not be allowed to write to external volumes, so
# files are saved here first and then moved to the output folder.
STAGING = pathlib.Path(tempfile.mkdtemp(prefix='store_media_'))


class Recording:
    """simctl recordVideo, noting when the file's first frame was taken."""

    def __init__(self, udid, path):
        self.path = path
        self.started = None
        self.process = subprocess.Popen(
            ['xcrun', 'simctl', 'io', udid, 'recordVideo', '--codec=h264',
             '--force', str(STAGING / path.name)],
            stderr=subprocess.PIPE, text=True)
        threading.Thread(target=self._watch, daemon=True).start()

    def _watch(self):
        for line in self.process.stderr:
            if 'Recording started' in line and self.started is None:
                self.started = time.time()

    def stop(self):
        self.process.send_signal(signal.SIGINT)
        self.process.wait()
        # The simulator service finishes writing the file after simctl exits.
        staged = STAGING / self.path.name
        size = -1
        while size <= 0 or staged.stat().st_size != size:
            size = staged.stat().st_size if staged.exists() else -1
            time.sleep(1)
        shutil.move(staged, self.path)


def capture_mac(scene, key='mac'):
    """Screenshots drawn off screen on this Mac: the desktop app ("mac") or
    the phone app as Android ("android")."""
    out = ROOT / 'build' / 'store_media' / key / 'raw'
    out.mkdir(parents=True, exist_ok=True)
    frames = ROOT / 'build' / 'store_media' / key / 'frames'
    marks_path = out.parent / 'marks.json'
    marks = json.loads(marks_path.read_text()) if marks_path.exists() else {}
    command = ['flutter', 'test', 'integration_test/store_media_test.dart',
               '-d', 'macos', f'--dart-define={key.upper()}=true',
               f'--dart-define=SCENE={scene}']
    test = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, bufsize=1)
    data = {}
    for line in test.stdout:
        match = MARKER.search(line)
        if not match:
            sys.stdout.write(line)
            continue
        kind, name, payload = match.group(1, 2, 3)
        if kind == 'DATA':
            data.setdefault(name, []).append(payload)
        elif kind == 'SHOT':
            (out / f'{name}.png').write_bytes(
                base64.b64decode(''.join(data.pop(name))))
            print(f'[capture] {name}')
        elif kind == 'REC_START':
            recording = name
            marks[recording] = {}
        elif kind in ('BEGIN', 'END'):
            # Absolute, in seconds: the frames are named after the time they
            # were taken.
            marks[recording][kind.lower()] = int(match.group(4)) / 1000
        elif kind == 'FRAMES':
            target = frames / name
            shutil.rmtree(target, ignore_errors=True)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(payload, target)
            print(f'[capture] {name}: '
                  f'{len(list(target.glob("*.png")))} frames')
    test.wait()
    marks_path.write_text(json.dumps(marks, indent=2))
    sys.exit(test.returncode)


def main():
    if sys.argv[1] == 'mac':
        capture_mac(sys.argv[2] if len(sys.argv) > 2 else '')
    if sys.argv[1] == 'android':
        capture_mac('screenshots', 'android')
    udid, device = sys.argv[1:3]
    scene = sys.argv[3] if len(sys.argv) > 3 else ''
    out = ROOT / 'build' / 'store_media' / device
    for folder in ('raw', 'masked', 'video'):
        (out / folder).mkdir(parents=True, exist_ok=True)
    marks_path = out / 'marks.json'
    marks = json.loads(marks_path.read_text()) if marks_path.exists() else {}

    command = ['flutter', 'test', 'integration_test/store_media_test.dart',
               '-d', udid, f'--dart-define=SCENE={scene}']
    subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'],
                   check=True, capture_output=True)
    subprocess.run(['xcrun', 'simctl', 'status_bar', udid, 'override',
                    '--time', '9:41', '--dataNetwork', 'wifi',
                    '--wifiMode', 'active', '--wifiBars', '3',
                    '--cellularMode', 'active', '--cellularBars', '4',
                    '--batteryState', 'charged', '--batteryLevel', '100'],
                   check=True)
    test = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, bufsize=1)
    recording = None
    name = None
    for line in test.stdout:
        sys.stdout.write(line)
        match = MARKER.search(line)
        if not match:
            continue
        kind, arg, sent = match.group(1), match.group(2), int(match.group(4))
        delay = time.time() - sent / 1000
        if kind == 'SHOT':
            for folder, mask in (('raw', []), ('masked', ['--mask=alpha'])):
                staged = STAGING / f'{folder}_{arg}.png'
                subprocess.run(
                    ['xcrun', 'simctl', 'io', udid, 'screenshot',
                     '--type=png', *mask, str(staged)],
                    check=True, capture_output=True)
                shutil.move(staged, out / folder / f'{arg}.png')
            print(f'[capture] {arg}: marker arrived {delay:.2f}s late, '
                  f'taken {time.time() - sent / 1000:.2f}s after it')
        elif kind == 'REC_START':
            name = arg
            recording = Recording(udid, out / 'video' / f'{name}.mov')
            marks[name] = {}
        elif kind in ('BEGIN', 'END'):
            marks[name][kind.lower()] = sent / 1000 - recording.started
            print(f'[capture] {name} {kind} at {marks[name][kind.lower()]:.2f}s'
                  f' (marker {delay:.2f}s late)')
        elif kind == 'REC_STOP':
            recording.stop()
            recording = None
    test.wait()
    if recording:
        # The scene failed before asking to stop.
        recording.stop()
    subprocess.run(['xcrun', 'simctl', 'status_bar', udid, 'clear'])
    marks_path.write_text(json.dumps(marks, indent=2))
    sys.exit(test.returncode)


if __name__ == '__main__':
    main()
