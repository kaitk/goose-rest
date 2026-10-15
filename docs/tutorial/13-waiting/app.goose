// The routes and their case functions, apart from main so that test.goose
// can import them.
import std;
import http;
import rest;
import db;
import service;

struct Project { id: i64, name: u8[..64], owner: i64 }

fn format(out: u8[>..]&, p: const Project&) {
    format(out, "{\"id\":", p.id, ",\"name\":");
    http::json_string(out, p.name);
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
    let r, ok = rest::read_reply<service::ProjectReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 200, project_of(r.project));
}

fn resume(w: Waiting.Assign, cx) {
    let r, ok = rest::read_reply<service::AssignReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::json(cx, 200, Assigned { task: w.task, assignee: w.assignee });
}
