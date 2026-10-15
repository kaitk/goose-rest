// The projects' errors, and the status and code each answers.
namespace projects;

import std;
import rest;

enum Error { None, NotFound, NameTaken, Archived }

// Fails the route with e's status and code, or returns for Error.None.
fn check(e: Error.None, cx) {}
fn check(e: Error.NotFound, cx) { rest::fail(cx, 404, "project_not_found"); }
fn check(e: Error.NameTaken, cx) { rest::fail(cx, 409, "project_name_taken"); }
fn check(e: Error.Archived, cx) { rest::fail(cx, 409, "project_archived"); }
