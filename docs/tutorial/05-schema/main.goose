// docs/tutorial/05-schema.md: an API from api.json, whose router and types
// plod gen writes into api_gen.goose, with the handlers in app.goose,
// and a hand-written route before it.
//
//   build/plod gen docs/tutorial/05-schema/api.json -o docs/tutorial/05-schema/api_gen.goose
//   goose build -o build/projects docs/tutorial/05-schema/main.goose
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.10";
import plod from "../../../";
import .api_gen;
import .app;

// The longest upload PUT /uploads/:name takes, past the schema's longest
// body, api::MAX_BODY.
let UPLOAD_LIMIT: i64 = 2 * 1024 * 1024;

struct Upload { name: const u8[:], bytes: i64 }

fn format(out: u8[>..]&, u: const Upload&) { plod::format_fields(out, u); }

fn handle(cx) {
    plod::routes(cx) { cx =>
        plod::put(cx, "/uploads/:name") { upload(cx); };
        api::dispatch(cx);
    };
}

// An upload of any bytes, which a schema can't describe: its bodies are JSON.
fn upload(cx) {
    app::security_token(cx);
    let data = plod::body(cx, UPLOAD_LIMIT);
    plod::json(cx, 200, Upload { name: plod::param(cx, "name"), bytes: data.len });
}

thread_fn worker(cfg: http::Config) {
    var projects: api::Project[>..] = [];
    var app = app::App { projects: projects, token: "secret" };
    let e = plod::serve(cfg, app) { cx =>
        plod::timed(cx) { handle(cx); };
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
    http::exit_on_error(http::stop_on_signals());
    let cfg = http::Config { port: port as i32, workers: 1, max_body: max(api::MAX_BODY, UPLOAD_LIMIT), .. };
    http::run(cfg, worker);
}
