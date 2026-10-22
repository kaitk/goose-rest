// docs/best-practices/middleware.md: middleware named for what it does, in
// middleware.goose, and a stack per audience, in stacks.goose, each scope
// behind one stack.
//
//   goose build -o build/middleware docs/best-practices/middleware/main.goose
//   build/middleware 8080
//   curl -s -H 'Authorization: Bearer ada' -H 'X-Organization: 1' localhost:8080/organization/projects
import std;
import os;
import http from "github.com/kaitk/goose-http@e128cb39d82c0fa45280452b1c434a55384e14d7";
import rest from "../../../";
import stacks;

fn handle(cx) {
    rest::timed(cx) {
        rest::cors(cx, rest::Cors { origins: "https://app.example", .. }) {
            rest::routes(cx) { cx =>
                public_routes(cx) { rest::get(cx, "/health") { rest::text(cx, 200, "ok"); }; };
                rest::scope(cx, "/settings") { user_routes(cx) { user => settings(cx, user); }; };
                rest::scope(cx, "/organization") { member_routes(cx) { member => projects(cx, member); }; };
            };
        };
    };
}

fn settings(cx, user: users::User) {
    rest::get(cx, "") { rest::text(cx, 200, str("the settings of user ", user.id)); };
}

fn projects(cx, member: members::Member) {
    rest::get(cx, "/projects") { rest::text(cx, 200, str("the projects of organization ", member.organization)); };
}

thread_fn worker(cfg: http::Config) {
    let e = rest::serve(cfg) { cx => handle(cx) };
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
