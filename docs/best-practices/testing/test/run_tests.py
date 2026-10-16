#!/usr/bin/env python3
"""Runs the application's tests, as Goose's own test/run_tests.py does.

Each test/<domain>/<name>.goose with a main is a small test: run through the
compiler's TinyCC, its stdout must be test/expected/<name>.out. A file with
`// error: <message>` lines is a fixture that must not compile: `goose --check`
must exit 1, with each message in its diagnostics. Each test/<scenario>/ with
a requests.sh is a scenario: the program, main.goose, is built and served on
a local port, each `req METHOD PATH [curl options]` line is sent with curl,
and the `METHOD PATH STATUS BODY` lines must be test/expected/<scenario>.out.
Every failure is reported, not only the first.

GOOSE names the compiler (default: goose on PATH).

    test/run_tests.py [--bless] [NAME ...]
"""

import argparse
import concurrent.futures
import difflib
import os
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
EXPECTED = HERE / "expected"
GOOSE = os.environ.get("GOOSE", "goose")

# Defines req for a scenario's requests.sh, which the shell then sources.
REQ = """
req() {
    method=$1; path=$2; shift 2
    : >"$OUT/body"
    code=$(curl -s -o "$OUT/body" -w '%{http_code}' -X "$method" "$@" "http://127.0.0.1:$PORT$path") || true
    body=$(cat "$OUT/body")
    if [ -n "$body" ]; then echo "$method $path $code $body"; else echo "$method $path $code"; fi
}
"""


def run(argv, **kw):
    r = subprocess.run([str(a) for a in argv], capture_output=True, text=True, **kw)
    return r.returncode, r.stdout, r.stderr


def compare(name, got, bless):
    """None, or what's wrong with got as test/expected/<name>.out."""
    expected = EXPECTED / f"{name}.out"
    if bless:
        expected.write_text(got)
        return None
    if not expected.exists():
        return f"no {expected.relative_to(ROOT)}"
    want = expected.read_text()
    if got == want:
        return None
    return "".join(difflib.unified_diff(want.splitlines(True), got.splitlines(True), "expected", "got"))


def small_test(test, bless):
    markers = re.findall(r"^// error: (.+)$", test.read_text(), re.MULTILINE)
    if markers:
        code, out, err = run([GOOSE, "--check", test])
        missing = [m for m in markers if m not in err]
        if code != 1 or missing:
            return f"compiler exit {code}, expected 1 with {missing}\n{err}"
        return None
    code, out, err = run([GOOSE, test])
    if code != 0:
        return f"exit {code}\n{err}"
    return compare(test.stem, out, bless)


def scenario(folder, program, bless):
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    server = subprocess.Popen([program, str(port)], stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{port}/health")
                break
            except OSError:
                time.sleep(0.1)
        with tempfile.TemporaryDirectory() as out:
            env = dict(os.environ, PORT=str(port), OUT=out)
            code, got, err = run(["sh", "-c", REQ + '. "$1"', "sh", folder / "requests.sh"], env=env)
        if code != 0:
            return f"requests.sh exit {code}\n{err}"
        return compare(folder.name, got, bless)
    finally:
        server.terminate()
        server.wait()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", help="run only these tests or scenarios")
    ap.add_argument("--bless", action="store_true", help="write each output as its golden file")
    args = ap.parse_args()
    tests, scenarios = [], []
    for folder in sorted(p for p in HERE.iterdir() if p.is_dir() and p != EXPECTED):
        if (folder / "requests.sh").exists():
            scenarios.append(folder)
        else:
            tests += sorted(folder.glob("*.goose"))
    if args.names:
        tests = [t for t in tests if t.stem in args.names]
        scenarios = [s for s in scenarios if s.name in args.names]

    failed = 0
    with concurrent.futures.ThreadPoolExecutor() as pool, tempfile.TemporaryDirectory() as build:
        results = [(t, pool.submit(small_test, t, args.bless)) for t in tests]
        if scenarios:
            program = Path(build) / "app"
            code, out, err = run([GOOSE, "build", "-o", program, ROOT / "main.goose"])
            if code != 0:
                sys.exit(f"FAIL goose build main.goose\n{err}")
            results += [(s, pool.submit(scenario, s, program, args.bless)) for s in scenarios]
        for what, future in results:
            problem = future.result()
            name = what.relative_to(HERE)
            if problem is None:
                print(f"ok   {name}")
            else:
                failed += 1
                print(f"FAIL {name}\n    " + problem.rstrip().replace("\n", "\n    "))
    print(f"{len(results) - failed} passed" + (f", {failed} failed" if failed else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
