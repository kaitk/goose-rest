// The auth domain's routes, under /auth, public, each route's flow in the
// order it runs: the route, then each job's run on a lane and its resume.
namespace auth;

import std;
import http;
import plod;
import auth.structs;
import auth.errors;
import auth.rules;

fn routes(cx) {
    plod::post(cx, "/session") { sign_in(cx); };
}

// Signing in. On the worker: read the form, and ask the hasher lane.
fn sign_in(cx) {
    let email, has_email = plod::form(cx, "email");
    plod::require(cx, "email", has_email);
    let password, has_password = plod::form(cx, "password");
    plod::require(cx, "password", has_password);
    // Returns at once; at the reply, the worker calls resume(u: Hashes.AuthPassword, cx).
    plod::ask(cx, cx.app.hasher, Hashes.AuthPassword { email: email, password: password });
}

// The rows a query of the users table returns, in place of a database. Ada's
// password is goose.
let USERS = [
    User { id: 1, email: "ada@example.com", salt: 7, hash: 1357044906900630754 },
];

// On the hasher lane: CPU work, through the rule. A wrong password fails the
// route from here, with 401.
fn ::run(u: Hashes.AuthPassword, h: Hasher&, a) {
    let user, err = auth::signed_in(h.users, u.email, u.password);
    auth::check(err, a);
    plod::reply_value(a, user);
}

// On the worker: the route's second wait, on the writer lane: at the reply,
// resume(u: Writes.AuthSession, cx).
fn ::resume(u: Hashes.AuthPassword, cx) {
    plod::ask(cx, cx.app.writer, Writes.AuthSession { user: plod::answer<i64>(cx) });
}

// On the writer lane: one write. The writer's sessions stand in for the
// sessions table.
fn ::run(u: Writes.AuthSession, w: Writer&, a) {
    let s = auth::Session { id: w.sessions.len + 1, user: u.user };
    w.sessions.push(s);
    plod::reply_value(a, s);
}

// On the worker: the answer.
fn ::resume(u: Writes.AuthSession, cx) { plod::json(cx, 201, plod::answer<auth::Session>(cx)); }
