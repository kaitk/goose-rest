#!/usr/bin/env python3
"""Runs the tests under test/<area>/, as Goose's own test/run_tests.py does.

Each test/<area>/<name>.goose with a main is a test. Its stdout must be
test/expected/<name>.out, every nonblank line of test/expected/<name>.stderr,
if there is one, must occur in its stderr, and it must exit 0, or not 0
where test/expected/<name>.aborts exists. A file with `// error: <message>`
lines is a fixture that must not compile: `goose --check` must exit 1, with
each message in its diagnostics. Any other file there is a module the tests
of its area import; test/expect.goose holds what every area shares.

First every test and fixture is checked, in batches, a `goose --multi-test
--check` run per batch. Then each test is built with `goose build`, which
links goose-http's C, at -O0 and at -O2, and run as a process of its own in
a directory of its own under build/test/, the tests in parallel. --jit runs
them through the compiler's TinyCC instead, without a C compiler, in a few
seconds. Every failure is reported, with a count per area at the end.

GOOSE or GOOSE_COMMIT names the compiler (default: the pinned release,
scripts/goose.sh), and GOOSE_CC the C compiler `goose build` uses.

    test/run_tests.py [-j JOBS] [-O {0,2}] [--jit] [--bless] [-v] [AREA | NAME ...]
"""

import argparse
import concurrent.futures
import difflib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
EXPECTED = HERE / "expected"
OUT = ROOT / "build" / "test"
WINDOWS = os.name == "nt"
EXE = ".exe" if WINDOWS else ""
LEVELS = (0, 2)
# The golden files, and the generator's golden inputs and outputs.
NOT_AREAS = (EXPECTED, HERE / "gen")
TIMEOUT = 300

# What `goose --multi-test` ends each file's part of stdout and of stderr with,
# on a line of its own, followed by the file's exit code and name.
MULTIMARK = "==== goose --multi-test: exit"


def run(argv, cwd=None):
    """(exit code, stdout, stderr) of argv, as text with LF line endings."""
    def text(b):
        return (b or b"").decode("utf-8", errors="replace").replace("\r\n", "\n")
    try:
        r = subprocess.run([str(a) for a in argv], cwd=cwd, capture_output=True, timeout=TIMEOUT)
        return r.returncode, text(r.stdout), text(r.stderr)
    except subprocess.TimeoutExpired as e:
        return -1, text(e.stdout), text(e.stderr) + f"\ntimed out after {TIMEOUT} s"


def joined(text):
    """Output as it is compared and blessed: no trailing blank lines."""
    return text.rstrip("\n")


def find_goose():
    goose = os.environ.get("GOOSE")
    if not goose:
        code, out, err = run(["sh", ROOT / "scripts" / "goose.sh"])
        if code != 0:
            sys.exit(f"scripts/goose.sh failed:\n{err}")
        goose = out.strip()
    # Git Bash's shell gives its own form of a path, /c/..., which Windows
    # programs don't read.
    if WINDOWS and goose.startswith("/"):
        goose = run(["cygpath", "-w", goose])[1].strip()
    return goose


def split_multi(text, files):
    """{file: (exit code, what it printed)} for each of `files` that a
    `goose --multi-test` stream has the mark of."""
    parts, pos = {}, 0
    for f in files:
        m = re.compile(rf"\n{re.escape(MULTIMARK)} (-?\d+) {re.escape(str(f))}\n").search(text, pos)
        if not m:
            break
        parts[f] = (int(m[1]), text[pos:m.start()])
        pos = m.end()
    return parts


def multi_test(goose, args, files):
    """{file: (exit code, stdout, stderr)} for each of `files`, as a run of
    `goose *args file` of its own would give it, from one `goose --multi-test`
    run. A file that run didn't get through, because the compiler crashed on
    it or before it, runs alone."""
    code, out, err = run([goose, "--multi-test", *args, *files])
    outs, errs = split_multi(out, files), split_multi(err, files)
    done = {}
    for f in files:
        if f in outs and f in errs:
            done[f] = (outs[f][0], outs[f][1], errs[f][1])
        else:
            done[f] = run([goose, *args, f])
    return done


