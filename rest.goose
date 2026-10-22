// goose-rest: a REST framework on goose-http (docs/architecture.md). A
// program declares both packages in its root file, goose-http at the
// reference this file imports it at, a release tag or a commit:
//
//   import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@cbffc2a2b67db1a06467486cb128dda4b28e6eea";
import .check;
import .runtime;
import .extract;
import .middleware;
import .security;
import .waiting;
import .pieces;
import .testing;
import .fields;
import .sse;
import .cookies;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
