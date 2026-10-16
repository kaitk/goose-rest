// docs/tutorial/08-state.md: worker state and request state. One worker, so
// that the count below is the server's.
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../../";

struct User { name: u8[..64] }

// The request state, which starts from St { .. } for each request.
struct St { user: rest::Once<User> }

// The worker state, which lasts as long as the worker.
struct App { lookups: i64 }

type Cx = rest::Cx<St, App, http::Router>;

// The request's user, looked up on the first call in a request.
fn user(cx: Cx&) -> User& {
    return rest::once(cx.state.user) { lookup(cx) };
}

fn lookup(cx) -> User {
    let name, has = rest::header(cx, "X-User");
    guard has else { rest::fail(cx, 401, "unauthenticated"); }
    cx.app.lookups++;
    return User { name: name };
}

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/me") {
            rest::route(cx) {
                guard user(cx).name != "mallory" else { rest::fail(cx, 403, "forbidden"); }
                rest::text(cx, 200, str(user(cx).name, ", lookups so far: ", cx.app.lookups));
            };
        } else {
            rest::otherwise(cx);
        }
    };
}

thread_fn worker(cfg: http::Config) {
    var app = App { lookups: 0 };
    let e = rest::serve(cfg, app, St { .. }) { cx => handle(cx) };
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
