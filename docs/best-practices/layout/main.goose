// docs/best-practices/layout.md: an application laid out by domain. main
// starts the workers, dispatch.goose sends each audience's scope to the
// domains' routes, and each domain's folder holds its own code. One worker,
// as the projects live in its memory in place of a database.
//
//   goose build -o build/layout docs/best-practices/layout/main.goose
//   build/layout 8080
//   curl -s -H 'Authorization: Bearer ada' -H 'X-Organization: 1' localhost:8080/organization/projects
import std;
import os;
import http from "github.com/kaitk/goose-http@6e57c429ae1fa6dd01b5bc4c253eb4cf71a20aa7";
import rest from "../../../";
import dispatch;
import projects.structs;
import teams.structs;

// The worker state: what stands in for the database until goose-rest has
// database helpers.
struct App { projects: projects::Project[>..]&, teams: const teams::Team[:] }

let TEAMS = [
    teams::Team { id: 1, organization: 1, name: "design" },
    teams::Team { id: 2, organization: 2, name: "support" },
];

thread_fn worker(cfg: http::Config) {
    var projects: projects::Project[>..] = [];
    var app = App { projects: projects, teams: TEAMS };
    let e = rest::serve(cfg, app) { cx => handle(cx) };
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
