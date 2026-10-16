// The auth domain's errors, and the status and code each answers.
namespace auth;

import std;
import rest;

enum Error { None, BadCredentials }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.BadCredentials, cx) { rest::fail(cx, 401, "invalid_credentials"); }
