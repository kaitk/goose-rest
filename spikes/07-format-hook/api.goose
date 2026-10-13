// Types and writers as the generator would write them, in a namespace of
// their own.
namespace api;

import std;
import json;

struct Member { id: i64, admin: bool, name: u8[..32] }
struct Team { id: i64, lead: Member }

fn format(out: u8[>..]&, m: const Member&) {
    out.append("{\"id\":");
    json::format_int(out, m.id);
    out.append(",\"admin\":");
    json::format_bool(out, m.admin);
    out.append(",\"name\":");
    json::format_string(out, m.name);
    out.push('}');
}

fn format(out: u8[>..]&, t: const Team&) {
    out.append("{\"id\":");
    json::format_int(out, t.id);
    out.append(",\"lead\":");
    format(out, t.lead);
    out.push('}');
}
