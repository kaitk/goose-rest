// The entries' types, and how they're written as JSON.
namespace entries;

import std;

// A member's span on a project, in seconds since the epoch.
struct Entry { id: i64 = 0, project: i64 = 0, started: i64 = 0, stopped: i64 = 0 }

// What a client sends to create an entry.
struct CreateInput { project: i64, started: i64, stopped: i64 }

fn format(out: u8[>..]&, e: const Entry&) {
    format(out, "{\"id\":", e.id, ",\"project\":", e.project, ",\"started\":", e.started,
           ",\"stopped\":", e.stopped, "}");
}
