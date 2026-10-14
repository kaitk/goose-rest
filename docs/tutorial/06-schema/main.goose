// docs/tutorial.md, sections 6, 7, and 9: an API from api.json, whose
// router and types goose-rest gen writes into api_gen.goose, with the
// handlers in app.goose, and a hand-written route before it.
//
//   build/goose-rest gen docs/tutorial/06-schema/api.json -o docs/tutorial/06-schema/api_gen.goose
//   goose build -o build/projects docs/tutorial/06-schema/main.goose
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@e27ab215c8101a231a375cdfada182d3c9b388d7";
import rest from "../../../";
import .api_gen;
import .app;

// The longest upload PUT /uploads/:name takes, past the schema's longest
// body, api::MAX_BODY.
let UPLOAD_LIMIT: i64 = 2 * 1024 * 1024;

struct Upload { name: const u8[:], bytes: i64 }

fn format(out: u8[>..]&, u: const Upload&) {
    out.append("{\"name\":");
    json::format_string(out, u.name);
    format(out, ",\"bytes\":", u.bytes, "}");
}

fn handle(cx, state: app::App&) {
    var r = http::router(cx.req);
    if http::on(r, "PUT", "/uploads/:name") {
        rest::route(cx) { upload(cx, state, r); };
    } else {
        api::dispatch(cx, state, r.allow);
    }
}

// An upload of any bytes, which a schema can't describe: its bodies are JSON.
fn upload(cx, state: app::App&, r: const http::Router&) {
    app::security_token(cx, state);
    let data = rest::body(cx, UPLOAD_LIMIT);
    rest::json(cx, 200, Upload { name: rest::param(cx, r, "name"), bytes: data.len });
}

thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var state = app::App { projects: projects, token: "secret" };
    let e = rest::serve(cfg) { cx =>
        rest::timed(cx) { handle(cx, state); };
    };
    if e.code != 0 { http::report(e); }
}

fn main() {
    let a = args();
    var port: i64 = 8080;
    if a.len > 1 {
        let p, ok = parse_int(a[1]);
        if ok { port = p; }
    }
    assert(http::stop_on_signals() == 0);
    let cfg = http::Config { port: port as i32, workers: 1, max_body: max(api::MAX_BODY, UPLOAD_LIMIT), .. };
    thread_wait(thread_spawn(worker, cfg));
}
