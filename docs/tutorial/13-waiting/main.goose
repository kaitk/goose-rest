// docs/tutorial/13-waiting.md: routes that wait on a database. One queries
// in place and holds up the worker; the others ask a service thread, which
// owns the connection, and resume when it answers.
//
//   goose build -o build/waiting docs/tutorial/13-waiting/main.goose
//   build/waiting 8080
//   curl -s localhost:8080/v1/projects/1
//   curl -s -X PUT -H 'X-User: 1' 'localhost:8080/v1/projects/1/tasks/3/assignee?user=2'
import std;
import os;
import json;
import http from "github.com/kaitk/goose-http@v0.3.1";
import rest from "../../../";
import db from "../db/";
import .service;

// How long each statement takes, as a query over a network would.
let DELAY_MS: i64 = 20;

struct Project { id: i64, name: u8[..64], owner: i64 }

fn format(out: u8[>..]&, p: const Project&) {
    format(out, "{\"id\":", p.id, ",\"name\":");
    json::format_string(out, p.name);
    format(out, ",\"owner\":", p.owner, "}");
}

fn project_of(p: const db::Project&) -> Project { Project { id: p.id, name: p.name, owner: p.owner } }

struct Assigned { task: i64, assignee: i64 }

fn format(out: u8[>..]&, a: const Assigned&) {
    format(out, "{\"task\":", a.task, ",\"assignee\":", a.assignee, "}");
}

// What each route that waits needs when its reply comes.
enum Waiting {
    None,
    Project,
    Assign { task: i64, assignee: i64 },
}

struct St { waiting: Waiting = Waiting.None }

// The worker's state: a connection of its own, for the route that queries
// in place, and where the service takes jobs.
struct App { conn: db::Conn&, db: http::MailAddress }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::scope(cx, "/v1") {
            rest::route(cx) { v1(cx); };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn v1(cx) {
    if rest::on(cx, "GET", "/in-place/projects/:id") {
        // Blocks the worker, and every connection it holds, for the query.
        let id = rest::param_int(cx, "id");
        let p, found = db::fetch_one<db::Project>(cx.app.conn, "SELECT * FROM projects WHERE id = $1", [id]);
        guard found else { rest::fail(cx, 404, "project_not_found"); }
        rest::json(cx, 200, project_of(p));
    } else if rest::on(cx, "GET", "/projects/:id") {
        let job = service::ProjectJob { id: rest::param_int(cx, "id") };
        rest::ask(cx, cx.app.db, service::PROJECT, job, Waiting.Project);
    } else if rest::on(cx, "PUT", "/projects/:id/tasks/:task/assignee") {
        let user, has_user = rest::header(cx, "X-User");
        rest::require(cx, "X-User", has_user);
        let assignee, has_assignee = rest::query_int(cx, "user");
        rest::require(cx, "user", has_assignee);
        let job = service::AssignJob {
            project: rest::param_int(cx, "id"), task: rest::param_int(cx, "task"),
            user: rest::int_of(cx, user, "X-User"), assignee: assignee,
        };
        rest::ask(cx, cx.app.db, service::ASSIGN, job, Waiting.Assign { task: job.task, assignee: assignee });
    } else {
        rest::otherwise(cx);
    }
}

// The case functions, one per Waiting variant, when the reply comes.
fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

fn resume(w: Waiting.Project, cx) {
    let r, ok = rest::reply_value<service::ProjectReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 200, project_of(r.project));
}

fn resume(w: Waiting.Assign, cx) {
    let r, ok = rest::reply_value<service::AssignReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 200, Assigned { task: w.task, assignee: w.assignee });
}

thread_fn worker(cfg: http::Config, to: http::MailAddress) {
    var conn = db::open(DELAY_MS);
    var app = App { conn: conn, db: to };
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::woken(cx) {
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
    let st = thread_spawn(service::run, box, DELAY_MS);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, to));
    http::mail_send(to, service::STOP, "");
    thread_wait(st);
}
