"""Summarizes bench/rest.sh run's tiers F, R, and M (x-* files) as Markdown
tables, with goose-http's bench/rest/summary.py's parsers.

    python3 bench/rest/tiers/summary.py OUTDIR

Each cell: wrk's requests per second as the median and the range of the
runs, the server's median CPU time per request, and the highest peak RSS.
Errors are summed: wrk's socket errors and non-2xx.
"""

import glob
import os
import re
import statistics
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.environ.get("GOOSE_HTTP", os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "goose-http")), "bench", "rest"))
from summary import k, span, stat, wrk  # noqa: E402

ORDER = ["goose-uring-bare", "goose-epoll-bare", "goose-uring-plod", "goose-epoll-plod", "goose-uring-plod-gen",
         "goose-epoll-plod-gen", "axum", "actix-web", "ntex", "dusty-routes"]


def cells(out):
    c = defaultdict(list)
    for p in glob.glob(f"{out}/x-*.wrk"):
        m = re.match(r"x-([frm])-(.+)-([a-z]+)-r(\d+)\.wrk$", os.path.basename(p))
        w = wrk(p)
        cpu, rss = stat(p[:-4] + ".stat")
        w["cpu_us"] = cpu / w["requests"] * 1e6 if w["requests"] else 0
        w["rss"] = rss
        c[m.group(1), m.group(2), m.group(3)].append(w)
    return c


def cell(runs):
    rps = statistics.median(w["rps"] for w in runs)
    cpu = statistics.median(w["cpu_us"] for w in runs)
    errors = sum(w["errors"] for w in runs)
    text = f"{k(rps)} ({span([w['rps'] for w in runs], k)}), {cpu:.1f} µs"
    return text + (f", {errors} errors" if errors else "")


def table(c, tier, columns, title):
    servers = sorted({s for (t, s, _) in c if t == tier}, key=lambda s: (ORDER.index(s) if s in ORDER else 99, s))
    if not servers:
        return
    print(f"\n### {title}\n")
    print("| Server | " + " | ".join(columns) + " | Peak RSS |")
    print("|---|" + "---:|" * (len(columns) + 1))
    for s in servers:
        row = [cell(c[tier, s, col]) if c.get((tier, s, col)) else "" for col in columns]
        rss = max((w["rss"] for col in columns for w in c.get((tier, s, col), [])), default=0)
        print(f"| {s} | " + " | ".join(row) + f" | {rss:.0f} MB |")


def main():
    c = cells(sys.argv[1])
    print("Requests per second, median (range of runs), and the server's CPU time per request.")
    table(c, "f", ["root", "id", "json"], "Tier F")
    table(c, "r", ["routes"], "Tier R")
    table(c, "m", ["a", "m"], "Tier M, against tier A")


if __name__ == "__main__":
    main()
