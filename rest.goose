// goose-rest: a REST framework on goose-http (docs/architecture/README.md). A
// program declares both packages in its root file, goose-http at the commit below:
//
//   import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
//   import rest from "github.com/kaitk/goose-rest@<commit>";
namespace rest;

import std;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import .check;
import .runtime;
import .extract;
import .middleware;
import .waiting;
import .testing;

// The path a route matches: the request target without its query, as goose-http
// reads it.
fn path_of(target: const u8[:]) -> const u8[:] { http::path_of(target) }
