// The teams' types, and how they're written as JSON.
namespace teams;

import std;
import http;

struct Team { id: i64, organization: i64, name: const u8[:] }

fn format(out: u8[>..]&, t: const Team&) {
    format(out, "{\"id\":", t.id, ",\"name\":");
    http::json_string(out, t.name);
    out.push('}');
}
