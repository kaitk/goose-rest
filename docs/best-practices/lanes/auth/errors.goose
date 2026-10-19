// The auth domain's errors, and the status and code each answers.
namespace auth;

import std;
import rest;

enum Error { None, BadCredentials }

// Fails with e's status and code, or returns for Error.None: x is a route's
// cx, or on a lane, the job's a, which fails the route that asked.
fn check(e: Error.None, x) {}
fn check(e: Error.BadCredentials, x) { rest::fail(x, 401, "invalid_credentials"); }
