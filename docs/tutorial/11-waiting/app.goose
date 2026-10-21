// The routes and their resume case functions, apart from main so that
// test.goose can import them.
import std;
import http;
import rest;
import db;

struct Project { id: i64, name: u8[..64], owner: i64 }

fn format(out: u8[>..]&, p: const Project&) { rest::format_fields(out, p); }

fn project_of(p: const db::Project&) -> Project { Project { id: p.id, name: p.name, owner: p.owner } }

struct Assigned { task: i64, assignee: i64 }

fn format(out: u8[>..]&, a: const Assigned&) { rest::format_fields(out, a); }

// The database lane's jobs: a use case each, with what it needs.
enum DbJob {
    Project { id: i64 },
    Assign { project: i64, task: i64, user: i64, assignee: i64 },
}

// What a route waits on: here, the database lane.
enum Use { None, Db }

struct St { use: Use = Use.None }

// The worker state: a connection of its own, for the route that queries
// in place, and the database lane.
struct App { conn: db::Conn&, db: rest::Lane<DbJob, Use> }

fn handle(cx) {
    rest::routes(cx) { cx =>
        rest::get(cx, "/health") { rest::text(cx, 200, "ok"); };
        rest::scope(cx, "/v1") { v1(cx); };
    };
}

fn v1(cx) {
    rest::get(cx, "/in-place/projects/:id") {
        // Blocks the worker, and every connection it holds, for the query.
        let id = rest::param_int(cx, "id");
        let p, found = db::fetch_one<db::Project>(cx.app.conn, "SELECT * FROM projects WHERE id = $1", [id]);
        guard found else { rest::fail(cx, 404, "project_not_found"); }
        rest::json(cx, 200, project_of(p));
    };
    rest::get(cx, "/projects/:id") { rest::ask(cx, cx.app.db, DbJob.Project { id: rest::param_int(cx, "id") }); };
    rest::put(cx, "/projects/:id/tasks/:task/assignee") {
        let user, has_user = rest::header(cx, "X-User");
        rest::require(cx, "X-User", has_user);
        let assignee, has_assignee = rest::query_int(cx, "user");
        rest::require(cx, "user", has_assignee);
        // Returns at once; the reply comes to resume(u: DbJob.Assign, cx).
        rest::ask(cx, cx.app.db, DbJob.Assign {
            project: rest::param_int(cx, "id"), task: rest::param_int(cx, "task"),
            user: rest::int_of(cx, user, "X-User"), assignee: assignee,
        });
    };
}

// The resume case functions: one per Use variant, and one per job, when
// the reply comes.
fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// The database's reply carries its job back: resume again on it.
fn resume(u: Use.Db, cx) { resume(rest::job<DbJob>(cx), cx); }

fn resume(u: DbJob.Project, cx) {
    let p = rest::answer<db::Project>(cx);
    rest::json(cx, 200, project_of(p));
}

fn resume(u: DbJob.Assign, cx) { rest::json(cx, 200, rest::answer<Assigned>(cx)); }
