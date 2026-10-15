// The program's middleware, each named for what it does.
import std;
import http;
import rest;
import common.errors;
import common.users.structs;
import common.members.structs;

// Who each token belongs to, and which organization each user is a member
// of: what stands in for a session store and the database.
struct Session { token: const u8[:], user: i64, organization: i64 }

let SESSIONS = [
    Session { token: "ada", user: 1, organization: 1 },
    Session { token: "grace", user: 2, organization: 2 },
];

// Runs F with the user the bearer token names, or fails with 401.
inline fn authenticate<F>(cx) {
    rest::bearer(cx) { token =>
        var user: i64 = 0;
        for s in SESSIONS {
            if s.token == token { user = s.user; }
        }
        guard user != 0 else { rest::invalid_token(cx); }
        F(users::User { id: user });
    };
}

// Runs F with the user as a member of the organization the path names, or
// fails with 403 not_a_member. A scope's prefix can't hold a parameter yet,
// so the organization's id is the segment after the /organizations scope,
// read here, and the routes inside match the rest.
inline fn resolve_organization<F>(cx, user: users::User) {
    let path = cx.router.path;
    guard path.len > 1 else { rest::otherwise(cx); }
    var end: i64 = 1;
    while end < path.len && path[end] != '/' { end++; }
    let organization = rest::int_of(cx, path[1..end], "organization");
    var member = false;
    for s in SESSIONS {
        if s.user == user.id && s.organization == organization { member = true; }
    }
    guard member else { common::check(common::Error.NotAMember, cx); }
    cx.router.path = path[end..];
    F(members::Member { user: user.id, organization: organization });
}
