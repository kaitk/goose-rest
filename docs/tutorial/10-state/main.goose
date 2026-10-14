// docs/tutorial.md, section 10: state per worker, and per request. One
// worker, so that the count below is the server's.
import std;
import os;
import http from "github.com/kaitk/goose-http@bc75f2a6e761cb35096b740329d9f8044d027b3c";
import rest from "../../../";

struct User { name: u8[..64] }

// The per-request state, which starts from St { .. } for each request.
struct St { user: rest::Once<User> }

// The per-worker state, which lasts as long as the worker.
struct App { lookups: i64 }

// The request's user, looked up on the first call in a request.
fn user(cx, app: App&) -> User& {
    return rest::once(cx.state.user) { lookup(cx, app) };
}

fn lookup(cx, app: App&) -> User {
    let name, has = rest::header(cx, "X-User");
    guard has else { rest::fail(cx, 401, "unauthenticated"); }
    app.lookups++;
    return User { name: name };
}

fn handle(cx, app: App&) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/me") {
        rest::route(cx) {
            guard user(cx, app).name != "mallory" else { rest::fail(cx, 403, "forbidden"); }
            rest::text(cx, 200, str(user(cx, app).name, ", lookups so far: ", app.lookups));
        };
    } else {
        rest::otherwise(cx, r);
    }
}

thread_fn worker(cfg: http::Config) {
    var app = App { lookups: 0 };
    let e = rest::serve(cfg, St { .. }) { cx => handle(cx, app) };
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
    let cfg = http::Config { port: port as i32, workers: 1, .. };
    thread_wait(thread_spawn(worker, cfg));
}
