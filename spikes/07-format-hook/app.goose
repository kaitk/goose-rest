namespace app;

import std;
import rest;
import api;

struct Owner { id: i64, name: u8[..32] }
struct Project { id: i64, owner: Owner, name: u8[..32] }
// No format overload.
struct Session { user: i64, org: i64 }

fn format(out: u8[>..]&, o: const Owner&) {
    format(out, "{\"id\":", o.id, ",\"name\":\"", o.name, "\"}");
}

// Renders its nested Owner through the overload above.
fn format(out: u8[>..]&, p: const Project&) {
    format(out, "{\"id\":", p.id, ",\"owner\":", p.owner, ",\"name\":\"", p.name, "\"}");
}

fn handle(cx: rest::Cx&, n: i64) {
    if n == 0 {
        rest::json(cx, 200, Project { id: 42, owner: Owner { id: 7, name: "ada" }, name: "goose" });
    } else if n == 1 {
        rest::json(cx, 200, api::Team { id: 3, lead: api::Member { id: 9, admin: true, name: "say \"hi\"" } });
    } else if n == 2 {
        var all: Owner[>..] = [];
        all.push(Owner { id: 1, name: "a" });
        all.push(Owner { id: 2, name: "b" });
        rest::json(cx, 200, all);
    } else if n == 3 {
        rest::json(cx, 200, Session { user: 1, org: 2 });
    } else {
        rest::fail(cx, 404, "not_found");
    }
}
