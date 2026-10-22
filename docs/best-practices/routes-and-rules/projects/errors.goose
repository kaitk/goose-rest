// The projects' errors, and the status and code each answers.
namespace projects;

import std;
import plod;

enum Error { None, NotFound, NameRequired, NameTooLong, AlreadyArchived }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.NotFound, cx) { plod::fail(cx, 404, "project_not_found"); }
fn check(e: Error.NameRequired, cx) { plod::fail(cx, 422, "project_name_required"); }
fn check(e: Error.NameTooLong, cx) { plod::fail(cx, 422, "project_name_too_long"); }
fn check(e: Error.AlreadyArchived, cx) { plod::fail(cx, 409, "project_already_archived"); }
