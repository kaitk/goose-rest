// Signing in: the route, its two jobs, on the hasher lane and then the
// writer, and their resumes.
namespace auth;

import std;
import rest;

struct User { id: i64, email: u8[..64], salt: u64, hash: u64 }
struct Session { id: i64 = 0, user: i64 = 0 }

enum Error { None, BadCredentials }

fn check(e: Error.None, x) {}
fn check(e: Error.BadCredentials, x) { rest::fail(x, 401, "invalid_credentials"); }

fn format(out: u8[>..]&, s: const Session&) {
    format(out, "{\"session\":", s.id, ",\"user\":", s.user, "}");
}

// Ada's password is goose.
let USERS = [User { id: 1, email: "ada@example.com", salt: 7, hash: hashed("goose", 7) }];

fn routes(cx) {
    if rest::on(cx, "POST", "/session") { sign_in(cx); } else { rest::otherwise(cx); }
}

fn sign_in(cx) {
    let email, has_email = rest::query(cx, "email");
    rest::require(cx, "email", has_email);
    let password, has_password = rest::query(cx, "password");
    rest::require(cx, "password", has_password);
    rest::ask(cx, cx.app.hasher, Use.AuthPassword { email: email, password: password });
}

// On the hasher lane: a wrong password is a 401 from here.
fn ::run(u: Use.AuthPassword, db: Db&, a) {
    let user, err = auth::signed_in(auth::USERS, u.email, u.password);
    auth::check(err, a);
    rest::reply_value(a, user);
}

// On the worker: the second wait, on the writer.
fn ::resume(u: Use.AuthPassword, cx) {
    rest::ask(cx, cx.app.writer, Use.AuthSession { user: rest::answer<i64>(cx) });
}

fn ::run(u: Use.AuthSession, db: Db&, a) {
    let s = auth::Session { id: db.sessions.len + 1, user: u.user };
    db.sessions.push(s);
    rest::reply_value(a, s);
}

fn ::resume(u: Use.AuthSession, cx) { rest::json(cx, 201, rest::answer<auth::Session>(cx)); }

// password hashed with salt, standing in for a password hash.
fn hashed(password: const u8[:], salt: u64) -> u64 {
    var h: u64 = 14695981039346656037 ^ salt;
    for r in 1000 {
        for c in password { h = (h ^ c) * 1099511628211; }
    }
    return h;
}

fn signed_in(users: const User[:], email: const u8[:], password: const u8[:]) -> i64, Error {
    for u in users {
        if u.email == email {
            guard hashed(password, u.salt) == u.hash else { return 0, Error.BadCredentials; }
            return u.id, Error.None;
        }
    }
    return 0, Error.BadCredentials;
}
