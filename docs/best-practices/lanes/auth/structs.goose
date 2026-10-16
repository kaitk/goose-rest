// The auth domain's types, and how they're written as JSON.
namespace auth;

import std;
import auth.errors;

// A user who may sign in: the password's salt, and its hash with that salt.
struct User { id: i64, email: u8[..64], salt: u64, hash: u64 }

struct Session { id: i64 = 0, user: i64 = 0 }

// Signing in's two jobs, and their replies.
struct SignInJob { email: u8[..64], password: u8[..64] }
struct Verified { user: i64 = 0, err: Error = Error.None }
struct OpenJob { user: i64 }

fn format(out: u8[>..]&, s: const Session&) {
    format(out, "{\"session\":", s.id, ",\"user\":", s.user, "}");
}
