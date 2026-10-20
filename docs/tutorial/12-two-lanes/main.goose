// docs/tutorial/12-two-lanes.md: what one job per route can't do. A
// project's tasks come back from the database in pieces, sent on as they
// come, and an invitation waits on the database, then on a mailer.
//
//   goose build -o build/invite docs/tutorial/12-two-lanes/main.goose
//   build/invite 8080
//   curl -s localhost:8080/v1/projects/1/tasks
//   curl -s -X POST 'localhost:8080/v1/projects/1/members?user=3'
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.4.1";
import rest from "../../../";
import db from "../db/";

let DELAY_MS: i64 = 20;

// Each lane's jobs.
enum DbJob {
    Tasks { project: i64 },
    AddMember { project: i64, user: i64 },
}
enum MailJob { Invite { project: i64, user: i64 } }

// What a route waits on: one lane or the other.
enum Use { None, Db, Mail }

struct St { use: Use = Use.None }

struct App { db: rest::Lane<DbJob, Use>, mailer: rest::Lane<MailJob, Use> }

struct Invited { project: i64, user: i64, mail: i64 }

fn format(out: u8[>..]&, i: const Invited&) { rest::format_fields(out, i); }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "GET", "/v1/projects/:id/tasks") {
            rest::route(cx) { rest::ask(cx, cx.app.db, DbJob.Tasks { project: rest::param_int(cx, "id") }); };
        } else if rest::on(cx, "POST", "/v1/projects/:id/members") {
            rest::route(cx) {
                let user, has_user = rest::query_int(cx, "user");
                rest::require(cx, "user", has_user);
                rest::ask(cx, cx.app.db, DbJob.AddMember { project: rest::param_int(cx, "id"), user: user });
            };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn resume(u: Use.None, cx) { rest::fail(cx, 500, "not_waiting"); }
fn resume(u: Use.Db, cx) { resume(rest::job<DbJob>(cx), cx); }
fn resume(u: Use.Mail, cx) { resume(rest::job<MailJob>(cx), cx); }

// On the database lane: the project's tasks as a JSON array, in pieces of
// the worker's message size, 64 bytes here.
fn run(u: DbJob.Tasks, c: db::Conn&, a) {
    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [u.project]);
    var out: u8[>..] = [];
    out.push('[');
    for t, i in ts {
        if i > 0 { out.push(','); }
        format(out, "{\"id\":", t.id, ",\"title\":");
        http::json_string(out, t.title);
        format(out, ",\"assignee\":", t.assignee, "}");
    }
    out.push(']');
    rest::reply(a, out);
}

// Called at the first piece, which starts a chunked response; the rest go on as chunks.
fn resume(u: DbJob.Tasks, cx) { rest::relay(cx, 200, "application/json"); }

fn run(u: DbJob.AddMember, c: db::Conn&, a) {
    db::begin(c);
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [u.project]);
    guard found else { db::rollback(c); rest::fail(a, 404, "project_not_found"); }
    let m, member = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [u.project, u.user]);
    guard !member else { db::rollback(c); rest::fail(a, 409, "already_a_member"); }
    db::execute(c, "INSERT INTO members (project, user) VALUES ($1, $2)", [u.project, u.user]);
    db::commit(c);
    // The job alone: the resume needs nothing more.
    rest::reply(a, "");
}

// The database added the member: ask the mailer next, and wait again. The
// job came back with the reply, so its project and user are at hand.
fn resume(u: DbJob.AddMember, cx) {
    rest::ask(cx, cx.app.mailer, MailJob.Invite { project: u.project, user: u.user });
}

// On the mailer: it numbers each invitation it sends.
fn run(u: MailJob.Invite, sent: i64&, a) {
    sleep_ms(DELAY_MS);
    sent++;
    rest::reply_value(a, sent);
}

fn resume(u: MailJob.Invite, cx) {
    rest::json(cx, 201, Invited { project: u.project, user: u.user, mail: rest::answer<i64>(cx) });
}

thread_fn database(box: http::Box, jobs: rest::Jobs<DbJob>) {
    var c = db::open(DELAY_MS);
    rest::lane(box, jobs) { u, a => run(u, c, a); };
}

thread_fn mailer(box: http::Box, jobs: rest::Jobs<MailJob>) {
    var sent: i64 = 0;
    rest::lane(box, jobs) { u, a => run(u, sent, a); };
}

thread_fn worker(cfg: http::Config, lanes: App) {
    var app = lanes;
    let e = rest::serve(cfg, app, St { .. }) { cx =>
        if rest::resumed(cx) {
            rest::on_reply(cx) { resume(cx.state.use, cx); };
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
    let app = App {
        db: rest::lane_open<DbJob>(http::LaneConfig { .. }, Use.Db, database),
        mailer: rest::lane_open<MailJob>(http::LaneConfig { .. }, Use.Mail, mailer),
    };
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, mail_size: 64, max_waiting: 1024, .. };
    http::run(cfg, app, worker);
    rest::lane_stop(app.db);
    rest::lane_stop(app.mailer);
}
