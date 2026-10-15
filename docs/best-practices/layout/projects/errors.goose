// The projects' errors, and the status and code each answers.
namespace projects;

import std;
import rest;

enum Error { None, NameRequired, NameTooLong }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.NameRequired, cx) { rest::fail(cx, 422, "project_name_required"); }
fn check(e: Error.NameTooLong, cx) { rest::fail(cx, 422, "project_name_too_long"); }
