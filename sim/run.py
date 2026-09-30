#!/usr/bin/env python3
"""Build and run the example locally; reuse unchanged simulator binaries."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/sim"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lint", action="store_true")
    parser.add_argument("--view", action="store_true")
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()
    if args.clean:
        shutil.rmtree(BUILD, ignore_errors=True)
        return 0
    # A compilation failure must not leave an old trace available for viewing.
    (BUILD / "dump.vcd").unlink(missing_ok=True)
    verilator = shutil.which("verilator")
    if not verilator:
        raise RuntimeError("Install Verilator and a C++ compiler, then rerun make sim.")
    version = subprocess.check_output([verilator, "--version"], text=True).strip()
    print(version, flush=True)
    common = ["--timing", "--top-module", "tb_counter", "-f", "sim/files.f"]
    if args.lint:
        return subprocess.call([verilator, "--lint-only", *common], cwd=ROOT)
    BUILD.mkdir(parents=True, exist_ok=True)
    # Include headers and build configuration. Runtime-only data is deliberately excluded.
    digest = hashlib.sha256(json.dumps({"version": version, "args": common,
        "CXX": os.environ.get("CXX", ""), "CXXFLAGS": os.environ.get("CXXFLAGS", "")},
        sort_keys=True).encode())
    for path in sorted([ROOT / "sim/files.f", Path(__file__),
                        *(ROOT / "rtl").rglob("*"), *(ROOT / "tb").rglob("*")]):
        if path.is_file():
            digest.update(path.relative_to(ROOT).as_posix().encode())
            digest.update(path.read_bytes())
    key = digest.hexdigest()
    stamp = BUILD / "compile.sha256"
    executable = BUILD / "obj/Vtb_counter"
    if not executable.exists() or not stamp.exists() or stamp.read_text() != key:
        subprocess.run([verilator, "--binary", "--trace", "--build-jobs",
                        os.environ.get("SIM_BUILD_JOBS", "2"),
                        "--Mdir", str(BUILD / "obj"), *common], cwd=ROOT, check=True)
        stamp.write_text(key)
    else:
        print("Reusing compiled simulator", flush=True)
    # Remove the previous trace so a failed launch cannot present stale results.
    (BUILD / "dump.vcd").unlink(missing_ok=True)
    status = subprocess.call([str(executable)], cwd=BUILD)
    if args.view:
        viewer = shutil.which("gtkwave")
        if not viewer:
            raise RuntimeError("GTKWave is not on PATH. Use fpga wave with your viewer configured.")
        wave = BUILD / "dump.vcd"
        if not wave.exists():
            raise RuntimeError("This run did not produce a waveform.")
        subprocess.Popen([viewer, str(wave)], cwd=ROOT)
    return status

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
