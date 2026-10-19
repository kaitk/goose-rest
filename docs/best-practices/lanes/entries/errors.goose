// The entries' errors, and the status and code each answers.
namespace entries;

import std;
import rest;

enum Error { None, EndsBeforeStart, InFuture }

// Fails with e's status and code, or returns for Error.None: x is a route's
// cx, or on a lane, the job's a, which fails the route that asked.
fn check(e: Error.None, x) {}
fn check(e: Error.EndsBeforeStart, x) { rest::fail(x, 422, "entry_ends_before_start"); }
fn check(e: Error.InFuture, x) { rest::fail(x, 422, "entry_in_future"); }
