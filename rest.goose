// goose-rest: a REST framework on goose-http (docs/architecture/README.md). A
// program declares both packages in its root file, goose-http at the commit below:
//
//   import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import .check;
import .runtime;
import .extract;
import .middleware;
import .waiting;
import .testing;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
