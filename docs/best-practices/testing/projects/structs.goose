// The projects' types, and how they're written as JSON.
namespace projects;

import std;
import http;

struct Project { id: i64, name: u8[..64], archived: bool }

// What a client sends to create a project.
struct CreateInput { name: const u8[:] }

fn format(out: u8[>..]&, p: const Project&) {
    format(out, "{\"id\":", p.id, ",\"name\":");
    http::json_string(out, p.name);
    format(out, ",\"archived\":", p.archived, "}");
}
