// docs/tutorial/14-two-lanes.md: what one job per route can't do. A
// project's tasks come back from the database in pieces, sent on as they
// come, and an invitation waits on the database, then on a mailer.
//
//   goose build -o build/invite docs/tutorial/14-two-lanes/main.goose
//   build/invite 8080
//   curl -s localhost:8080/v1/projects/1/tasks
//   curl -s -X POST 'localhost:8080/v1/projects/1/members?user=3'
import std;
import os;
import http from "github.com/kaitk/goose-http@v0.3.5";
import rest from "../../../";
import db from "../db/";

let DELAY_MS: i64 = 20;

// A job's tag.
let TASKS: i32 = 1;
let ADD_MEMBER: i32 = 2;
let SEND: i32 = 3;
let STOP: i32 = 4;

struct TasksJob { project: i64 }
struct MemberJob { project: i64, user: i64 }
struct MemberReply { status: i32 = 201, code: u8[..32] = "" }
struct MailJob { project: i64, user: i64 }
struct MailReply { id: i64 }

struct Invited { project: i64, user: i64, mail: i64 }

fn format(out: u8[>..]&, i: const Invited&) {
    format(out, "{\"project\":", i.project, ",\"user\":", i.user, ",\"mail\":", i.mail, "}");
}

enum Waiting {
    None,
    Tasks,
    Member { project: i64, user: i64 },
    Mail { project: i64, user: i64 },
}

struct St { waiting: Waiting = Waiting.None }

struct App { db: http::MailAddress, mailer: http::MailAddress }

fn handle(cx) {
    rest::routes(cx) { cx =>
        if rest::on(cx, "GET", "/health") {
            rest::text(cx, 200, "ok");
        } else if rest::on(cx, "GET", "/v1/projects/:id/tasks") {
            rest::route(cx) {
                rest::ask(cx, cx.app.db, TASKS, TasksJob { project: rest::param_int(cx, "id") }, Waiting.Tasks);
            };
        } else if rest::on(cx, "POST", "/v1/projects/:id/members") {
            rest::route(cx) {
                let user, has_user = rest::query_int(cx, "user");
                rest::require(cx, "user", has_user);
                let project = rest::param_int(cx, "id");
                rest::ask(cx, cx.app.db, ADD_MEMBER, MemberJob { project: project, user: user },
                          Waiting.Member { project: project, user: user });
            };
        } else {
            rest::otherwise(cx);
        }
    };
}

fn resume(w: Waiting.None, cx) { rest::fail(cx, 500, "not_waiting"); }

// Called for each piece of the reply: rest::relay sends the first, and the
// ones after it, as a chunked response.
fn resume(w: Waiting.Tasks, cx) { rest::relay(cx, 200, "application/json"); }

// The database added the member: ask the mailer next, and wait again.
fn resume(w: Waiting.Member, cx) {
    let r, ok = rest::read_reply<MemberReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    guard r.status < 400 else { rest::fail(cx, r.status, r.code); }
    rest::ask(cx, cx.app.mailer, SEND, MailJob { project: w.project, user: w.user },
              Waiting.Mail { project: w.project, user: w.user });
}

fn resume(w: Waiting.Mail, cx) {
    let r, ok = rest::read_reply<MailReply>(cx);
    guard ok else { rest::fail(cx, 502, "bad_reply"); }
    rest::json(cx, 201, Invited { project: w.project, user: w.user, mail: r.id });
}

// The project's tasks as a JSON array, or null for a project that doesn't
// exist.
fn tasks_json(c: db::Conn&, j: TasksJob) -> u8[>..] {
    let ts = db::fetch_all<db::Task>(c, "SELECT * FROM tasks WHERE project = $1 ORDER BY id", [j.project]);
    var out: u8[>..] = [];
    out.push('[');
    for t, i in ts {
        if i > 0 { out.push(','); }
        format(out, "{\"id\":", t.id, ",\"title\":");
        http::json_string(out, t.title);
        format(out, ",\"assignee\":", t.assignee, "}");
    }
    out.push(']');
    return out;
}

fn add_member(c: db::Conn&, j: MemberJob) -> MemberReply {
    db::begin(c);
    let p, found = db::fetch_one<db::Project>(c, "SELECT * FROM projects WHERE id = $1", [j.project]);
    guard found else { db::rollback(c); return MemberReply { status: 404, code: "project_not_found" }; }
    let m, member = db::fetch_one<db::Member>(c, "SELECT * FROM members WHERE project = $1 AND user = $2", [j.project, j.user]);
    guard !member else { db::rollback(c); return MemberReply { status: 409, code: "already_a_member" }; }
    db::execute(c, "INSERT INTO members (project, user) VALUES ($1, $2)", [j.project, j.user]);
    db::commit(c);
    return MemberReply { .. };
}

thread_fn database(box: http::Box) {
    var c = db::open(DELAY_MS);
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == TASKS {
                let a, ok = rest::asked<TasksJob>(bytes);
                // In pieces of the worker's message size, 64 bytes here.
                if ok { rest::reply(a, tasks_json(c, a.job)); }
            } else if tag == ADD_MEMBER {
                let a, ok = rest::asked<MemberJob>(bytes);
                if ok { rest::reply_value(a, add_member(c, a.job)); }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

// The mailer: it numbers each invitation it sends.
thread_fn mailer(box: http::Box) {
    var sent = 0;
    var running = true;
    while running {
        http::mail_wait(box, 1000);
        http::mail_take(box) { key, tag, bytes =>
            if tag == SEND {
                let a, ok = rest::asked<MailJob>(bytes);
                if ok {
                    sleep_ms(DELAY_MS);
                    sent++;
                    rest::reply_value(a, MailReply { id: sent });
                }
            } else if tag == STOP {
                running = false;
            }
        };
    }
    http::mail_close(box);
}

thread_fn worker(cfg: http::Config, to_db: http::MailAddress, to_mailer: http::MailAddress) {
    var app = App { db: to_db, mailer: to_mailer };
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
    let dbox, e = http::mail_open(64, 256);
    http::exit_on_error(e);
    let mbox, e2 = http::mail_open(64, 256);
    http::exit_on_error(e2);
    let to_db = http::address(dbox, 0);
    let to_mailer = http::address(mbox, 0);
    let dt = thread_spawn(database, dbox);
    let mt = thread_spawn(mailer, mbox);
    let cfg = http::Config { port: port as i32, workers: 1, mail_slots: 64, mail_size: 64, max_waiting: 1024, .. };
    thread_wait(thread_spawn(worker, cfg, to_db, to_mailer));
    http::mail_send(to_db, STOP, "");
    http::mail_send(to_mailer, STOP, "");
    thread_wait(dt);
    thread_wait(mt);
}
