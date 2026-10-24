// Plod: a REST framework on goose-http (docs/architecture.md). A
// program declares both packages in its root file, goose-http at the
// reference this file imports it at, a release tag or a commit:
//
//   import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
//   import plod from "github.com/kaitk/plod@<commit>";
namespace plod;

import std;
import http from "github.com/kaitk/goose-http@999757063408a9a50c7a865dcad309a213489e33";
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
