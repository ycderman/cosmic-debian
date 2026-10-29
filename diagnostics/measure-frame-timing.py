#!/usr/bin/env python3
"""Compare 3/6/3 ms in one diagnostic session, restoring its original margin."""
import argparse
import csv
import datetime
import hashlib
import json
import os
from pathlib import Path
import signal
import statistics
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("probe", type=Path, help="presentation probe built with build-probe.sh")
parser.add_argument("--margins", nargs="+", type=int, default=[3, 6, 3])
parser.add_argument("--output", type=Path)
args = parser.parse_args()
runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
margin_path = runtime / "cosmic-frame-timing/safety-margin-ms"
if not margin_path.is_file():
    parser.error("Log into a COSMIC timing test session first; its runtime margin file is missing.")
if not os.access(args.probe, os.X_OK):
    parser.error(f"Probe is not executable: {args.probe}")
if "WAYLAND_DISPLAY" not in os.environ:
    parser.error("WAYLAND_DISPLAY must identify the active test session.")
if "PROBE_FULLSCREEN" in os.environ or "PROBE_TIMER" in os.environ:
    parser.error("Unset PROBE_FULLSCREEN and PROBE_TIMER for the windowed callback comparison.")
if any(margin < 0 or margin > 2**64 - 1 for margin in args.margins):
    parser.error("Margins must be unsigned 64-bit integer millisecond values.")

compositor = None
for process in Path("/proc").iterdir():
    if not process.name.isdigit():
        continue
    try:
        if (process / "comm").read_text().strip() != "cosmic-comp":
            continue
        environment = dict(item.split(b"=", 1) for item in (process / "environ").read_bytes().split(b"\0")
                           if b"=" in item)
        executable = os.readlink(process / "exe")
    except (OSError, ValueError):
        continue
    if environment.get(b"COSMIC_FRAME_SAFETY_MARGIN_FILE") == os.fsencode(margin_path) \
            and environment.get(b"COSMIC_BACKEND") == b"kms" \
            and executable == "/opt/cosmic-frame-timing/libexec/cosmic-comp":
        compositor = process
        break
if compositor is None:
    parser.error("The active compositor is not using this diagnostic margin file.")

stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
output = args.output or Path.home() / ".cache/cosmic-frame-timing/measurements" / stamp
output.mkdir(parents=True, exist_ok=False)
original = margin_path.read_bytes()
with (compositor / "exe").open("rb") as stream:
    binary_sha256 = hashlib.file_digest(stream, "sha256").hexdigest()
(output / "metadata.json").write_text(json.dumps({
    "compositor_pid": int(compositor.name),
    "compositor_sha256": binary_sha256,
    "backend": "kms",
    "wayland_display": os.environ["WAYLAND_DISPLAY"],
    "original_margin": original.decode(),
}, indent=2) + "\n")


def replace_margin(data):
    fd, temporary = tempfile.mkstemp(prefix=".margin-", dir=margin_path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.replace(temporary, margin_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def interrupted(signum, frame):
    raise SystemExit(128 + signum)


for signum in (signal.SIGTERM, signal.SIGHUP):
    signal.signal(signum, interrupted)

results = []
try:
    for index, margin in enumerate(args.margins):
        if not (compositor / "exe").exists():
            raise RuntimeError("The diagnostic compositor exited during the comparison.")
        replace_margin(f"{margin}\n".encode())
        time.sleep(2)
        name = f"{index + 1:02d}-{margin}ms"
        with (output / f"{name}.csv").open("w") as out, (output / f"{name}.log").open("w") as err:
            subprocess.run([str(args.probe.resolve()), "egl"], stdout=out, stderr=err,
                           timeout=15, check=True)
        with (output / f"{name}.csv").open() as stream:
            frames = [row for row in csv.reader(stream) if row[0] == "P"]
        if not frames:
            raise RuntimeError("The compositor returned no presentation feedback.")
        # Exclude each window's initial configuration and shader warmup.
        cutoff = float(frames[0][1]) + 2
        frames = [row for row in frames if float(row[1]) >= cutoff]
        if len(frames) < 2:
            raise RuntimeError("Too few presented frames after warmup.")
        times = [float(row[1]) for row in frames]
        gaps = sorted((b - a) * 1000 for a, b in zip(times, times[1:]))
        seq = [int(row[3]) for row in frames]
        result = {
            "margin_ms": margin,
            "presented": len(frames),
            "fps": (len(times) - 1) / (times[-1] - times[0]),
            "median_interval_ms": statistics.median(gaps),
            "p95_interval_ms": gaps[int((len(gaps) - 1) * 0.95)],
            "intervals_over25ms": sum(gap > 25 for gap in gaps),
            "missed_refreshes": sum(max(b - a - 1, 0) for a, b in zip(seq, seq[1:])),
            "zero_copy_frames": sum(bool(int(row[4]) & 8) for row in frames),
        }
        results.append(result)
        (output / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
        print(json.dumps(result), flush=True)
finally:
    if (compositor / "exe").exists():
        replace_margin(original)
        print(f"Margin restored: {margin_path.read_bytes() == original}", flush=True)
    else:
        print("Diagnostic session ended; leaving the next session's runtime settings alone.", flush=True)
print(f"Measurements: {output}")
