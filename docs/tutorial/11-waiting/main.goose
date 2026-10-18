// docs/tutorial/11-waiting.md: routes that wait on a database. One queries
// in place and holds up the worker; the others ask a lane, a thread that
// owns the connection, and resume when it answers. The routes are in
// app.goose, and the lane in database.goose.
//
//   goose build -o build/waiting docs/tutorial/11-waiting/main.goose
//   build/waiting 8080
//   curl -s localhost:8080/v1/projects/1
//   curl -s -X PUT -H 'X-User: 1' 'localhost:8080/v1/projects/1/tasks/3/assignee?user=2'
import std;
import os;
import http from "github.com/kaitk/goose-http@746f9567b5a51ca725b7e7e55f86cce8da703a56";
import rest from "../../../";
import db from "../db/";
import .database;
import .app;

// How long each statement takes, as a query over a network would.
let DELAY_MS: i64 = 20;

thread_fn worker(cfg: http::Config, to: http::MailAddress) {
    var conn = db::open(DELAY_MS);
    var app = App { conn: conn, db: to };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::route(cx) { resume(cx.state.waiting, cx); };
        } else {
            handle(cx);
        }
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
    let box, e = http::mail_open(64, 256);
    http::exit_on_error(e);
    let to = http::address(box, 0);
    let st = thread_spawn(database::run, box, DELAY_MS);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, to));
    // A flag in the box, not a message: a full box can't refuse it.
    http::mail_stop(box);
    thread_wait(st);
}
