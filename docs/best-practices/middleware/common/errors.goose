// The errors that more than one domain, or the middleware, answers.
namespace common;

import std;
import rest;

enum Error { None, NotAMember }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.NotAMember, cx) { rest::fail(cx, 403, "not_a_member"); }
