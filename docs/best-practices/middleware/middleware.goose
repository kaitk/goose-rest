// The program's middleware, each named for what it does.
import std;
import http;
import plod;
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
    // The token, or 401 for a request that has none.
    plod::bearer(cx) { token =>
        var user: i64 = 0;
        for s in SESSIONS {
            if s.token == token { user = s.user; }
        }
        guard user != 0 else { plod::invalid_token(cx); }
        // F is the block the caller gave: the next middleware, or the route.
        F(users::User { id: user });
    };
}

// Runs F with the user as a member of the organization the X-Organization
// header names, or fails with 403 not_a_member. A scope's prefix can't hold
// a parameter yet, so the organization's id comes from a header.
inline fn resolve_organization<F>(cx, user: users::User) {
    let value, has = plod::header(cx, "X-Organization");
    plod::require(cx, "X-Organization", has);
    let organization = plod::int_of(cx, value, "X-Organization");
    var member = false;
    for s in SESSIONS {
        if s.user == user.id && s.organization == organization { member = true; }
    }
    guard member else { common::check(common::Error.NotAMember, cx); }
    F(members::Member { user: user.id, organization: organization });
}
