// goose-rest: a REST framework on goose-http (docs/architecture/README.md). A
// program declares both packages in its root file, goose-http at the commit below:
//
//   import http from "github.com/kaitk/goose-http@04791ac50b69d99e93c08dc2c3f3ff8d4ab1867c";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@04791ac50b69d99e93c08dc2c3f3ff8d4ab1867c";
import .check;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
