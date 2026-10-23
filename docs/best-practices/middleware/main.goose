// docs/best-practices/middleware.md: middleware named for what it does, in
// middleware.goose, and a stack per audience, in stacks.goose, each scope
// behind one stack.
//
//   goose build -o build/middleware docs/best-practices/middleware/main.goose
//   build/middleware 8080
//   curl -s -H 'Authorization: Bearer ada' -H 'X-Organization: 1' localhost:8080/organization/projects
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.5.6";
import plod from "../../../";
import stacks;

fn handle(cx) {
    plod::timed(cx) {
        plod::cors(cx, plod::Cors { origins: "https://app.example", .. }) {
            plod::routes(cx) { cx =>
                public_routes(cx) { plod::get(cx, "/health") { plod::text(cx, 200, "ok"); }; };
                plod::scope(cx, "/settings") { user_routes(cx) { user => settings(cx, user); }; };
                plod::scope(cx, "/organization") { member_routes(cx) { member => projects(cx, member); }; };
            };
        };
    };
}

fn settings(cx, user: users::User) {
    plod::get(cx, "") { plod::text(cx, 200, str("the settings of user ", user.id)); };
}

fn projects(cx, member: members::Member) {
    plod::get(cx, "/projects") { plod::text(cx, 200, str("the projects of organization ", member.organization)); };
}

thread_fn worker(cfg: http::Config) {
    let e = plod::serve(cfg) { cx => handle(cx) };
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
    let cfg = http::Config { port: port as i32, .. };
    http::run(cfg, worker);
}
