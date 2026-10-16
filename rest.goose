// goose-rest: a REST framework on goose-http (docs/architecture.md). A
// program declares both packages in its root file, goose-http at the release below:
//
//   import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import .check;
import .runtime;
import .extract;
import .middleware;
import .waiting;
import .pieces;
import .testing;
import .fields;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