def batches(files, jobs):
    size = max(1, -(-len(files) // jobs))
    return [files[i:i + size] for i in range(0, len(files), size)]


def error_markers(test):
    return re.findall(r"^// error: (.+)$", test.read_text(encoding="utf-8"), re.MULTILINE)


class Tests:
    def __init__(self, goose, jobs, levels, jit, bless, verbose):
        self.goose, self.levels, self.jit = goose, levels, jit
        self.bless, self.verbose = bless, verbose
        self.pool = concurrent.futures.ThreadPoolExecutor(jobs)
        self.jobs = jobs
        self.failed = set()

    def report(self, test, label, problem=None, detail=""):
        name = f"{test.parent.name}/{test.stem}"
        if problem is None:
            if self.verbose:
                print(f"ok   {name} {label}")
            return
        self.failed.add(test)
        print(f"FAIL {name} {label}: {problem}")
        if detail.strip():
            print("    " + joined(detail).replace("\n", "\n    "))

    def check(self, tests):
        """Checks each of tests, a batch to a `goose --multi-test --check`.
        A fixture must fail with each of its `// error:` messages in a
        diagnostic, a line `file:line: error: message`, rather than in the
        source the compiler echoes. Returns the tests that compile."""
        futures = [self.pool.submit(multi_test, self.goose, ["--check"], b)
                   for b in batches(tests, self.jobs)]
        compiled = []
        for future in futures:
            for f, (code, out, err) in future.result().items():
                markers = error_markers(f)
                if not markers:
                    if code != 0:
                        self.report(f, "--check", "doesn't compile", out + err)
                    else:
                        self.report(f, "--check")
                        compiled.append(f)
                    continue
                diagnostics = "\n".join(re.findall(r"^\S.*:\d+(?::\d+)?: error: (.*)$",
                                                   err, re.MULTILINE))
                missing = [m for m in markers if m not in diagnostics]
                if code != 1:
                    self.report(f, "--check", f"compiler exit {code}, expected 1", out + err)
                elif missing:
                    self.report(f, "--check", f"no diagnostic {missing}", err)
                else:
                    self.report(f, "--check")
        return compiled

    def build_and_run(self, test):
        """[(level, build failure or None, (exit code, stdout, stderr) of the
        run)] for each level, one after another: `goose build` writes a
        program's C in the same place at each level."""
        results = []
        for level in self.levels:
            work = OUT / f"O{level}" / test.stem
            shutil.rmtree(work, ignore_errors=True)
            work.mkdir(parents=True)
            if self.jit:
                results.append((level, None, run([self.goose, f"-O{level}", test], cwd=work)))
                continue
            exe = work / (test.stem + EXE)
            code, out, err = run([self.goose, "build", f"-O{level}", "-o", exe, test])
            if code != 0:
                results.append((level, out + err, None))
            else:
                results.append((level, None, run([exe], cwd=work)))
        return results

    def check_programs(self, programs):
        runs = [(f, self.pool.submit(self.build_and_run, f)) for f in programs]
        for f, future in runs:
            for level, failure, result in future.result():
                label = f"-O{level}" + (" --jit" if self.jit else "")
                if failure is not None:
                    self.report(f, label, "goose build failed", failure)
                else:
                    self.check_run(f, label, level, *result)

    def check_run(self, test, label, level, code, out, err):
        expected = EXPECTED / f"{test.stem}.out"
        aborts = (EXPECTED / f"{test.stem}.aborts").exists()
        if aborts and code == 0:
            return self.report(test, label, "exit 0, expected an abort", out + err)
        if not aborts and code != 0:
            return self.report(test, label, f"exit {code}", out + err)
        stderr_file = EXPECTED / f"{test.stem}.stderr"
        if stderr_file.exists():
            lines = [l.strip() for l in stderr_file.read_text(encoding="utf-8").splitlines()]
            missing = [l for l in lines if l and l not in err]
            if missing:
                return self.report(test, label, f"stderr lacks {missing}", err)
        if self.bless and level == self.levels[0]:
            if not expected.exists() or joined(expected.read_text(encoding="utf-8")) != joined(out):
                with open(expected, "w", encoding="utf-8", newline="\n") as f:
                    f.write(joined(out) + "\n")
                print(f"blessed {expected.relative_to(ROOT).as_posix()}")
        if not expected.exists():
            return self.report(test, label, f"no {expected.relative_to(ROOT).as_posix()}")
        want = joined(expected.read_text(encoding="utf-8").replace("\r\n", "\n"))
        got = joined(out)
        if got != want:
            diff = difflib.unified_diff(want.splitlines(), got.splitlines(),
                                        "expected", "got", lineterm="")
            return self.report(test, label, "stdout differs", "\n".join(diff))
        self.report(test, label)


def find_tests(names):
    """test/<area>/*.goose that are tests or error fixtures, or those of them
    whose area or name is in `names`."""
    tests = []
    for p in sorted(HERE.glob("*/*.goose")):
        if p.parent in NOT_AREAS:
            continue
        source = p.read_text(encoding="utf-8")
        if re.search(r"^// error: |^fn main\(", source, re.MULTILINE):
            tests.append(p)
    # test/tls/'s programs import goose-tls, which builds with OpenSSL, not yet
    # set up on Windows (goose-http's docs/development.md, "OpenSSL"), and
    # serve on serve_epoll, which Windows lacks.
    if WINDOWS:
        tests = [t for t in tests if t.parent.name != "tls"]
    stems = {}
    for t in tests:
        if t.stem in stems:
            sys.exit(f"two tests named {t.stem}: {stems[t.stem]} and {t}; "
                     "test/expected/ needs each name once")
        stems[t.stem] = t
    if names:
        wanted = [Path(n).stem for n in names]
        tests = [t for t in tests if t.stem in wanted or t.parent.name in wanted]
        if not tests:
            sys.exit(f"no test or area named {', '.join(names)}")
    return tests


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("names", nargs="*", metavar="AREA | NAME",
                    help="run only these areas (router) or tests (cors)")
    ap.add_argument("-j", "--jobs", type=int, default=min(32, os.cpu_count() or 1),
                    help="how many things to do at once (default: one per processor)")
    ap.add_argument("-O", dest="level", type=int, choices=LEVELS,
                    help="build at this level only (default: -O0 and -O2)")
    ap.add_argument("--jit", action="store_true",
                    help="run through the compiler's TinyCC instead of building with goose build")
    ap.add_argument("--bless", action="store_true",
                    help="write each run's stdout to its test/expected/<name>.out")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the passes too")
    args = ap.parse_args()

    tests = find_tests(args.names)
    goose = find_goose()
    levels = (args.level,) if args.level is not None else LEVELS
    suite = Tests(goose, args.jobs, levels, args.jit, args.bless, args.verbose)
    compiled = suite.check(tests)
    suite.check_programs([t for t in tests if t in compiled])
    suite.pool.shutdown()

    for area in sorted({t.parent.name for t in tests}):
        n = sum(1 for t in tests if t.parent.name == area)
        bad = sum(1 for t in suite.failed if t.parent.name == area)
        print(f"== {area}: {n - bad} passed" + (f", {bad} failed" if bad else ""))
    fixtures = sum(1 for t in tests if error_markers(t))
    print(f"== {len(tests) - fixtures} tests at " + ", ".join(f"-O{l}" for l in levels)
          + (" through TinyCC" if args.jit else "") + f", and {fixtures} error fixtures: "
          + (f"{len(suite.failed)} failed" if suite.failed else "all passed"))
    sys.exit(1 if suite.failed else 0)


if __name__ == "__main__":
    main()
