// goose-rest: a REST framework on goose-http (docs/architecture.md). A
// program declares both packages in its root file, goose-http at the
// reference this file imports it at, a release tag or a commit:
//
//   import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@81bbf9baa315ad3607cd2a3a67fa7d14d154726c";
import .check;
import .runtime;
import .extract;
import .middleware;
import .waiting;
import .lane;
import .pieces;
import .testing;
import .fields;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
