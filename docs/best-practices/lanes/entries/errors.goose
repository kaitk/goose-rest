// The entries' errors, and the status and code each answers.
namespace entries;

import std;
import rest;

enum Error { None, EndsBeforeStart, InFuture }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.EndsBeforeStart, cx) { rest::fail(cx, 422, "entry_ends_before_start"); }
fn check(e: Error.InFuture, cx) { rest::fail(cx, 422, "entry_in_future"); }
