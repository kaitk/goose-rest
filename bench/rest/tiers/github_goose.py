"""Writes goose-rest's tier R sources from github.txt (task 010):

    python3 bench/rest/tiers/github_goose.py

- bench/rest/goose-rest/github.json, an OpenAPI 3.1 document of the 203
  routes, operation n named rN, each path parameter a string, from which
  goose-rest gen writes github_gen.goose's router (bench/rest.sh build);
- bench/rest/goose-rest/github_app.goose, the handlers both routers call,
  app::rN, and chain, the same routes as an http::router if chain in
  github.txt's order.

Run it after changing github.txt, and commit what it writes.
"""

import json
import os
import re

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "goose-rest")
routes = [line.split() for line in open(os.path.join(here, "github.txt")).read().splitlines()]


def params(pattern):
    return re.findall(r":(\w+)", pattern)


# A parameter named as a variable of the generated code gets another name.
def ident(p):
    return p + "_" if p in ("state", "cx", "r", "b", "n") else p


paths = {}
for n, (method, pattern) in enumerate(routes, 1):
    path = re.sub(r":(\w+)", lambda m: "{" + ident(m.group(1)) + "}", pattern)
    op = {"operationId": f"r{n}"}
    names = params(pattern)
    if names:
        op["parameters"] = [{"name": ident(p), "in": "path", "required": True, "schema": {"type": "string"}}
                            for p in names]
    paths.setdefault(path, {})[method.lower()] = op

doc = {
    "openapi": "3.1.0",
    "info": {"title": "The GitHub API's routes, from go-http-routing-benchmark", "version": "1"},
    "paths": paths,
    "components": {"schemas": {}},
}
with open(os.path.join(out, "github.json"), "w") as f:
    json.dump(doc, f, indent=1)
    f.write("\n")

lines = [
    "// Tier R's handlers and its if chain, written by bench/rest/tiers/github_goose.py",
    "// from github.txt; don't edit. Route n answers n and its parameters, separated",
    "// by spaces. github_gen.goose's router calls the same handlers.",
    "namespace app;",
    "",
    "import std;",
    "import http;",
    "import rest;",
    "",
    "fn answer(cx, n: i64, values: const u8[:][:]) {",
    "    var b: u8[>..] = [];",
    "    format(b, n);",
    "    for v in values {",
    "        b.push(' ');",
    "        b.append(v);",
    "    }",
    "    rest::text(cx, 200, b);",
    "}",
    "",
]
for n, (method, pattern) in enumerate(routes, 1):
    names = [ident(p) for p in params(pattern)]
    args = "".join(f", {p}" for p in names)
    lines.append(f"fn r{n}(cx{args}) {{ answer(cx, {n}, [{', '.join(names)}]); }}")
lines += ["", "// The routes as an if chain, in github.txt's order.", "fn chain(cx) {",
          "    var r = http::router(cx.req);"]
for n, (method, pattern) in enumerate(routes, 1):
    names = params(pattern)
    args = "".join(f", rest::param(cx, r, \"{p}\")" for p in names)
    lead = "if" if n == 1 else "} else if"
    lines.append(f"    {lead} http::on(r, \"{method}\", \"{pattern}\") {{")
    lines.append(f"        r{n}(cx{args});")
lines += ["    } else {", "        rest::otherwise(cx, r);", "    }", "}", ""]
with open(os.path.join(out, "github_app.goose"), "w") as f:
    f.write("\n".join(lines))
