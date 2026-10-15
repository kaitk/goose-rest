"""Checks a server's answers on goose-rest's own tiers (task 010) before its
load runs, as goose-http's bench/rest/check.py does for tiers A to D.

    python3 bench/rest/tiers/check.py PORT TIER [DATADIR]    (TIER: f, r, or m)

Tier F, the bun-http-framework-benchmark's three routes: GET / answers "Hi";
GET /id/{id}?name= answers "{id} {name}" with x-powered-by: benchmark; POST
/json answers the JSON body it was sent, members in order.

Tier R, the GitHub API's 203 routes in github.txt: each route n, requested
with each parameter's value its name and n, answers 200 text/plain "n" and
the values, separated by spaces. A path no route has is 404.

Tier M, tier A behind a middleware stack: every answer, errors included,
carries Server-Timing: app;dur=<ms>; one with Origin: https://app.example
carries Access-Control-Allow-Origin for it; a request without a bearer token
is 401; a preflight is 2xx without one, as the Fetch standard accepts any ok status
(goose-rest and dusty answer 204, tower-http and actix-cors 200). DATADIR is goose-http's datasets,
for an item to compare.

Exits non-zero with a message on the first failure.
"""

import http.client
import json
import os
import re
import sys

ORIGIN = "https://app.example"
TOKEN = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0MiIsImV4cCI6MTc5MDAwMDAwMH0." + "x" * 70
BODY = ('{"id":12345,"name":"goose \\"rest\\"","active":true,"score":98.5,'
        '"tags":["fast","small","typed"],"owner":{"id":7,"login":"octo"},"note":null,"items":[1,2,3,4,5]}')


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


class Server:
    def __init__(self, port):
        self.conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)

    def ask(self, method, path, body=None, headers=None):
        self.conn.request(method, path, body=body, headers=headers or {})
        r = self.conn.getresponse()
        return r.status, r, r.read()


def text(s, path, want, headers=None):
    status, r, body = s.ask("GET", path)
    ctype = r.getheader("content-type") or ""
    if status != 200 or not ctype.startswith("text/plain") or body.decode() != want:
        fail(f"GET {path}: {status} {ctype} {body[:200]!r}, want {want!r}")
    for k, v in (headers or {}).items():
        if r.getheader(k) != v:
            fail(f"GET {path}: {k} is {r.getheader(k)!r}, want {v!r}")


def tier_f(port):
    s = Server(port)
    text(s, "/", "Hi")
    for path, want in [("/id/1?name=bun", "1 bun"), ("/id/42?name=b%20un", "42 b un"),
                       ("/id/abc?name=x&other=1", "abc x")]:
        text(s, path, want, {"x-powered-by": "benchmark"})
    for body in [BODY, '{"a":[{"b":{}}],"c":""}', "{}"]:
        status, r, got = s.ask("POST", "/json", body, {"Content-Type": "application/json"})
        ctype = r.getheader("content-type") or ""
        if status != 200 or not ctype.startswith("application/json"):
            fail(f"POST /json {body}: {status} {ctype}")
        pairs = lambda raw: json.loads(raw, object_pairs_hook=list)
        if pairs(got) != pairs(body):
            fail(f"POST /json: {got[:300]!r}, want {body!r}")
    print("tier f: ok")


def routes():
    here = os.path.dirname(os.path.abspath(__file__))
    return [line.split() for line in open(os.path.join(here, "github.txt")).read().splitlines()]


def request_of(n, pattern):
    """Route n's path, each parameter's value its name and n, and the answer."""
    values = []
    parts = []
    for seg in pattern.split("/"):
        if seg.startswith(":"):
            values.append(f"{seg[1:]}{n}")
            parts.append(values[-1])
        else:
            parts.append(seg)
    return "/".join(parts), " ".join([str(n)] + values)


def tier_r(port):
    s = Server(port)
    for n, (method, pattern) in enumerate(routes(), 1):
        path, want = request_of(n, pattern)
        status, r, body = s.ask(method, path, b"" if method in ("POST", "PUT", "PATCH") else None)
        if status != 200 or body.decode() != want:
            fail(f"{method} {path}: {status} {body[:200]!r}, want {want!r}")
    for path in ["/nothing/here", "/repos/a/b/c/d/e/f/g"]:
        status, _, _ = s.ask("GET", path)
        if status != 404:
            fail(f"GET {path}: {status}, want 404")
    print(f"tier r: {len(routes())} routes ok")


def tier_m(port, data):
    s = Server(port)
    item = json.load(open(os.path.join(data, "arena-items.json")))[0] if data else None

    def asked(method, path, headers, want):
        status, r, body = s.ask(method, path, headers=headers)
        if status != want and not (want == "2xx" and 200 <= status < 300):
            fail(f"{method} {path} {headers}: {status} {body[:200]!r}, want {want}")
        # A field value's trailing whitespace isn't part of it (RFC 9110, 5.5).
        timing = (r.getheader("server-timing") or "").strip()
        if not re.fullmatch(r"app;dur=[0-9]+(\.[0-9]+)?", timing):
            fail(f"{method} {path}: Server-Timing {timing!r}")
        if "Origin" in headers and r.getheader("access-control-allow-origin") != ORIGIN:
            fail(f"{method} {path}: Access-Control-Allow-Origin {r.getheader('access-control-allow-origin')!r}")
        return r, body

    both = {"Authorization": TOKEN, "Origin": ORIGIN}
    _, body = asked("GET", "/api/items/1", both, 200)
    got = json.loads(body)
    got.pop("servedAt", None)
    if item is not None and got != item:
        fail(f"GET /api/items/1: {got}, want {item}")
    asked("GET", "/api/items/1", {"Authorization": TOKEN}, 200)
    asked("GET", "/api/me", both, 401)
    asked("GET", "/api/items/0", both, 404)
    asked("GET", "/api/items/1", {"Origin": ORIGIN}, 401)
    r, _ = asked("OPTIONS", "/api/items/1", {"Origin": ORIGIN, "Access-Control-Request-Method": "POST"}, "2xx")
    if "POST" not in (r.getheader("access-control-allow-methods") or "").upper():
        fail(f"preflight: Access-Control-Allow-Methods {r.getheader('access-control-allow-methods')!r}")
    print("tier m: ok")


def main():
    port, tier = int(sys.argv[1]), sys.argv[2]
    data = sys.argv[3] if len(sys.argv) > 3 else None
    if tier == "f":
        tier_f(port)
    elif tier == "r":
        tier_r(port)
    elif tier == "m":
        tier_m(port, data)
    else:
        fail(f"no tier {tier}")


if __name__ == "__main__":
    main()
