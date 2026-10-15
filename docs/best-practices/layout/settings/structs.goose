// A user's settings, and how they're written as JSON.
namespace settings;

import std;
import http;

struct Settings { user: i64, time_zone: const u8[:] }

fn format(out: u8[>..]&, s: const Settings&) {
    out.append("{\"time_zone\":");
    http::json_string(out, s.time_zone);
    out.push('}');
}
