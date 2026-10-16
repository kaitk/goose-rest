// The auth domain's routes, under /auth, public, each route's flow in the
// order it runs: the route, its jobs, its resume steps.
namespace auth;

import std;
import http;
import rest;
import auth.structs;
import auth.errors;
import auth.rules;

fn routes(cx) {
    if rest::on(cx, "POST", "/session") {
        sign_in(cx);
    } else {
        rest::otherwise(cx);
    }
}

// Signing in. On the worker: read the form, and ask the hasher lane.
fn sign_in(cx) {
    let email, has_email = rest::form(cx, "email");
    rest::require(cx, "email", has_email);
    let password, has_password = rest::form(cx, "password");
    rest::require(cx, "password", has_password);
    let job = SignInJob { email: email, password: password };
    // Returns at once; at the reply, the worker calls resume(Waiting.AuthPassword).
    rest::ask(cx, cx.app.hasher, VERIFY_PASSWORD, job, Waiting.AuthPassword);
}

// The rows a query of the users table returns, in place of a database. Ada's
// password is goose.
let USERS = [
    User { id: 1, email: "ada@example.com", salt: 7, hash: 1357044906900630754 },
];

// On the hasher lane: CPU work, through the rule.
fn verify_password(j: SignInJob) -> Verified {
    let user, err = signed_in(USERS, j.email, j.password);
    return Verified { user: user, err: err };
}

fn ::resume(w: Waiting.AuthPassword, cx) { auth::resume(w, cx); }
fn ::resume(w: Waiting.AuthSession, cx) { auth::resume(w, cx); }

// On the worker: 401 for a wrong password, or ask the writer lane.
fn resume(w: Waiting.AuthPassword, cx) {
    let v, ok = rest::read_reply<Verified>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    // A wrong password ends the route here, with 401.
    check(v.err, cx);
    // The route's second wait: at the reply, resume(Waiting.AuthSession).
    rest::ask(cx, cx.app.writer, OPEN_SESSION, OpenJob { user: v.user }, Waiting.AuthSession);
}

// On the writer lane: one write. sessions is the writer's stand-in for the
// sessions table.
fn open_session(sessions: Session[>..]&, j: OpenJob) -> Session {
    let s = Session { id: sessions.len + 1, user: j.user };
    sessions.push(s);
    return s;
}

// On the worker: the answer.
fn resume(w: Waiting.AuthSession, cx) {
    let s, ok = rest::read_reply<Session>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 201, s);
}
