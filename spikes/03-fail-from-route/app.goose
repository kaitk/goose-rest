namespace app;

import std;
import rest;

struct Project { id: i64, name: const u8[:] }

fn find_project(cx: rest::Cx&, id: i64) -> Project {
    guard id != 0 else { rest::fail(cx, 404, "project_not_found"); }
    return Project { id: id, name: "goose" };
}

fn load(cx: rest::Cx&, id: i64) -> Project {
    let p = find_project(cx, id);
    guard p.id != 13 else { rest::fail(cx, 403, "forbidden"); }
    guard p.id != 7 else { rest::fail(cx, 400, cx.path); }
    return p;
}

fn get_project(cx: rest::Cx&, id: i64) {
    let p = load(cx, id);
    cx.status = 200;
    format(cx.body, "{\"id\":", p.id, ",\"name\":\"", p.name, "\"}");
}
